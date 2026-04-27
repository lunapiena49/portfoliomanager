---
name: flutter-release
description: Costruisce release web e/o apk dell'app Portfolio Manager dopo aver verificato flutter analyze + flutter test. Usa quando l'utente chiede "release", "build production", "build apk", "build web release", "prepara per play store", "prepara per deploy web".
---

# Skill: flutter-release

Pipeline release locale con gate di qualita'. Segue [QUICK_START.md sezione 6-7-8](../../../QUICK_START.md).

## Gate (fail-fast)

Esegui in sequenza, ferma al primo fallimento:

```bash
rtk flutter pub get
flutter analyze
flutter test
```

Regole:
- `flutter analyze`: zero warning `error` o `warning`. Hint sono tollerati.
- `flutter test`: tutti i test verdi. Se rossi, non procedere con build.

Se qualcosa fallisce: riporta output breve e interrompi senza lanciare build.

## Domanda target

Chiedi all'utente quale build serve (multipla ok):
- Web (`build/web/`)
- Android APK (`build/app/outputs/flutter-apk/app-release.apk`)
- Android App Bundle `.aab` (per Play Store)

## Build

**Obfuscation e' default**, non opzionale. Il repo e' pubblico (per la pipeline
snapshot servita da GitHub Pages) quindi gli APK e bundle distribuiti DEVONO
avere simboli offuscati per ridurre la superficie di reverse-engineering --
chiunque scarichi l'APK dal Play Store o dal sito non deve poter ricostruire
in modo banale la struttura del codice Dart.

I simboli vengono salvati in `build/symbols/<piattaforma>/` (gia' in
`.gitignore` via `build/`) e servono per il de-obfuscation degli stack trace
in caso di crash report. **NON cancellarli** dopo il build: tienili
nell'archivio della release.

Web:
```bash
rtk flutter build web --release \
  --obfuscate \
  --split-debug-info=build/symbols/web
```

Android APK:
```bash
rtk flutter build apk --release \
  --obfuscate \
  --split-debug-info=build/symbols/android
```

Android AAB (Play Store):
```bash
rtk flutter build appbundle --release \
  --obfuscate \
  --split-debug-info=build/symbols/android
```

Se l'utente chiede esplicitamente un build NON offuscato (per debug del
binario), puoi rimuovere i flag, ma chiedi conferma prima ("Vuoi davvero un
build non offuscato? Esporrebbe nomi e simboli Dart nell'artefatto") e
documenta la scelta nella sessione.

## Post-build

Dopo build web, proponi smoke test locale:
```bash
python -m http.server 8080 --directory build/web
```

Dopo build apk, mostra dimensione:
```bash
rtk ls -lh build/app/outputs/flutter-apk/
```

## Checklist pre-release (richiamare all'utente)

- [ ] Traduzioni popolate in tutte le 6 lingue (`translations-sync` skill)
- [ ] `dist/market-data/top_movers.json` con `as_of_date` recente
- [ ] Version bump in `pubspec.yaml` se release store
- [ ] `IMPLEMENTATION_HISTORY.md` aggiornato (skill `session-wrap`)
