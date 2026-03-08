# IMPLEMENTATION HISTORY

Storico implementazioni recuperabile da git e documentazione interna.

## Fonti usate

- `git log`
- `analisi_codice.md`
- `formati_brokers.md`
- `flutter_workflow.md`

## Timeline commit (storico recuperato)

| Date (UTC) | Commit | Summary |
|---|---|---|
| 2026-02-23 | `9499e16` | Finalizzazione filtro top movers basato su dollar volume. |
| 2026-02-22 | `52ee380` | Min mover volume portato a 1.5M, fix truncation timeframe tab, auto-download snapshot. |
| 2026-02-20 | `c945b23` | Migrazione snapshot a rolling history DB e hardening prezzo in market tab. |
| 2026-02-19 | `149c908` | Refresh onboarding/help e cleanup mapping di mercato deprecati. |
| 2026-02-19 | `9827b4d` | Enforce min-volume movers e schedule snapshot giornaliero. |
| 2026-02-19 | `dc25022` | Correzione calcolo top movers in pipeline snapshot. |
| 2026-02-18 | `d1b2670` | Fix CI: auto-enable GitHub Pages nel workflow market snapshot. |
| 2026-02-18 | `6fb0324` | Import iniziale progetto + push trigger per market snapshot. |

## Baseline funzionale emersa dalla documentazione

1. Architettura Flutter modulare per feature (`portfolio`, `market`, `goals`, `analysis`, `settings`).
2. BLoC per stato applicativo principale (portfolio/settings/onboarding/goals).
3. Parser dedicati per broker multipli (IBKR, TD, Fidelity, Schwab, ETrade, Robinhood, Vanguard, DEGIRO, Trading212, XTB, Revolut, generic).
4. Localizzazione multi-lingua completa su `assets/translations`.
5. Pipeline market data automatica con GitHub Actions + pubblicazione artifact su GitHub Pages.

## Implementazioni eseguite in questa sessione (2026-03-08)

1. Cleanup file obsoleto
   - Rimosso backup non usato: `lib/features/goals/presentation/pages/goals_tab.dart.backup`.

2. Allineamento traduzioni (copertura completa)
   - Aggiunte chiavi mancanti:
     - `portfolio.create_empty_tab`
     - `portfolio.create_import_tab`
   - Lingue aggiornate: `de`, `es`, `fr`, `pt`.

3. Sync dati market locale da GitHub Pages
   - Aggiunto script: `scripts/eodhd/sync_market_snapshot_from_pages.ps1`.
   - Script scarica:
     - `top_movers.json`
     - `prices_index.json`
     - `daily_market.db.zip`
     - `market_history.db.zip`
   - Dati locali verificati dopo sync:
     - top movers `as_of_date`: `2026-03-06`
     - prices index `generated_at_utc`: `2026-03-07T22:59:08.218268+00:00`

4. Pull repository
   - Eseguito `git pull --ff-only`.
   - Stato remoto: `Already up to date`.

## Note operative

- La cartella `dist/` contiene artifact locali pesanti usati a runtime/test locale e non viene inclusa automaticamente nei commit se non esplicitamente aggiunta.
- Questo documento verra aggiornato nelle prossime sessioni con i nuovi commit.
