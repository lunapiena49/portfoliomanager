# Piano C — User manuale (Filippo Salemi, persona fisica)

Tutto cio' che NESSUN agente AI puo' eseguire al posto tuo.

## Vincoli decisi (lock-in)

- **Forma giuridica**: persona fisica, niente SRL
- **Pubblicazione v1.0**: solo Android su Play Store. iOS rimandato a Fase 2.
- **Spese rimandate** (fino a quando l'app produce ricavi >= spesa):
  - Apple Developer Program (99 USD/anno)
  - Dominio plurifin.app (12 €/anno)
  - Iubenda Pro (60 €/anno)
  - Email Pro / Google Workspace / Proton (60-150 €/anno)
  - Marchio EUIPO (~ 900 €)
  - Assicurazione RC Tech (~ 500 €/anno)
  - Revisione legale a pagamento (500-1500 €)
  - Atto di destinazione 2645-ter / trust (~ 1.500-5.000 €)

## Costo immediato richiesto a te in v1.0

| Voce | Costo | Necessita' |
|---|---|---|
| Google Play Console | 25 USD una tantum | OBBLIGATORIO per pubblicare |
| Yubikey 5C NFC x2 | ~ 120 € | Fortemente raccomandato per sicurezza account |
| **Minimo per partire** | **~ 25 USD** | Senza Yubikey, ma con 2FA TOTP |
| **Raccomandato** | **~ 145 €** | Con Yubikey x2 |

## Strategia "intoccabilita' giuridica" come persona fisica zero-cost

Senza assicurazione e senza revisione legale a pagamento, le difese realistiche
gratuite sono:

1. **Disclaimer in-app rigoroso** (Claude Code lo scrive, tu lo rileggi)
   - "non e' consulenza finanziaria ex art. 1 TUF (D.Lgs. 58/1998)"
   - "non e' sollecitazione all'investimento"
   - "non e' servizio MiFID II"
   - "decisioni di esclusiva responsabilita' utente"
   - "consulta consulente abilitato albo OCF"
2. **Audit trail consenso**: ogni accept/decline registrato in Hive con
   timestamp, version, hash testo. Esportabile dall'utente (GDPR).
3. **ToS con limitazione responsabilita'** al massimo permesso dal Codice del
   Consumo (art. 33+). Per consumatori UE non si puo' escludere dolo/colpa
   grave: il resto si limita.
4. **Niente trading, niente broker integration, niente raccomandazioni
   specifiche**: l'app traccia, l'AI commenta in modo informativo. Mai bottoni
   "compra/vendi".
5. **Niente analytics di terzi**, niente ads: meno tracker = meno superficie GDPR.
6. **Conto corrente attivita' separato** (Fineco / Revolut / BBVA gratuiti):
   eventuali entrate isolate dal patrimonio personale.
7. **Prima casa gia' impignorabile** per debiti professionali (art. 76 DPR
   602/73 con eccezioni) -- protezione legale gratuita.

Quando l'app produce 500-1000 €/anno, attivare assicurazione RC Tech (~ 500 €):
salto qualitativo enorme nelle difese.

---

## Fase 0C — Decisioni da chiudere subito

### 0C.1 Conferme gia' date dall'utente (lock-in)
- Persona fisica: **CONFERMATO**
- Brand: **PluriFin** (developer name)
- App store name: **Portfolio Manager**
- Bundle ID: **app.plurifin.portfoliomanager**
- Web URL: **lunapiena49.github.io/portfoliomanager-data/app/**
- iOS day-1: **NO**, rimandato a Fase 2

### 0C.2 Decisione email professionale (gratuita)
**Opzione A** (semplice): alias plus-tag su Gmail principale
- `filippo.salemi.23+plurifin.support@gmail.com` #creata plurifin.app@gmail.com
- `filippo.salemi.23+plurifin.privacy@gmail.com` #creata plurifin.app@gmail.com
- Filtri auto-inbox
- **Pro**: zero setup. **Contro**: meno professionale, meno separato.

**Opzione B** (consigliata): nuovo account Gmail dedicato
- Esempio: `plurifin.app@gmail.com` (verifica disponibilita') #creata plurifin.app@gmail.com
- 2FA con Yubikey + TOTP backup
- Recovery email = la tua email personale
- **Pro**: separazione, recovery distinto, indirizzo pulito.
- **Contro**: 30 minuti di setup.

**Decisione tua prima della Sessione 6** del master plan.

### 0C.3 P.IVA forfettaria? (decisione opzionale)
- Non necessaria se l'app e' free senza IAP.
- Se prevedi domani di aggiungere subscription "PluriFin Pro" o ads, aprila ora
  (gratuito su Fisconline, ~ 30 min, NESSUN costo finche' non superi soglie).
- **Mia raccomandazione**: aprila preventivamente. Costa zero. Zero impegno
  fiscale finche' fatturato 0 €. 
- Decisione tua. Non blocca nessuna sessione del master plan. #più tardi

### 0C.4 Account corrente attivita' separato? (decisione opzionale)
- Apri conto gratuito (Fineco / BBVA / Revolut Standard) intestato a te.
- Funziona anche solo per ricevere eventuali entrate future dell'app.
- **Mia raccomandazione**: aprilo. Costa zero. Aiuta in caso di causa civile.
- Decisione tua. #fatto

---

## Fase 1C — Sicurezza account

### 1C.1 Yubikey hardware
- Acquisto: **Yubikey 5C NFC** x2 (~ 60 €/cad)
  - 1 primaria (sempre con te)
  - 1 backup (cassaforte/cassetto separato)
- Alternative free (meno sicure): TOTP authenticator app (Aegis / 2FAS Auth).
- **Bloccante per Yubikey-based hardening**, non bloccante in assoluto. Puoi
  partire con TOTP e aggiornare a Yubikey quando vuoi. #partire con TOTP

### 1C.2 Bitwarden vault
- Crea account Bitwarden (free tier, illimitati password)
- Master password >= 20 char, mai riutilizzata
- Stampa cartacea della master password divisa in 2 meta' fisiche separate
- Importa/aggiungi tutte le credenziali progetto (GitHub, Gmail nuovo,
  Play Console, ecc.) #per ora uso proton

### 1C.3 GitHub account hardening
- 2FA: WebAuthn key (Yubikey) + TOTP backup
- Disabilita SMS 2FA
- Audit accessi recenti (Settings -> Sessions)
- Personal Access Token: scope minimo, scadenza 90 giorni
  - Genera quello richiesto da Cowork (1B.6) `DATA_REPO_PAT` #più tardi

### 1C.4 Google account dedicato (se Opzione B in 0C.2)
- Crea `plurifin.app@gmail.com` (o nome alternativo se occupato)
- 2FA con Yubikey + TOTP
- Recovery email = la tua personale
- Non collegare a YouTube/Drive/Photos personali #fatto

### 1C.5 Documento ID digitalizzato
- Scansiona passaporto + carta identita' fronte/retro
- Salva crittografato (Bitwarden Send / Cryptomator vault)
- Mai in plain Drive/Dropbox

---

## Fase 2C — Pagamenti e budget

### 2C.1 Carta di credito dedicata
- Carta prepagata ricaricabile gratuita (Postepay Evolution, Revolut, Hype).
- In caso di compromise blocchi solo quella.
- Bilancio massimo: 100 € per coprire Play Console + eventuali spese impreviste. #fatto

### 2C.2 Tracciamento spese
- Foglio Google Sheet con: data, voce, importo, ricevuta PDF
- Anche se ora le spese sono solo 25 USD, abituati subito al tracking. #più tardi

### 2C.3 Ricevute Play Console
- Google emette receipt automatica via email post-pagamento
- Salvala su Drive in cartella `Plurifin/Receipts/`

---

## Fase 3C — Verifiche identita' Play Console

### 3C.1 Google Play Console enrollment
- Cowork compila form fino a checkout
- Tu carichi:
  - Foto documento ID (passaporto consigliato)
  - Selfie video se richiesto (Google ha aumentato controlli su personal
    accounts dal 2023)
- **Tu paghi 25 USD** con carta dedicata
- **Verifica indirizzo via posta cartacea**: Google puo' richiedere PIN su
  carta (2-4 settimane di attesa)
  - Inserisci subito l'indirizzo corretto: una volta inviata la posta non puoi
    cambiare per la prima verifica
- Output: Developer ID -> salva in Bitwarden

### 3C.2 Apple Developer
**Skip in v1.0** (rimandato).

### 3C.3 D-U-N-S Number
**Skip in v1.0** (non serve senza Apple Org / marchio).

### 3C.4 Marchio EUIPO
**Skip in v1.0** (rimandato).

---

## Fase 4C — Generazione e custodia keystore Android

### 4C.1 Generazione upload-keystore
- Claude Code prepara `scripts/release/setup_keystore.ps1`
- TU lo lanci dal tuo computer (mai da macchina condivisa)
- Lo script prompt:
  - Passphrase keystore (>= 16 char, **memorizza in Bitwarden**)
  - Passphrase alias (puo' essere uguale)
  - Nome (Filippo Salemi)
  - Org (PluriFin)
  - City, Country
- Output: `~/.plurifin/keys/upload-keystore.jks` (~ 5 KB)

### 4C.2 Backup keystore (CRITICO)
La keystore + passphrase sono l'unica cosa NON rigenerabile.

Backup minimi consigliati:
1. **Copia su USB cifrata** (VeraCrypt container, password diversa dal keystore)
2. **Stessa USB cifrata in 2° luogo fisico** (cassetta sicurezza, casa familiare)
3. **Copia base64 in Bitwarden** vault (encrypted backup digitale)
4. **Stampa cartacea passphrase** divisa in 2 meta' in 2 luoghi fisici
   (Shamir secret sharing manuale, ridondanza)

Se sbagli e perdi tutto: Play App Signing (gestione Google) ti permette il
**recovery via richiesta a Google Support**. Non e' istantaneo (giorni-settimane)
ma e' possibile. Senza Play App Signing saresti bloccato a vita.

### 4C.3 Apple distribution certificate
**Skip in v1.0**.

---

## Fase 5C — Compliance legale (decisioni che richiedono te)

### 5C.1 Privacy Policy + ToS scritti da Claude Code: tua review
- Claude Code genera template solidi in `legal/*.md` (vedi piano A 4A.1)
- TU rileggi, customizzi se serve, approvi prima della pubblicazione su Pages
- Punti chiave da verificare:
  - Sub-processor list match con realta' (Google Gemini, EODHD, FMP -- solo se
    utente attiva)
  - Email di contatto match (alias Gmail scelto)
  - Foro competente Italia
  - Lingua primaria italiana, traduzioni 5 lingue allegate
- **Non sostituisce revisione legale** -- accetti il rischio in zero-cost mode

### 5C.2 Disclaimer finanziario: tua review
- Claude Code prepara IT, traduzioni 5 lingue
- TU rileggi, particolarmente:
  - Riferimenti normativi corretti (TUF, MiFID II)
  - Linguaggio chiaro per utente non tecnico
  - Nessuna formula ambigua tipo "puoi guadagnare", "raccomandiamo"
- Se vuoi riassicurarti, una consulenza una-tantum di un avvocato fintech
  (~ 100-200 € per 1h) e' **opzionale ma raccomandata**. Il resto e' free.

### 5C.3 Registro trattamenti GDPR
- Anche persona fisica, GDPR ti impone (semplificato):
  - Registro trattamenti (~ 5 pagine)
  - Indicazione titolare = tu, base giuridica, dati raccolti, retention,
    sub-processor
- Modello scaricabile da Garante Privacy: https://www.garanteprivacy.it
- Lo prepari (con aiuto Claude Code), lo conservi offline. Mai pubblicato.

### 5C.4 Assicurazione RC Tech
**Skip in v1.0**. Quando l'app produce 500+ €/anno, attivala (~ 500 €/anno
Hiscox / AIG / Generali). Senza assicurazione corri il rischio.

---

## Fase 6C — Asset store (decisioni e produzione contenuti)

### 6C.1 Review testi store
- Claude Code prepara short + long description in 6 lingue
- TU rileggi, particolarmente:
  - Niente "consigli per investire", "guadagna in borsa", "il miglior
    investimento" (triggera review manuale Google)
  - Tone professionale, neutro
  - Match con disclaimer in-app

### 6C.2 Screenshot reali con dati demo
- Cowork genera screenshot da web build
- Per qualita' marketing serve il tuo OK estetico
- Decidi: schermate da evidenziare in primo piano

### 6C.3 Privacy Policy URL approvazione
- Approvi i testi finali Claude Code prima del deploy su Pages
- L'URL deve essere stabile (non cambia mai post-submission)

### 6C.4 Demo CSV per Play Review
- Google Review puo' chiedere come provare l'app
- Prepara `assets/demo/portfolio_demo.csv` (10 posizioni dummy realistiche)
- Istruzioni in App Submission notes:
  "Aprire app -> Importa portafoglio -> selezionare CSV fornito"

---

## Fase 7C — Beta testing reale

### 7C.1 Closed Testing Play
- Cowork crea track, tu fornisci 12+ email tester
- 14 giorni minimi obbligatori (regola Google)

### 7C.2 Test fisico personale
Installa la build su 2-3 device tuoi (almeno 1 Android).

Scenari:
- Onboarding completo
- Import CSV broker (almeno 2 broker diversi)
- Tab Mercato con 5G/Wi-Fi/connessione lenta
- Modalita' aereo poi riconnessione (cache funziona?)
- Background/foreground rapido
- Locale switch (it -> en -> de -> ...)
- Theme switch (light/dark)
- Reboot device, riapri app (state restoration)
- Rotazione device (se supportata)
- Accessibilita' base con TalkBack attivo

Documenta bug in `IMPLEMENTATION_HISTORY.md`.

### 7C.3 Feedback raccolta
- Crea Google Form / Typeform per i tester (free tier)
- Domande: gradimento UI, bug, feature mancanti
- Iterazione fix prima della production submission

---

## Fase 8C — Submission e review iterations

### 8C.1 Submit
- Cowork prepara, **TU premi Submit**

### 8C.2 Risposte rejection
- 50% probabilita' rejection al primo invio
- Cowork suggerisce, Claude Code fixa, **TU rivedi e re-submit**

### 8C.3 Comunicazione utenti durante review
- Mantieni email di contatto sempre attive

---

## Fase 9C — Post-launch

### 9C.1 Risposta review utenti
- Rispondi a OGNI review, anche negativa, professionalmente.
- Le review aumentano il ranking.

### 9C.2 Comunicazioni legali in arrivo
Possibili:
- DMCA notice (qualcuno ha clonato l'app)
- DMCA counter-notice
- GDPR data subject access request: l'app ha export integrato (consent_service)
- Google policy changes: target SDK update annuale (Aug)
- Authority letters (raro per app a basso volume)

### 9C.3 Manutenzione ricorrente

| Task | Frequenza | Costo |
|---|---|---|
| Update target SDK | Annuale (Aug) | 0 € (Claude Code prepara) |
| Update privacy policy | Quando aggiungi feature | 0 € |
| Audit security report | Trimestrale | 0 € (Cowork genera) |
| Backup keystore verify | Semestrale | 0 € (tu apri/verifichi/richiudi) |

### 9C.4 Trigger per Fase 2 (post-revenue)

Ad app pubblicata, monitora ricavi (donations, ads, subscription, ecc.).
Suggerimenti soglie:

| Ricavi annuali | Aggiungere |
|---|---|
| 50 € | Yubikey x2 se non gia' fatto |
| 100 € | Apple Developer Program (99 USD/anno) -> sblocca iOS |
| 200 € | Dominio custom plurifin.app + setup CNAME GitHub Pages |
| 500 € | Assicurazione RC Tech (massimale 500k-1M €) |
| 1000 € | Marchio EUIPO PluriFin (~ 900 €) |
| 2000 € | Iubenda Pro + revisione legale fintech una-tantum |
| 5000 € | Valutazione SRL + commercialista per ottimizzare fiscale |

---

## Web deployment gratuito

### Confermato: GitHub Pages free zero-cost
- URL definitivo: `https://lunapiena49.github.io/portfoliomanager-data/app/`
- Niente custom domain in v1.0

### Cosa devi fare tu
1. Approvi pubblicazione web sul repo pubblico data (Cowork la setupa)
2. Approvi testi banner (Claude Code li scrive in 6 lingue, tu rivedi)
3. Test personale su almeno 3 browser (Chrome, Firefox, Safari)
4. Aggiorni la privacy policy per menzionare deployment web (Claude Code lo
   include nel template, tu confermi)

### Costo deployment web
**0 €** confermato.

---

## Output finale Piano C v1.0

Una volta completato:
1. Email professionale operativa (alias o Gmail dedicato)
2. (Opzionale) P.IVA aperta + conto corrente attivita' separato
3. Bitwarden vault con tutti i secret
4. (Raccomandato) Yubikey x2 attive
5. ID digitale pronto per upload
6. Play Console attivato e verified
7. Keystore Android generata + backup multipli
8. Privacy Policy + ToS reviewed (gratuiti, hostati su Pages)
9. Disclaimer finanziario reviewed
10. Tester Closed Testing invitati e attivi
11. Submission Play Store production approvata
12. Web app pubblica e linkata

**Tempo stimato Piano C v1.0**: 15-20 ore di tuo tempo distribuite su 6-10
settimane (a causa attesa identity verification + 14 giorni Closed Testing).

**Costo totale stimato v1.0**: 25 USD (Play Console) + opzionalmente 145 €
(Yubikey x2). Tutto il resto rimandato.

**Costo annuo a regime v1.0**: 0 €.
