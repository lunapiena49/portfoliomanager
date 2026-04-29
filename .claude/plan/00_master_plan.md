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
