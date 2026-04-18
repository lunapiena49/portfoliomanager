---
name: translations-sync
description: Verifica che tutte le chiavi di traduzione siano presenti in tutti e 6 i file locale (it/en/es/fr/de/pt), genera report dei mancanti, opzionalmente inserisce placeholder. Usa quando l'utente chiede "sync traduzioni", "verifica i18n", "mancano traduzioni", "aggiungi chiave i18n", o dopo aver modificato una delle 6 lingue da solo.
---

# Skill: translations-sync

Mantiene allineati i 6 file `assets/translations/{it,en,es,fr,de,pt}.json`.

## Contract

- Tutte e 6 le lingue devono avere **le stesse chiavi** (stessa struttura nested).
- Regola d'oro: mai aggiungere/rimuovere chiavi in un solo file.

## Procedura diff

1. Leggi i 6 file (`it.json` e' source-of-truth prioritaria, essendo lingua primaria dell'autore).

2. Computa set di chiavi (flatten path con `.`) per ciascun file.

3. Per ogni coppia `(it, <target>)` riporta:
   - Chiavi presenti in `it` ma mancanti in `target` -> **da tradurre**.
   - Chiavi presenti in `target` ma non in `it` -> **orfane** (probabile refactor incompleto).

4. Output report compatto:
   ```
   en: +3 mancanti, -0 orfane
     - portfolio.new_feature.title
     - portfolio.new_feature.hint
     - import.custom_step
   es: ...
   ```

## Azioni

Chiedi all'utente quale modalita':

- **Report only** (default): mostra il diff e si ferma.
- **Placeholder insert**: aggiunge chiavi mancanti con valore `"[TODO: translate] <it value>"`. Mai sovrascrivere chiavi esistenti. Non rimuovere orfane senza conferma esplicita.
- **Translate**: propone traduzioni (usare modello in runtime se disponibile, altrimenti chiedere conferma umana).

## Validazione JSON

Dopo ogni edit: valida che i file siano JSON parsabili (nessuna trailing comma, escape corretto).
Non usare `flutter test` per questo -- un `python -m json.tool` basta:

```bash
rtk read assets/translations/en.json
```

## Note ortografia italiana

Il progetto serve utenza IT come mercato primario. In `it.json`:
- **Mantenere** diacritici corretti (`e`, `a`, `o`, `u`, `i`).
- Alcune stringhe legacy usano versione senza accenti (es. `Sanita`, `Volatilita`). **Non convertire in massa** senza conferma -- rischio regressione su layout che si basa sulla larghezza stringa.

## Riferimenti

- [assets/translations/it.json](../../../assets/translations/it.json) -- source
- [assets/translations/en.json](../../../assets/translations/en.json)
- [assets/translations/es.json](../../../assets/translations/es.json)
- [assets/translations/fr.json](../../../assets/translations/fr.json)
- [assets/translations/de.json](../../../assets/translations/de.json)
- [assets/translations/pt.json](../../../assets/translations/pt.json)
