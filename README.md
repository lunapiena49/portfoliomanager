# Portfolio Manager

App Flutter multi-piattaforma per gestione portafoglio investimenti: import da broker multipli,
analisi AI, ribilanciamento, top movers globali gratuiti via pipeline GitHub Actions.

- **Piattaforme**: Android - iOS - Web - Windows - Linux - macOS
- **Stack**: Flutter + BLoC + Hive + Dio + Gemini AI + fl_chart/syncfusion
- **Lingue**: IT - EN - ES - FR - DE - PT

## Cosa puo fare l'utente

Sintesi; il catalogo completo e' in [USER_FEATURES.md](USER_FEATURES.md).

- Crea e gestisce portafogli multipli (uno dispositivo, N portafogli)
- Importa estratti CSV/PDF da 12 broker (IBKR, TD, Fidelity, Schwab, E*TRADE, Robinhood, Vanguard, DEGIRO, Trading 212, XTB, Revolut, generico)
- Aggiunge manualmente posizioni con tipo/settore/regione
- Esegue analisi AI (Gemini) e chat contestuale sul portafoglio
- Visualizza top gainers/losers globali su 8 mercati -- senza API key
- Imposta obiettivi di investimento con progress tracking
- Definisce target allocation e confronta con l'attuale (ribilanciamento)
- Configura prezzi live opzionali (EODHD/FMP) con catena di fallback

## Quick start

Setup e avvio in dettaglio: [QUICK_START.md](QUICK_START.md).

```bash
git clone https://github.com/lunapiena49/portfoliomanager.git
cd portfoliomanager
flutter pub get
flutter run -d chrome --web-port 8080   # debug web
# oppure
flutter run -d <DEVICE_ID>              # debug mobile
```

Build release:
```bash
flutter build web --release
flutter build apk --release
flutter build appbundle --release
```

## Struttura repository

```
lib/
|-- main.dart - app_router.dart
|-- core/              # theme, constants, localization, widget comuni
|-- features/          # portfolio, analysis, goals, market, rebalancing, settings, onboarding
|-- services/          # api (gemini), parsers (12 broker), storage (Hive)
assets/translations/   # 6 lingue JSON
scripts/eodhd/         # pipeline market snapshot (Python + PowerShell sync)
.github/workflows/     # market-data-snapshot (Pages) + daily-data-commit (repo)
.claude/               # settings + hooks + skills per Claude Code
```

## Pipeline dati di mercato

Due workflow GitHub Actions:

| Workflow | Cron | Output | Scopo |
|---|---|---|---|
| [market-data-snapshot.yml](.github/workflows/market-data-snapshot.yml) | 22:35 UTC | Pubblica su GitHub Pages | Top movers + prices index + history DB |
| [daily-data-commit.yml](.github/workflows/daily-data-commit.yml) | 07:00 UTC | Commit `top_movers.json` in main | Traccia freshness nel repo |

L'app consuma i JSON pubblicati su Pages -- no cron locale necessario.

## Documentazione

- [CLAUDE.md](CLAUDE.md) -- istruzioni per Claude Code + comandi `rtk`
- [USER_FEATURES.md](USER_FEATURES.md) -- catalogo funzioni utente (aggiornato per sessione)
- [IMPLEMENTATION_HISTORY.md](IMPLEMENTATION_HISTORY.md) -- storico implementazioni
- [QUICK_START.md](QUICK_START.md) -- setup dev/prod
- [formati_brokers.md](formati_brokers.md) -- spec CSV dei 12 broker
- [flutter_workflow.md](flutter_workflow.md) -- workflow release multi-piattaforma
- [docs/DATA_SNAPSHOT_LOG.md](docs/DATA_SNAPSHOT_LOG.md) -- log snapshot giornalieri
- [ULTRAREVIEW_PLAN.md](ULTRAREVIEW_PLAN.md) -- piano Claude Code/skills/hooks

## Sicurezza e privacy

- Dati utente **locali** (Hive + SharedPreferences + flutter_secure_storage)
- API keys utente (Gemini, EODHD, FMP) mai committate -- solo in secure storage
- Top movers funzionano senza alcuna chiave utente
- Cancellazione dati completa da Impostazioni > Dati
