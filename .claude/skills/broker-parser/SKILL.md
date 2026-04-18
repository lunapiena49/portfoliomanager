---
name: broker-parser
description: Crea un nuovo parser broker CSV/PDF partendo dal template base_parser.dart, lo registra nel parser_factory e aggiorna formati_brokers.md. Usa quando l'utente chiede di "aggiungere un broker", "supportare broker X", "nuovo parser per Y", "importa da [nome broker]".
---

# Skill: broker-parser

Aggiunge un parser broker conforme al contract di `base_parser.dart`.

## Input richiesto all'utente

1. **Nome broker** (slug snake_case, es. `saxo_bank`, `interactive_brokers`).
2. **Separatore CSV**: virgola / punto e virgola / auto-detect.
3. **Formato date**: `DD/MM/YYYY`, `YYYY-MM-DD`, `DD-MM-YYYY`, `DD.MM.YYYY`, ecc.
4. **Decimali**: `1,234.56` (US) / `1.234,56` (EU).
5. **File di esempio** (obbligatorio): chiedi di allegare un CSV/PDF reale anonimizzato per validare il parser.

Se mancano → non procedere, chiedi il campione.

## Sequenza

1. **Analizza campione**:
   ```bash
   rtk read <file_campione>
   ```
   Identifica: numero righe header, metadata iniziale, encoding (UTF-8 BOM?), footer disclaimer.

2. **Crea il parser** in [lib/services/parsers/](../../../lib/services/parsers/) seguendo il contract di `base_parser.dart`. Template minimo:
   - Classe `<Broker>Parser extends BaseParser`
   - Override `parse(String content) → List<Position>`
   - Helper `_isHeaderRow`, `_parseNumber`, `_inferAssetType` se serve

3. **Registra in factory**: aggiungi import + case in [lib/services/parsers/parser_factory.dart](../../../lib/services/parsers/parser_factory.dart).

4. **Chiavi i18n import**: aggiungi `import.brokers.<slug>` e `import.help.<slug>` in **tutti e 6** i file `assets/translations/{it,en,es,fr,de,pt}.json` (usa skill `translations-sync` a supporto).

5. **Aggiorna [formati_brokers.md](../../../formati_brokers.md)**: aggiungi sezione con header esatti, separatore, date format, peculiarita'.

6. **Test**:
   ```bash
   flutter test test/services/parsers/
   ```
   (se manca il test, crealo replicando lo stile dei parser esistenti)

## Riferimenti broker gia' supportati

[lib/services/parsers/parser_factory.dart](../../../lib/services/parsers/parser_factory.dart) registra:
IBKR, TD Ameritrade, Fidelity, Charles Schwab, E*TRADE, Robinhood, Vanguard,
DEGIRO, Trading 212, XTB, Revolut, generic.

Vedi [formati_brokers.md](../../../formati_brokers.md) per i 5 problemi critici ricorrenti
(Trading212 colonne dinamiche, Saxo/eToro Excel native, XTB punto-e-virgola,
Fidelity BOM+footer, Schwab metadata pre-header).

## Do / Don't

- Do: normalizza ticker (uppercase, trim exchange suffix se separato) prima di passarlo al motore quote.
- Do: aggrega Buy+Sell in posizione netta se il broker esporta transazioni (vedi `revolut_parser.dart`, `trading212_parser.dart`, `xtb_parser.dart`).
- Don't: hardcodare indici di colonna. Usa header name → index via mapping.
- Don't: lanciare eccezioni su riga singola malformata; salta e logga.
