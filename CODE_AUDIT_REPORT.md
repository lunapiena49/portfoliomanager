# CODE AUDIT REPORT -- Portfolio Manager

**Data audit**: 2026-04-18
**Scope**: intera codebase (lib/ 54 file, assets/translations/ 6 locale, scripts/, .github/workflows/, .claude/hooks/)
**Metodo**: 9 fasi di review via subagent specializzati (test-runner, i18n-auditor, code-reviewer, general-purpose)
**Output**: findings raggruppati per severity (BLOCK / WARN / NIT) e per area. Nessun file modificato durante l'audit.

---

## Executive Summary

| Severity | Count | Aree impattate |
|---|---|---|
| BLOCK | **22** | Test, i18n Goals, Parser IBKR/Robinhood/PDF, BLoC Goals/Settings, API keys plaintext, ASCII, Market data stale, Router race, Position detail fallback, GoalsTab orphaned |
| WARN | **45** | Parser edge cases, add() chain BLoC, Hive error handling, retry logic market data, Gemini timeout/cost, Dark mode contrast, Form validators |
| NIT | **20+** | Stile, magic strings, TODO non risolti, i18n dinamici |

**Verdict globale**: **BLOCK** -- la codebase NON e' pronta per una release. Si identificano 6 "aree critiche" che richiedono fix immediato prima di qualunque deploy.

### Top 6 aree critiche (da fixare per prime)

1. **i18n Goals rotte** -- 50+ chiavi `goals.*` mancanti in tutti i 6 locale, Goals tab mostrera' nomi chiave grezzi in produzione.
2. **API keys in plaintext** -- `LocalStorageService` salva Gemini/EODHD/FMP in Hive box non cifrato, violando CLAUDE.md sezione 4.3.
3. **Goals feature irraggiungibile** -- `GoalsTab` definita (1200 righe) ma mai montata in `HomePage`, nessun `BlocProvider<GoalsBloc>` in `main.dart`.
4. **Market data 43 giorni stale** -- snapshot locale del 2026-03-06 mai ruotato, nessun banner utente sulla staleness, workflow CI potrebbe essere rotto senza alert.
5. **Parser Robinhood cost basis errato** -- formula `totalCost * quantity / (quantity + 0.001)` produce valori finanziariamente sbagliati per utenti Robinhood.
6. **Test suite non compila** -- `widget_test.dart:16` referenzia `MyApp` inesistente, `flutter analyze` e `flutter test` falliscono entrambi.

---

## Fase 0 -- Baseline Flutter Analyze + Test

### BLOCK

- **[test/widget_test.dart:16]** `creation_with_non_type: MyApp` -- la classe `MyApp` non esiste piu' in `lib/main.dart` (probabilmente rinominata durante refactor bootstrap). Il file non compila, `flutter analyze` esce non-zero, `flutter test` non esegue nessun test.
  **Fix**: aggiornare il test per referenziare la classe root attuale, oppure rimuovere il stub ed iniziare una vera test suite.

### WARN

- **64 issues in `flutter analyze`** (1 error, 5 warnings, 58 infos). Top offender:
  - `rebalancing_tab.dart` -- 18
  - `settings_page.dart` -- 13
  - `goals_tab.dart` -- 11
  - `import_page.dart` -- 9
  - `language_selection_page.dart` -- 4
- **Unused imports/locals** (5): `goals_tab.dart:10,11,502`, `language_selection_page.dart:7`, `trading212_parser.dart:52`.
- **Test coverage ~0%** -- esiste solo `widget_test.dart` stub. Nessun bloc test, nessun parser test, nessun integration test.

---

## Fase 1 -- i18n 6 Locale

### BLOCK

- **50+ chiavi `goals.*` + `common.clear` referenziate in `goals_tab.dart` ma ASSENTI da tutti e 6 i file `assets/translations/*.json`.**
  Chiavi mancanti includono:
  - `goals.title`, `goals.subtitle`, `goals.search`, `goals.add.first`, `goals.add.title`, `goals.add.coming_soon`
  - `goals.tabs.{list,analytics,settings}`
  - `goals.error.title`, `goals.empty.{title,description}`
  - `goals.analytics.{total_goals,completed,total_value,progress_chart,type_distribution}`
  - `goals.settings.{show_completed,show_completed_desc,default_currency,default_currency_desc}`
  - `goals.filter.{title,type,status,sort}`
  - `goals.details.{description,no_description,target_amount,current_amount,progress,target_date,monthly_contribution,asset_allocation}`
  - `goals.types.{retirement,emergency,house,education,travel,custom}`
  - `goals.status.{active,completed,paused,cancelled}`
  - `goals.sort.{name,target_amount,progress,target_date,created_date}`
  - `common.clear`

  **Fix**: aggiungere l'intero namespace `goals.*` + `common.clear` in tutti e 6 i file locale (it source of truth, poi tradurre en/es/fr/de/pt). Usare skill `translations-sync`.

### PASS

- **Parity perfetta**: 578 chiavi in it.json, stesse 578 chiavi in en/es/fr/de/pt. Zero divergenze strutturali.
- **Placeholder consistency**: 15 chiavi con placeholder (`{count}`, `{dollarVolume}`, `{time}`, `{symbol}`, ecc.) tutte coerenti nei 6 locale.
- **Nessuna stringa vuota** e nessun valore identico alla chiave.

### WARN

- **Orphan keys** (nei JSON ma mai chiamate con `.tr()`): `app.tagline`, `portfolio.daily_change`, `portfolio.sort_by.*`, `portfolio.filters.{funds,cfds}`, `analysis.metrics.*` (sharpe_ratio/volatility/beta/alpha/max_drawdown/sortino_ratio), `settings.notifications.*`, `settings.data.{backup,restore}`, `settings.about.{privacy,terms,licenses,rate,contact}`, `sectors.*` (top-level), `currencies.*`, `market.event_labels.*`, `market.markets.*`, `rebalancing.messages.import_portfolio_first`.
  Alcune potrebbero essere risolte dinamicamente (guide_page usa `titleKey.tr()` con variabile) -- richiede verifica manuale prima di eliminare.

---

## Fase 2 -- Parser Broker (13 parser + base + factory)

### BLOCK

- **[ibkr_parser.dart:1-5, 140-155]** IBKR parser duplica utility private (`_uuid`, `_parseDoubleSafe`, `_parseIntSafe`, `_normalizeAssetType`, `_normalizeSector`) da `base_parser.dart`, causando divergenza silente: la versione IBKR di `_parseDoubleSafe` NON gestisce parenthesis-negatives `(1234.56)` che base gestisce. Inoltre `_parseKeyStatistics` usa hardcoded positional indices (`line[2]..line[4]`) invece di header-name lookup.
  **Fix**: rimuovere i duplicati privati, chiamare `BaseBrokerParser.*`. Aggiungere lookup per header in `_parseKeyStatistics`.

- **[robinhood_parser.dart:181]** Formula cost basis errata:
  ```dart
  final double costBasis = quantity > 0 ? (totalCost * quantity / (quantity + 0.001)) : 0.0;
  ```
  `totalCost` e' gia' il running cost basis per le `quantity` azioni rimanenti. Moltiplicare per `quantity / (quantity + 0.001)` introduce errore numerico senza ragione. Il guard `+ 0.001` e' cargo-cult.
  **Fix**: `costBasis: totalCost.abs()`.

- **[parser_factory.dart + pdf_import_parser.dart]** `PdfImportParser` NON estende `BaseBrokerParser`, non ha `canParse`, non e' registrato nel factory. CLAUDE.md sezione 4.5 richiede che tutti i parser usino `base_parser.dart` come template e siano registrati.
  **Fix**: creare wrapper `PdfBrokerParser extends BaseBrokerParser` oppure documentare l'eccezione in `formati_brokers.md`.

### WARN

- **[base_parser.dart:347-388]** `parseDate` ambiguita' ISO vs `DD-MM-YYYY`. Date DEGIRO come `"11-10-2024"` vengono interpretate come ISO e silently ritornano `null` per `int.parse` che fallisce.
  **Fix**: check `parts[0].length == 4` prima di assumere ISO.

- **[trading212_parser.dart:78]** Filtro `p.quantity > 0` drop silenti di short position (quantity < 0) e rounding edge cases (`-0.000001`). Gli altri parser (DEGIRO, Revolut) usano `!= 0`.
  **Fix**: `!= 0` per coerenza.

- **[charles_schwab_parser.dart:42-44]** Variabile `firstCellLower` con condition over-broad -- simbolo "ACCOUNT" potrebbe essere mistakenly parsato come metadata.

- **[xtb_parser.dart:58]** `_isNumeric` e' unico filtro per righe data. Se XTB cambiasse a ID alfanumerici, tutti dati droppati silenti.

- **[degiro_parser.dart:170-175]** Descriptions non riconosciute con `quantity != 0` vengono silenti droppate (es. stock split, corporate action). Nessun log di skip count.

- **[ibkr_parser.dart:25-29]** Bypassa `BaseBrokerParser.parseCSV` che normalizza `\r\n` -> `\n`. Su export Windows IBKR puo' produrre empty trailing cells.

- **[vanguard_parser.dart:179]** Asset type inference `symLower.startsWith('v') && length <= 5` classifica `V` (Visa) come ETF.
  **Fix**: `nameLower.contains('etf')` come check primario.

- **[generic_parser.dart:276-279]** `_parseFlexibleNumber` ambiguita' tra `"1,00"` europeo (uno) e US thousand `"1,000"` (mille). Documentare in commento.

### NIT

- `[trading212_parser.dart:54-63]` `firstCellLower` unused (warning flutter analyze).
- `[ibkr_parser.dart:409-411]` `_normalizeAssetType` ritorna `'Forex'` vs base che ritorna `'Cash'` per stessi input -- inconsistenza deduplicazione.
- `[pdf_import_parser.dart:47-78]` Split PDF su `\s{2,}|\t` fragile su layout multi-colonna con right-aligned pricing.
- `[revolut_parser.dart:136-138]` Parsing `"BRK B"` truncato a `"BRK"` da `split(' ')[0]`.

### Contract Conformance

| Parser | Conforme | Note |
|---|---|---|
| IBKR | **NO** | duplicates utils, hardcoded indices (BLOCK) |
| Robinhood | PARZIALE | costBasis formula wrong (BLOCK) |
| PDF | **NO** | non estende BaseBrokerParser (BLOCK) |
| TDAmeritrade, Fidelity, Schwab, E-Trade, Vanguard, Trading212, XTB, DEGIRO, Revolut, Generic | OK | minor issues (WARN/NIT) |

---

## Fase 3 -- BLoC & State Management

### BLOCK

- **[goals_bloc.dart:298-312]** `_onSyncWithPortfolio` setta `currentAmount = portfolio.totalValue` per **TUTTI** i goal attivi, ignorando tipo goal e valuta. Un goal "emergency fund EUR" mostrera' l'intero portafoglio includendo posizioni USD/GBP senza FX conversion.
  **Fix**: filtrare per `GoalType.retirement`/`GoalType.custom`, applicare FX via `goal.currency`.

- **[goals_bloc.dart:133-142, goals_entities.dart:89-121]** `GoalsLoaded.copyWith` e `InvestmentGoal.copyWith` usano pattern `field ?? this.field` -- NON possono clearare nullable fields. `copyWith(rebalanceSuggestions: null)` no-op, `copyWith(completedAt: null)` non puo' "uncompletare" un goal.
  **Fix**: sentinel object pattern (come gia' fatto in `PortfolioLoaded.copyWith`).

- **[settings_bloc.dart:143-165]** Stesso problema: `AppSettings.copyWith` non puo' clearare API keys a null. Dopo delete user key, lo state mostra ancora `hasGeminiApiKey == true` fino a cold start.
  **Fix**: sentinel pattern.

### WARN

- **[portfolio_bloc.dart:485-493, 656-680]** `_onDeletePortfolio`, `AddPositionEvent`, `UpdatePositionEvent`, `DeletePositionEvent` chiamano `add(LoadPortfolioEvent)` / `add(UpdatePortfolioEvent)` dentro handler. Se BLoC chiude tra i due eventi -> evento chained swallowed silently + potenziale `StateError`.
  **Fix**: estrarre `_saveAndEmit(Portfolio, Emitter)` helper e chiamare direttamente con emit corrente.

- **[rebalancing_bloc.dart:208-214]** Stesso anti-pattern su `_onReset`.

- **[goals_bloc.dart:329-331]** `firstWhere((g) => g.id == event.goalId)` senza `orElse` -- throw `StateError` se goal deleted durante dispatch.
  **Fix**: `orElse: () => throw ...` o null-check esplicito.

- **[app_router.dart + main.dart]** `GoalsBloc` NON registrato in `MultiBlocProvider` in `main.dart` -- qualsiasi `context.read<GoalsBloc>()` produrra' `ProviderNotFoundException`. (Coerente con BLOCK fase 7: GoalsTab orphaned.)

### NIT

- `[portfolio_bloc.dart:422]` `previousState` ridondante.
- `[rebalancing_bloc.dart:119]` `_currentPortfolio` come mutable instance state -- smell.
- `[onboarding_bloc.dart:48-59]` `_onCheckStatus` marcato `async` ma senza `await`.
- `[main.dart:69 + SplashPage.initState]` `CheckOnboardingStatusEvent` dispatchato due volte su cold start.

---

## Fase 4 -- Storage & Sicurezza

### BLOCK

- **[local_storage_service.dart:88-127]** `getGeminiApiKey()`, `getFmpApiKey()`, `getEodhdApiKey()` leggono da `_settingsBox` (Hive box NON cifrata). CLAUDE.md sezione 4.3 richiede `flutter_secure_storage`. Il pacchetto e' in `pubspec.yaml` e i registrant nativi sono attivi, ma **zero codice Dart lo chiama**. Qualsiasi tool di backup o app con read access al sandbox puo' estrarre le chiavi in plaintext.
  **Leak risk**: **HIGH**.
  **Fix**: migrare i 3 getter/setter a `FlutterSecureStorage().read/write/delete`. Rimuovere le costanti corrispondenti da Hive logic.

- **[eodhd_service.dart:6, settings_page.dart:114]** Em-dash `—` (U+2014) in .dart doc comment -- viola CLAUDE.md sezione 4.1 (ASCII-only nei .dart).
  **Fix**: sostituire con `--`.

### WARN

- **[market_snapshot_service.dart:97]** Freccia `→` (U+2192) in doc comment .dart.
- **[app_constants.dart:39]** `eodhdApiKeyKey` fuori sezione "Storage Keys" (inconsistenza posizionale).
- **[local_storage_service.dart:17-22]** `Hive.openBox()` senza try/catch. Se box corrupt (crash, force-kill) -> crash launch senza recovery.
  **Fix**: try/catch, delete corrupt box, reopen.
- **[local_storage_service.dart:240,255]** `'rebalance_targets'` magic string.
- **[main.dart]** Zero Hive adapters registrati -- serializzazione via JSON string su tutti i box. Documentare la scelta, aggiungere lint note per futuri contributor.
- **[gemini_service.dart:128]** Stampa `e.response?.data` verbatim in exception message -- il body Gemini error puo' echare prompt contenente portfolio financials.

### NIT

- `[local_storage_service.dart:136,142]` `'current_portfolio_id'` magic string.
- `[local_storage_service.dart:269-280]` `exportAllData()` esclude API keys correttamente ma senza doc comment.
- ASCII violations in file .dart non-critici: `market_tab.dart:1781,1783` (box-drawing `──` in commenti), `rebalancing_tab.dart:302,336,340` (en-dash, `£`, `¥`), `portfolio_summary_card.dart`, `position_list_item.dart`, `position_detail_page.dart`, `import_page.dart` (bullet `•`). Currency symbols (`£`, `¥`) e flag emoji in `app_localization.dart:64-76` sono glyph display-only, potrebbero stare in i18n `language.flag.xx`.

---

## Fase 5 -- Market Data Pipeline

### BLOCK

- **[dist/market-data/top_movers.json]** `as_of_date = 2026-03-06`, oggi 2026-04-18 -> **43 giorni stale**. Il workflow CI potrebbe essere rotto senza alert, oppure il hook background sync fallisce silenzioso.
  **Fix immediato**: verificare che `market-data-snapshot.yml` sta girando (`rtk gh run list --workflow=market-data-snapshot.yml`) e rifare un manual trigger.

- **[market_tab.dart:_buildBody + _lastUpdated]** La UI mostra "aggiornato X min fa" basato sul fetch time client-side, NON su `as_of_date` del snapshot. Utente vede "just now" dopo refresh anche se dati sono di 43 giorni fa.
  **Fix**: confrontare `as_of_date` con oggi; se > 3 giorni lavorativi, banner warning "Dati non aggiornati da X giorni".

- **[market_snapshot_service.dart:55-61]** `fetchTopMoversSnapshot()` senza try/catch. 404/DNS/timeout propagano, fallback a FMP silenzioso -- e se FMP non configurato, tab vuota senza spiegazione.
  **Fix**: try/catch + flag `offlineSnapshot=true` per UI banner "last good snapshot".

- **[scripts/eodhd/sync_market_snapshot_from_pages.ps1:11-14 vs market-data-snapshot.yml:44]** URL Pages del sync script (`portfoliomanager` senza underscore) potrebbe NON coincidere con il publish path del workflow (`${{ github.event.repository.name }}` = `portfolio_manager` con underscore).
  **Fix**: verificare `rtk git remote -v` e allineare.

### WARN

- **[market_tab.dart:307 vs workflow yml:55 vs commit history]** `_minimumMoverDollarVolume = 1_000_000` (1M) ma commit `feat: increase min mover volume to 1.5M` promette 1.5M. Il workflow usa `--min-dollar-volume 1000000`. O commit mentiva, o dimenticato aggiornare costanti.

- **[eodhd_service.dart, fmp_market_service.dart]** Zero retry logic, single request con 30s timeout. Dio `RetryInterceptor` quick win.

- **[.github/workflows/market-data-snapshot.yml, daily-data-commit.yml]** No failure notification. Workflow rotto per 7 giorni = nessun alert.
  **Fix**: step `if: failure()` che apre issue GitHub o notifica.

- **[daily-data-commit.yml:41-45]** 404 da Pages = silent skip + exit 0. Reale outage indistinguibile da "not yet published".
  **Fix**: fail dopo N retries.

- **[session-start.ps1:99]** `git pull --ff-only` swallow silent su uncommitted local -- log generico `"skip"`.
  **Fix**: log `rev-list --count HEAD..origin/main`.

- **[market_tab.dart:1013-1023, 1205]** `_hasAnyFetchedMarketContent()` + `_fetchErrors` -- partial failures nascoste (es. weekly/monthly ok ma 1D failed -> Today tab vuota senza errore).

- **[market_tab.dart:700-773]** `_mapSnapshotMovers` non deduplica simboli.

- **[sync_market_snapshot_from_pages.ps1:28-47]** `market_history.db.zip` (950MB) re-download unconditional.
  **Fix**: `If-Modified-Since` / ETag.

### NIT

- Alcuni hardcoded: `_maxQuoteStalenessDays = 5`, `_pricesIndexCacheTtl = 4h`, `_preferredMarketOrder` 8 markets.
- `[eodhd_service.dart:81]` `rt?['close'] ?? rt?['last']` -- `last` non e' campo EODHD standard.

### Pipeline Health Snapshot

- `top_movers.json` -- 728 KB (2026-03-06, **43 giorni fa**)
- `prices_index.json` -- 12.6 MB
- `market_history.db.zip` -- 907 MB
- `market_history.db` -- 3.17 GB (2026-02-22, **56 giorni fa**)
- `daily_market.db.zip` -- 3.9 MB

---

## Fase 6 -- Gemini AI

### WARN

- **[gemini_service.dart:171-248]** `chat()` non ha 429/401/400 handling (solo generic `throw Exception('API error: ${e.message}')`). `analyzePortfolio()` ha switch completo -- inconsistenza.

- **[gemini_service.dart:10-13]** `sendTimeout` non settato. Su portfolio grande con mobile lento, send puo' hang.
  **Fix**: `_dio.options.sendTimeout = Duration(seconds: 30)`.

- **[ai_chat_page.dart:21, analysis_page.dart:26]** `GeminiService` istanziato DIRETTAMENTE in widget (non BLoC). Chat history in `_messages` in-memory widget-local -- persa su hot-restart o pop.
  **Fix**: `AnalysisChatBloc` dedicato + persistenza.

- **[gemini_service.dart:355-373]** `_buildAnalysisPrompt()` itera `portfolio.positions` senza cap. 100+ posizioni -> prompt 30-40k tokens -> costi esplosivi + rischio token limit.
  **Fix**: `positions.take(50)` + nota `"(top 50 di N)"`.

- **[ai_chat_page.dart:49, analysis_page.dart:44]** Nessun debounce / in-flight guard. `onSubmitted` + button concorrenti.
  **Fix**: `if (_isLoading) return;` prima riga.

- **[gemini_service.dart:89-99]** Tutti i safety filter a `BLOCK_NONE`. Unnecessary per financial Q&A, liability exposure.
  **Fix**: rimuovere o `BLOCK_MEDIUM_AND_ABOVE`.

### NIT

- `[gemini_service.dart:34]` Model `gemini-2.5-flash` unpinned (no version suffix).
- `[analysis_page.dart:279]` `TODO: Generate specific analysis` -- 4 suggestion chip no-op.
- `[gemini_service.dart:221]` `chat()` ignora param `model` override (asimmetrico con `analyzePortfolio`).
- `[ai_chat_page.dart:83]` Role `'assistant'` vs Gemini `'model'` -- funziona grazie a remap in service:204 ma semanticamente sbagliato.
- `[gemini_service.dart:126-134]` Error `Invalid request: ${e.response?.data}` leak response body.

### Gemini Configuration

| Parametro | Valore |
|---|---|
| Model | `gemini-2.5-flash` (unpinned) |
| Max tokens | 8192 |
| Temperature | 0.7 (alto per financial; preferire 0.3-0.5) |
| Connect timeout | 30s |
| Receive timeout | 60s |
| Send timeout | **non set** |
| Retry logic | **none** |
| Cost guard | **none** |

---

## Fase 7 -- UI/UX & Strategia

### BLOCK

- **[app_router.dart:63-94]** `redirect` race con `OnboardingBloc` async init. Deep link `/home` viene redirectato a `/onboarding` finche' `CheckOnboardingStatusEvent` non risolve, anche per utente gia' onboarded.
  **Fix**: gate redirect su flag sincrono `LocalStorageService.isOnboardingCompleted()`.

- **[app_router.dart:58-184]** No `refreshListenable`. Transizione `OnboardingRequired -> Completed` non trigger reroute -- `onboarding_page.dart:100` papera sopra con `context.go(RouteNames.home)` manuale ma altre transizioni future silenti.
  **Fix**: `GoRouterRefreshStream(bloc.stream)`.

- **[position_detail_page.dart:32-35]** `firstWhere(..., orElse: () => state.portfolio.positions.first)` -- se id non esiste, mostra prima posizione random con dati sbagliati sotto il simbolo richiesto.
  **Fix**: "not found" state come `edit_position_page.dart:143-168`.

- **[add_position_page.dart:96-114]** `BlocListener` tratta qualunque `PortfolioLoaded` come "add success" -> naviga pop su qualsiasi refresh (price auto-update, selectPortfolio) mentre form aperto -> perde input.
  **Fix**: `_isLoading=true` prima di `AddPositionEvent`, gate condition.

- **[portfolio_bloc.dart:87-148 + UI]** `DeletePositionEvent`, `DeletePortfolioEvent`, `DeleteGoalEvent` dichiarati ma **nessun widget li invoca**. Utente NON puo' eliminare position/portfolio/goal.
  **Fix**: aggiungere azioni destructive con AlertDialog confirm in `position_detail_page.dart`, `home_page.dart` (`_showPortfolioManager`), `goals_tab.dart` (`_showGoalDetailSheet`).

- **[main.dart:63-76 + home_page.dart:33-37]** `GoalsBloc` NON in `MultiBlocProvider`; `GoalsTab` NON nell'`IndexedStack` di `HomePage`. La feature "goals" (1200 righe) e' codice morto + unreachable.
  **Fix**: wire `GoalsTab` nell'IndexedStack + BottomNavigationBar, aggiungere `BlocProvider<GoalsBloc>` in main.dart. Oppure eliminare la feature.

### WARN

- **[goals_tab.dart / rebalancing_tab.dart / ai_chat_page.dart]** 30+ hardcoded `Colors.grey[xxx]`, `Colors.red[400]`, `Colors.white`, `Colors.black` -- dark mode rotto (search field bianco su scaffold nero, shadow nere invisibili, grey[400] perde contrasto).
  **Fix**: `Theme.of(context).colorScheme.{surfaceVariant,outline,onSurfaceVariant,shadow}`.

- **[add_position_page.dart:155-173, edit_position_page.dart:205-222]** No `FilteringTextInputFormatter` su quantity/price/cost_basis -- utente puo' digitare `-5` o `12.34.56`, validazione solo on-submit.
  **Fix**: `FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d*'))`.

- **[add_position / edit_position / create_portfolio / import / ai_chat]** No `resizeToAvoidBottomInset` control, no tap-outside dismiss keyboard. Su mobile, keyboard copre submit.

- **[home_page.dart:33-37]** `IndexedStack` eager renderiza MarketTab+RebalancingTab al primo build -> `RebalancingBloc` carica al boot anche se utente su Portfolio.

- **[app_router.dart:395-430]** `ErrorPage` usa `const Text('Error')`, `const Text('Page not found')`, `const Text('Go Home')` -- inglese hardcoded.

- **[app_theme.dart:66,214]** `toolbarHeight: (kToolbarHeight + (kIsWeb ? 64 : 24)).h` -- scaling doppio: `+64` e' gia' pixel, poi moltiplicato da `.h` ScreenUtil. AppBar >130px su large screens.

- **[position_detail_page.dart:178,223,229,235]** `'Details'`, `'Unrealized P&L'`, `'P&L %'`, `'Exchange'`, `'FX Rate'` inglese hardcoded.

- **[analysis_page.dart:92-96 + rebalancing_tab.dart:1398-1438]** "No portfolio loaded" senza CTA (import/create button).

- **[language_selection_page.dart:77-99]** Selected highlight `primaryColor @ 10%` barely visible in dark mode -- aggiungere border/checkmark.

- **[goals_tab.dart:797-841]** `_showAddGoalSheet` placeholder "coming soon" -- feature esposta ma non funzionale.

### NIT

- `[app_router.dart:188-387]` SplashPage inline in router.dart, preferire file dedicato.
- `[home_page.dart:42-55]` BottomNav `_short` keys -- lingue lunghe (DE "Neuausrichtung") rischio truncate.
- `[add_position_page.dart:98-105]` Snackbar generica su `PortfolioLoaded`.
- `[position_detail_page.dart:371]` Hardcoded `\$` per USD.
- `[onboarding_page.dart:113-123]` Skip always-on senza confirmation dialog.
- `[settings_page.dart:614-621]` `_resetOnboarding` non resetta `PortfolioBloc`.
- `[rebalancing_tab._buildBottomBar]` `minimumSize: Size(44.w, 40.h)` sotto 48px a11y.

### Navigation Matrix

| Route | Guard | Nota |
|---|---|---|
| `/` splash | -- | race condition su deep link (BLOCK) |
| `/language-selection` | `!hasSelectedLanguage` | OK |
| `/onboarding` | `!isOnboardingComplete` | OK |
| `/home` | onboarded | BottomNav: Portfolio, Market, Rebalancing (**goals manca**) |
| `/home/position/:id` | onboarded | **fallback wrong position se id non esiste (BLOCK)** |
| `/home/add-position` | onboarded | **perde form su refresh portfolio (BLOCK)** |
| `/analysis`, `/ai-chat`, `/settings`, `/guide` | onboarded | OK |
| `/goals/*` | -- | **route non esistente** |

### Theme Coverage

| Mode | Status |
|---|---|
| Light | ISSUES (hardcoded colors in goals/rebalancing) |
| Dark | ISSUES (search field white-on-dark, shadow nere, grey[400] low contrast) |
| System | OK (plumbing corretto, issue a valle) |

---

## Fase 8 -- Build / Release Gate

### WARN

- **[pubspec.yaml]** `flutter_secure_storage: ^10.0.0-beta.5` -- beta, rischio breaking changes.
- **[pubspec.yaml]** `go_router: ^17.0.0` -- major molto recente, verificare migration.

### PASS

- SDK constraint: `>=3.2.0 <4.0.0` (match CLAUDE.md).
- Assets referenziati esistono (translations, images, fonts).
- Zero git deps non pinned.
- Zero tracked files proibiti (`.db`, `build/`, `.env*`, `.keystore`, `google-services.json`).
- `.gitignore` onorata correttamente.

---

## Prioritizzazione & Effort Estimate

### Sprint 0 -- Fix critici per release (8-12 h)

| # | Task | Effort | Area |
|---|---|---|---|
| 1 | Fix `widget_test.dart:16` (`MyApp` -> root widget attuale) | 10 min | Test |
| 2 | Rimuovere 5 unused imports/locals | 15 min | Analyze |
| 3 | Aggiungere 50+ chiavi `goals.*` + `common.clear` in 6 locale | 2 h | i18n |
| 4 | Migrare API keys a `flutter_secure_storage` | 1.5 h | Security |
| 5 | Fix Robinhood costBasis formula | 15 min | Parser |
| 6 | Wire GoalsTab in HomePage o eliminare feature | 1 h | UI |
| 7 | Sync snapshot market data + verificare workflow | 30 min | Data |
| 8 | UI stale banner su `as_of_date > 3 giorni` | 45 min | UI |
| 9 | Fix router deep-link race (sync flag) | 30 min | Navigation |
| 10 | `position_detail` not-found state (no firstWhere fallback) | 30 min | UI |
| 11 | `add_position` _isLoading gate su BlocListener | 15 min | UI |
| 12 | Delete actions con AlertDialog (position/portfolio/goal) | 1 h | UI |
| 13 | Fix IBKR parser: rimuovi duplicati + header lookup KeyStats | 1.5 h | Parser |
| 14 | Fix BLoC copyWith sentinel pattern (Goals, Settings) | 1 h | BLoC |
| 15 | Fix goals_bloc sync_with_portfolio (filtro tipo + FX) | 1 h | BLoC |
| 16 | Rimuovere em-dash da 2 .dart + fix ASCII critici | 30 min | Style |

### Sprint 1 -- Quality & Robustness (12-16 h)

- Test suite baseline (bloc test, parser test per ogni broker) -- 6 h
- Retry logic su eodhd/fmp/Gemini -- 2 h
- Failure notification GitHub Actions -- 1 h
- Dark mode audit completo + replace Colors.grey/white/black -- 3 h
- FilteringTextInputFormatter su tutti i form numerici -- 1 h
- i18n hardcoded strings (ErrorPage, position_detail, "No portfolio loaded") -- 2 h
- Gemini input truncation + debounce + 429 handling in chat() -- 2 h

### Sprint 2 -- Architettura & Dead Code (6-10 h)

- Spostare `GeminiService` dentro `AnalysisChatBloc`/`AnalysisBloc` -- 3 h
- Refactor `add()` chain in portfolio_bloc/rebalancing_bloc (`_saveAndEmit` helper) -- 1.5 h
- Cleanup orphan i18n keys (~15 chiavi) -- 1 h
- Fix PdfImportParser contract o documentare eccezione -- 1 h
- Replace magic strings con costanti (`rebalance_targets`, `current_portfolio_id`) -- 30 min
- Hive `openBox` error handling con recovery -- 1 h

---

## Note Finali

- **Zero modifiche al codice eseguite durante questo audit**. Tutti i findings sono basati su read-only analysis di 4+5 subagent paralleli.
- **File di questo report**: `CODE_AUDIT_REPORT.md` (root). Da aggiornare quando i fix vengono applicati, oppure eliminare a fix completati.
- **Prossimo passo suggerito**: iniziare Sprint 0 dal task #1 (test + analyze pulito -> sblocca quality gate) e task #3 (i18n goals -> sblocca feature utente-visibile). Entrambi parallelizzabili.
