# Portfolio Manager (PluriFin)

Private Flutter source for the **Portfolio Manager** app published on Google
Play Store under the developer name **PluriFin**.

> This is the **private** repo (`portfolio-manager-app`). The companion public
> repo `portfoliomanager-data` hosts market-data snapshots, the Flutter web
> build, and legal HTML pages on GitHub Pages.

## Architecture

Multi-platform Flutter app for personal investment portfolio management:
broker CSV/PDF import, AI analysis (Gemini), rebalancing helpers, market
data via the public data repo.

- **Bundle ID**: `app.plurifin.portfoliomanager`
- **Pubspec name**: `portfolio_manager`
- **Day-1 target**: Android (Play Store). iOS deferred to phase 2.
- **Web URL**: <https://lunapiena49.github.io/portfoliomanager-data/app/>

See [CLAUDE.md](CLAUDE.md) for the full repo conventions and dev workflow.

## Quick start

```bash
flutter pub get
flutter run -d chrome --web-port 8080         # debug web
flutter test                                  # unit + widget tests
flutter analyze
```

Release builds (always obfuscated, repo is public):

```bash
flutter build apk --release \
    --obfuscate --split-debug-info=build/symbols/android \
    --dart-define=MARKET_SNAPSHOT_BASE_URL=https://lunapiena49.github.io/portfoliomanager-data
flutter build appbundle --release \
    --obfuscate --split-debug-info=build/symbols/android \
    --dart-define=MARKET_SNAPSHOT_BASE_URL=https://lunapiena49.github.io/portfoliomanager-data
flutter build web --release \
    --obfuscate --split-debug-info=build/symbols/web \
    --base-href=/portfoliomanager-data/app/ \
    --dart-define=MARKET_SNAPSHOT_BASE_URL=https://lunapiena49.github.io/portfoliomanager-data \
    --dart-define=APP_DEPLOYMENT=web
```

Symbol files (`build/symbols/`) must be archived per release for stack-trace
de-obfuscation. They are NOT committed (`.gitignore`).

## Security

- API keys (Gemini, EODHD, FMP) are stored in `flutter_secure_storage` at
  runtime. Never hardcoded.
- Pre-commit hook runs `gitleaks` against the staged diff; activate with
  `pwsh -File scripts/security/install_hooks.ps1`.
- Release builds use R8 + ProGuard; see `android/app/proguard-rules.pro`.
- Hive boxes are AES-256 encrypted; key is in secure storage (Android Keystore /
  iOS Keychain).

## Layout

```
lib/
  main.dart             bootstrap
  app_router.dart       GoRouter
  core/                 theme, constants, shared widgets
  features/             portfolio, analysis, goals, market, rebalancing,
                        settings, onboarding (BLoC per feature)
  services/
    api/                gemini, eodhd, fmp wrappers (Dio + retrofit)
    parsers/            12 broker CSV/PDF parsers + factory
    storage/            Hive + secure storage
```

## Companion data repo

Market snapshots are pulled from the public data repo at:

- `https://lunapiena49.github.io/portfoliomanager-data/top_movers.json`
- `https://lunapiena49.github.io/portfoliomanager-data/prices_index.json`
- `https://lunapiena49.github.io/portfoliomanager-data/market_history.db.zip`

The override URL can be set at build time via
`--dart-define=MARKET_SNAPSHOT_BASE_URL=https://...`.

## License

Proprietary -- see [LICENSE](LICENSE).
