---
name: flutter-dev
description: Avvia l'app Portfolio Manager in modalita' debug su browser o device mobile, verifica deps e device disponibili. Usa quando l'utente chiede di "avviare l'app", "provare su chrome", "debug mobile", "run app", o di fare hot reload/restart.
---

# Skill: flutter-dev

Avvia Portfolio Manager in debug mode. Segue [QUICK_START.md sezione 4-5](../../../QUICK_START.md).

## Pre-flight

Esegui in ordine:
```bash
rtk flutter pub get
rtk flutter doctor -v
rtk flutter devices
```

Se `pub get` fallisce: interrompi e segnala dipendenza problematica.
Se `doctor` mostra issue critiche (Flutter SDK mancante, Android toolchain rotta): interrompi.

## Decisione target

1. Chiedi a quale device l'utente vuole fare il run (se non gia' specificato):
   - `chrome` -> browser web locale
   - device ID dalla lista di `flutter devices` -> mobile
2. Default intelligente: se c'e' un device Android connesso usa quello, altrimenti `chrome`.

## Avvio

Web:
```bash
rtk flutter run -d chrome --web-port 8080
```

Mobile:
```bash
rtk flutter run -d <DEVICE_ID>
```

Informa l'utente dei tasti utili: `r` hot reload, `R` hot restart, `q` quit.

## Note

- Mai `flutter clean` senza esplicita richiesta dell'utente (e' in `deny` di `.claude/settings.json`).
- Per layout responsive debug: suggerisci di usare DevTools browser (responsive mode).
- Il comando `flutter run` e' long-running: se l'utente vuole solo verificare che builda, proponi `rtk flutter build web --debug` come check.
