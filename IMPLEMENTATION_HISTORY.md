# IMPLEMENTATION HISTORY

Storico implementazioni recuperabile da git e documentazione interna.

## Fonti usate

- `git log`
- `docs/archive/codebase-snapshot-2026-02/analisi_codice.md`
- `formati_brokers.md`
- `flutter_workflow.md`

## Timeline commit (storico recuperato)

| Date (UTC) | Commit | Summary |
|---|---|---|
| 2026-04-18 | `90c8258` | Eliminati 59 warning deprecation flutter analyze (Color.withValues, RadioGroup, context.mounted, unused imports). |
| 2026-04-18 | `e90c49d` | Fix Hero tag duplicato su FAB; abilitato Android predictive back gesture (API 33+). |
| 2026-04-18 | `8f4c1a2` | Aggiunta regola CLAUDE.md sezione 4: end-of-session repo sync obbligatorio. |
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

## Sessione 2026-04-18 -- Ultrareview #1+#2+#3 (Claude Code + automazione daily)

Tre sessioni di ultrareview eseguite in sequenza nello stesso giorno, deliverable pianificati in
[ULTRAREVIEW_PLAN.md](ULTRAREVIEW_PLAN.md).

### Ultrareview #1 -- Fondazioni Claude Code

- Creato `ULTRAREVIEW_PLAN.md`: piano 3 sessioni (fondazioni / skills+hooks / GH Action daily commit).
- Creato `CLAUDE.md`: overview progetto, architettura `lib/`, comandi obbligatori `rtk`, regole traduzioni + API keys, convenzioni commit, riferimenti interni.
- Creato `.claude/settings.json`: env + permissions allow/deny/ask per `rtk git/gh/flutter/...`, deny per `push --force`, `rm -rf`, `flutter clean`; ask per commit/push/workflow run.
- Creato `USER_FEATURES.md`: catalogo funzioni utente per area con file:line.

### Ultrareview #2 -- Skills + hooks + RTK enforcement

- Creato hook `.claude/hooks/rtk-rewrite.ps1` (PreToolUse): blocca Bash con binari filtrati (`git`, `gh`, `flutter`, `npm`, ...) non prefissati con `rtk`. Whitelist per `flutter analyze|test|pub get|doctor|devices`.
- Creato hook `.claude/hooks/session-start.ps1`: `git pull --ff-only` su main, check freshness `dist/market-data/top_movers.json`, warning se `daily-data-commit` workflow non eseguito da >24h.
- Creato hook `.claude/hooks/stop-wrap.ps1`: se ci sono commit nuovi o modifiche in `lib/`/`translations/`/`workflows/`, suggerisce l'esecuzione della skill `session-wrap`.
- Create 6 skills in `.claude/skills/`: `flutter-dev`, `flutter-release`, `broker-parser`, `translations-sync`, `market-data-local`, `session-wrap`.
- Registrati hook in `.claude/settings.json`; aggiunte sezione 7 Skills e sezione 8 Hooks in `CLAUDE.md`.

### Ultrareview #3 -- GitHub Action daily commit + consolidation

- Creato workflow `.github/workflows/daily-data-commit.yml`: trigger cron `0 7 * * *` + `workflow_dispatch`, scarica `top_movers.json` dall'endpoint GitHub Pages pubblicato da `market-data-snapshot.yml`, committa su `main` solo se diff reale. Concurrency group dedicato, `cancel-in-progress: false` per non perdere giorni.
- Creato `docs/DATA_SNAPSHOT_LOG.md`: log append-only dei sync giornalieri (popolato dal workflow stesso).
- Aggiornato `.gitignore`: esclusi file pesanti di `dist/market-data/` (`market_history.db.zip` ~950MB, `prices_index.json` ~13MB, `daily_market.db.zip`, `.db`) tramite pattern negate; tracciato solo `top_movers.json` (~745KB/giorno). Escluso anche `.claude/settings.local.json`.
- Riscritto `README.md`: sostituito placeholder Flutter default con overview reale, feature summary, quick start, struttura repo, pipeline dati, riferimenti a docs.
- Archiviati `analisi_codice.md`, `lista_files.md`, `lista_moduli.md` in `docs/archive/codebase-snapshot-2026-02/` con README esplicativo (mappa codebase viva ora in `CLAUDE.md` sezione 2).
- Aggiornati riferimenti obsoleti in `CLAUDE.md` e `IMPLEMENTATION_HISTORY.md`.

### Outcome

- 0 righe di codice Dart modificate.
- 3 workflow attivi: `market-data-snapshot.yml` (pubblicazione Pages, invariato), `daily-data-commit.yml` (nuovo, commit repo), e gli hook Claude Code che li orchestrano.
- Requisito "git + commit e aggiornamento dati tramite GH Action cron ad ogni nuovo giorno di utilizzo" soddisfatto via: cron workflow + hook `SessionStart` che trigga il workflow manuale se l'ultimo run e' stale.

## Sessione 2026-04-18 -- Hardening + subagents

Follow-up post-commit #1, in risposta a feedback utente:

- **Regola ASCII-only nei file di codice** aggiunta in `CLAUDE.md` sezione 4.1. Motivo: em-dash `--` dentro stringhe PowerShell su Windows (default Windows-1252) aveva rotto il parsing di `session-start.ps1` nel commit precedente. Rimossi em-dash da tutti e 3 gli hook; regola ora mandatoria per `.ps1`, `.dart`, `.py`, `.yml`, `.json`.
- **Environment Windows** documentato esplicitamente in `CLAUDE.md` sezione 0 (shell Git Bash, percorsi Unix-style in Bash tool, PowerShell per hook/script, no `&&` in PS, no flag non-POSIX).
- **4 subagents creati** in `.claude/agents/`:
  - `code-reviewer` (Read/Grep/Glob/Bash): punch list per severity su ASCII/security/BLoC/parser/i18n.
  - `test-runner` (Bash/Read/Grep): gate `flutter analyze` + `flutter test` con report failure-only.
  - `docs-updater` (Read/Edit/Write/Grep/Glob/Bash): mirror subagent di skill `session-wrap` per mantenere context main pulito.
  - `i18n-auditor` (Read/Edit/Grep/Glob/Bash): diff chiavi tra i 6 locale, modalita' report-only / placeholder / remove-orphans.
- Aggiunta sezione sezione 9 Subagents in `CLAUDE.md` con differenziazione skill vs agent.

Prossima sessione: lavoro feature reale sull'app (non piu' setup); gli agent e skill sono pronti a essere invocati.

## Sessione 2026-04-18 -- Fix deprecation flutter analyze + Hero tag + Android back gesture

- **Regola CLAUDE.md sezione 4 (end-of-session sync)**: aggiunta obbligatorieta' di push su origin prima di chiudere la sessione; motivazione: evitare commit locali non condivisi dopo sessioni lunghe.
- **Fix Hero tag duplicato** (`home_page.dart`, `goals_tab.dart`): aggiunto `heroTag: 'fab_portfolio_add_position'` e `heroTag: 'fab_goals_add_goal'` ai due FloatingActionButton.extended; Flutter lancia un assert se due Hero con lo stesso tag convivono nella stessa route.
- **Android predictive back gesture** (`AndroidManifest.xml`): abilitato `android:enableOnBackInvokedCallback="true"` per il supporto nativo all'animazione di back introdotta in Android 13 (API 33).
- **Migrazione Color.withOpacity -> Color.withValues** (22 siti in `goals_tab.dart` e `rebalancing_tab.dart`): `withOpacity` e' deprecato dal Flutter 3.27; `withValues(alpha: x)` e' il rimpiazzo ufficiale.
- **Migrazione DropdownButtonFormField.value -> initialValue** (7 siti in `goals_tab.dart`, `add_position_page.dart`, `edit_position_page.dart`, `import_page.dart`): parametro `value` rimosso dalla firma pubblica.
- **Migrazione RadioListTile -> RadioGroup<T>** (`import_page.dart`, `settings_page.dart`): pattern `groupValue/onChanged` sul singolo tile e' ora gestito dall'ancestor `RadioGroup`; aggiornati selettori import target e 3 dialog impostazioni (lingua, valuta, tema).
- **context.mounted / !mounted guards** (9 siti in `language_selection_page.dart`, `import_page.dart`, `settings_page.dart`): inseriti per soddisfare lint `use_build_context_synchronously` dopo ogni `await`.
- **Rimossi unused imports intl** (3 siti: `position_detail_page.dart`, `portfolio_treemap_section.dart`, `position_list_item.dart`).
- **Rimosso parametro deprecated encryptedSharedPreferences** da `FlutterSecureStorage.aOptions` in `local_storage_service.dart`.
- **Fix lint minori**: `sized_box_for_whitespace` in `goals_tab.dart`, `unnecessary_brace_in_string_interps` in `portfolio_treemap_section.dart`, `unnecessary_string_interpolations` in `base_parser.dart`.
- **Risultato**: `flutter analyze` passa con "No issues found!"; `flutter test` verde (34 test); app verificata su Chrome e Pixel 7 emulator.

## Note operative

- La cartella `dist/` contiene artifact locali pesanti usati a runtime/test locale e non viene inclusa automaticamente nei commit se non esplicitamente aggiunta.
- Questo documento verra aggiornato nelle prossime sessioni con i nuovi commit.
- Da Ultrareview #2 in poi l'aggiornamento sara automatizzato via skill `session-wrap` all'hook `Stop`.
