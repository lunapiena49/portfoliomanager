# Master Plan — Portfolio Manager v1.0 (Android Play Store)

Sequenza di sessioni ottimizzata per portare l'app sullo store con costo
immediato di **25 USD** (Play Console) e zero altre spese fisse.
Tutto il resto (iOS, marchio, dominio, assicurazione, revisione legale) e'
rimandato a Fase 2 quando l'app produce ricavi sufficienti.

## Vincoli lock-in

- **Persona fisica** (Filippo Salemi)
- **Brand**: PluriFin (developer name) / **Nome app**: Portfolio Manager
- **Bundle ID**: `app.plurifin.portfoliomanager`
- **Web URL**: `https://lunapiena49.github.io/portfoliomanager-data/app/`
- **Solo Android day-1**, iOS in Fase 2
- Repo split: `portfolio-manager-app` (privato) + `portfoliomanager-data` (pubblico)

## Convenzioni tabella

- **Owner**: chi guida la sessione (`U` user / `CC` Claude Code / `CW` Cowork browser)
- **Durata**: tempo stimato attivo (escluse attese tipo posta cartacea Play)
- **Dipende da**: sessioni che devono essere completate prima
- **Blocker**: se la sessione blocca submission o solo migliora robustezza

---

## Sequenza ottimale (17 sessioni in ~ 8-10 settimane)

| # | Sessione | Owner | Durata | Dipende da | Output |
|---|---|---|---|---|---|
| **W1** | **Setup base e codice core** | | | | |
| S1 | Decisioni email + opzionali (P.IVA, conto separato, Yubikey order) | U | 30 min | — | Email scelta, ordini partiti | #email creata: plurifin.app@gmail.com
| S2 | Brand availability check + creazione 2 repo GitHub + branch protection + Pages config + secret scanning | CW + U | 1.5h | S1 | 2 repo pronti, Pages live |
| S3 | Bundle ID + keystore setup script + R8 + Network Security Config + permissions Android | CC | 3-4h | — | Codice migrato bundle ID, build.gradle hardened |
| **W2** | **Sicurezza app** | | | | |
| S4 | Generazione keystore + backup multipli (USB cifrate, Bitwarden, paper) | U | 1h | S3 | upload-keystore.jks + 4 backup separati |
| S5 | Hive encryption + anti-tamper + FLAG_SECURE + backup rules XML | CC | 3-4h | S3 | Storage cifrato, integrity check, screen secure |
| S6 | Disclaimer finanziario in-app + audit trail consenso + Settings page legali | CC | 2-3h | S5 | Onboarding aggiornato, consent_service |
| **W3** | **Compliance e infrastruttura** | | | | |
| S7 | Privacy Policy + ToS scritti da template (6 lingue) + script build_legal_html.ps1 | CC | 3h | S6 | legal/*.md + dist/legal/<lang>/*.html |
| S8 | User legal review (rilegge tutti i testi, conferma) | U | 1.5h | S7 | Approvazione + eventuali correzioni |
| S9 | Repo split staging + cleanup history script + CI/CD release.yml + app-web-deploy.yml | CC | 3h | S2, S8 | repo_split/ pronto, workflow CI |
| S10 | Push iniziale repo privato + repo dati + GitHub Secrets (DATA_REPO_PAT, KEYSTORE_BASE64, passphrase) | CW + U | 1h | S4, S9 | Repo popolati, CI configurabile |
| **W4** | **Build e smoke test** | | | | |
| S11 | Primo build release Android obfuscated locale + smoke test APK su device fisico + smoke test web build | CC + U | 2h | S10 | app-release.aab + apk + build/web/ |
| S12 | Play Console signup (utente paga 25 USD, carica ID) + app creation + Data Safety form | CW + U | 2h | S11 | Play Console attivo, app creata |
| **W4-6** | **Attesa identity verification Play** (0-3 settimane di attesa cartacea) | | | | |
| S13 | Listing Play Store: descriptions 6 lingue + screenshot generation + feature graphic + app icon | CW | 2h | S12 | Listing completo bozza |
| S14 | Final review listing (utente approva testi e visual) | U | 1h | S13 | Listing approvato |
| **W6-7** | **Closed Testing track** | | | | |
| S15 | Upload .aab Closed Testing + invito 12 tester (utente fornisce email) | CW + U | 1h | S14 | Track alpha attiva |
| S16 | 14 giorni Closed Testing (utente monitora feedback, segnala bug, raccoglie review) | U | passive | S15 | Lista bug + feedback |
| **W8** | **Hotfix e production submission** | | | | |
| S17 | Hotfix da feedback beta + bump version + tag release + submit production + risposta a rejection | CC + CW + U | 3-5h | S16 | App live su Play Store |

---

## Diagramma dipendenze

```
W1: [S1 U] → [S2 CW+U]
    [S3 CC] ←─────────────┐
W2: [S4 U] ← S3            │
    [S5 CC] ← S3            │
    [S6 CC] ← S5            │
W3: [S7 CC] ← S6            │
    [S8 U]  ← S7            │
    [S9 CC] ← S2,S8         │
    [S10 CW+U] ← S4,S9 ─────┘
W4: [S11 CC+U] ← S10
    [S12 CW+U] ← S11
W4-6: [⏳ identity verification Play, 0-3 settimane]
    [S13 CW] ← S12
    [S14 U]  ← S13
W6-7: [S15 CW+U] ← S14
      [S16 U  ⏳ 14 giorni Closed Testing]
W8: [S17 CC+CW+U] ← S16 → LIVE
```

## Parallelizzazioni possibili

- **S3 (CC)** puo' partire in parallelo a **S1+S2 (U+CW)** -- non ha dipendenze
  da repo o decisioni utente. Permette di guadagnare ~2-3 giorni.
- **S5 e S6 (CC)** possono essere stessa sessione lunga (5-6h totale)
- **S13 (CW)** puo' iniziare prima di S12 essere completato (testi e screenshot
  preparabili offline)
- **S16 (passive 14 giorni)** -- usa il tempo per S13/S14/S17.prep

## Decision points e blocker bloccanti

1. **Prima di S2**: utente conferma email scelta (Opzione A alias o B account
   dedicato).
2. **Prima di S4**: utente decide se Yubikey o TOTP (la procedura keystore
   funziona uguale, cambia solo il vault Bitwarden).
3. **Prima di S10**: utente ha generato keystore (S4) E ha creato repo (S2). Se
   uno dei due manca, S10 si blocca.
4. **S12 -> S13 attesa**: Google puo' richiedere PIN via posta cartacea per
   verificare indirizzo. Tempi: 2-4 settimane. Inserire indirizzo CORRETTO
   alla prima volta -- non si puo' cambiare durante la prima verifica.
5. **S15 -> S17 attesa**: Closed Testing track e' obbligatoriamente di 14 giorni
   per personal accounts su Play (regola Google 2023). Non si puo' saltare.
6. **S17 review Play**: 24-72h prima volta, fino a 7 giorni. 50% probabilita' di
   rejection iniziale. Tempo extra: 1-2 settimane se serve iterazione.

## Tempistica realistica end-to-end

- **Lavoro attivo totale**: ~ 30-40 ore (CC + CW + U sommati)
- **Tempo calendario minimo** (fortunato): 5 settimane
- **Tempo calendario realistico**: 8-10 settimane
- **Tempo calendario sfortunato** (rejection multiple, ritardo PIN): 12-14
  settimane

## Costi totali v1.0

| Voce | Costo | Quando |
|---|---|---|
| Google Play Console | 25 USD | S12 |
| Yubikey 5C NFC x2 (raccomandato) | ~ 120 € | S1 (opzionale) |
| **Minimo bloccante** | **25 USD** | |
| **Raccomandato** | **~ 145 €** | |

## Output finale al W8/W10

- App "Portfolio Manager" by **PluriFin** live su Google Play Store
- Webapp pubblica su `lunapiena49.github.io/portfoliomanager-data/app/`
- Privacy Policy + Terms hostate stabilmente su GitHub Pages
- Repo privato hardened, repo pubblico con webapp + dati + legal
- CI/CD release pipeline funzionante (tag v* -> build + deploy)
- Sentry crash reporting attivo (free tier)
- Pool di 12+ beta tester che hanno gia' validato la build

## Trigger di promozione a Fase 2 (post-revenue)

Quando le entrate annuali superano le soglie sotto, attivare in ordine:

| Soglia ricavi | Aggiungere | Costo annuo |
|---|---|---|
| 100 € | Apple Developer (sblocca iOS) | 99 USD |
| 200 € | Dominio plurifin.app + custom CNAME Pages | 12 € |
| 500 € | Assicurazione RC Tech (massimale 500k€-1M€) | ~ 500 € |
| 1000 € | Marchio EUIPO PluriFin classi 9+36 | ~ 900 € (one-shot, rinnovo 10 anni) |
| 2000 € | Iubenda Pro + revisione legale fintech una-tantum | ~ 60 €/anno + 500 € one-shot |
| 5000 € | Valutazione SRL + commercialista per ottimizzazione | dipende |

---

## Sequenza ottimale fase-per-fase (mappa integrata A + B + C)

Qui sotto la stessa pipeline vista dalla prospettiva di **ogni** sub-fase
dei tre sub-plan, organizzata in 7 ondate ("wave") con dipendenze esplicite
e stato corrente. Ogni fase del piano A/B/C ha una riga; le wave girano in
sequenza ma dentro la stessa wave i task possono andare in parallelo se
appartengono a stream (Owner) diversi.

Legenda owner: **CC** = Claude Code, **CW** = Claude Cowork (browser),
**U** = utente.
Legenda stato: `done` = chiuso, `wip` = parzialmente fatto, `todo` =
da fare, `wait` = bloccato da attesa esterna.

---

### Wave W1 — Preparativi senza dipendenze (settimana 1)

Tutto cio' che si puo' fare prima di toccare Play Console o di pagare.

| # | Owner | Sub-fase | Output | Dipende da | Stato |
|---|---|---|---|---|---|
| 1 | U  | 0C.1 Conferme lock-in (persona fisica, brand, bundle ID, no iOS) | Decisioni in `00_master_plan.md` | -- | done |
| 2 | U  | 0C.2 Email professionale (Opzione B: `plurifin.app@gmail.com`) | Account creato | -- | done |
| 3 | U  | 0C.3 P.IVA forfettaria (rimandata) | Decisione tracciata | -- | done (rimandata) |
| 4 | U  | 0C.4 Conto corrente attivita' separato | Conto aperto | -- | done |
| 5 | U  | 1C.1 2FA hardware -> TOTP ora, Yubikey rimandate | Authenticator app attiva | 2 | wip (TOTP attivo, Yubikey post-revenue) |
| 6 | U  | 1C.2 Vault password (Proton Pass per ora, Bitwarden in futuro) | Vault con master password | 2 | wip (Proton attivo) |
| 7 | U  | 1C.4 Google account dedicato 2FA | 2FA attiva su `plurifin.app@gmail.com` | 2 | done |
| 8 | U  | 1C.5 ID digitalizzato (passaporto + carta identita') cifrato | File in Proton/Bitwarden Send | 6 | todo |
| 9 | CW | 0B.1 Brand availability check PluriFin (TMview / Madrid Monitor / Play Store / dominio) | `.claude/plan/output/brand_availability_report.md` | -- | todo |
| 10 | CC | 1A.1 gitleaks + secret scanning + pre-commit hook | `.gitleaks.toml`, hook PowerShell, report pulito | -- | done |
| 11 | CC | 1A.2 Repo split staging (`repo_split/app/` + `repo_split/data/`) | Cartelle pronte + READMEs | -- | done |
| 12 | CC | 1A.3 `marketSnapshotBaseUrl` + `--dart-define=MARKET_SNAPSHOT_BASE_URL` | Codice app puntato al repo dati pubblico | -- | done |

**Gate W1 -> W2**: brand non in conflitto (9), 1A.1-3 chiusi, decisioni 0C
chiuse, ID utente pronto (8 e' l'unico todo bloccante).

---

### Wave W2 — Hardening codice + sicurezza account (settimane 1-2)

Il "muro" tecnico prima di toccare la Play Console. Stream CC e U girano
in parallelo.

| # | Owner | Sub-fase | Output | Dipende da | Stato |
|---|---|---|---|---|---|
| 13 | CC | 2A.1 Bundle ID `app.plurifin.portfoliomanager` su Android/iOS/macOS/Linux/Windows + Kotlin sources | Build target unificato | W1 | done |
| 14 | CC | 2A.2 `setup_keystore.ps1` + `key.properties` wiring + signingConfigs | Script + Gradle wiring (gitignored) | 13 | done |
| 15 | CC | 2A.3 R8 + shrinkResources + `proguard-rules.pro` | Release piu' piccolo, decompilazione resa difficile | 14 | done |
| 16 | CC | 2A.4 Network Security Config + iOS ATS strict + backup_rules.xml + data_extraction_rules.xml | Cleartext OFF, backup OFF | 13 | done |
| 17 | CC | 2A.5 SecureScreen MethodChannel `FLAG_SECURE` + wrapping pagine sensibili | No screenshot/screen-record sui dati portafoglio | 13 | done |
| 18 | CC | 2A.6 Hive encryption AES-256 + migrazione plaintext one-shot | Box cifrati, dati storici importati | -- | done |
| 19 | CC | 2A.7 Anti-tamper jailbreak/root detection (`flutter_jailbreak_detection`) | `IntegrityCheck` cached al boot | -- | done |
| 20 | CC | 2A.8 Pipeline obfuscation (`build_release.ps1` + symbols + manifest sha256) | Symbols archive `~/.plurifin/symbols/<v>/` | 14, 15 | done |
| 21 | CC | 2A.9 Disclaimer finanziario + ConsentService + AiDisclaimerBanner | Onboarding gate + audit trail | -- | done |
| 22 | CC | 2A.10 LegalDocumentsPage in Settings + URL Privacy/Terms + open-source licenses | Settings -> Legal documents | 21 | done |
| 23 | CC | 2A.11 Astrazione `IGeminiClient` + `--dart-define=GEMINI_MODE=direct\|proxy` | Pronti per migrare a Cloudflare in Fase 2 | -- | done |
| 24 | U  | 1C.3 GitHub account hardening (2FA WebAuthn -> TOTP per ora) | 2FA attiva su `lunapiena49` | W1 | todo |
| 25 | U  | 2C.1 Carta dedicata (Postepay/Revolut/Hype prepagata) | Carta con max 100 EUR | -- | done |
| 26 | U  | 2C.2 Tracking spese (Google Sheet) | Sheet operativo | -- | wip (rimandato) |

**Gate W2 -> W3**: tutta la fase 2A chiusa (done), GitHub 2FA hardened (24).

---

### Wave W3 — Compliance legale + repo GitHub live (settimane 2-3)

CC genera i testi legali, U li rivede, CW pubblica i due repo e li configura.

| # | Owner | Sub-fase | Output | Dipende da | Stato |
|---|---|---|---|---|---|
| 27 | CC | 4A.1 Privacy Policy + ToS + disclaimer in `legal/*.md` (IT) | 4 file MD principali | W2 | todo |
| 28 | CC | 4A.1 Traduzioni EN/ES/FR/DE/PT dei 4 file legali | 24 file MD totali | 27 | todo |
| 29 | CC | 6A.3 `scripts/legal/build_legal_html.ps1` -> `dist/legal/<lang>/<doc>.html` | HTML pronti al deploy | 28 | todo |
| 30 | CC | 4A.2 Open source licenses generation in `lib/generated/licenses.dart` | Pagina licenze in-app | -- | todo |
| 31 | CC | 4A.3 Audit trail consenso + export GDPR (Settings -> Esporta dati) | ZIP export portafoglio + consensi + log | 21 | todo |
| 32 | U  | 5C.1 Review Privacy + ToS (sub-processor, foro Italia, email contatto) | OK utente o richieste fix | 28 | todo |
| 33 | U  | 5C.2 Review disclaimer finanziario (TUF, MiFID II, lessico) | OK utente | 28 | todo |
| 34 | U  | 5C.3 Registro trattamenti GDPR (modello Garante) offline | PDF locale | 28 | todo |
| 35 | CW | 1B.1 Repo privato `portfolio-manager-app` su GitHub | Repo creato | 24 | todo |
| 36 | CW | 1B.2 Repo pubblico `portfoliomanager-data` | Repo creato | 24 | todo |
| 37 | CW | 1B.3 Branch protection main (PR required, signed commits, status checks) | Settings ON su entrambi | 35, 36 | todo |
| 38 | CW | 1B.4 GitHub Pages config su repo data (root, HTTPS) | URL `lunapiena49.github.io/portfoliomanager-data/` live | 36 | todo |
| 39 | CW | 1B.5 Push protection + secret scanning + Dependabot + CodeQL su entrambi | Code security ON | 35, 36 | todo |
| 40 | U  | 1C.3 Personal Access Token `DATA_REPO_PAT` (scope `repo`, scadenza 90gg) | PAT incollato in Bitwarden/Proton | 24 | todo |
| 41 | CW | 1B.6 GitHub Secrets in repo privato (`DATA_REPO_PAT`, `KEYSTORE_BASE64`, passphrase) | CI configurabile | 40, 53 (W4) | todo (parte attende W4) |
| 42 | CC | 1A.4 `.github/CODEOWNERS` + push iniziale su repo split | Repo popolati con history pulita | 35, 36, 32, 33 | todo |
| 43 | CC | 9A app-web-deploy.yml + release.yml workflow | Workflow CI nei due repo | 42 | todo |
| 44 | CW | 1B.7 CODEOWNERS verification con PR di test | PR test approvata | 42 | todo |
| 45 | CW | 4B.2 Verifica Privacy/Terms su Pages (Lighthouse a11y, GDPR checklist Garante) | Report OK | 38, 42 | todo |

**Gate W3 -> W4**: 4A.1-2-3 chiusi, repo entrambi live, branch protection
attiva, legal HTML pubblicato su Pages.

---

### Wave W4 — Keystore + asset store (settimane 3-4)

Generazione e backup keystore (azione manuale critica), poi asset visivi.

| # | Owner | Sub-fase | Output | Dipende da | Stato |
|---|---|---|---|---|---|
| 46 | U  | 4C.1 Esegui `setup_keystore.ps1` localmente, prompt passphrase | `~/.plurifin/keys/upload-keystore.jks` | 14 | todo |
| 47 | U  | 4C.2 Backup keystore: USB cifrata #1, USB #2 in luogo separato, base64 in vault, stampa cartacea fingerprint | 4 backup verificati | 46 | todo |
| 48 | U  | 4C.2 Verifica con `keytool -list -v` -> SHA-256 match | Fingerprint annotato | 46 | todo |
| 49 | CC | 6A.1 Asset store icon-512.png + feature-graphic-1024x500.png generati | Asset in `assets/store/` | -- | todo |
| 50 | CC | 6A.2 `bump_version.ps1` (major/minor/patch + versionCode + CHANGELOG + tag) | Script pronto | -- | todo |
| 51 | CC | 7A.2 Test addizionali: legal_disclaimer + integrity_check + hive_encryption + market_snapshot | Suite >= 90% feature critiche | W2 | todo |
| 52 | CC | 7A.3 Accessibility audit (touch target 48dp, contrast 4.5:1, Semantics labels) | Test widget passing | -- | todo |
| 53 | U  | 1C.3 Convertire keystore in base64 e incollare in `KEYSTORE_BASE64` secret | Secret popolato | 46, 35 | todo |
| 54 | CC | 7A.1 Workflow `release.yml` con gate analyze+test, build aab/apk obfuscated, upload artifact GitHub Release | CI release pipeline live | 14, 41, 53 | todo |
| 55 | CC | First build release locale via `build_release.ps1` (aab + apk) | `app-release.aab` + `app-release.apk` | 46, 50 | todo |
| 56 | U  | Smoke test `app-release.apk` su device fisico Android | Bug list / OK | 55 | todo |
| 57 | CC | First build web release con base-href + dart-define market URL | `build/web/` deployabile | 50 | todo |
| 58 | CW | Deploy `build/web/` su `portfoliomanager-data/app/` via PR | Webapp live | 57, 38 | todo |
| 59 | CW | Test webapp post-deploy (Chrome desktop+mobile, Firefox, Safari iOS) | Smoke check OK | 58 | todo |

**Gate W4 -> W5**: keystore esistente + 4 backup, primo .aab firmato release,
webapp live su Pages, workflow CI verde.

---

### Wave W5 — Play Console signup + listing (settimane 4-6)

Stream U paga e fa identity verification (puo' richiedere PIN cartaceo
2-4 settimane). CW prepara il listing in parallelo.

| # | Owner | Sub-fase | Output | Dipende da | Stato |
|---|---|---|---|---|---|
| 60 | U  | 3C.1 Play Console signup `play.google.com/console/signup` (Personal account) | Account creato | 25 | todo |
| 61 | U  | 3C.1 Identity verification: upload ID + selfie video se richiesto | Stato "verifying" | 60, 8 | todo |
| 62 | U  | 3C.1 Pagamento 25 USD con carta dedicata | Receipt salvato in `Plurifin/Receipts/` | 60 | todo |
| 63 | U  | 3C.1 Inserimento indirizzo per PIN cartaceo (verifica indirizzo Google) | Posta in arrivo entro 2-4 settimane | 60 | wait |
| 64 | CW | 5B.1 Configurazione developer profile (PluriFin, email pubblica `plurifin.app@gmail.com`, sito `lunapiena49.github.io/portfoliomanager-data/`) | Profilo completo | 60 | todo |
| 65 | CC | 6A.1 Generazione testi store (short 80 char + long 4000 char in 6 lingue) -> `legal/store_metadata/<lang>.md` | 6 file pronti | 28 | todo |
| 66 | CW | 6B.1 Screenshot generation: 5 phone + 3 tablet x 6 locale = 48 screenshot da web build via emulazione mobile | `assets/store/screenshots/<lang>/*.png` | 58 | todo |
| 67 | U  | 6C.2 Review estetica screenshot + decidere quali in primo piano | OK utente | 66 | todo |
| 68 | U  | 6C.1 Review testi store (no "consigli investimento", "guadagna", ecc.) | OK utente | 65 | todo |
| 69 | CW | 6B.4 App creation Play Console: name "Portfolio Manager", default lang it-IT, free, content rating PEGI 3 / Everyone, target 18+ | App creata | 60 | todo |
| 70 | CW | 6B.4 Form Data Safety + Financial features ("personal investment data, no transactions, no advice, no MiFID II services") | Form compilato | 69, 28 | todo |
| 71 | CW | 6B.3 Description compilation: paste 6 lingue nei campi listing | Listing testi pronti | 65, 68, 69 | todo |
| 72 | CW | 6B.2 Upload feature graphic + screenshots nei campi listing | Listing visual completo | 49, 66, 67, 69 | todo |
| 73 | U  | 6C.3 Approvazione finale URL Privacy Policy (deve essere stabile per sempre) | OK utente | 45 | todo |
| 74 | U  | 6C.4 Demo CSV `assets/demo/portfolio_demo.csv` per Google Review | CSV in repo | -- | todo |

**Gate W5 -> W6**: identity Play verified (63 done, attesa cartacea
chiusa), listing 100% pronto in bozza.

---

### Wave W6 — Closed Testing track (settimane 6-8, almeno 14 gg di test)

Regola Google personal account: closed testing obbligatorio per >= 14
giorni continuativi prima di poter chiedere production.

| # | Owner | Sub-fase | Output | Dipende da | Stato |
|---|---|---|---|---|---|
| 75 | U  | 7C.3 Lista 12+ tester (email amici/famiglia, idealmente con device Android diversi) | Mailing list | -- | todo |
| 76 | CW | 7B.1 Closed Testing track "internal-alpha" su Play Console | Track creato | 69 | todo |
| 77 | CW | 7B.1 Upload primo `.aab` release nel track con roll-out 100% | Build attiva | 55, 76 | todo |
| 78 | CW | 7B.1 Invito tester via mailing list + opt-in URL | Tester ricevono invito | 75, 77 | todo |
| 79 | CW | 7B.3 Pre-launch report Play (auto-test su flotta device Google) | Report OK | 77 | todo |
| 80 | U  | 7C.2 Test fisico personale (onboarding, import 2 broker, mercato 5G/wifi/aereo, lifecycle, locale switch, theme switch, reboot) | Lista bug documentata | 56 | todo |
| 81 | U  | 7C.3 Google Form / Typeform per feedback tester | Form attivo | 75 | todo |
| 82 | U  | 7C.1 Monitor 14 gg Closed Testing: feedback, crash, ANR | Bug list consolidata | 78 | wait (14gg) |
| 83 | CW | 9B.2 Sentry free tier (5k errori/mese): create project Flutter, DSN come `--dart-define=SENTRY_DSN=` | DSN in CI release | 54 | todo |
| 84 | CW | 9B.2 Symbol upload via sentry-cli da CI (de-obfuscation crash) | Workflow step attivo | 54, 83 | todo |
| 85 | CC | Hotfix da feedback W6 (bug list 80 + 82) | PR + nuovi `.aab` se serve | 80, 82 | todo |
| 86 | CC | Bump version + tag `v1.0.x` se patch necessarie | Tag git pushato | 50, 85 | todo |

**Gate W6 -> W7**: 14 gg trascorsi, no crash bloccanti, feedback raccolto,
hotfix critici inclusi.

---

### Wave W7 — Production submission + post-launch (settimane 8-10+)

| # | Owner | Sub-fase | Output | Dipende da | Stato |
|---|---|---|---|---|---|
| 87 | CW | 8B.1 Play Console -> Production track -> Create new release | Release in bozza | W6 | todo |
| 88 | CW | 8B.1 Upload .aab finale + release notes per ogni locale + roll-out 20% staged | Release configurata | 86, 87 | todo |
| 89 | U  | 8C.1 Premi Submit finale (azione manuale obbligatoria) | App "in review" | 88 | todo |
| 90 | -- | Attesa review Google (24-72h prima volta, fino a 7gg) | Decisione Google | 89 | wait |
| 91 | CC | 8C.2 / 8B.2 Risposta a rejection (50% probabilita' iniziale): fix codice/listing | Re-submit | 90 | wait/todo |
| 92 | U  | 8C.2 Re-submit dopo fix | App ri-in review | 91 | todo |
| 93 | -- | App live su Play Store | Listing pubblico | 92 | wait |
| 94 | CC | Aggiorna `IMPLEMENTATION_HISTORY.md` + `USER_FEATURES.md` con la milestone go-live | Storico aggiornato | 93 | todo |
| 95 | CW | 9B.1 Daily console check (crash rate, ANR, rating, reviews) | Report settimanale | 93 | todo |
| 96 | CW | 9B.3 GitHub Code Scanning monitoring + DMCA fork search | Alert mensile | W3 | todo |
| 97 | U  | 9C.1 Risposta a OGNI review (anche negativa, professionale) | Reputation | 93 | todo |
| 98 | U  | 9C.3 Manutenzione: target SDK update annuale (Aug), backup keystore semestrale, audit security trimestrale | Calendar entries | 93 | todo |
| 99 | U  | 9C.4 Trigger Fase 2 (post-revenue): >=100 EUR Apple Dev, >=500 EUR assicurazione, ecc. | Decisioni soglia | 93 | future |

---

### Riassunto stato corrente (dopo commit `a353234`)

```
W1 [DONE 8/12 - 67%]   1A.1, 1A.2, 1A.3, 0C.1-4, 1C.4, 2C.1     |  TODO: 0B.1, 1C.3, 1C.5, 2C.2 (rimandata)
W2 [DONE 11/14 - 79%]  2A.1-11 + 2C.1                            |  TODO: 1C.3 (GitHub 2FA), 2C.2 tracking
W3 [DONE 0/19 - 0%]    -                                         |  PROSSIMA WAVE: 4A + 1B + Pages legal
W4 [DONE 0/14]         -
W5 [DONE 0/15]         -
W6 [DONE 0/12]         -
W7 [DONE 0/13]         -

Totale: 19/99 task (19%) - tutta l'infrastruttura tecnica side-CC della W2 e' completa.
```

### Prossima azione concreta

Le 4 wave residue del codice (4A + 6A + 7A) e la wave repo (1B) si possono
chiudere in 2-3 sessioni di lavoro. Il blocker della W4 e' l'azione utente
**46** (esecuzione `setup_keystore.ps1` con backup multipli) -- da li' parte
la pipeline Play Console.

Ordine raccomandato:
1. **Sessione successiva CC**: completare 4A.1 (testi legali IT + traduzioni)
   + 4A.2 (licenses.dart) + 4A.3 (audit trail export). Output gating per W3.
2. **Sessione utente**: 1C.3 GitHub hardening + generazione PAT (`DATA_REPO_PAT`).
3. **Sessione CW**: 0B.1 brand check + 1B.1-7 setup repo GitHub.
4. **Sessione utente bloccante**: 4C.1-2 generazione + backup keystore.
5. **Sessione CC**: 6A asset + 7A CI/CD pipeline release.
6. Da qui in poi le W5-W7 dipendono da Play Console e dai 14 gg di test.

---

## Riferimenti

- [01_claude_code_plan.md](01_claude_code_plan.md) - dettaglio task Claude Code
- [02_claude_cowork_plan.md](02_claude_cowork_plan.md) - dettaglio task Cowork
- [03_user_manual_plan.md](03_user_manual_plan.md) - dettaglio task user

## Prossima azione richiesta all'utente

Quando vuoi partire, basta dire **"vai con S1"** (o un'altra sessione iniziale).
Non c'e' bisogno di pianificare ulteriormente: il master plan ha gia' ordine
ottimo + parallelizzazioni note.

Decisioni rapide da chiudere ora (5 minuti):

1. Email: **Opzione A** (alias plus-tag su filippo.salemi.23@gmail.com) o
   **Opzione B** (nuovo account `plurifin.app@gmail.com`)? #email creata: plurifin.app@gmail.com
2. Yubikey ora o piu' tardi (TOTP per ora)? #più tardi
3. P.IVA forfettaria gia' aperta o da aprire? (decisione opzionale, non blocca) #più tardi
4. Conto corrente attivita' separato gia' presente o da aprire? (opzionale) #aperto

Una volta date queste 4 risposte, S1 si conclude da sola e possiamo lanciare
S3 (Claude Code) in parallelo a S2 (Cowork).
