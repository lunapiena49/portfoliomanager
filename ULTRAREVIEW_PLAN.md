# ULTRAREVIEW PLAN — Portfolio Manager

> **Stato: COMPLETATO (2026-04-18)** — tutte e 3 le sessioni eseguite in data 2026-04-18.
> Vedi [IMPLEMENTATION_HISTORY.md](IMPLEMENTATION_HISTORY.md) per il dettaglio dei deliverable prodotti.

Piano operativo per configurare Claude Code (CLAUDE.md, skills, hooks, integrazione RTK) e automazioni
(daily commit + market data sync) tramite sessioni di ultrareview sequenziali.

- Target: app Flutter multi-piattaforma (Android, iOS, Web, Windows, Linux, macOS)
- Stack: BLoC + get_it + go_router + dio + hive + easy_localization + fl_chart + syncfusion + Gemini AI
- Dominio: import broker multipli, analisi AI, market data pipeline (GitHub Actions + Pages)

---

## 0. Stato attuale (baseline)

Presenti:
- `IMPLEMENTATION_HISTORY.md` (storico commit + sessioni)
- `QUICK_START.md`, `flutter_workflow.md`, `formati_brokers.md`, `analisi_codice.md`, `lista_files.md`, `lista_moduli.md`
- `.github/workflows/market-data-snapshot.yml` (cron 22:35 UTC, pubblica su GitHub Pages)
- `scripts/eodhd/build_daily_market_snapshot.py` + `sync_market_snapshot_from_pages.ps1`
- `push_to_github.ps1`
- 12 parser broker, 6 lingue in `assets/translations/`

Mancanti:
- `CLAUDE.md` (istruzioni Claude per la repo)
- `.claude/` (settings, skills, hooks)
- `USER_FEATURES.md` (catalogo funzioni utente finale)
- Hook / action che integri **RTK** per ogni Bash (obbligatorio per ottimizzazione token)
- Automazione `git commit` giornaliero dei dati al primo utilizzo

---

## 1. Criteri di qualità (definition of done, globale)

1. Ogni comando Bash in una sessione Claude passa attraverso `rtk` (hook `PreToolUse`).
2. CLAUDE.md contiene: overview, architettura, workflow dev, comandi obbligatori (`rtk flutter ...`, `rtk git ...`), convenzioni di commit, checklist pre-release, regole sui file sensibili.
3. Le skills coprono i 5 workflow core del progetto (build, release, import broker, traduzioni, market data).
4. GitHub Action dedicata (separata da `market-data-snapshot.yml`) esegue `git commit` quotidiano dei dati aggiornati sulla `main` (solo se ci sono diff reali).
5. `USER_FEATURES.md` e `IMPLEMENTATION_HISTORY.md` vengono aggiornati automaticamente dall'hook `Stop` a fine sessione tramite una skill dedicata.
6. `flutter analyze` e `flutter test` verdi prima di ogni commit generato dalle skill.

---

## 2. Sessioni di ultrareview pianificate

### Sessione #1 — Fondazioni Claude Code ✅

Obiettivo: rendere il repo "Claude-ready" e risparmiare token da subito.

Deliverable:
1. **`CLAUDE.md`** (root) contenente:
   - Overview progetto (1 riga), piattaforme target, entry-point.
   - Struttura `lib/` (features/services/core) e convenzioni BLoC.
   - Comandi obbligatori prefissati con `rtk`:
     - `rtk flutter pub get`
     - `rtk flutter analyze`
     - `rtk flutter test`
     - `rtk flutter run -d chrome --web-port 8080`
     - `rtk flutter build web --release`
     - `rtk flutter build apk --release`
     - `rtk git status|diff|log|add|commit|push`
   - Regole specifiche:
     - Mai modificare `pubspec.lock` a mano.
     - Mai committare contenuti di `dist/market-data/`, `build/`, `.dart_tool/` (già gitignored — verificare).
     - Aggiungere chiavi in **tutte e 6** le lingue (`it/en/es/fr/de/pt`) contemporaneamente.
     - Le API keys (Gemini, EODHD) vivono in `flutter_secure_storage` / GitHub Secrets — **mai hardcoded**.
   - Convenzioni commit: `feat:`, `fix:`, `chore:`, `docs:` (coerenti con git log esistente).
   - Pre-release checklist (richiama `QUICK_START.md` §8).

2. **`.claude/settings.json`** con:
   - `env`: `FORCE_COLOR=0`, `FLUTTER_SUPPRESS_ANALYTICS=true`.
   - `permissions.allow`: `Bash(rtk git:*)`, `Bash(rtk flutter:*)`, `Bash(rtk gh:*)`, `Bash(flutter analyze)`, `Bash(flutter test)`, `Bash(flutter pub get)`, `Read`, `Edit`, `Write`, `Glob`, `Grep`.
   - `permissions.deny`: `Bash(git push --force*)`, `Bash(rm -rf*)`, `Bash(flutter clean)` senza conferma.
   - `hooks`: vedi §3.

3. **`USER_FEATURES.md`** prima versione (catalogo generato leggendo `lib/features/*/presentation/pages/*.dart` e `assets/translations/it.json`):
   - Portfolio: crea, importa da 12 broker (IBKR/TD/Fidelity/Schwab/ETrade/Robinhood/Vanguard/DEGIRO/Trading212/XTB/Revolut/generic), aggiunge manualmente posizioni, detail view con P&L.
   - Analisi: AI (Gemini) su portafoglio, chat contestuale.
   - Goals: obiettivi di investimento con progress chart e rebalance.
   - Market: top movers, calendario economico, filtri dollar volume.
   - Settings: lingua (6), valuta, tema, API key Gemini.
   - Onboarding: multi-step + guide page.

4. **`IMPLEMENTATION_HISTORY.md`** — aggiunge voce sessione #1 (in formato compatto, tabella + bullet).

Output atteso: ~6 file nuovi/aggiornati, 0 righe di codice Dart toccate.

---

### Sessione #2 — Skills + hooks + RTK enforcement ✅

Obiettivo: automatizzare i workflow ricorrenti e rendere RTK impossibile da saltare.

Deliverable:

1. **Hook `PreToolUse` Bash → RTK rewrite** (`.claude/hooks/rtk-rewrite.ps1` + settings):
   - Intercetta ogni `Bash` tool use, controlla il comando.
   - Se inizia con uno dei comandi filtrati da RTK (`git`, `flutter`, `gh`, `pnpm`, `npm`, `npx`, `ls`, `grep`, `find`, `cargo`, ecc.) e **non** è già prefissato con `rtk`, blocca l'esecuzione con messaggio `"use rtk <cmd>"`.
   - Whitelist esplicita di eccezioni documentata nell'hook.

2. **Skills dedicate** in `.claude/skills/`:
   - `flutter-dev` — avvio app in debug (web o device), richiama `QUICK_START.md`.
   - `flutter-release` — build web + apk release con verifica `flutter analyze` + `flutter test` (fail-fast).
   - `broker-parser` — genera nuovo parser broker partendo da template (`base_parser.dart`), aggiorna `parser_factory.dart` e `formati_brokers.md`.
   - `translations-sync` — trova chiavi mancanti tra i 6 file `assets/translations/*.json`, genera report, opzionalmente aggiunge placeholder.
   - `market-data-local` — lancia `scripts/eodhd/sync_market_snapshot_from_pages.ps1` e verifica `as_of_date` recente.
   - `session-wrap` — **skill obbligatoria a fine sessione** che:
     - Legge git log dei commit della sessione.
     - Aggiunge voce compatta a `IMPLEMENTATION_HISTORY.md` (data, commit, 1 bullet per change).
     - Aggiorna `USER_FEATURES.md` se sono toccati file in `lib/features/*/presentation/pages/`.

3. **Hook `Stop`** che richiama `session-wrap` automaticamente se ci sono commit nuovi rispetto a `HEAD` all'inizio sessione.

4. **Hook `SessionStart`** che:
   - Esegue `rtk git pull --ff-only` se la branch è `main`.
   - Verifica `as_of_date` del market snapshot; se > 24h, avvisa di rilanciare `market-data-local`.

Output atteso: 4 hook, 6 skill, update `CLAUDE.md` con sezione "Skills disponibili".

---

### Sessione #3 — GitHub Actions: daily commit + consolidation ✅

Obiettivo: soddisfare il requisito **"git + commit e aggiornamento dati tramite GH Action cron ad ogni nuovo giorno di utilizzo"**.

Deliverable:

1. **Nuova workflow `.github/workflows/daily-data-commit.yml`**:
   - Trigger: `workflow_dispatch` + `schedule` (cron `0 7 * * *` → 07:00 UTC, prima dell'orario di utilizzo tipico dell'utente).
   - Step:
     - `actions/checkout@v4` con `token: ${{ secrets.GITHUB_TOKEN }}` e `fetch-depth: 0`.
     - `python scripts/eodhd/build_daily_market_snapshot.py` (riuso dello stesso script del workflow Pages).
     - `scripts/ci/commit_if_changed.ps1` o step inline:
       - `git config user.name "github-actions[bot]"`
       - `git config user.email "41898282+github-actions[bot]@users.noreply.github.com"`
       - `git add dist/market-data/ IMPLEMENTATION_HISTORY.md`
       - `git diff --staged --quiet || git commit -m "chore(data): daily snapshot $(date -u +%Y-%m-%d)"`
       - `git push`
   - Guard rail: step salta se `dist/market-data/` non ha modifiche reali.
   - Concurrency group: `daily-data-commit` (no cancel-in-progress per non perdere giorni).

2. **Interazione con workflow esistente**:
   - `market-data-snapshot.yml` resta come pubblicazione Pages (non-gated).
   - Il nuovo workflow è **source of truth** per la history committata nella repo.
   - Verifica assenza di race condition (i due workflow non devono scrivere sugli stessi artifact contemporaneamente — diversi output dir / `concurrency`).

3. **Session-start hook** (aggiunto in sessione #2) triggera `rtk gh workflow run daily-data-commit.yml` se l'ultimo run è > 24h → soddisfa "ad ogni nuovo giorno di utilizzo dell'app".

4. **Cleanup documentazione** (opzionale ma consigliato):
   - Merge `lista_files.md` + `lista_moduli.md` + `analisi_codice.md` in un unico `ARCHITECTURE.md` (oppure spostarli in `docs/archive/` se storici).
   - Aggiornare `README.md` (oggi è placeholder Flutter default) con overview reale + link a `QUICK_START.md` e `USER_FEATURES.md`.

Output atteso: 1 workflow nuovo, 1 script helper, README rifatto, docs consolidate.

---

## 3. Hook model (riepilogo)

| Hook | Trigger | Azione |
|---|---|---|
| `SessionStart` | Inizio sessione | `rtk git pull --ff-only`; trigger GH Action daily se stale |
| `PreToolUse` | Prima di ogni Bash | Forza prefisso `rtk` su comandi filtrati; blocca altrimenti |
| `PreToolUse` | Prima di Write/Edit su `assets/translations/*.json` | Avvisa se le 6 lingue non sono tutte toccate |
| `Stop` | Fine sessione | Se ci sono commit nuovi → lancia skill `session-wrap` |

---

## 4. File attesi al termine delle 3 sessioni

```
portfolio_manager/
├── CLAUDE.md                          [NEW - sessione 1]
├── USER_FEATURES.md                   [NEW - sessione 1, aggiornato ogni sessione]
├── IMPLEMENTATION_HISTORY.md          [EXIST - aggiornato ogni sessione]
├── ULTRAREVIEW_PLAN.md                [NEW - questo file]
├── README.md                          [REWRITE - sessione 3]
├── .claude/
│   ├── settings.json                  [NEW - sessione 1]
│   ├── hooks/
│   │   ├── rtk-rewrite.ps1            [NEW - sessione 2]
│   │   ├── session-start.ps1          [NEW - sessione 2]
│   │   └── stop-wrap.ps1              [NEW - sessione 2]
│   └── skills/
│       ├── flutter-dev/SKILL.md       [NEW - sessione 2]
│       ├── flutter-release/SKILL.md   [NEW - sessione 2]
│       ├── broker-parser/SKILL.md     [NEW - sessione 2]
│       ├── translations-sync/SKILL.md [NEW - sessione 2]
│       ├── market-data-local/SKILL.md [NEW - sessione 2]
│       └── session-wrap/SKILL.md      [NEW - sessione 2]
└── .github/workflows/
    ├── market-data-snapshot.yml       [EXIST]
    └── daily-data-commit.yml          [NEW - sessione 3]
```

---

## 5. Contratti dei file viventi (aggiornati ogni sessione)

### `IMPLEMENTATION_HISTORY.md`
- Formato compatto (max ~150 righe nuove per sessione, poi consolidate).
- Sezione "Sessione YYYY-MM-DD": bullet elenco change, 1 riga per commit.
- Niente duplicazione di `git log` — solo voci a valore aggiunto (perché, non solo cosa).

### `USER_FEATURES.md`
- Organizzato per **area funzionale** (Portfolio / Analysis / Goals / Market / Settings / Onboarding).
- Ogni voce: `- [nome feature]: [descrizione 1 riga] · [file principale]:[line]`.
- Aggiornato **solo** se l'area feature ha change nella sessione.

---

## 6. Rischi e mitigazioni

| Rischio | Mitigazione |
|---|---|
| Hook RTK rompe tool use su Windows | Test su `powershell` + `bash`; whitelist esplicita |
| Daily commit workflow spamma la history | Skip commit su diff vuoto; messaggio deterministico |
| Sessione senza connessione → pull fallisce | Hook `SessionStart` non-blocking con warning |
| Skill `session-wrap` aggiorna doc fuori sessione | Trigger solo su `Stop` con commit nuovi |
| Translations sync introduce regressioni | Skill genera report, non scrive placeholder senza conferma |

---

## 7. Come procedere

Avvio consigliato:
1. Utente conferma piano (o richiede modifiche).
2. Esecuzione **Sessione #1** (fondazioni): `/review` della codebase completa in ultrareview mode → produce `CLAUDE.md`, `.claude/settings.json`, `USER_FEATURES.md`, update `IMPLEMENTATION_HISTORY.md`.
3. Esecuzione **Sessione #2** (skills + hook): dopo validazione sessione 1.
4. Esecuzione **Sessione #3** (GH Action + consolidation): dopo validazione sessione 2.

Ogni sessione si chiude con commit via `rtk git commit` e aggiornamento di `IMPLEMENTATION_HISTORY.md` e (se applicabile) `USER_FEATURES.md`.
