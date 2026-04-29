# Piano B — Claude Cowork (computer-use / browser automation)

Tutto cio' che richiede browser e account web. Eseguibile da Claude in Cowork
con MCP `claude-in-chrome` (DOM-aware) o `computer-use`.

L'utente resta presente per: 2FA, dati carta, upload ID, password.

## Costo immediato richiesto al piano B (v1.0): 25 USD

(solo Play Console developer account, una tantum)

## Vincoli decisi dall'utente (lock-in)

- **iOS day-1**: NO. Apple Developer Program (99 USD/anno) rimandato a quando
  l'app produce ricavi. Solo Android su Play Store.
- **Dominio custom plurifin.app**: rimandato. Web URL = `lunapiena49.github.io`
- **Iubenda Pro**: NO. Privacy/ToS scritti da Claude Code, hostati su Pages.
- **Email professionale Pro**: NO. Alias Gmail per email pubbliche.
- **Marchio EUIPO**: rimandato.
- **D-U-N-S**: non serve in v1.0 (no Apple Org, no marchio).

---

## Fase 0B — Verifiche preliminari (gratuite)

### 0B.1 Verifica disponibilita' brand "PluriFin" (lookup-only)
- EUIPO TMview: https://www.tmdn.org/tmview/ -> classi 9 e 36
- WIPO Madrid Monitor
- Search Play Store: app esistenti con nome simile
- Search dominio plurifin.* (solo lookup, no acquisto)
- Output: `.claude/plan/output/brand_availability_report.md`
- **No registrazione**. Solo conferma che il nome non sia gia' bruciato. Se
  trovi conflitti gravi, alert all'utente per cambio brand.

---

## Fase 1B — Setup repository GitHub

### 1B.1 Repo privato app
- Login GitHub `lunapiena49` (utente apre sessione, Cowork naviga)
- Verifica 2FA WebAuthn attiva
- New repository:
  - Name: `portfolio-manager-app`
  - Description: "PluriFin Portfolio Manager - app source (private)"
  - Private: yes
  - No README/gitignore/license iniziali (li fa Claude Code)

### 1B.2 Repo pubblico data
- Name: `portfoliomanager-data`
- Description: "PluriFin Portfolio Manager - public market data + webapp + legal"
- Public: yes
- License repository: NESSUNA (l'app e' proprietaria; solo gli script Python di
  pipeline avranno LICENSE secondario nella sottocartella `scripts/`)

### 1B.3 Branch protection
Repo privato app, `main`:
- Required PR before merge (1 approval)
- Required status checks (ci/test, ci/analyze)
- Required signed commits
- Required linear history
- Block force push
- Restrict deletion

Repo pubblico data, `main`:
- Required status checks ci-only
- Block force push

### 1B.4 GitHub Pages config (repo data)
- Settings -> Pages
- Source: branch `main`, folder `/` (root)
- Custom domain: VUOTO (URL = `lunapiena49.github.io/portfoliomanager-data`)
- Enforce HTTPS: si

### 1B.5 Push Protection e Secret Scanning
Per entrambi i repo:
- Settings -> Code security and analysis
- Dependabot alerts: ON
- Dependabot security updates: ON
- Secret scanning: ON
- Push protection: ON
- Code scanning (CodeQL): ON

### 1B.6 GitHub Secrets per CI (repo privato app)
Settings -> Secrets and variables -> Actions:
- `DATA_REPO_PAT` (Personal Access Token con scope `repo` per push su data-repo)
  - Cowork apre la pagina, l'utente genera il PAT e lo incolla
- `KEYSTORE_BASE64` (contenuto upload-keystore.jks in base64)
  - L'utente esegue `[Convert]::ToBase64String((Get-Content -Path
    keystore.jks -Encoding Byte))` e incolla
- `KEYSTORE_PASSPHRASE`, `KEY_ALIAS_PASSPHRASE`: input utente

### 1B.7 CODEOWNERS verification
- Cowork verifica che la GitHub UI riconosca il file `.github/CODEOWNERS`
  (creato da Claude Code) -- aprire un PR di test e verificare che richieda
  approvazione di `@lunapiena49`

---

## Fase 4B — Compliance via web (zero-cost)

### 4B.1 Email professionali via alias Gmail (gratuita)
- L'utente ha gia' Gmail.
- Strategia: usare alias `+`-tag o un account Gmail dedicato:
  - **Opzione A** (semplice): alias plus-tag sul Gmail principale
    - `filippo.salemi.23+plurifin.support@gmail.com`
    - `filippo.salemi.23+plurifin.privacy@gmail.com`
    - `filippo.salemi.23+plurifin.security@gmail.com`
    - Le email arrivano tutte nella inbox principale, filtri auto-categorizzano
  - **Opzione B** (piu' professionale): nuovo account Gmail dedicato
    `plurifin.app@gmail.com` con 2FA. Cowork puo' aiutare nel signup.
- **Mia raccomandazione**: Opzione B per separazione e backup recovery distinto.
- Costo: 0 €

### 4B.2 Privacy Policy / ToS hostati su Pages (zero-cost)
- Claude Code ha generato i template in `legal/*.md` (vedi piano A 4A.1)
- Cowork verifica che dopo il deploy automatico siano accessibili a:
  - `https://lunapiena49.github.io/portfoliomanager-data/legal/it/privacy.html`
  - `https://lunapiena49.github.io/portfoliomanager-data/legal/it/terms.html`
  - idem per en/es/fr/de/pt
- Test ognuno con Lighthouse a11y check
- Validazione GDPR del testo: Cowork esegue checklist contro template ufficiale
  Garante (https://www.garanteprivacy.it) -- non sostituisce revisione legale
  ma copre i punti standard

### 4B.3 D-U-N-S, marchio, dominio custom
**Skip in v1.0**. Da rivalutare in Fase 2 quando l'app rende.

---

## Fase 5B — Account stores (Android only)

### 5B.1 Google Play Console
- URL: https://play.google.com/console/signup
- Tipo account: **Personal** (persona fisica)
- Identity verification:
  - Documento ID: utente carica foto da telefono (Cowork si ferma all'upload)
  - Indirizzo verificato: Google puo' chiedere PIN via posta cartacea
    (2-4 settimane di attesa)
  - Verifica viso (selfie video): in alcune giurisdizioni
- **Pagamento: 25 USD una tantum** -- utente paga
- Developer name: "PluriFin" (NB: Google permette nomi commerciali anche per
  personal accounts purche' non ingannevoli; "PluriFin by Filippo Salemi" e'
  l'opzione piu' sicura)
- Email developer pubblica: alias Gmail dedicato (vedi 4B.1)
- Sito sviluppatore: `https://lunapiena49.github.io/portfoliomanager-data/`
  (la landing pubblica, non la webapp)
- Salvare developer ID

### 5B.2 Apple Developer Program
**Skip in v1.0** (rimandato a Fase 2).

---

## Fase 6B — Listing Play Store (zero-cost)

### 6B.1 Screenshot generation
- Cowork apre la web build deployata
- Naviga schermate principali a viewport mobile (Pixel 7 360x800)
- Screenshot via `mcp__Claude_in_Chrome__screenshot` con device emulation
- Salvati in `assets/store/screenshots/<locale>/<screen-id>.png`
- Necessari: 5 telefono + 3 tablet 7"+10" = 8 totali x 6 locale = ~ 48 screenshot
- Iterazione qualita' con utente (review estetica)

### 6B.2 Feature graphic
- Generato programmaticamente da Claude Code (1024x500 PNG)
- Cowork carica nel campo "Feature graphic"

### 6B.3 Description compilation
- Short (80 char) + Long (4000 char) in 6 lingue
- Testi preparati da Claude Code in `legal/store_metadata/<lang>.md`
- Cowork copia/incolla nei campi
- **Attenzione**: niente "consigli per investire", "guadagna in borsa", "il miglior
  investimento". Triggera review manuale e potenziale rejection.

### 6B.4 App creation Play Console
- All apps -> Create app
- App name: "Portfolio Manager"
- Default language: it-IT
- App or Game: App
- Free or Paid: Free
- Confermare:
  - Developer Program Policies
  - US export laws
- Configurazione iniziale:
  - App access: no login required
  - Ads: no
  - Content rating: questionario IARC -> PEGI 3 / Everyone
  - Target audience: 18+ (consigliato per app finanziaria)
  - News app: NO
  - COVID-19 contact tracing: NO
  - Government apps: NO
  - **Data safety**: form completo (Cowork lo compila in base alla Privacy
    Policy generata da Claude Code; tipi dati raccolti = "App activity +
    Personal financial info, locale only, no transmission")
  - **Financial features**: dichiarare "Manages personal investment data, no
    transactions, no advice, no MiFID II services". Critico per non finire in
    "trading/brokerage" review track.

---

## Fase 7B — Pre-submission

### 7B.1 Closed Testing track Play
- Play Console -> Testing -> Closed testing -> Create new track
- Track name: "internal-alpha"
- Tester via mailing list (utente fornisce 12+ email amici/familiari)
- Upload primo `.aab`
- Roll-out 100% nel track
- **14 giorni minimi** di test obbligatori per personal accounts (regola Google)
- Cowork monitora pre-launch report Play (auto-test su flotta device Google)

### 7B.2 TestFlight Apple
**Skip in v1.0**.

### 7B.3 Pre-launch report Play
- Automatico dopo upload .aab
- Cowork verifica nessun crash bloccante
- Restituisce screenshot del report

---

## Fase 8B — Submission produzione (Android)

### 8B.1 Play Store production
- Production track -> Create new release
- Upload `.aab` finale
- Release notes per ogni locale
- Roll-out: 20% staged rollout per primi 7 giorni, poi 100%
- Submit to review
- **L'utente preme il bottone Submit finale**

### 8B.2 Risposta a review iterations
- 50% probabilita' rejection al primo invio.
- Cause comuni:
  - Privacy Policy URL morto / non match Data Safety
  - Disclaimer "consulenza finanziaria" debole
  - Permessi non giustificati
- Cowork suggerisce fix, Claude Code li applica, utente ri-invia

---

## Fase 9B — Post-launch monitoring

### 9B.1 Daily console check
- Play Console: crash rate, ANR rate, rating, reviews
- Cowork puo' generare report settimanale automatico

### 9B.2 Sentry free tier
- URL: https://sentry.io/signup/
- Free tier: 5k errori/mese, 50 sessioni replay/mese
- Create project Flutter
- DSN come `--dart-define=SENTRY_DSN=...` in CI release
- Symbol upload via sentry-cli da CI (vedi piano A 7A.1)

### 9B.3 GitHub Code Scanning monitoring
- Settimanale: review dei CodeQL alerts su entrambi i repo
- DMCA monitoring: search "portfolio-manager-app" su GitHub fork list

---

## Web deployment gratuito (parte browser-side)

### Setup GitHub Pages (zero-cost confermato)
- Repo data -> Settings -> Pages -> Source: `main` branch, `/` root
- URL pubblico:
  - Market data: `https://lunapiena49.github.io/portfoliomanager-data/top_movers.json`
  - Webapp: `https://lunapiena49.github.io/portfoliomanager-data/app/`
  - Legal: `https://lunapiena49.github.io/portfoliomanager-data/legal/<lang>/<doc>.html`
- Enforce HTTPS: si
- Custom domain: VUOTO (Fase 2)

### Test post-deploy
- Aprire la webapp su Chrome desktop, Chrome mobile, Firefox, Safari iOS (web)
- DevTools Network: nessuna chiamata cleartext
- DevTools Console: nessun errore
- Test funzionali: splash, onboarding, import CSV demo, posizioni, Mercato

### CORS check
- `top_movers.json` su Pages e' served con `Access-Control-Allow-Origin: *`
- Webapp su stesso domain non triggera CORS

### Robots.txt
- `web/robots.txt`: `Disallow: /` per la webapp (privacy: niente bot indicizzano
  pagine cliente)
- Permettiamo indicizzazione solo della landing root del repo data

### Indicizzazione SEO (futura)
- Skip in v1.0 (non c'e' landing page pubblica con SEO)
- Submit a Google Search Console quando comprerai il dominio (Fase 2)

---

## Output finale Piano B v1.0

1. Due repo GitHub creati e protetti
2. Account Play Console attivo (in attesa identity verification)
3. Privacy Policy + ToS pubblicati su URL stabili Pages
4. Listing Play Store compilato con metadata, screenshots, asset
5. Closed testing track Play attivo con tester invitati
6. Sentry free tier setup
7. GitHub Pages servente webapp + legal docs

**Tempo stimato Cowork v1.0**: 4-6 sessioni di 1-2 ore (~ 6-10 ore totali)
**Pre-requisito**: utente ha completato Piano C step 1-3.
