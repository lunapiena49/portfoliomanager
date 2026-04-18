# CLAUDE.md -- Portfolio Manager

Istruzioni per Claude Code su questo repo. Leggere prima di ogni sessione.

## 0. Environment di sviluppo

- **OS host**: Windows 10/11 -- **sempre**. Shell di default in Claude Code: Git Bash (sintassi Unix: `/dev/null`, forward slash).
- **PowerShell** usato per hook (`.claude/hooks/*.ps1`) e script di supporto (`scripts/eodhd/*.ps1`). Invocazione standard:
  `powershell -NoProfile -ExecutionPolicy Bypass -File <script>`.
- **Path nei comandi Bash**: usa `/c/Projects/portfolio_manager/...` o relativi. Nei `.ps1` e comandi PS: `C:/Projects/...` o `C:\Projects\...`.
- **Sottintendi Windows**: non usare `&&` in PowerShell (solo `;`), non assumere `grep`/`sed` GNU con flag non-POSIX, non usare `rm -rf` (in deny list), mai `chmod`.

## 1. Cos'e' il progetto

App Flutter multi-piattaforma per gestione portafoglio investimenti: import da broker multipli, analisi AI (Gemini),
ribilanciamento, market data via pipeline GitHub Actions.

- **Piattaforme target app**: Android, iOS, Web (Chrome), Windows, Linux, macOS
- **Pubspec**: `portfolio_manager` v1.0.0+1 - Dart SDK `>=3.2.0 <4.0.0`
- **Entry-point**: [lib/main.dart](lib/main.dart) - Router: [lib/app_router.dart](lib/app_router.dart)

## 2. Architettura in 30 secondi

```
lib/
|-- main.dart                   # bootstrap: Hive + EasyLocalization + ScreenUtil + BLoC providers
|-- app_router.dart             # GoRouter: onboarding gate, home con bottom tabs
|-- core/
?   |-- constants/              # AppConstants (env, colors, keys)
?   |-- theme/                  # app_theme.dart (light/dark/system)
?   |-- localization/           # locale helper
?   |-- widgets/                # widget condivisi
|-- features/                   # feature-first, ognuna con bloc/presentation/domain
?   |-- portfolio/              # home, import, add/edit/detail posizione
?   |-- analysis/               # AI analysis + chat Gemini
?   |-- goals/                  # obiettivi + progress chart + rebalance sync
?   |-- market/                 # top movers, calendario economico, prezzi live
?   |-- rebalancing/            # target allocation + delta
?   |-- settings/               # lingua, valuta, tema, API keys
?   |-- onboarding/             # splash, onboarding multi-step, guide
|-- services/
    |-- api/                    # gemini_service.dart (+ EODHD/FMP wrappers)
    |-- parsers/                # 12 parser broker + generic, factory centrale
    |-- storage/                # local_storage_service.dart (Hive + SharedPreferences)
```

**State management**: `flutter_bloc` (`PortfolioBloc`, `SettingsBloc`, `OnboardingBloc`, `GoalsBloc`). Eventi e stati
sono `Equatable`. Niente Provider/Riverpod -- non introdurne.

**Storage locale**: Hive box per portafogli/goals, `shared_preferences` per settings, `flutter_secure_storage` per API keys.

**Network**: `dio` + `retrofit`. Gemini via `gemini_service.dart`. Market data caricato da `dist/market-data/*.json`
(popolato da GitHub Action).

## 3. Comandi (tutti prefissati `rtk`)

RTK (Rust Token Killer) e installato globalmente. **Prefisso obbligatorio** per tagliare output token.
Mai eseguire Bash senza `rtk` sui comandi filtrati (git, flutter, gh, ls, grep, find, npm, pnpm).

### Dev loop
```bash
rtk flutter pub get                           # deps
rtk flutter analyze                           # lint + static analysis
rtk flutter test                              # unit/widget tests
rtk flutter run -d chrome --web-port 8080     # debug web
rtk flutter run -d <DEVICE_ID>                # debug mobile
rtk flutter devices                           # lista device
```

### Release
```bash
rtk flutter clean
rtk flutter pub get
rtk flutter build web --release               # -> build/web/
rtk flutter build apk --release               # -> build/app/outputs/flutter-apk/app-release.apk
rtk flutter build appbundle --release         # -> .aab per Play Store
```

### Git / GitHub
```bash
rtk git status
rtk git diff
rtk git log --oneline -20
rtk git add <file>                            # mai `git add .` -- file specifici
rtk git commit -m "feat: ..."                 # convenzione: feat/fix/chore/docs
rtk git push
rtk gh workflow run daily-data-commit.yml
rtk gh run list --workflow=market-data-snapshot.yml
```

### Market data locale
```bash
powershell -ExecutionPolicy Bypass -File scripts/eodhd/sync_market_snapshot_from_pages.ps1
```
Aggiorna `dist/market-data/top_movers.json`, `prices_index.json`, `market_history.db.zip`.

## 4. Regole di lavoro

1. **ASCII-only nel codice**: **mai** scrivere caratteri non-ASCII (em-dash `--`, apici tipografici `' '` `" "`, accenti `e' a' o' u' i'`, simboli `->`) dentro:
   - script PowerShell (`.ps1`) -- PowerShell su Windows legge come Windows-1252 senza BOM e ROMPE il parsing
   - codice Dart (`.dart`) -- usare stringhe ASCII, l'italiano con accenti va nei file `assets/translations/*.json` (UTF-8) non nel sorgente
   - script Python (`.py`), YAML workflow (`.yml`), JSON config (`.json`)
   Sostitutivi sicuri: `--` per em-dash, `'` per apostrofi, `->` per freccia, `e`/`a`/`o` senza accento o chiave i18n.
   I markdown (`.md`) possono restare UTF-8 per leggibilita', ma evita em-dash anche li' per consistenza.

2. **Traduzioni sincronizzate**: qualsiasi chiave nuova va aggiunta in **tutti e 6** i file
   `assets/translations/{it,en,es,fr,de,pt}.json`. Mai toccarne solo uno.

3. **API keys mai hardcoded**: Gemini/EODHD/FMP vivono in `flutter_secure_storage` (runtime) o GitHub Secrets (CI).

4. **Non committare**:
   - `build/`, `.dart_tool/`, `dist/market-data/*.db*`, `dist/market-data/prices_index.json` (workflow CI li rigenera -- vedi sezione 6)
   - `.env*`, file con API keys, `*.keystore`, `google-services.json` con secret

5. **Parser broker**: usare sempre `base_parser.dart` come template. Registrare il nuovo parser in
   `parser_factory.dart` e aggiornare `formati_brokers.md`.

6. **BLoC**: un evento -> uno state transition. Niente side-effect nei widget.

7. **Pre-release checklist** (vedi [QUICK_START.md](QUICK_START.md) sezione 8):
   - `rtk flutter analyze` pulito
   - `rtk flutter test` verde
   - Traduzioni tutte popolate
   - `dist/market-data/top_movers.json` con `as_of_date` recente

8. **End-of-session sync obbligatorio**: a fine di **ogni** sessione, repo locale e repo GitHub devono essere allineati.
   Prima di chiudere sempre: `rtk git status`, poi se ci sono modifiche utili committarle e `rtk git push`.
   Nessun commit locale deve restare non pushato. Se il push fallisce per non-fast-forward (tipico dopo
   `daily-data-commit.yml`), `rtk git pull --rebase origin main` e ripushare. Non committare mai file ignorati
   o untracked locali (`dist/`, `.claude/scheduled_tasks.lock`).

## 5. Convenzioni commit

Coerente con git log esistente (prefissi lowercase, niente body se fix minimi):

- `feat: ...` -- nuova funzionalita utente-visibile
- `fix: ...` -- bug fix
- `chore: ...` -- refactor/cleanup/CI
- `docs: ...` -- solo documentazione

Esempi reali presenti nel repo:
- `feat: finalize market movers dollar-volume filter`
- `feat: increase min mover volume to 1.5M, fix timeframe tab truncation`
- `chore: cleanup docs and market snapshot local sync`

## 6. Pipeline automazione dati

Due workflow GitHub Actions + un hook locale compongono il ciclo "dati sempre aggiornati":

| Componente | File | Trigger | Output |
|---|---|---|---|
| Market snapshot -> Pages | [.github/workflows/market-data-snapshot.yml](.github/workflows/market-data-snapshot.yml) | cron 22:35 UTC - push main - manual | Rigenera top_movers + prices_index + market_history.db (rolling), pubblica su GitHub Pages |
| Daily data commit -> repo | [.github/workflows/daily-data-commit.yml](.github/workflows/daily-data-commit.yml) | cron 07:00 UTC - manual | Scarica `top_movers.json` da Pages e committa su `main` + aggiorna `docs/DATA_SNAPSHOT_LOG.md` |
| SessionStart sync locale | [.claude/hooks/session-start.ps1](.claude/hooks/session-start.ps1) | apertura sessione Claude | `git pull --ff-only`; se dati locali > 24h lancia `scripts/eodhd/sync_market_snapshot_from_pages.ps1` in background detached (pull-only) |

**Regola sul database**:
- `market_history.db` / `.db.zip` (~950MB) **non** sono in git -- `.gitignore` li esclude.
- Source of truth: **GitHub Pages**, aggiornato dal workflow `market-data-snapshot.yml`.
- Sessione locale: **solo pull** (mai push manuale). Il workflow CI ricalcola e ripubblica.
- Il commit "proof of freshness" nella repo e' solo `top_movers.json` + la riga giornaliera in
  `docs/DATA_SNAPSHOT_LOG.md`, curata dal workflow `daily-data-commit.yml`.

Requisito "git + commit e aggiornamento dati ad ogni nuovo giorno di utilizzo" soddisfatto da:
`SessionStart hook` (pull DB) + cron `daily-data-commit.yml` (commit proof of freshness).

## 7. Skills disponibili

Skills custom del progetto (vedi [.claude/skills/](.claude/skills/)):

| Skill | Quando usarla |
|---|---|
| `flutter-dev` | Avvio app in debug su chrome o device mobile (vedi QUICK_START sezione 4-5) |
| `flutter-release` | Build release web/apk/aab con gate analyze+test |
| `broker-parser` | Aggiunge un nuovo parser broker + registra in factory + aggiorna docs |
| `translations-sync` | Verifica/ripara allineamento chiavi i18n tra i 6 file locale |
| `market-data-local` | Scarica snapshot market data locale da GitHub Pages |
| `session-wrap` | Aggiorna `IMPLEMENTATION_HISTORY.md` e `USER_FEATURES.md` a fine sessione |

Invoca via `/<skill-name>` quando serve.

## 8. Hooks attivi

Configurati in [.claude/settings.json](.claude/settings.json), implementati in [.claude/hooks/](.claude/hooks/):

| Hook | Trigger | Cosa fa |
|---|---|---|
| `SessionStart` | Avvio sessione | `git pull --ff-only` su main; warning se snapshot stale o daily workflow non eseguito da >24h |
| `PreToolUse` (Bash) | Prima di ogni Bash tool use | Blocca comandi filtrati (git/gh/flutter/...) non prefissati con `rtk` |
| `Stop` | Fine sessione | Se ci sono commit nuovi o modifiche in `lib/`/`translations/`/`workflows/`, ricorda di eseguire skill `session-wrap` |

Hook scritti in PowerShell (Windows-first), invocati con `powershell -ExecutionPolicy Bypass`.

## 9. Subagents

Subagent isolati in [.claude/agents/](.claude/agents/) (context separato, non inquinano la sessione principale):

| Agent | Trigger | Tools | Scopo |
|---|---|---|---|
| `code-reviewer` | Dopo change non-triviali in `lib/` o `scripts/` | Read, Grep, Glob, Bash | Punch list per severity (BLOCK/WARN/NIT) su ASCII, sicurezza, BLoC, parser contract, i18n |
| `test-runner` | Dopo change in `lib/` o pre-release | Bash, Read, Grep | Esegue `flutter analyze` + `flutter test`, report solo failure raggruppati per file |
| `docs-updater` | Fine sessione | Read, Edit, Write, Grep, Glob, Bash | Aggiorna `IMPLEMENTATION_HISTORY.md` + `USER_FEATURES.md` (mirror di skill `session-wrap` in subagent) |
| `i18n-auditor` | Modifiche a `assets/translations/*.json` | Read, Edit, Grep, Glob, Bash | Diff chiavi tra i 6 locale, report missing/orphan/placeholder mismatch |

Invocazione tipica: dal main agent via Agent tool (`subagent_type: code-reviewer`) in parallelo a task indipendenti.

Differenza **skill vs agent**:
- **Skill** (`.claude/skills/`) = playbook che guida Claude main, stessa sessione/context.
- **Agent** (`.claude/agents/`) = sessione isolata, context pulito, utile per review indipendenti o operazioni che produrrebbero molto output (test suite, grep massivi).

## 10. File viventi

Tre markdown da tenere aggiornati a fine sessione (skill `session-wrap` / agent `docs-updater`):

- [ULTRAREVIEW_PLAN.md](ULTRAREVIEW_PLAN.md) -- piano delle 3 sessioni di ultrareview (questo piano).
- [IMPLEMENTATION_HISTORY.md](IMPLEMENTATION_HISTORY.md) -- storico compatto (tabella commit + bullet per sessione).
- [USER_FEATURES.md](USER_FEATURES.md) -- catalogo funzioni utente finale per area.

Regola: se la sessione tocca `lib/features/*/presentation/pages/`, aggiornare `USER_FEATURES.md`.
Sempre aggiungere una voce in `IMPLEMENTATION_HISTORY.md` a fine sessione.

## 11. Riferimenti interni

- [QUICK_START.md](QUICK_START.md) -- avvio dev/prod step-by-step
- [formati_brokers.md](formati_brokers.md) -- contract dei CSV broker (12 formati)
- [flutter_workflow.md](flutter_workflow.md) -- workflow release multi-piattaforma generale
- [docs/DATA_SNAPSHOT_LOG.md](docs/DATA_SNAPSHOT_LOG.md) -- log dei sync snapshot giornalieri (popolato da `daily-data-commit.yml`)
- [docs/archive/codebase-snapshot-2026-02/](docs/archive/codebase-snapshot-2026-02/) -- mappa codebase statica Feb 2026 (archivio, non aggiornata)
