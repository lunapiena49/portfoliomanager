# Piano A — Claude Code (Opus 4.7, max effort, max privilegi)

Tutto cio' che e' eseguibile da Claude Code via tool (Edit, Write, Bash,
PowerShell, git, flutter, keytool). Ogni task ha un **owner = Claude Code** e un
**artifact** verificabile (file modificato, commit, build output).

## Vincoli decisi dall'utente (lock-in)

- **Bundle ID Android**: `app.plurifin.portfoliomanager` (immutabile dopo Play
  Store submission)
- **Brand**: PluriFin (developer name)
- **Nome app store**: Portfolio Manager
- **Web deploy**: `https://lunapiena49.github.io/portfoliomanager-data/app/`
  (zero costi, no custom domain finche' l'app non rende)
- **iOS**: rimandato a Fase 2 (quando l'app produce ricavi sufficienti per Apple
  Developer 99 USD/anno + macOS access). Tutto il codice Flutter resta
  cross-platform pronto.
- **Backend proxy / Cloudflare**: rimandato a Fase 2
- **Dominio custom**: rimandato a Fase 2
- **Email pro**: rimandato a Fase 2 (uso alias Gmail nel frattempo)
- **Marchio EUIPO**: rimandato
- **Assicurazione RC Tech**: rimandato
- **Revisione legale a pagamento**: rimandato
- **Iubenda Pro**: rimandato (Privacy Policy + ToS scritti da Claude Code da
  template solidi, hostati su GitHub Pages free)

## Costo immediato richiesto al piano A: 0 €

---

## Fase 1A — Hardening repo e codice

### 1A.1 Pulizia history e secret scanning locale
- Installare gitleaks via PowerShell da release ufficiale
- `gitleaks detect --source . --no-banner --redact` -> report in
  `.claude/plan/output/gitleaks_report.json`
- Per ogni hit: preparare lo script `git filter-repo` per riscrivere la history
  (script preparato, esecuzione delegata all'utente con backup esplicito)
- Aggiungere `.gitleaks.toml` con regole custom (EODHD/FMP/Gemini patterns)
- Pre-commit hook PowerShell che chiama gitleaks su `git diff --staged`

### 1A.2 Repo split — preparazione lato codice
Generare cartella `repo_split/` di staging:
- `repo_split/app/` -- repo privato finale, esclude `dist/`, `scripts/eodhd/`,
  workflow `market-*.yml` e `daily-data-commit.yml`
- `repo_split/data/` -- repo pubblico finale, contiene solo
  `scripts/eodhd/`, workflow market-data, `dist/market-data/.gitkeep`,
  `docs/DATA_SNAPSHOT_LOG.md`, README dedicato, **e dopo il primo build web la
  cartella `app/` con la build deployata**
- README per ognuno dei due repo
- `.gitignore` mirati

### 1A.3 Aggiornamento URL backend market-data nel codice app
- Mantenere `marketSnapshotBaseUrl =
  https://lunapiena49.github.io/portfoliomanager-data` (sara' il nuovo nome del
  repo dati pubblico)
- Aggiungere `--dart-define=MARKET_SNAPSHOT_BASE_URL=...` per override CI

---

## Fase 2A — Hardening build app (Android-only day 1)

### 2A.1 Bundle ID e namespace
- `android/app/build.gradle.kts`:
  - `namespace = "app.plurifin.portfoliomanager"`
  - `applicationId = "app.plurifin.portfoliomanager"`
- iOS `project.pbxproj`: aggiornare comunque PRODUCT_BUNDLE_IDENTIFIER a
  `app.plurifin.portfoliomanager` per coerenza futura
- Rinominare cartella `android/app/src/main/kotlin/com/example/portfolio_manager/`
  in `android/app/src/main/kotlin/app/plurifin/portfoliomanager/`
- Update `package` declaration in `MainActivity.kt`

### 2A.2 Release signing config
- Script `scripts/release/setup_keystore.ps1`:
  - usa `keytool` per generare `upload-keystore.jks` (RSA 4096, 10000 giorni)
  - prompt interattivo per passphrase (mai salva su disco)
  - keystore in `~/.plurifin/keys/upload-keystore.jks` (fuori dal repo)
  - genera `android/key.properties` (gia' in `.gitignore`)
- Aggiornare `android/app/build.gradle.kts`:
  - import `key.properties`
  - `signingConfigs.create("release") { ... }`
  - `buildTypes.release.signingConfig = signingConfigs.getByName("release")`
  - rimuovere fallback `getByName("debug")`
- Documentare backup keystore in `docs/RELEASE_SIGNING.md`

### 2A.3 R8 / ProGuard rules
- `android/app/build.gradle.kts` release:
  - `isMinifyEnabled = true`
  - `isShrinkResources = true`
  - `proguardFiles(...)`
- `android/app/proguard-rules.pro` con keep mirati:
  - tipi Hive serializzati
  - Dio + retrofit interfaces
  - flutter_secure_storage native bindings
  - Lottie classi parser
- Test build release offline per verificare no crash

### 2A.4 Network Security Config
- `android/app/src/main/res/xml/network_security_config.xml`:
  - `<base-config cleartextTrafficPermitted="false">`
  - trust anchors solo sistema (no user CA)
  - **Pin opzionale** per `lunapiena49.github.io`: SHA-256 del leaf + intermediate
    GitHub Pages (estratti via openssl). Soft pinning (warning-only) finche' non
    siamo sicuri della stabilita' della catena
- Riferito da `android:networkSecurityConfig="@xml/network_security_config"` nel
  manifest
- iOS: aggiungere `NSAppTransportSecurity` strict in Info.plist

### 2A.5 Anti-screenshot e anti-backup
- `android/app/src/main/AndroidManifest.xml`:
  - `android:allowBackup="false"`
  - `android:fullBackupContent="@xml/backup_rules"`
  - `android:dataExtractionRules="@xml/data_extraction_rules"`
- `xml/backup_rules.xml` + `xml/data_extraction_rules.xml`: escludere Hive +
  secure storage
- `lib/core/security/secure_screen.dart`:
  - wrapper widget con `FLAG_SECURE` su Android via platform channel
  - iOS: blur view in `applicationWillResignActive`
- Wrappare con `SecureScreen`:
  - `home_page.dart`
  - `position_detail_page.dart`
  - `ai_analysis_page.dart`
  - `analysis_chat_page.dart`

### 2A.6 Hive encryption
- `lib/services/storage/hive_encryption.dart`: chiave AES-256 alla prima
  esecuzione, salvata in `flutter_secure_storage` (Keychain iOS / EncryptedSP
  Android)
- Migrare apertura box in `local_storage_service.dart`:
  `await Hive.openBox(name, encryptionCipher: HiveAesCipher(key))`
- Migrazione dati: rilevare box non cifrato, leggerlo, riscriverlo cifrato,
  cancellare l'originale (one-shot al boot, gated da SharedPreferences flag)
- Test: `hive_encryption_test.dart`

### 2A.7 Anti-tamper: jailbreak / root detection
- Dipendenza `flutter_jailbreak_detection`
- `lib/core/security/integrity_check.dart`:
  - check root/jailbreak al boot
  - se positivo: degrade graceful (disabilita AI, mostra warning, blocca
    funzionalita' critiche)
  - logga evento solo locale
- Wirearlo nello splash prima del routing finale
- Chiavi i18n `errors.security.compromised_device` x6 lingue

### 2A.8 Dart obfuscation pipeline
- Gia' default per release. Confermare in
  `scripts/release/build_release.ps1`:
  - `--obfuscate --split-debug-info=build/symbols/<platform>/<version>`
  - dopo ogni build: zip dei symbol files in `~/.plurifin/symbols/<version>/`
  - manifesto `symbols-manifest.json` con sha256 di ogni .symbols

### 2A.9 Disclaimer finanziario in-app
- `lib/features/onboarding/presentation/pages/legal_disclaimer_page.dart`:
  - testo localizzato chiavi `legal.disclaimer.*` x6 lingue
  - checkbox obbligatori
  - persiste accettazione in Hive con timestamp + version
  - blocca onboarding se non accettato
- Banner persistente "I contenuti AI non costituiscono consulenza finanziaria"
  in fondo a:
  - `analysis_chat_page.dart`
  - `ai_analysis_page.dart`
  - `rebalance_page.dart`
- Route `/legal/disclaimer` accessibile da Settings
- Bump versione disclaimer ricapita consenso

### 2A.10 Privacy Policy / ToS in-app
- Pagina `lib/features/settings/presentation/pages/legal_documents_page.dart`:
  - link a Privacy Policy (URL hostato esternamente -- vedi 4A.1)
  - link a Terms of Service
  - link a Open Source Licenses generato da `flutter_licenses`
  - email contatto: alias Gmail (es. plurifin.support@gmail.com -- vedi piano C)
- Splash gate: prima di home, se non accettato ToS attuale -> redirect

### 2A.11 Astrazione provider AI (preparazione futura)
- `lib/services/api/gemini_service.dart`: astrarre dietro `IGeminiClient`
  - `DirectGeminiClient` (default v1.0, usa chiave utente)
  - `ProxyGeminiClient` (placeholder per Fase 2)
- Selezionato via `--dart-define=GEMINI_MODE=direct|proxy`

---

## Fase 4A — Compliance legale lato codice (zero-cost path)

### 4A.1 Privacy Policy + ToS scritti da Claude Code (no Iubenda)
- `legal/privacy_policy.md`: testo basato su template GDPR-compliant +
  Play Store policy. Sezioni:
  - Identificazione titolare (persona fisica Filippo Salemi)
  - Dati raccolti (categorie, finalita', base giuridica)
  - Sub-processor (Google Gemini, EODHD, FMP -- solo se utente attiva)
  - Diritti utente (accesso, cancellazione, portabilita', opposizione)
  - Data retention (locale device only)
  - Contatto (alias Gmail)
- `legal/terms_of_service.md`: limitazione responsabilita' al massimo permesso
  da Codice Consumo italiano + clausola "non e' consulenza finanziaria ex TUF"
- `legal/disclaimer_financial.md`
- `legal/dmca_template.md`
- Traduzioni in EN/ES/FR/DE/PT (Claude Code traduce mantenendo precisione legale)
- **Hostati su GitHub Pages** del repo dati pubblico:
  `https://lunapiena49.github.io/portfoliomanager-data/legal/privacy.html`
  `https://lunapiena49.github.io/portfoliomanager-data/legal/terms.html`
- File HTML statici minimal (no JS), generati da Markdown via build step

### 4A.2 Open source licenses generation
- CI step `flutter pub run flutter_licenses`
- Output committato in `lib/generated/licenses.dart`
- Pagina `Settings > Licenze open source`

### 4A.3 Audit trail consenso
- `lib/core/services/consent_service.dart`:
  - record di ogni accept/decline con timestamp UTC, version, hash testo
  - persistito in Hive box `consent_box`
  - export JSON per GDPR right to data portability
- Pagina `Settings > Esporta i miei dati` -> ZIP con portafoglio + consensi + log

---

## Fase 6A — Asset store (lato codice)

### 6A.1 App icon multi-density
- Gia' generato via `flutter_launcher_icons`
- Generare `assets/store/icon-512.png` per Play Store listing
- Generare `assets/store/feature-graphic-1024x500.png` programmaticamente

### 6A.2 Versioning automatico
- Script `scripts/release/bump_version.ps1`:
  - prompt: tipo (major/minor/patch)
  - aggiorna `pubspec.yaml version`
  - aggiorna `versionCode` (+1)
  - genera `CHANGELOG.md` entry
  - committa con tag `v<version>`

### 6A.3 Generazione asset legali su Pages
- Script `scripts/legal/build_legal_html.ps1`: converte ogni `legal/*.md` in
  HTML statico con CSS minimal (un solo file CSS condiviso)
- Output in `dist/legal/<lang>/<doc>.html`
- Workflow CI committa output sul repo dati su trigger di update legali

---

## Fase 7A — Pre-submission QA

### 7A.1 CI/CD pipeline release (sul repo privato app)
`.github/workflows/release.yml`:
- trigger: tag `v*`
- job 1: `flutter analyze` + `flutter test` (gate)
- job 2: build android `--release --obfuscate --split-debug-info=...`
- job 3: build web release (vedi sezione web)
- job 4: upload artifact su GitHub Releases (privato)
- iOS rimandato a Fase 2

### 7A.2 Test addizionali
- `test/features/onboarding/legal_disclaimer_test.dart`
- `test/core/security/integrity_check_test.dart` (mock device rooted)
- `test/services/storage/hive_encryption_test.dart`
- `test/services/api/market_snapshot_service_test.dart`

### 7A.3 Accessibility audit
- `test/accessibility/`: widget test per touch target >= 48dp, contrast 4.5:1,
  Semantics labels

---

## Web deployment gratuito (zero-cost path confermato)

### Architettura

```
[Repo PRIVATO app]                       [Repo PUBBLICO data]
plurifin/portfolio-manager-app           plurifin/portfoliomanager-data
        |                                         |
        | tag v* triggera workflow                | (gia' attivo per market-data)
        |                                         |
        | build: flutter build web --release      |
        |        --obfuscate                      |
        |        --base-href /portfoliomanager-data/app/
        |                                         |
        +---> push solo build/web/ ---> branch ---+--> GitHub Pages serve:
              su data-repo path /app/                  /                       -> market-data
              + dist/legal/* su /legal/                /portfoliomanager-data/ -> root
                                                       /app/                   -> webapp
                                                       /legal/<lang>/*.html    -> privacy/ToS
```

### Workflow `app-web-deploy.yml`
- Trigger: push tag `v*` oppure manual
- Steps:
  1. checkout repo app
  2. setup Flutter
  3. `flutter build web --release --obfuscate
     --split-debug-info=build/symbols/web
     --base-href=/portfoliomanager-data/app/
     --dart-define=MARKET_SNAPSHOT_BASE_URL=https://lunapiena49.github.io/portfoliomanager-data
     --dart-define=APP_DEPLOYMENT=web`
  4. checkout repo data con PAT (`DATA_REPO_PAT` secret)
  5. rsync `build/web/` -> `data-repo/app/`
  6. commit + push
  7. zip symbols + upload artifact in GitHub Release del repo privato

### Configurazione web build
- `web/index.html`: meta SEO + OG + favicon (ma bloccare indicizzazione webapp:
  `<meta name="robots" content="noindex,nofollow">`)
- `web/manifest.json`: PluriFin theme
- `lib/main.dart`: detect `kIsWeb`, fallback secure storage a sessionStorage
  cifrato con passphrase utente

### Banner "modalita' web"
- Permanente nella webapp:
  - "Versione web: i tuoi dati restano nel browser. Per uso reale e massima
    sicurezza scarica l'app da Play Store."
- Localizzato x6 lingue, chiave `web.security_disclaimer`

### Test post-deploy
- Smoke test in CI: GET `https://lunapiena49.github.io/portfoliomanager-data/app/`
  dopo 2 min, verifica HTTP 200 + marker JS presente

---

## Fase 2 (deferred, post-revenue)

Non eseguito da Claude Code in v1.0, ma il codice e' pronto:
- `IGeminiClient` -> swappare a `ProxyGeminiClient` quando il backend Cloudflare
  Worker e' attivo
- iOS build (richiede macOS + Apple Dev account)
- Custom domain CNAME su `app.plurifin.app`
- Play Integrity API integration

---

## Output finale Piano A v1.0

1. Repo privato setup-ready
2. Repo dati con workflow di pubblicazione web e legal HTML
3. Build artifacts:
   - `build/app/outputs/bundle/release/app-release.aab` (per Play Store)
   - `build/app/outputs/flutter-apk/app-release.apk` (per sideload/test)
   - `build/web/` deployato su `lunapiena49.github.io/portfoliomanager-data/app/`
4. Symbols files in `~/.plurifin/symbols/`
5. Documentazione `docs/RELEASE_SIGNING.md`, `docs/STORE_SUBMISSION.md`
6. Privacy Policy + ToS hostati su Pages
7. Test suite verde, `flutter analyze` pulito

**Tempo totale Claude Code v1.0**: ~ 12-15 ore distribuite su 4-5 sessioni.
**Pre-requisito**: utente ha completato Piano C step 1-3.
