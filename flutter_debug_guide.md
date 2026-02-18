# Flutter Debug Guide — Portfolio Manager

## Prerequisiti

Verifica che siano installati:
```powershell
flutter --version    # >= 3.x
dart --version
git --version
```

Se `flutter doctor` segnala problemi, risolvili prima di procedere.

---

## 1. Eseguire l'app in locale (senza configurare nulla)

### Chrome / Web (consigliato per il debug)
```powershell
flutter run -d chrome
```

### Desktop Windows
```powershell
flutter run -d windows
```

L'app si avvia **senza** dati di mercato reali perché `MARKET_SNAPSHOT_BASE_URL` non è configurato. La scheda Mercato mostrerà "No data available" — normale per ora.

---

## 2. Configurare `MARKET_SNAPSHOT_BASE_URL` in locale

Il valore deve puntare all'URL base di GitHub Pages dove vengono pubblicati
`top_movers.json`, `prices_index.json`, ecc.

**Formato URL atteso:**
```
https://<owner>.github.io/<repo-name>
```
Esempio: `https://mariorossi.github.io/portfolio_manager`

### Passarlo via `--dart-define` al run

```powershell
flutter run -d chrome `
  --dart-define=MARKET_SNAPSHOT_BASE_URL=https://mariorossi.github.io/portfolio_manager
```

### Oppure su Windows desktop
```powershell
flutter run -d windows `
  --dart-define=MARKET_SNAPSHOT_BASE_URL=https://mariorossi.github.io/portfolio_manager
```

> **Nota**: prima che GitHub Actions abbia completato almeno una run, l'URL
> restituirà 404 e l'app userà i dati locali/FMP come fallback.

---

## 3. Configurare le chiavi API opzionali via `--dart-define`

Puoi iniettare le chiavi senza digitarle ogni volta nell'app:

```powershell
flutter run -d chrome `
  --dart-define=MARKET_SNAPSHOT_BASE_URL=https://mariorossi.github.io/portfolio_manager `
  --dart-define=EODHD_API_KEY=la_tua_chiave_eodhd `
  --dart-define=GEMINI_API_KEY=la_tua_chiave_gemini
```

Il codice le legge tramite `String.fromEnvironment(...)` nelle impostazioni.

> **IMPORTANTE**: non aggiungere mai le chiavi in file committati su Git.
> Usale **solo** localmente via `--dart-define`.

---

## 4. Build web per test offline

```powershell
flutter build web --release `
  --dart-define=MARKET_SNAPSHOT_BASE_URL=https://mariorossi.github.io/portfolio_manager
```

Output in `build/web/`. Per servire localmente:
```powershell
# Se hai Python installato:
python -m http.server 8080 --directory build/web
# Poi apri http://localhost:8080
```

---

## 5. Push su GitHub e attivare la pipeline

Usa lo script incluso nel progetto:

```powershell
# Commit + push di tutti i file modificati
.\push_to_github.ps1

# Con messaggio personalizzato
.\push_to_github.ps1 -Message "feat: aggiorna pipeline milestone"

# Su branch specifico
.\push_to_github.ps1 -Message "fix: correzione" -Branch main
```

### Dopo il push

1. Vai su **GitHub → Actions** e controlla che il workflow  
   `Market Data Snapshot` parta automaticamente (trigger: push su main)  
   oppure avvialo manualmente con **Run workflow**.
2. Attendi il completamento (~3-5 min per 10 mercati).
3. Vai su **GitHub → Settings → Pages** e verifica che  
   il sito sia pubblicato (source: `GitHub Actions`).
4. Dopo la prima run riuscita, l'URL  
   `https://<owner>.github.io/<repo>/top_movers.json`  
   sarà accessibile pubblicamente.

---

## 6. Configurare GitHub Secrets per la pipeline

Vai su **GitHub → Settings → Secrets and variables → Actions** e aggiungi:

| Nome              | Valore                        |
|-------------------|-------------------------------|
| `EODHD_API_KEY`   | La tua chiave EODHD personale |

> La chiave NON deve mai essere scritta nei file del repository.

---

## 7. Abilitare GitHub Pages

1. **GitHub → Settings → Pages**
2. Source: **GitHub Actions**
3. Salva. La prima pubblicazione avviene al completamento del workflow.

---

## 8. Flusso dati — cosa aspettarsi giorno per giorno

| Giorno | Dati disponibili |
|--------|-----------------|
| 1ª run | Solo 1D (oggi). 5D/1M/1Y vuoti (milestone appena inizializzato) |
| Dopo 7 gg | 5D disponibile |
| Dopo 30 gg | 1M disponibile |
| Dopo 365 gg | 1Y disponibile |

Il file `milestone_prices.db.zip` (~2-5 MB compresso) viene pubblicato su
GitHub Pages e riscaricato ad ogni run del workflow per aggiornare i slot.

---

## 9. Comandi utili per debug

```powershell
# Verifica lista device disponibili
flutter devices

# Build + analisi codice
flutter analyze

# Pulizia cache Flutter
flutter clean
flutter pub get

# Hot reload è attivo automaticamente con 'flutter run' — premi 'r'
# Hot restart completo — premi 'R'
# Quit — premi 'q'
```
