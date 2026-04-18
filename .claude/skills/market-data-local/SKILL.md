---
name: market-data-local
description: Scarica l'ultimo snapshot market data (top_movers, prices_index, market_history) da GitHub Pages nella cartella dist/market-data e verifica che as_of_date sia recente. Usa quando l'utente chiede "aggiorna dati mercato locale", "sync snapshot", "movers stale", o quando SessionStart segnala snapshot stale.
---

# Skill: market-data-local

Sincronizza lo snapshot market data locale con l'artifact pubblicato dal workflow `market-data-snapshot.yml`.

## Quando usare

- Snapshot locale `dist/market-data/top_movers.json` ha `as_of_date` > 24h (segnalato dal SessionStart hook).
- Prima di testare la feature Market in debug locale.
- Dopo aver scaricato una fresh copia del repo.

## Esecuzione

```bash
powershell -ExecutionPolicy Bypass -File scripts/eodhd/sync_market_snapshot_from_pages.ps1
```

Override owner/repo se necessario (rara):
```bash
powershell -ExecutionPolicy Bypass -File scripts/eodhd/sync_market_snapshot_from_pages.ps1 -Owner lunapiena49 -Repo portfoliomanager
```

## Verifiche post-sync

1. File presenti:
   ```bash
   rtk ls dist/market-data/
   ```
   Attesi: `top_movers.json`, `prices_index.json`, `daily_market.db.zip`, `market_history.db.zip`

2. Freshness:
   ```bash
   rtk read dist/market-data/top_movers.json
   ```
   Controlla `as_of_date` — deve essere entro gli ultimi 1-2 giorni di borsa (il workflow gira alle 22:35 UTC giorni lavorativi).

3. Se `as_of_date` e' ancora vecchio dopo il sync: il workflow potrebbe aver fallito. Check:
   ```bash
   rtk gh run list --workflow=market-data-snapshot.yml --limit 3
   ```

## Interazione con SessionStart hook

Il hook [.claude/hooks/session-start.ps1](../../../.claude/hooks/session-start.ps1) lancia gia' lo stesso
script in **background detached** se rileva `top_movers.json` o `market_history.db.zip` piu' vecchi di 24h.
Usa questa skill quando:
- Vuoi eseguire il sync **sincrono** (per sapere se e' andato a buon fine).
- Il background sync e' fallito (niente file o `as_of_date` ancora vecchio dopo qualche minuto).
- Vuoi forzare il sync anche con file freschi (es. dopo un hotfix del workflow Pages).

## Non committare

- La cartella `dist/market-data/` contiene artifact pesanti; `.gitignore` tiene fuori tutto tranne `top_movers.json`.
- Il DB (`market_history.db.zip`, `market_history.db`, `daily_market.db.zip`, `prices_index.json`) vive solo su GitHub Pages.
- Flusso DB: **pull-only** in locale; push/aggiornamento e' compito esclusivo del workflow CI `market-data-snapshot.yml`.
- Il workflow `daily-data-commit.yml` committa solo `top_movers.json` + `docs/DATA_SNAPSHOT_LOG.md` come traccia giornaliera nella repo.

## Riferimenti

- Script sync: [scripts/eodhd/sync_market_snapshot_from_pages.ps1](../../../scripts/eodhd/sync_market_snapshot_from_pages.ps1)
- Builder snapshot (CI): [scripts/eodhd/build_daily_market_snapshot.py](../../../scripts/eodhd/build_daily_market_snapshot.py)
- Workflow pub Pages: [.github/workflows/market-data-snapshot.yml](../../../.github/workflows/market-data-snapshot.yml)
