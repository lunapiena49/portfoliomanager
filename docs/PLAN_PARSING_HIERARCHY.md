# PIANO IMPLEMENTAZIONE -- Gerarchia Parsing 3 Livelli (Specifico -> Euristico -> AI Gemini)

> Target esecutore: Claude Opus 4.7 (max effort / 1M context).
> Stato redazione: 2026-04-18.
> Obiettivo: rendere l'import portafoglio resiliente ai cambi di formato dei broker, trasformando il parser in un sistema a cascata con ultima spiaggia AI.

---

## 0. Contesto e principi

### 0.1 Problema
I broker cambiano spesso il layout dei CSV/PDF di export. Ogni cambio rompe il parser dedicato e l'utente resta bloccato all'import. Il `GenericCSVParser` copre solo il caso CSV molto standard.

### 0.2 Soluzione: cascata deterministica + consenso AI
```
File utente
   |
   v
[Layer 1 - Specifico]  parser broker dedicato (12 esistenti + PDF extractor)
   | FAIL
   v
[Layer 2 - Euristico]  heuristic_parser: keyword multi-lingua (EN/IT), score per
   | FAIL              colonna, conferma utente su mapping proposto
   v
[Layer 3 - AI Gemini]  dialog consenso -> (se key manca) redirect settings ->
                       back to import -> Gemini structured extraction -> conferma
```

### 0.3 Vincoli non negoziabili
- **ASCII-only** nel codice Dart, PowerShell, Python, YAML, JSON config. Solo i file `assets/translations/*.json` (UTF-8) contengono italiano accentato.
- **Niente Provider/Riverpod**: restiamo su `flutter_bloc`.
- **Privacy**: il contenuto del file va a Gemini **solo** dopo consenso esplicito dell'utente per quel singolo file. Nessun opt-in globale silenzioso.
- **API key**: mai hardcoded, letta da `flutter_secure_storage` attraverso `SettingsBloc`.
- **Traduzioni su 6 lingue** (it/en/es/fr/de/pt) sincrone -- mai committare una chiave in meno di 6 file.
- **BLoC discipline**: un evento -> una transizione di stato, niente side-effect nei widget.
- **Test**: ogni layer ha test dedicati con fixture CSV/PDF in `test/fixtures/`.
- **Backward compatible**: tutti i parser specifici esistenti continuano a funzionare invariati.

### 0.4 Metriche di successo
- Un file DEGIRO storico passa ancora da Layer 1 (parser specifico) -- zero regressioni.
- Un CSV non riconosciuto ma con colonne in italiano ("ISIN","Quantita","Prezzo","Valore") viene parsato in Layer 2 senza AI, conferma mapping ottenuta con un tap.
- Un CSV "strano" (ordine colonne arbitrario, header multilinea, separatore `;`) triggera il dialog AI, completa l'estrazione, popola posizioni corrette.
- Tempo percepito totale <= 20s per Layer 3 su file <100KB.
- Zero token Gemini bruciati senza consenso esplicito utente.

---

## 1. Architettura target

### 1.1 Nuovo modulo: `ParseOrchestrator`

File: [lib/services/parsers/parse_orchestrator.dart](../lib/services/parsers/parse_orchestrator.dart) (da creare)

Punto d'ingresso unico chiamato dal `PortfolioBloc`. Sostituisce l'attuale `_parseImportFile()` in `import_page.dart`. Ritorna non solo `Portfolio`, ma un `ParseResult` strutturato:

```dart
enum ParseStage { specific, heuristic, ai, failed }

class ParseResult {
  final Portfolio? portfolio;
  final ParseStage stage;               // quale layer ha avuto successo (o 'failed')
  final ParseConfidence confidence;     // low | medium | high
  final List<ParseWarning> warnings;    // errori colonna non mappate, assunzioni, etc.
  final HeuristicMapping? mapping;      // se stage == heuristic, mapping proposto
  final String? aiRawResponse;          // se stage == ai, utile per debug
  final Duration elapsed;
}

class ParseRequest {
  final Uint8List bytes;
  final String fileName;
  final String? hintBrokerId;           // opzionale, se utente ha scelto broker
  final bool allowHeuristic;            // default true
  final bool allowAi;                   // default false: richiede chiamante abiliti dopo consenso
  final String? geminiApiKey;           // null se non disponibile -> allowAi=true fallira' pulito
  final String userLocale;              // per prompt Gemini e keyword euristiche (it/en/...)
}
```

API pubblica:
```dart
Future<ParseResult> run(ParseRequest req);
```

**Flusso interno:**
1. Detect formato (csv/pdf) da `fileName` + sniff dei primi bytes.
2. **Stage specific**: se `hintBrokerId` != null e != 'other' -> prova `BrokerParserFactory.parseWithBroker()`; se `hintBrokerId` == null -> prova `autoParseCSV` con soglia detection >= 5 (alza la soglia attuale da 4 per ridurre falsi positivi).
3. Se Stage 1 fallisce o ritorna 0 posizioni, **Stage heuristic**: `HeuristicParser.tryParse()` (vedi sezione 3).
4. Se Stage 2 fallisce (o confidence == low e `allowAi == false`), ritorna `ParseResult(stage: failed, ...)`.
5. Se Stage 2 fallisce e `allowAi == true`, **Stage AI**: `AiParser.parse()` (vedi sezione 4).

Mai chiamare Stage AI senza `allowAi == true`.

### 1.2 Perche' non rompere `BrokerParserFactory`
La factory resta come Stage 1 interno. `ParseOrchestrator` e' un super-layer. Questo mantiene i test esistenti verdi e isola il nuovo codice.

---

## 2. Fase 0 -- Scaffolding (commit #1)

### 2.1 Deliverable
- Skeleton file + tipi comuni, nessun cambio comportamentale.

### 2.2 File da creare
1. [lib/services/parsers/parse_orchestrator.dart](../lib/services/parsers/parse_orchestrator.dart) -- `ParseOrchestrator`, stub `run()` che delega a `BrokerParserFactory` (comportamento invariato).
2. [lib/services/parsers/parse_result.dart](../lib/services/parsers/parse_result.dart) -- `ParseResult`, `ParseStage`, `ParseConfidence`, `ParseWarning`, `ParseRequest`, `HeuristicMapping`. Tutti `Equatable`.
3. [lib/services/parsers/heuristic_parser.dart](../lib/services/parsers/heuristic_parser.dart) -- stub vuoto con firma `tryParse(...)`, ritorna null (implementazione in Fase 2).
4. [lib/services/parsers/ai_parser.dart](../lib/services/parsers/ai_parser.dart) -- stub vuoto con firma `parse(...)`, throws UnimplementedError (impl in Fase 3).

### 2.3 Done criteria
- `rtk flutter analyze` pulito.
- `rtk flutter test` verde (nessun test aggiunto in questa fase).
- `ParseOrchestrator.run()` chiamabile ma non ancora collegato al bloc.

---

## 3. Fase 1 -- Rinforzo Layer Specifico (commit #2)

### 3.1 Obiettivo
Aumentare precisione dell'auto-detect + evitare falsi positivi.

### 3.2 Modifiche a `parser_factory.dart`
- File: [lib/services/parsers/parser_factory.dart](../lib/services/parsers/parser_factory.dart)
- Alza `detectBroker` threshold da 4 a 5.
- Aggiungi pattern IT per broker europei (DEGIRO IT, Fineco, Trading212 EU).
- Ritorna tuple `(brokerId, score)` (helper interno) per consentire al `ParseOrchestrator` di decidere se fidarsi o delegare a Stage 2.

### 3.3 PDF: hardening
- File: [lib/services/parsers/pdf_import_parser.dart](../lib/services/parsers/pdf_import_parser.dart)
- Separa due stadi: `extractText(bytes)` -> raw pages; `textToCsvCandidate(pages)` -> best-effort CSV.
- Se `textToCsvCandidate` produce CSV con meno di 2 colonne riconosciute, ritorna null invece di lanciare eccezione (lascia a `ParseOrchestrator` decidere fallback).

### 3.4 Test
- `test/services/parsers/parser_factory_test.dart` (nuovo): 6 test che verificano detection score per sample headers di 6 broker + caso ambiguo.
- `test/fixtures/` (nuovo): aggiungere `ibkr_sample.csv`, `fidelity_sample.csv`, `degiro_sample.csv`, `trading212_sample.csv`, `robinhood_sample.csv`, `ambiguous_sample.csv`. File anonimizzati, max 10 posizioni ciascuno, no dati personali.

### 3.5 Done criteria
- `rtk flutter analyze` pulito.
- Tutti i nuovi test verdi.
- Nessun test esistente rotto.

---

## 4. Fase 2 -- Layer Euristico potente (commit #3)

### 4.1 Obiettivo
Sostituire `GenericCSVParser` con un `HeuristicParser` che:
- Mappa colonne via dizionario keyword multi-lingua.
- Supporta separatori `,` `;` `\t`.
- Supporta header multilinea (merge prime 2 righe se seconda e' sottotitolo).
- Parsa numeri EU (1.234,56) e US (1,234.56) auto-detectando il formato.
- Ritorna `HeuristicMapping` con confidence e lista warning.

### 4.2 Dizionario keyword

File: [lib/services/parsers/heuristic_keywords.dart](../lib/services/parsers/heuristic_keywords.dart)

Struttura (esempio):
```dart
const Map<String, List<String>> heuristicKeywords = {
  'symbol':    ['symbol', 'ticker', 'simbolo', 'sigla', 'codice', 'code'],
  'name':      ['name', 'description', 'nome', 'descrizione', 'titolo', 'security'],
  'quantity':  ['quantity', 'qty', 'shares', 'units', 'quantita', 'quantitA',
                'numero', 'pezzi', 'unita'],
  'price':     ['price', 'close', 'last', 'prezzo', 'corso', 'quotazione'],
  'value':     ['value', 'market value', 'valore', 'controvalore', 'mkt value'],
  'cost':      ['cost', 'cost basis', 'book value', 'costo', 'prezzo medio',
                'investito', 'pmc'],
  'pnl':       ['pnl', 'gain', 'profit', 'plusvalenza', 'guadagno',
                'perdita', 'unrealized'],
  'currency':  ['currency', 'ccy', 'valuta', 'divisa'],
  'isin':      ['isin'],
  'exchange':  ['exchange', 'market', 'borsa', 'mercato'],
  'asset_type':['type', 'asset', 'tipo', 'strumento', 'categoria'],
  'sector':    ['sector', 'settore', 'industry', 'industria'],
};
```

**Regola ASCII**: le keyword italiane perdono gli accenti ("quantita" senza "a' " finale). Matching e' case-insensitive e ignora accenti quando possibile (normalizza input header prima del match: lowercase + rimuovi diacritici).

### 4.3 Algoritmo

File: [lib/services/parsers/heuristic_parser.dart](../lib/services/parsers/heuristic_parser.dart)

```dart
class HeuristicParser {
  static ParseResult? tryParse({
    required String csvContent,
    required String userLocale,
  });
}
```

Step:
1. **Normalizzazione input**: rimuovi BOM, trim righe vuote, prende prime 50 righe.
2. **Delimiter detection**: conta occorrenze di `,` `;` `\t` nelle prime 5 righe non vuote, vince il piu' frequente con almeno 2 occorrenze/riga (soglia 3 colonne minime).
3. **Header detection**: cerca la prima riga in cui almeno 3 celle matchano keyword canoniche. Se non trovata -> ritorna null.
4. **Column mapping**: per ogni cella header, calcola score = max similarita' (Levenshtein normalizzata o substring containment + bonus locale utente). Assegna ogni cella al campo canonico con score maggiore, purche' >= 0.6. Campi opzionali (isin, exchange, asset_type, sector) mappati solo se score >= 0.75.
5. **Validazione minimo**: deve avere mapping per almeno `symbol_or_name`, `quantity`, `price_or_value`. Altrimenti null.
6. **Parsing righe dati**: righe successive header, trim, skip righe che non hanno celle numeriche nelle posizioni mappate.
7. **Number format detection**: se la cella prezzo contiene `,` e non `.` -> formato EU; se contiene `.` e non `,` -> US; se entrambi -> il separatore che sta prima di max 2 cifre e' decimale. `BaseBrokerParser.parseDoubleSafe` gia' supporta molti casi, aggiungere `parseLocaleAwareDouble`.
8. **Currency default**: se colonna currency mancante, usa `defaultCurrency` inferito da locale utente (it -> EUR, en-US -> USD, etc.).
9. **Post-processing**: chiama `BaseBrokerParser.normalizeAndDeduplicatePositions()`.
10. **Confidence scoring**:
    - `high` se mapping copre >= 6 campi e zero warning.
    - `medium` se mapping copre 4-5 campi o 1-3 warning.
    - `low` altrimenti.

Ritorna `ParseResult(stage: heuristic, confidence: ..., mapping: ..., warnings: ...)`.

### 4.4 UI: dialog di conferma mapping

File: [lib/features/portfolio/presentation/widgets/heuristic_mapping_dialog.dart](../lib/features/portfolio/presentation/widgets/heuristic_mapping_dialog.dart) (nuovo)

Mostrato dal bloc quando `stage == heuristic && confidence != high`. Contenuto:
- Tabella "Colonna nel file" -> "Campo portafoglio" con dropdown editabile.
- Preview prime 3 righe mappate.
- Bottoni: "Conferma" (procedi con mapping mostrato) | "Annulla" (aborta import) | "Prova con AI" (se key presente, escalate a Stage 3; se no, redirect settings).

### 4.5 Test
- `test/services/parsers/heuristic_parser_test.dart` (nuovo):
  - 8 test coprenti: CSV standard EN, CSV IT con accenti, separatore `;`, separatore `\t`, numeri EU, numeri US, header multilinea, CSV senza header riconoscibile (deve ritornare null).
- Fixtures in `test/fixtures/heuristic/`:
  - `en_standard.csv`, `it_accented.csv`, `eu_semicolon.csv`, `tab_separated.tsv`, `mixed_numbers.csv`, `multiline_header.csv`, `unknown_columns.csv`.

### 4.6 Done criteria
- `rtk flutter analyze` pulito.
- Tutti i test Fase 2 verdi.
- `GenericCSVParser` segnato deprecato (commento `@deprecated` + redirect interno a `HeuristicParser`), non cancellato in questa fase (cancellazione in Fase 7).

---

## 5. Fase 3 -- Layer AI Gemini (commit #4)

### 5.1 Obiettivo
Implementare `AiParser` che usa Gemini per estrarre posizioni da qualsiasi file testuale.

### 5.2 Estensione `GeminiService`

File: [lib/services/api/gemini_service.dart](../lib/services/api/gemini_service.dart)

Aggiungere metodo dedicato:
```dart
Future<List<Map<String, dynamic>>> extractPositionsFromDocument({
  required String documentContent,
  required String fileName,
  required String userLocale,
});
```

**Prompt engineering (system prompt):**
```
You are a financial data extraction assistant. Given the raw content of a broker
statement (CSV or extracted PDF text), extract a JSON array of positions.

Each position MUST conform to this schema:
{
  "symbol": "string, ticker (e.g., AAPL, MSFT)",
  "name": "string, security full name",
  "isin": "string or null, 12 chars if present",
  "quantity": "number, units held",
  "price": "number, price per unit, numeric only",
  "value": "number, market value",
  "cost_basis": "number or null, total invested",
  "currency": "string, ISO 4217 (USD, EUR, GBP, ...)",
  "asset_type": "one of: Stocks, ETFs, Bonds, Crypto, Options, Futures, Funds, Commodities, CFDs, Cash, Other",
  "exchange": "string or null"
}

Rules:
- Return ONLY a JSON array. No markdown, no prose, no backticks.
- If a value is missing, use null. Never invent prices.
- Numbers must be JSON numbers (not strings), using period as decimal separator.
- If the document contains transactions (buy/sell) instead of positions,
  aggregate per symbol and return the net position.
- If no positions are present, return [].
- Respond in English regardless of document language.

Document language hint: {userLocale}
File name: {fileName}
```

**User prompt**: contenuto del file (truncato a `AppConstants.aiParserMaxChars = 48000` per restare sotto limite token Gemini Flash).

**Response parsing**:
- Tenta `jsonDecode(response)` diretto.
- Se fallisce, estrai primo blocco `[ ... ]` via regex, riprova decode.
- Se ancora fallisce -> `FormatException('AI response not valid JSON')`.
- Valida ogni elemento: skip se manca `symbol` e `name`; coerce tipi numerici.

**Error mapping** (aggiungi a `_mapDioException`):
- 401/403 -> `AiParserException.invalidKey`
- 429 -> `AiParserException.rateLimited`
- timeout -> `AiParserException.timeout`

### 5.3 `AiParser`

File: [lib/services/parsers/ai_parser.dart](../lib/services/parsers/ai_parser.dart)

```dart
class AiParser {
  final GeminiService geminiService;
  AiParser(this.geminiService);

  Future<ParseResult> parse({
    required String documentContent,
    required String fileName,
    required String userLocale,
  });
}
```

Flusso:
1. Se `geminiService.hasApiKey == false` -> lancia `AiParserException.noApiKey`.
2. Chiama `geminiService.extractPositionsFromDocument(...)`.
3. Mappa ogni dict JSON a `Position` (via factory statica `Position.fromAiPayload(Map<String,dynamic>)` in `portfolio_entities.dart`).
4. Chiama `BaseBrokerParser.normalizeAndDeduplicatePositions(...)`.
5. Costruisce `Portfolio` con `broker: 'ai-extracted'`, `accountName: fileName`, `baseCurrency: mostFrequentCurrency`.
6. Ritorna `ParseResult(stage: ai, confidence: medium, ...)`.

### 5.4 Test
- `test/services/parsers/ai_parser_test.dart` con `GeminiService` mockato (Mockito o fake).
  - Test 1: risposta JSON valida -> posizioni parsate.
  - Test 2: risposta con markdown fences (` ```json `) -> regex extraction funziona.
  - Test 3: risposta invalida -> FormatException.
  - Test 4: noApiKey -> AiParserException.
- Mai chiamate reali a Gemini nei test unit.

### 5.5 Done criteria
- `rtk flutter analyze` pulito.
- Tutti i test Fase 3 verdi.
- `AiParser` isolato, non ancora collegato al bloc.

---

## 6. Fase 4 -- Integrazione UI e Bloc (commit #5)

### 6.1 Nuovi eventi bloc

File: [lib/features/portfolio/presentation/bloc/portfolio_bloc.dart](../lib/features/portfolio/presentation/bloc/portfolio_bloc.dart)

Eventi:
- `ImportFileAnalyzeEvent({files, broker, target, portfolioName, portfolioId})` -- entry point unico. Sostituisce logicamente l'accoppiata `CreatePortfolioFromImportEvent`/`AddPositionsFromImportEvent` ma le mantiene come handler terminali (dopo conferma).
- `ImportHeuristicMappingConfirmedEvent({adjustedMapping})` -- user ha confermato/modificato il mapping.
- `ImportAiConsentGivenEvent()` -- user ha acconsentito a inviare file a Gemini.
- `ImportRetryAfterApiKeyEvent()` -- triggerato quando rientra in ImportPage dopo inserimento key.

### 6.2 Nuovi stati
- `PortfolioImportAnalyzing(fileName)` -- sta processando.
- `PortfolioImportAwaitingHeuristicConfirm(result, fileName)` -- aspetta conferma mapping.
- `PortfolioImportAwaitingAiConsent(fileName, reason)` -- aspetta OK user per AI.
- `PortfolioImportAwaitingApiKey(pendingFiles, broker, target)` -- user deve inserire key Gemini; bloc conserva context per retry.
- `PortfolioImportAiInProgress(fileName)` -- AI sta girando.
- `PortfolioImportFailed(stage, reason, retryable)` -- failure terminale con hint azione.

### 6.3 Orchestrazione handler

```
ImportFileAnalyzeEvent
  -> emit PortfolioImportAnalyzing
  -> per ogni file: orchestrator.run(allowAi=false)
  -> se tutti stage=specific o (stage=heuristic && confidence=high)
        -> finalize (save + emit PortfolioImportSuccess)
  -> se stage=heuristic && confidence<high
        -> emit PortfolioImportAwaitingHeuristicConfirm
  -> se stage=failed
        -> se geminiApiKey presente
              -> emit PortfolioImportAwaitingAiConsent
           altrimenti
              -> emit PortfolioImportAwaitingApiKey

ImportHeuristicMappingConfirmedEvent
  -> applica mapping (ri-parse con override)
  -> finalize

ImportAiConsentGivenEvent
  -> emit PortfolioImportAiInProgress
  -> orchestrator.run(allowAi=true)
  -> se success -> finalize
  -> se fail -> emit PortfolioImportFailed

ImportRetryAfterApiKeyEvent
  -> se state == PortfolioImportAwaitingApiKey
        -> ri-lancia ImportFileAnalyzeEvent con stessi input
```

### 6.4 Widget UI aggiornati

File: [lib/features/portfolio/presentation/pages/import_page.dart](../lib/features/portfolio/presentation/pages/import_page.dart)

`BlocListener<PortfolioBloc, PortfolioState>`:
- `PortfolioImportAnalyzing` -> full-screen loader con fileName + stage corrente (testo i18n).
- `PortfolioImportAwaitingHeuristicConfirm` -> push `HeuristicMappingDialog`.
- `PortfolioImportAwaitingAiConsent` -> push `AiConsentDialog` (vedi 6.5).
- `PortfolioImportAwaitingApiKey` -> navigate `/settings?highlight=gemini&returnTo=/home/import` (vedi Fase 5).
- `PortfolioImportAiInProgress` -> loader "AI sta analizzando il tuo file...".
- `PortfolioImportFailed` -> dialog errore con bottone "Riprova" o "Segnala".

### 6.5 `AiConsentDialog`

File: [lib/features/portfolio/presentation/widgets/ai_consent_dialog.dart](../lib/features/portfolio/presentation/widgets/ai_consent_dialog.dart)

Contenuto:
- Titolo: "Usa l'AI per leggere questo file?"
- Testo: spiega che il contenuto (prime N righe + struttura, non i saldi) sara' inviato a Google Gemini. Elenca: cosa viene inviato, cosa NON viene inviato (API key, altri portafogli), link privacy policy.
- Checkbox opzionale: "Non chiedermelo piu' per questa sessione" (flag in memoria bloc, non persistito).
- Bottoni: "Annulla" | "Usa l'AI".

### 6.6 Done criteria
- Utente che carica CSV DEGIRO standard arriva a success senza vedere dialog aggiuntivi (non-regression).
- Utente che carica CSV custom in italiano vede heuristic dialog con mapping suggerito.
- Utente che carica CSV inparsabile senza API key viene portato in settings con banner "Inserisci key Gemini per completare import".
- Utente che carica CSV inparsabile con API key vede consent dialog, accetta, vede loader, vede success.

---

## 7. Fase 5 -- Routing, guard, return-to (commit #6)

### 7.1 Modifiche a `app_router.dart`

File: [lib/app_router.dart](../lib/app_router.dart)

Aggiungere support per queryParams `returnTo` e `highlight` sulla rotta `/settings`:
```dart
GoRoute(
  path: RouteNames.settings,
  builder: (context, state) {
    final returnTo = state.uri.queryParameters['returnTo'];
    final highlight = state.uri.queryParameters['highlight']; // 'gemini'
    return SettingsPage(returnTo: returnTo, highlight: highlight);
  },
),
```

### 7.2 `SettingsPage` aggiornata

File: [lib/features/settings/presentation/pages/settings_page.dart](../lib/features/settings/presentation/pages/settings_page.dart)

- Accetta `returnTo` e `highlight` come props.
- Se `highlight == 'gemini'`, auto-scroll alla tile Gemini + lampeggio glow 2s (usa `AnimationController` ciclo singolo).
- Dopo `UpdateGeminiApiKeyEvent` + test connection success: se `returnTo != null`, mostra snackbar "Key salvata. Torna all'import?" con bottone "Torna" che fa `context.go(returnTo + '?resumeImport=1')`.

### 7.3 `ImportPage` resume

- In `initState`, legge `state.uri.queryParameters['resumeImport']`. Se == '1' e bloc ha stato `PortfolioImportAwaitingApiKey`, dispatcha `ImportRetryAfterApiKeyEvent`.
- Il bloc conserva in memoria (non disco) gli input dell'ultima richiesta fallita -- nessuna persistenza di file bytes oltre la sessione corrente.

### 7.4 Done criteria
- Navigate `/settings?highlight=gemini&returnTo=/home/import` -> scrolla a tile Gemini.
- Save + test -> mostra CTA ritorno.
- Tap ritorno -> arriva a `/home/import?resumeImport=1` -> bloc riprende parsing.

---

## 8. Fase 6 -- i18n 6 lingue (commit #7)

### 8.1 Nuove chiavi da aggiungere (in ordine)

Sezione `import.*`:
```
import.analyzing_title
import.analyzing_file
import.stage_specific
import.stage_heuristic
import.stage_ai
import.heuristic.dialog_title
import.heuristic.dialog_subtitle
import.heuristic.column_preview
import.heuristic.column_mapped_to
import.heuristic.confirm
import.heuristic.edit_mapping
import.heuristic.use_ai_instead
import.ai.consent_title
import.ai.consent_explain
import.ai.consent_privacy_notice
import.ai.consent_accept
import.ai.consent_cancel
import.ai.dont_ask_again_session
import.ai.in_progress
import.ai.success
import.ai.error_invalid_key
import.ai.error_rate_limited
import.ai.error_generic
import.ai.requires_api_key_banner
import.ai.goto_settings
import.failed.title
import.failed.no_parser_matched
import.failed.retry
```

Sezione `settings.ai.*` (aggiunte):
```
settings.ai.highlight_hint
settings.ai.key_saved_return_prompt
settings.ai.return_to_import
```

### 8.2 Processo
- Popolare **prima** `en.json` e `it.json` con wording definitivo.
- Invocare skill `/translations-sync` (o subagent `i18n-auditor`) per generare placeholder nelle altre 4 lingue.
- Tradurre manualmente es/fr/de/pt revisionando i placeholder.
- Verificare chiavi identiche in tutti e 6 i file (`i18n-auditor` conferma parity).

### 8.3 Done criteria
- 6 file JSON sincroni.
- Nessuna stringa hardcoded italiana/inglese nelle nuove UI (grep test: `Text\(['"][A-Z]` in nuovi widget -> 0 match che non siano `.tr()`).

---

## 9. Fase 7 -- Test integration e fixtures (commit #8)

### 9.1 Fixtures estese
`test/fixtures/orchestrator/`:
- `specific_ibkr.csv` -- deve stage=specific.
- `heuristic_it_standard.csv` -- stage=heuristic confidence=high.
- `heuristic_it_ambiguous.csv` -- stage=heuristic confidence=medium (triggera dialog).
- `fail_binary_garbage.bin` -- stage=failed immediato (invalid UTF-8).
- `ai_needed_weird.csv` -- stage=failed senza AI, stage=ai con AI mock.

### 9.2 Test orchestrator
`test/services/parsers/parse_orchestrator_test.dart`:
- 5 test, uno per fixture sopra.
- `GeminiService` mockato per evitare chiamate reali.

### 9.3 Bloc test
`test/features/portfolio/presentation/bloc/portfolio_bloc_import_test.dart`:
- Test macchina a stati: analyze -> awaitingHeuristicConfirm -> confirm -> success.
- Test: analyze -> awaitingApiKey -> retry con key -> awaitingAiConsent -> accept -> success.
- Test: ai error invalidKey -> failed.

### 9.4 Widget test
`test/features/portfolio/presentation/widgets/ai_consent_dialog_test.dart` -- dialog renders + invoca callback.
`test/features/portfolio/presentation/widgets/heuristic_mapping_dialog_test.dart` -- edit dropdown + conferma chiama callback.

### 9.5 Pulizia
Cancellare `lib/services/parsers/generic_parser.dart` (usage redirect gia' a HeuristicParser da Fase 2). Rimuovere import morti.

### 9.6 Done criteria
- `rtk flutter analyze` pulito.
- `rtk flutter test` verde completo.
- Coverage nuovi moduli >= 70% (spot check manuale, no gate automatico).

---

## 10. Fase 8 -- Hardening, telemetria, docs (commit #9)

### 10.1 Rate limiting client
- Nel `GeminiService.extractPositionsFromDocument`: semaforo in-memory max 1 richiesta concorrente per istanza. Se utente tenta secondo file mentre primo e' in AI, secondo aspetta in coda.
- Timeout duro: 45s sull'intera richiesta, oltre -> AiParserException.timeout.

### 10.2 Costo / trasparenza
- Aggiungere in consent dialog stima: "Circa N token, costo stimato: ~$0.0003" (usa tabella statica `geminiModelCosts` in `AppConstants`). Mostra solo se l'app lo abilita via flag `AppConstants.showAiCostEstimate = true`.

### 10.3 Privacy safety
- Prima di inviare documento, strip di eventuali colonne "Account Number", "IBAN", "Tax ID" se nomi colonna matchano keyword sensibili. Implementa `PrivacySanitizer.sanitize(String) -> String`.
- Log utente (solo debug build): cosa e' stato inviato (metadata only, no contenuto).

### 10.4 Docs
- Aggiornare [formati_brokers.md](../formati_brokers.md): nuova sezione "Fallback automatico (euristica + AI)".
- Aggiungere [docs/PARSING_HIERARCHY.md](../docs/PARSING_HIERARCHY.md) -- versione utente-facing del sistema (come funziona quando AI interviene, come revocare consenso, come cambiare key).
- Aggiornare [USER_FEATURES.md](../USER_FEATURES.md): nuova voce "Import resiliente con AI fallback".
- Aggiungere voce in [IMPLEMENTATION_HISTORY.md](../IMPLEMENTATION_HISTORY.md) a fine sessione (via skill `/session-wrap`).

### 10.5 Done criteria
- Tutte le 8 fasi precedenti merged.
- Rate limit verificato manualmente (doppia richiesta non esplode).
- PrivacySanitizer ha test dedicato.
- Docs aggiornati.

---

## 11. Ordine di esecuzione consigliato (commit map)

| # | Commit | Branch | Fase | Contenuto |
|---|--------|--------|------|-----------|
| 1 | `feat(parser): scaffold parse orchestrator + result types` | `feature/parse-orchestrator-scaffold` | 0 | Stub, nessun cambio UI |
| 2 | `chore(parser): tighten broker auto-detection threshold` | `feature/parser-autodetect-tune` | 1 | factory + pdf hardening + test |
| 3 | `feat(parser): heuristic fallback with multilang keywords` | `feature/heuristic-parser` | 2 | HeuristicParser + dialog + fixtures |
| 4 | `feat(parser): gemini AI structured extraction` | `feature/ai-parser` | 3 | AiParser + gemini method extension + test |
| 5 | `feat(portfolio): orchestrate parsing in import bloc` | `feature/bloc-parse-orchestration` | 4 | Eventi/stati/UI listener |
| 6 | `feat(settings): deep-link + return-to for missing key` | `feature/settings-returnto` | 5 | Router + settings highlight |
| 7 | `feat(i18n): translations for parsing hierarchy` | `feature/i18n-parsing-hierarchy` | 6 | 6 lingue sincrone |
| 8 | `test(parser): integration tests for 3-layer pipeline` | `feature/tests-parsing-hierarchy` | 7 | Test + pulizia generic_parser |
| 9 | `chore(parser): hardening + docs + privacy sanitizer` | `feature/parsing-hardening` | 8 | Rate limit + docs + sanitizer |

Ogni commit deve compilare da solo (`rtk flutter analyze` + `rtk flutter test` verdi) e non rompere la UX esistente.

---

## 12. Rischi e mitigazioni

| Rischio | Impatto | Mitigazione |
|---------|---------|-------------|
| Gemini rate limit su free tier | Utente bloccato | Rate limit client + messaggio chiaro + link pricing |
| Gemini restituisce JSON malformato | AI parse fallisce | Regex fallback su `[ ... ]` + FormatException pulita |
| File enorme >48k chars | Troncamento perde dati | Truncation strategia: se CSV, prendi header + prime 300 righe + ultime 100 (pattern a "W"), avvisa utente |
| User invia dati sensibili a Gemini senza rendersene conto | Privacy | PrivacySanitizer + consent dialog esplicito + docs |
| Heuristic mappa male la colonna prezzo con quella valore | Posizioni sballate | Confidence penalty se `price * quantity` differisce >5% da colonna `value` quando entrambe mappate |
| Regressione su parser specifici | Utenti esistenti rotti | Stage 1 invariato + test fixture esistenti + threshold solo alzato (non abbassato) |
| Utente rifiuta consenso AI | Nessun import possibile | Messaggio: "L'import manuale resta disponibile via 'Aggiungi posizione'" |

---

## 13. Checklist finale pre-merge (da rieseguire su commit #9)

- [ ] `rtk flutter analyze` pulito (zero warning nuovi)
- [ ] `rtk flutter test` verde su tutte le suite
- [ ] `rtk flutter build web --release` completa senza errori
- [ ] `rtk flutter build apk --release` completa senza errori
- [ ] Fixtures in `test/fixtures/` anonimizzate (no dati personali)
- [ ] 6 file `assets/translations/*.json` con stesse chiavi (verifica con `/translations-sync` o `i18n-auditor`)
- [ ] Nessun caratter non-ASCII nei `.dart`, `.ps1`, `.py`, `.yml`, `.json config`
- [ ] `dist/market-data/top_movers.json` non toccato (non-related)
- [ ] [USER_FEATURES.md](../USER_FEATURES.md) aggiornato con la nuova feature
- [ ] [IMPLEMENTATION_HISTORY.md](../IMPLEMENTATION_HISTORY.md) aggiornato via `/session-wrap`
- [ ] Hook `SessionStart` non rotto (verifica apertura sessione successiva)
- [ ] Code review via subagent `code-reviewer` su almeno commit #3, #4, #5

---

## 14. Out-of-scope (esplicitamente NON in questo piano)

- Riconoscimento OCR di PDF scansionati (immagini). Solo PDF con testo estraibile.
- Storico run AI per analisi retroattiva.
- Fine-tuning / prompt caching Gemini.
- Multi-provider AI (solo Gemini per ora; abstraction pulita lascia porta aperta a OpenAI/Claude futuri senza refactor strutturale).
- Migration automatica di portafogli gia' importati con GenericCSVParser (restano come sono).
- UI drag&drop (separato da questo piano, il `FilePicker` attuale resta).

---

## 15. Appendice -- riferimenti rapidi

- Architettura attuale parser: [lib/services/parsers/parser_factory.dart](../lib/services/parsers/parser_factory.dart)
- Modello posizione: [lib/features/portfolio/domain/entities/portfolio_entities.dart](../lib/features/portfolio/domain/entities/portfolio_entities.dart) (linee 4-154)
- Gemini service: [lib/services/api/gemini_service.dart](../lib/services/api/gemini_service.dart)
- Import page attuale: [lib/features/portfolio/presentation/pages/import_page.dart](../lib/features/portfolio/presentation/pages/import_page.dart) (linee 113-625)
- Settings API key: [lib/features/settings/presentation/pages/settings_page.dart](../lib/features/settings/presentation/pages/settings_page.dart) (linee 350-420)
- Router: [lib/app_router.dart](../lib/app_router.dart)
- Regole di lavoro globali: [CLAUDE.md](../CLAUDE.md)
