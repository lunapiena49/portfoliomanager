# Release signing — Portfolio Manager (PluriFin)

How the Android upload key is generated, stored, and used to ship release
builds to the Play Store.

> Losing the upload key = locked out of pushing app updates. Treat the
> `.jks` file as a master credential. Back it up in **four** independent
> places before submitting to Play Console.

## 1. Generate the keystore (one-shot)

Run:

```
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\release\setup_keystore.ps1
```

The script will:

1. Prompt for owner DN (CN, OU, O, L, ST, C).
2. Prompt for a passphrase (16+ chars suggested, minimum 12).
3. Generate `~/.plurifin/keys/upload-keystore.jks` (RSA 4096, 10000 days).
4. Write `android/key.properties` so Gradle picks the keystore up.

Both files are gitignored.

## 2. Verify

```
keytool -list -v -keystore "%USERPROFILE%\.plurifin\keys\upload-keystore.jks"
```

Note the SHA-256 fingerprint — Play Console shows the same value after the
first upload, so a mismatch tells you immediately which key is which.

## 3. Backup checklist (before submitting to Play)

- [ ] Encrypted USB stick #1 (offline drawer)
- [ ] Encrypted USB stick #2 (different physical location)
- [ ] 1Password / Bitwarden secure attachment (the `.jks` blob)
- [ ] Paper printout of the SHA-256 fingerprint stored with personal docs
- [ ] Passphrase saved in a SEPARATE vault entry (never in the same file as the .jks)

## 4. Build release artifacts

```
flutter clean
flutter pub get
flutter build appbundle --release \
  --obfuscate \
  --split-debug-info=build/symbols/android
```

The `key.properties` wiring causes Gradle to sign with the upload key
automatically. Without `key.properties` Gradle falls back to the debug
signing key — the build still completes but the resulting `.aab` is
useless for the Play Store.

The de-obfuscation symbols land in `build/symbols/android/`. Copy them to
`~/.plurifin/symbols/<version>/` after every release tag — without those
symbols Play Console crash reports stay un-symbolicated.

## 5. Rotate or recover

- The upload key in v1.0 cannot be rotated automatically (Play App Signing
  enrollment ticket required).
- If the passphrase is lost but the .jks file is intact, the keystore is
  irrecoverable. Delete and regenerate; you will need to register a new
  upload key with Google support.
- If the .jks file is lost, you cannot ship updates to the existing Play
  Store listing without escalating to Play developer support.

## 6. Files

| Path | Purpose | Tracked in git? |
|---|---|---|
| `scripts/release/setup_keystore.ps1` | Idempotent keystore generator | yes |
| `~/.plurifin/keys/upload-keystore.jks` | Actual signing key | NO |
| `android/key.properties` | Gradle wiring (paths + passwords) | NO |
| `android/app/proguard-rules.pro` | R8 keep rules | yes |
| `build/symbols/android/` | De-obfuscation maps per build | NO |
| `~/.plurifin/symbols/<version>/` | Archived maps per release | NO |
