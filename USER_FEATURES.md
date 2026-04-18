# USER_FEATURES -- Portfolio Manager

Catalogo funzionalita disponibili all'utente finale. Organizzato per area, con riferimento ai file principali.
Aggiornato alla sessione: **2026-04-18** (Ultrareview #1).

---

## Onboarding & avvio

- **Selezione lingua + valuta base**: schermata iniziale con supporto IT/EN/ES/FR/DE/PT e valute EUR/USD/GBP/CHF/JPY/CAD/AUD - [lib/features/onboarding/presentation/pages/onboarding_page.dart](lib/features/onboarding/presentation/pages/onboarding_page.dart)
- **Onboarding multi-step**: 7 slide (welcome, setup, import, analysis, tracking, goals, market, security) - [lib/features/onboarding/presentation/pages/onboarding_page.dart](lib/features/onboarding/presentation/pages/onboarding_page.dart)
- **Guide in-app**: sezioni getting_started, importing, analysis, market_data, data_pipeline, privacy, troubleshooting, charts, goals, rebalancing, glossary - [lib/features/onboarding/presentation/pages/guide_page.dart](lib/features/onboarding/presentation/pages/guide_page.dart)
- **Splash + persistenza stato onboarding**: stato salvato in `shared_preferences`, replay possibile da Impostazioni > Informazioni

---

## Portafoglio

- **Crea portafoglio vuoto** con nome custom - [lib/features/portfolio/presentation/pages/create_portfolio_page.dart](lib/features/portfolio/presentation/pages/create_portfolio_page.dart)
- **Gestione multi-portafoglio**: selezione, rinomina, eliminazione, switch via dialog - [lib/features/portfolio/presentation/pages/home_page.dart](lib/features/portfolio/presentation/pages/home_page.dart)
- **Aggiunta manuale posizione**: simbolo, nome, quantita, prezzo, costo base, settore, valuta, tipo asset, regione (con auto-detect) - [lib/features/portfolio/presentation/pages/add_position_page.dart](lib/features/portfolio/presentation/pages/add_position_page.dart)
- **Dettaglio posizione**: P&L, P&L %, allocazione, tags tipo/settore, valuta - [lib/features/portfolio/presentation/pages/position_detail_page.dart](lib/features/portfolio/presentation/pages/position_detail_page.dart)
- **Modifica posizione**: aggiornamento campi, exchange esplicito - chiave i18n `edit_position`
- **Summary card portafoglio**: valore totale, P&L totale, variazione giornaliera, numero posizioni - [lib/features/portfolio/presentation/widgets/portfolio_summary_card.dart](lib/features/portfolio/presentation/widgets/portfolio_summary_card.dart)
- **Filtri posizioni**: All / Stocks / ETFs / Crypto / Bonds / Options / Futures / Cash / Funds / Commodities / CFDs / Unassigned - [lib/features/portfolio/presentation/pages/home_page.dart](lib/features/portfolio/presentation/pages/home_page.dart)
- **Ordinamento**: per nome, valore, P&L, P&L %, settore
- **Grafici portafoglio**: treemap posizioni (peso sul valore totale), treemap geografica (US/EU/Asia/Rest/Liquidity/Commodities/Unassigned) - [lib/features/portfolio/presentation/widgets/portfolio_charts.dart](lib/features/portfolio/presentation/widgets/portfolio_charts.dart)

---

## Import da broker

- **12 broker supportati** con parser dedicati - [lib/services/parsers/parser_factory.dart](lib/services/parsers/parser_factory.dart):
  - Interactive Brokers (IBKR) - [lib/services/parsers/ibkr_parser.dart](lib/services/parsers/ibkr_parser.dart)
  - TD Ameritrade - [lib/services/parsers/td_ameritrade_parser.dart](lib/services/parsers/td_ameritrade_parser.dart)
  - Fidelity - [lib/services/parsers/fidelity_parser.dart](lib/services/parsers/fidelity_parser.dart)
  - Charles Schwab - [lib/services/parsers/charles_schwab_parser.dart](lib/services/parsers/charles_schwab_parser.dart)
  - E*TRADE - [lib/services/parsers/etrade_parser.dart](lib/services/parsers/etrade_parser.dart)
  - Robinhood - [lib/services/parsers/robinhood_parser.dart](lib/services/parsers/robinhood_parser.dart)
  - Vanguard - [lib/services/parsers/vanguard_parser.dart](lib/services/parsers/vanguard_parser.dart)
  - DEGIRO - [lib/services/parsers/degiro_parser.dart](lib/services/parsers/degiro_parser.dart)
  - Trading 212 - [lib/services/parsers/trading212_parser.dart](lib/services/parsers/trading212_parser.dart)
  - XTB - [lib/services/parsers/xtb_parser.dart](lib/services/parsers/xtb_parser.dart)
  - Revolut - [lib/services/parsers/revolut_parser.dart](lib/services/parsers/revolut_parser.dart)
  - CSV generico - [lib/services/parsers/generic_parser.dart](lib/services/parsers/generic_parser.dart)
- **Upload file**: drag-and-drop o file picker, formati CSV/PDF - [lib/features/portfolio/presentation/pages/import_page.dart](lib/features/portfolio/presentation/pages/import_page.dart)
- **Anteprima posizioni trovate** prima del salvataggio
- **Import target**: crea nuovo portafoglio o aggiungi a esistente
- **Gestione duplicati**: Ignora / Sostituisci / Somma quantita
- **Help contestuale per broker**: istruzioni step-by-step per export da ciascuna piattaforma

---

## Analisi AI

- **Analisi completa portafoglio**: riepilogo, allocazione asset, analisi rischio, performance, raccomandazioni - [lib/features/analysis/presentation/pages/analysis_page.dart](lib/features/analysis/presentation/pages/analysis_page.dart)
- **Chat contestuale Gemini**: domande libere sul portafoglio con history - [lib/features/analysis/presentation/pages/ai_chat_page.dart](lib/features/analysis/presentation/pages/ai_chat_page.dart)
- **Suggerimenti pre-built**: rischio, diversificazione, performance, raccomandazioni
- **Metriche esposte**: Sharpe, Sortino, Volatility, Beta, Alpha, Max Drawdown
- **Modello**: `gemini-2.5-flash` default con safety settings - [lib/services/api/gemini_service.dart](lib/services/api/gemini_service.dart)
- **Requisito**: chiave API Gemini in Impostazioni > AI

---

## Mercato

- **Top gainers / Top losers globali**: 8 mercati (US, LSE, XETRA, PA, TO, HK, AU, NSE) - [lib/features/market/presentation/pages/market_tab.dart](lib/features/market/presentation/pages/market_tab.dart)
- **Timeframe selector**: Today / 5 giorni / 1 mese / 1 anno
- **Filtri mover**: dollar volume ? $1M, prezzo ? $1 (esclude penny stock)
- **Snapshot gratuito senza API key**: feed pubblico via GitHub Pages (aggiornato da workflow)
- **Prezzi live portafoglio** (opzionali): catena fallback EODHD real-time -> EODHD EOD -> FMP -> snapshot
- **Badge fonte prezzo**: indica provenienza quotazione per ogni posizione
- **Outlier blocker**: blocca salti di prezzo sospetti
- **Calendario economico**: eventi con impact level, forecast, actual, previous

---

## Obiettivi

- **Creazione obiettivi** per tipo (retirement, savings, purchase, education, generic) - [lib/features/goals/presentation/pages/goals_tab.dart](lib/features/goals/presentation/pages/goals_tab.dart)
- **Progress chart**: avanzamento verso target nel tempo
- **Contributo mensile** configurabile
- **Sync con portafoglio**: importa allocazione corrente come baseline
- **Rebalance sheet**: confronto target vs. attuale con suggerimenti
- **Modifica / eliminazione** obiettivo con conferma

---

## Ribilanciamento

- **Vista target allocation**: per ogni posizione mostra Attuale / Target / Delta - [lib/features/rebalancing/...](lib/features/rebalancing)
- **Azioni rapide**:
  - Ripristina allocazione attuale (copia pesi correnti)
  - Distribuisci equamente
  - Solo modifiche (filter per delta != 0)
- **Indicatori**: AGGIUNGI / RIMUOVI / OK per ogni riga
- **Summary**: target totale, rimanente al 100%, over/under allocation, stato bilanciato
- **Salvataggio piano**: persistito localmente

---

## Impostazioni

- **Generali**: lingua (6), valuta base (7), tema (light/dark/system) - [lib/features/settings/presentation/pages/settings_page.dart](lib/features/settings/presentation/pages/settings_page.dart)
- **AI**: chiave API Gemini con test connessione
- **EODHD**: chiave API opzionale per quotazioni real-time
- **FMP**: chiave API opzionale come fallback
- **Gestione dati**:
  - Esporta tutti i dati (JSON)
  - Backup / ripristino locale
  - Cancella tutti i dati (azione irreversibile, con conferma)
- **Notifiche** (stub UI): avvisi di prezzo, riepilogo giornaliero, news
- **About**: versione app, rivedi onboarding, privacy, licenze, contatti

---

## Sicurezza & privacy

- Tutti i dati salvati **localmente** su dispositivo (Hive + SharedPreferences)
- Chiavi API in **flutter_secure_storage** (keystore Android / Keychain iOS)
- Top movers funzionano **senza alcuna chiave** (snapshot pubblico)
- Cancellazione dati completa da Impostazioni > Dati

---

## Piattaforme supportate

| Platform | Stato | Note |
|---|---|---|
| Android | ? | `flutter build apk --release` |
| iOS | ? | Richiede Apple Developer Program |
| Web (Chrome) | ? | `flutter build web --release` |
| Windows | ?? | Desktop supported, IAP non disponibile via plugin Flutter |
| Linux | ?? | Desktop supported, non testato attivamente |
| macOS | ?? | Desktop supported, non testato attivamente |

---

## Convenzione di aggiornamento

A fine sessione Claude, se la sessione ha toccato `lib/features/*/presentation/pages/` oppure
`assets/translations/*.json`, aggiungere/modificare le voci sopra nella sezione rilevante e
aggiornare la data nel titolo.
