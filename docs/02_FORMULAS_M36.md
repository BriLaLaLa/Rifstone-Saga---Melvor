# 02. Formule, §5p: Pagina di raccolta (F-204…F-208; M36B, V46)

Estensione di `02_FORMULAS.md`. Regole in `01_GDD_M36.md` (§44). Convenzioni: `floor`, `round` a metà verso l'alto. Gli esempi sono **casi di test**; le tabelle di zona negli esempi sono
**fixture** scritte nel test (come in `02_FORMULAS_M35B.md`), non i dati veri. Tabelle degli esempi (Minatore; livelli Rame 1, Ferro 10, Ferro scuro 20, Ferro nero 30):
z1 (`character` 1) Rame 79, Ferro 21 · z2 (`character` 11) Rame 26, Ferro 58, Ferro scuro 16 · z3 (`character` 21) Rame 5, Ferro 25, Ferro scuro 55, Ferro nero 15.

## F-204 Ritmo di sessione (`GatherStats`)
Per la disciplina `s`: contatori di sessione `nodes_s`, `units_s`, `xp_s` e tempo di gioco online `T = play_time_ms − start_ms` (`start_ms` = `play_time_ms` alla creazione di `GatherStats`).
- `nodes_s` +1 a ogni `node_finished(s, …, units, reason)` con `reason` ∈ {`node_done`, `bank_full`}; `units_s += units`; `xp_s += amount` di `xp_gained(s, amount)` **solo se un nodo di `s`
  è in corso** (`combat.node_skill() == s`: la ricompensa XP di un incarico incassata fuori dal nodo non è ritmo di raccolta).
- Nulla si conta mentre `GameSession.in_offline` è vero (`05_INTERFACES_M36.md` §3j); `play_time_ms` non avanza offline (l'offline lo ripristina, già oggi).
- `rate_units = round(units_s × 3 600 000 / T)`, `rate_xp = round(xp_s × 3 600 000 / T)`, **«non disponibili» se `T < gather_stats.min_sample_ms`**.
Esempi (`min_sample_ms` 120 000): `T` 600 000, 12 unità, 90 XP → 72 unità/h, 540 XP/h; `T` 90 000 con 3 unità → non disponibile; `T` 3 600 000, 0 unità → 0; 50 nodi finiti con
`in_offline` vero → contatori invariati; un nodo finito per `too_hard` o `not_learned` non conta; XP guadagnati con `node_skill()` diverso da `s` non contano.
Test: `tests/systems/encounters/test_gather_stats.gd`.

## F-205 Tempo al prossimo livello
`L` = livello di `s` (F-01), `X` = XP della disciplina. Se `L` = livello massimo: «massimo». `missing = xp_for_level(L+1) − X` (≥ 1). Se `rate_xp` è «non disponibile» o 0: tempo «non
disponibile». Altrimenti `time_ms = ceil(missing × 3 600 000 / rate_xp)`.
Esempi (tabella di prova): `xp_for_level(11) = 1000`, `X` 250 → `missing` 750; `rate_xp` 1500 → 1 800 000 ms (30 min); `rate_xp` 0 → non disponibile; `L` = massimo → «massimo».
Test: stesso file di F-204 (`GatherStats.time_to_level`).

## F-206 Fabbisogno di risorse della disciplina (`GatherNeeds`)
Per la disciplina di raccolta `s`, `R(s)` = i prodotti (`outputs[0].item_id`) delle azioni di `s`. Il fabbisogno è una lista di voci `{item, source, missing}` con `source` ∈ {`queue`, `quest`}
e `missing > 0`:
- **queue**: per ogni lavoro della coda (`actions.jobs()`; i lavori di **progetto** si escludono: i loro materiali escono dal deposito all'avvio) e per ogni ingrediente `(item ∈ R(s), qty)`:
  cicli `c = remaining` se il lavoro non ripete, `c = cycles_possible + 1` se ripete (`ProductionQueueLoader.cycles_possible`: «cosa manca per un ciclo in più»); `need[item] += qty × c`.
  Poi `missing = need[item] − bank.get_count(item)`, voce solo se > 0 (la scorta si sottrae **una volta** sulla somma dei lavori).
- **quest**: per ogni slot della Bacheca con incarico di tipo `gather`, non completo, la cui `item ∈ R(s)`: `missing = target − progress` (il progresso conta solo i pezzi raccolti dopo
  l'assegnazione: **la scorta non si sottrae**). Un incarico per slot (due slot con lo stesso `item` danno due voci).
- **altre discipline**: `other` = numero di `item` **distinti** con `missing > 0` (queue o quest) che appartengono a `R(s')` con `s' ≠ s` (discipline di raccolta); ingredienti che non sono
  prodotti di una raccolta non si contano.
Ordinamento: prima `queue` poi `quest`, a parità per ordine della coda/slot.
Esempi: coda = [lavoro ×5 con Rame ×2; lavoro ×3 con Rame ×2 e Ferro ×1] (non ripetono), scorta Rame 4, Ferro 0 → need Rame 16, Ferro 3 → voci Rame 12, Ferro 3. Lavoro che ripete con
Rame ×2, scorta 5 → `cycles_possible` 2, `c` 3, need 6 → missing 1. Incarico `gather` Rame target 150, progresso 40, scorta 999 → missing 110. Coda con un ingrediente del Boscaiolo,
interrogato il Minatore → `other` 1, nessuna voce. Lavoro di progetto: ignorato. Coda vuota e nessun incarico → lista vuota, `other` 0. Test: `tests/systems/disciplines/test_gather_needs.gd`.

## F-207 Migliore zona per una risorsa (`GatherAdvice.best_zone`)
Per l'azione `a` di `s`, il livello `L` di `s` e il livello del personaggio `C`: tra le zone di `zones_of_action(a)` (F-202) tengo quelle **lavorabili** (`level(a) ≤ L`) e **accessibili**
(`requirements.character ≤ C`). Tra queste scelgo la massima `P_eff` (F-202); a parità la massima `P_nom`; a parità la zona di `order` minore. Risultato `{area, pct_nominal, pct_effective}`,
oppure `{}` con `reason` = `level` (nessuna zona lavorabile) o `access` (lavorabili ma non accessibili).
Esempi (tabelle in testa): Ferro, `L` 10, `C` 25: P_eff z1 21,0 · z2 58/84 = 69,0 · z3 25/30 = 83,3 → **z3 (83,3%)**. Ferro, `L` 25, `C` 25: z1 21 · z2 58/100 = 58 · z3 25/85 = 29,4 →
**z2 (58%)** (la zona più alta non è sempre la migliore). Ferro, `L` 10, `C` 15: z3 non accessibile → z2 (69,0). Ferro, `L` 5 → `{}` motivo `level`. Rame, `L` 1, `C` 1: z1 (100%, 79 nominale).
Ferro scuro, `L` 25, `C` 5 (compare solo in z2 e z3) → `{}` motivo `access`. Test: `tests/systems/encounters/test_gather_advice.gd`.

## F-208 Cosa si sblocca (`GatherAdvice.next_unlocks`)
`N` = il minimo `level(a)` tra le azioni di `s` con `level(a) > L`; se non c'è: vuoto («nessuna novità»). Risultato `{level: N, resources: [{action, zones: [area]}]}` con tutte le azioni di
livello `N` e, per ognuna, le zone di `zones_of_action(a)` nell'ordine di F-202 (anche non accessibili). Esempio (Minatore, gradini 1/10/20/30): `L` 1 → `N` 10: Ferro in z2, z3, z1 (58, 25, 21);
`L` 10 → `N` 20: Ferro scuro in z3, z2 (55, 16); `L` 30 con il gradino successivo a 45 → `N` 45; `L` massimo → vuoto. Test: stesso file di F-207.

## Parametri (`balance.json`)
| Chiave | Valore | Usata in |
|---|---|---|
| `gather_stats.min_sample_ms` | 120000 | F-204 (soglia del campione) |
