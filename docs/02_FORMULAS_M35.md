# 02. Formule, §5n: Raccolta mirata e attrezzi con teste (F-195…F-199; M35-D, V44)

> **Abrogato da V45 (M35B)**: F-195 (raccolta mirata) non esiste più; la risorsa è F-200 in `02_FORMULAS_M35B.md`. Le altre formule di questo file valgono.

Estensione di `02_FORMULAS.md`: **modifica** F-154 (risorsa), F-94 (effetto; i costi restano), F-155/F-162 (unità), F-164 (nodo ricco), F-103 (sottoprodotto), F-165
(forma chiusa). Convenzioni: `floor`, `round` a metà verso l'alto, `T(stat, ctx)` = F-05. Gli esempi sono **casi di test**. Regole in `01_GDD_M35.md` (§42), dati in
`04_DATA_SCHEMA_M35.md` (§35). Gradini del Minatore (livello): Rame 1, Ferro 10, Ferro scuro 20, Ferro nero 30, Argento runico 45, Ossidiana 60, Astrite 75, Riftite 90.

## F-195 Risorsa del nodo con raccolta mirata (modifica F-154)
Per un nodo della disciplina `s` con tetto `M`, livello `L` e scelta `f` (`disciplines.focus[s]`, può mancare): `limit = min(L, M)`.
- `f` assente → come F-154 (azione di livello più alto ≤ `limit`).
- `f` presente e `level(f) ≤ limit` → la risorsa è **`f`**; altrimenti (`level(f) > limit`, per esempio l'area permette meno) → come F-154 (**Automatico**, mai salto).
- Colore, durata, unità e maestria: invariati (F-154 colore con `d = L − level(risorsa)`).
**Impostare la scelta** (`set_focus`): l'azione deve essere di `s` (`unknown_id`), `s` appresa (`not_learned`), `level(f) ≤ L` (`level_too_low`; `L` = livello della
disciplina, F-01/F-160), altrimenti rifiuto; `&""` toglie la scelta (sempre ok). Disimparare o azzerare `s` toglie `focus[s]`.
Esempi (Minatore): `L` 45, `M` 60, nessuna scelta → **Argento runico**; `L` 45, `M` 50, `f` = Rame → **Rame**, `d` 44 → **grigio** (XP 0%, prodotto e maestria pieni);
`L` 45, `M` 30, `f` = Argento runico → `limit` 30 → **Ferro nero** (Automatico); `L` 27, `M` 30, `f` = Ferro → **Ferro**, `d` 17 → **giallo**; `L` 30, `f` = Ferro, `M` 99 →
**Ferro**, `d` 20 → **verde**; `L` 45, `set_focus` Ossidiana → `level_too_low`; `set_focus` con Minatore non appreso → `not_learned`; `set_focus(quarrying, &"")` → ok, Automatico.
Test: `tests/systems/encounters/test_gather_focus.gd`, `tests/systems/disciplines/test_focus.gd`.

## F-196 Effetto base dell'attrezzo (modifica F-94, solo l'effetto)
Attrezzo unico della disciplina `s` a `+N` (0…9), modificatori con scope `skill:<s>`:
- `skill_interval_pct = −(tool_upgrade.interval_base_pct + tool_upgrade.interval_per_level_pct × N)` (5 e 2: invariato);
- **nuovo** `node_units_pct = tool_upgrade.units_per_level_pct × N` (1).
Gli `upgrade_extras` di F-94 (`double_item_chance` +2/+3, `rift_shard_chance` +10/+15 a +5/+9) sono **tolti** dai dati: le teste (F-197) li sostituiscono.
Esempi: +0 → `skill_interval_pct` −5, `node_units_pct` 0; +4 → −13, +4; +9 → −23, +9. Falcetto +0 → −5, 0.
**Costi di F-94: tabella corretta** (i valori veri sono quelli di `balance.json`, 100 volte la vecchia tabella; vedi la correzione in `02_FORMULAS.md` F-94):
oro `10.000, 25.000, 60.000, 120.000, 250.000, 500.000, 1.000.000, 2.000.000, 4.000.000` per i passi +1…+9. Test: `tests/systems/armory/test_upgrade_tool.gd` (esteso).

## F-197 Teste: scelte ai passi +3, +6, +9
`tool_upgrade.head_steps` = `[3, 6, 9]`. L'attrezzo ha due teste (`equip.heads` in `data/items/tools.json`); ogni testa ha, per ciascun passo, una lista di modificatori
con scope `skill:<s>`. Lo stato dell'istanza è `heads[i]` (`i` = 0, 1, 2 per i passi 3, 6, 9; `&""` = nessuna scelta). I modificatori attivi (sorgente
`equipment:<slot>`, insieme a F-196) sono, per ogni `i` con `heads[i] ≠ ""` e `head_steps[i] ≤ N`, quelli del passo `i` della testa scelta.
**Valori** (stessa tabella per i tre passi, `T3 = T6 = T9` salvo dove indicato):
| Attrezzo | Testa | Modificatori per passo (+3 / +6 / +9) |
|---|---|---|
| tutti | Resa (Lama larga, Punta da filone, Rete, Cesto) | `node_units_pct` 5 / 5 / 5 |
| Accetta | Ricchezza: Scure fine | `double_item_chance` 4 / 4 / 4; `byproduct_chance_pct` 1 / 1 / 1 |
| Piccone | Ricchezza: Martello da cava | `node_rich_pct` 6 / 6 / 6; `double_item_chance` 2 / 2 / 2 |
| Canna | Ricchezza: Amo fine | `rift_shard_chance` 8 / 8 / 9; `double_item_chance` 3 / 3 / 3 |
| Falcetto | Ricchezza: Mazzo scelto | `node_rich_pct` 4 / 4 / 4; `double_item_chance` 3 / 3 / 3 |
**Unità equivalenti** (UE, solo per il bilanciamento): `node_units_pct` 1 per punto, `double_item_chance` 1 per punto, `node_rich_pct` 0,5 per punto (F-165:
un nodo ricco dà +50% di unità). Ogni testa Resa = **15 UE** a +9; Scure fine = 12 UE + sottoprodotto; Martello da cava = 9 + 6 = **15**; Amo fine = 9 UE + Frammenti;
Mazzo scelto = 6 + 9 = **15** (Falcetto: 6 UE da `node_rich_pct` 12 punti × 0,5 + 9 da doppio). Regola di test: nessuna testa fuori da [9, 15] UE e tutte le Resa = 15.
Esempi: Piccone +9, scelte `[Resa, Resa, Resa]` → `node_units_pct` 9 + 15 = **24**; `[Ricchezza ×3]` → `node_rich_pct` **+18**, `double_item_chance` **+6**, `node_units_pct` 9;
Piccone +5 con `heads = [Resa, "", ""]` → `node_units_pct` 5 + 5 = **10**, il passo +6 non conta; Accetta +9 `[Ricchezza ×3]` → `double_item_chance` **+12**, `byproduct_chance_pct` **+3**;
Piccone +2 → nessuna testa attiva anche se salvata. Test: `tests/systems/armory/test_tool_heads.gd`.

## F-198 Cambio di testa e unità del nodo
**Costo**: `respec_gold(T) = floor(tool_upgrade.levels[T−1].gold × tool_upgrade.respec_pct / 100)` con `respec_pct` 25 (T = passo 3, 6 o 9). La **prima** scelta di un passo
(`heads[i] = ""`) è gratuita; cambiare una scelta già fatta paga `respec_gold(T)`, senza componenti. Esempi: passo +3 → `floor(60.000 × 25 / 100)` = **15.000**; +6 → **125.000**;
+9 → **1.000.000**. Rifiuti in ordine: `unknown_id`, `not_a_tool`, `not_equippable` (leggendario), `invalid_step`, `head_locked` (`upgrade` < passo), `unknown_head`,
`head_unchanged`, `not_enough_gold`; atomico.
**Unità previste del nodo** (modifica F-162): `u = T(node_units_pct, ctx)` calcolato **all'inizio** del nodo (come la durata) e salvato in `node.ne`;
`Ne = floor(N × (100 + u) / 100)` per un nodo normale, `Ne = floor(N × (100 + u) × rich_units_pct / 10000)` per un ricco. Poi le unità per tentativo restano quelle di F-162.
Esempi (`N` 80, `A` 3, `y` 100): `u` 0 → `Ne` 80 → **26, 27, 27**; `u` 9 → `Ne` 87 → **29, 29, 29**; `u` 24 → `Ne` 99 → **33, 33, 33**; ricco con `u` 24 (`A` 5, 150%) → `Ne` **148**
→ **29, 30, 29, 30, 30**. Test: `tests/systems/encounters/test_attempts.gd` (esteso), `tests/systems/encounters/test_node_work.gd`.

## F-199 Probabilità di nodo ricco e di sottoprodotto; forma chiusa
- **Nodo ricco** (modifica F-164): `p = min(100, encounters.rich_chance_pct + T(node_rich_pct, ctx))`; **un** `roll_pct(p)` come oggi (la sequenza del generatore non cambia).
  Esempi: nessuna testa → **10**; Martello da cava completo → 10 + 18 = **28**; tetto 100.
- **Sottoprodotto** (modifica F-103, punto 25): chance `= mastery.milestones.byproduct_chance_pct (2,0) + T(byproduct_chance_pct, ctx)` (tetto 100). Esempio Scure fine completa:
  2,0 + 3 = **5,0**.
- **Forma chiusa** (modifica F-165): `mU = 1 + (p/100) × (rich_units_pct/100 − 1)` e `mM = 1 + (p/100) × (rich_ms_pct/100 − 1)` con `p` di sopra; le unità all'ora di `s` usano
  `N × (100 + u)/100`. Esempio: `p` 28 → `mU` = `mM` = **1,14**; Piccone +9 tutto Resa (`u` 24, `p` 10): unità per nodo medie `80 × 1,24 × 1,05` = **104,16** contro 84 oggi (**+24%**);
  tutto Ricchezza (`u` 9, `p` 28, doppio +6): `80 × 1,09 × 1,14` = **99,41** (+18%) più doppio (+6%) = **105,4** (≈ +25% UE): le due teste sono equivalenti entro 1-2 punti.
- **Bilanciamento** (`tools/sim_encounters.gd` esteso, ±5% su F-165): un Piccone +9 non deve superare **+30%** di unità/ora rispetto a +0 con la stessa disciplina, e le due
  teste non devono differire di oltre il **10%**.
Test: `tests/systems/encounters/test_node_work.gd`, `tests/systems/actions/test_gathering_resolver.gd`, `tools/sim_encounters.gd`.

## 9d. Chiavi di `balance.json` (M35), sezione `tool_upgrade` (le altre invariate)
| Chiave | Valore | Usata in |
|---|---|---|
| `tool_upgrade.units_per_level_pct` | 1 | F-196 |
| `tool_upgrade.head_steps` | `[3, 6, 9]` | F-197 |
| `tool_upgrade.respec_pct` | 25 | F-198 |
| `start.tools` | + `{"base": "unique_sickle"}` | §42.2 |
Le teste (`equip.heads`) stanno in `data/items/tools.json`, mai in `balance.json`.
