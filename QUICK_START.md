# QUICK_START

Guida rapida per avviare Portfolio Manager su Windows (browser) e smartphone, sia in debug sia in produzione.

## 1) Prerequisiti

- Windows 10/11
- Flutter SDK (stable)
- Android Studio + Android SDK (per smartphone Android)
- Chrome (per build web locale)
- Python 3.11+ (solo per servire build web in locale)
- PowerShell

Verifica setup:

```powershell
flutter doctor -v
```

## 2) Setup progetto (prima volta)

```powershell
git clone https://github.com/lunapiena49/portfoliomanager.git
# entra nella cartella del progetto
flutter pub get
```

## 3) Aggiornare dati market snapshot in locale

Scarica gli artifact pubblicati su GitHub Pages dentro `dist/market-data`:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/eodhd/sync_market_snapshot_from_pages.ps1
```

Override owner/repo se necessario:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/eodhd/sync_market_snapshot_from_pages.ps1 -Owner lunapiena49 -Repo portfoliomanager
```

## 4) Avvio DEBUG - Browser Windows

```powershell
flutter run -d chrome --web-port 8080
```

Note debug utili:
- Hot reload: `r` nel terminale
- Hot restart: `R` nel terminale
- Per verificare layout full-size e mobile: usa DevTools del browser (responsive mode)

## 5) Avvio DEBUG - Smartphone Android

1. Attiva "Developer options" + "USB debugging" sul telefono.
2. Collega il device via USB.
3. Verifica device:

```powershell
flutter devices
```

4. Avvia app in debug:

```powershell
flutter run -d <DEVICE_ID>
```

## 6) Build PRODUZIONE - Browser Web

Tutti i build di release sono offuscati di default (`--obfuscate
--split-debug-info`): il repo e' pubblico, quindi gli artefatti distribuiti
non devono esporre nomi e simboli Dart.

```powershell
flutter clean
flutter pub get
flutter build web --release `
  --obfuscate `
  --split-debug-info=build/symbols/web
```

Smoke test locale della build prod:

```powershell
python -m http.server 8080 --directory build/web
```

Poi apri: `http://localhost:8080`

## 7) Build PRODUZIONE - Smartphone Android

```powershell
flutter clean
flutter pub get
flutter build apk --release `
  --obfuscate `
  --split-debug-info=build/symbols/android
```

APK output:
- `build/app/outputs/flutter-apk/app-release.apk`

I simboli di debug finiscono in `build/symbols/android/` (gia' in
`.gitignore` via `build/`). Conservali insieme alla release: servono per
de-obfuscation degli stack trace dei crash report.

Installazione su device collegato:

```powershell
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

## 8) Controlli consigliati prima del rilascio

```powershell
flutter analyze
flutter test
```

Checklist rapida:
- UI corretta su browser full-size e viewport mobile
- Traduzioni presenti in tutte le lingue (`assets/translations/*.json`)
- Market snapshot aggiornato (`dist/market-data/top_movers.json`, `dist/market-data/prices_index.json`)
