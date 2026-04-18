---
name: session-wrap
description: Chiude la sessione Claude aggiornando IMPLEMENTATION_HISTORY.md (storico compatto) e USER_FEATURES.md (se toccate lib/features/*/presentation/pages/ o assets/translations/). Usa alla fine di ogni sessione prima del commit finale, o quando l'hook Stop segnala commit non ancora riflessi nello storico.
---

# Skill: session-wrap

Skill di chiusura sessione. Scritta per essere deterministica e veloce.

## Input

Data corrente (oggi) e opzionale lista di commit nuovi rispetto all'ultima voce in
`IMPLEMENTATION_HISTORY.md`. Se l'utente non specifica, calcolala.

## Step 1 — Raccogli delta

```bash
rtk git log --since="<last_session_date>" --pretty=format:"%h|%ad|%s" --date=short
rtk git status
```

Se nessun commit nuovo **e** nessuna modifica uncommitted significativa in `lib/`,
`assets/translations/`, `.github/workflows/` → la sessione era solo read/discussion:
salta IMPLEMENTATION_HISTORY.md, ma chiedi conferma prima.

## Step 2 — Aggiorna IMPLEMENTATION_HISTORY.md

Append (non sostituire) una sezione in cima al blocco "Note operative":

```markdown
## Sessione YYYY-MM-DD — <titolo sintetico>

- <bullet 1 — change + perche', 1 riga>
- <bullet 2>
- ...

Prossima sessione: <prossimo obiettivo se noto, altrimenti omesso>
```

Aggiungi anche le voci alla tabella "Timeline commit" in testa al file, rispettando il formato esistente:
`| YYYY-MM-DD | \`<hash>\` | Summary. |`.

## Step 3 — Aggiorna USER_FEATURES.md (se applicabile)

Condizione: almeno uno dei file toccati in sessione sta in:
- `lib/features/*/presentation/pages/**`
- `assets/translations/*.json`

Se si':
- Aggiorna la data nel titolo (`Aggiornato alla sessione: YYYY-MM-DD`).
- Aggiungi/modifica la voce nella sezione rilevante (Onboarding / Portafoglio / Import / Analisi AI / Mercato / Obiettivi / Ribilanciamento / Impostazioni / Sicurezza / Piattaforme).
- Formato voce: `- **Nome feature**: descrizione 1 riga · [path](path):line_se_puntuale`.

Se non si': non toccare `USER_FEATURES.md`.

## Step 4 — Proposta commit finale

Proponi all'utente:

```bash
rtk git add CLAUDE.md USER_FEATURES.md IMPLEMENTATION_HISTORY.md ULTRAREVIEW_PLAN.md .claude/ .github/
rtk git commit -m "chore(session): wrap YYYY-MM-DD"
```

Non eseguire il commit senza conferma (vedi `permissions.ask` in `.claude/settings.json`).

## Regole

- Non duplicare voci gia' presenti.
- Non cancellare sessioni passate (append-only per lo storico).
- Mantieni `IMPLEMENTATION_HISTORY.md` sotto ~400 righe — se cresce troppo, proponi consolidation
  spostando le sessioni > 90 giorni in `docs/history/archive-YYYY-Qn.md`.
- Mantieni `USER_FEATURES.md` sotto ~300 righe — se cresce, suddividi per area in
  `docs/features/<area>.md` e lascia `USER_FEATURES.md` come indice.

## Riferimenti

- [IMPLEMENTATION_HISTORY.md](../../../IMPLEMENTATION_HISTORY.md)
- [USER_FEATURES.md](../../../USER_FEATURES.md)
- [ULTRAREVIEW_PLAN.md](../../../ULTRAREVIEW_PLAN.md) §5 — contratti dei file viventi
