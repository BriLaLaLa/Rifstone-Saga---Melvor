# 04. Schema dei dati, §35: Attrezzi con teste e stat del nodo (M35-D; V44, `01_GDD_M35.md` §42, `02_FORMULAS_M35.md` F-195…F-199)

Estensione di `04_DATA_SCHEMA.md` (che supera le 400 righe): vale come la sua sezione **§35**. Regole generali di §0-§1 invariate (id `snake_case`, nessun campo sconosciuto,
nessun fallback silenzioso). Il validatore da estendere è `DataValidatorItems`/`data_validator_m10.gd` (attrezzi) e quello delle stat. I valori sono **di design** (tabelle di
F-196/F-197): i JSON ne sono la trascrizione (M35-02).

## 35.1 `data/items/tools.json`: `equip.heads` al posto di `equip.upgrade_extras`
Quattro attrezzi unici (`unique_hatchet`, `unique_pick`, `unique_rod`, **`unique_sickle`**). `upgrade_extras` è **vietato** (campo sconosciuto). Nuovo campo `equip.heads`
(obbligatorio per un attrezzo con `unique: true`):
```json
"equip": {"slot": "tool_quarrying", "grade": 1, "unique": true, "requirements": {},
  "modifiers": [{"stat": "skill_interval_pct", "value": -5, "scope": "skill:quarrying"}],
  "heads": [
    {"id": "pick_vein", "name": "Punta da filone", "description": "Più minerale da ogni filone.",
     "steps": [[{"stat": "node_units_pct", "value": 5}], [{"stat": "node_units_pct", "value": 5}], [{"stat": "node_units_pct", "value": 5}]]},
    {"id": "pick_quarry", "name": "Martello da cava", "description": "Più filoni ricchi e più doppi.",
     "steps": [[{"stat": "node_rich_pct", "value": 6}, {"stat": "double_item_chance", "value": 2}], [...], [...]]}
  ]}
```
- `heads`: esattamente **2** teste per attrezzo; `id` `snake_case` unico nel file; `name` e `description` non vuoti (italiano, originali, max 24 e 80 caratteri).
- `steps`: lista di **tanti elementi quanti `tool_upgrade.head_steps`** (3); ogni elemento è una lista **non vuota** di modificatori `{stat, value}`. Lo `scope` **non si scrive**:
  il caricatore lo imposta a `skill:<skill dell'attrezzo>` (`skill` dallo `slot`).
- Le `stat` ammesse: `node_units_pct`, `node_rich_pct`, `byproduct_chance_pct`, `double_item_chance`, `rift_shard_chance` (registro di §35.3). `value` > 0 e ≤ `max` della stat.
- Falcetto: `{"id":"unique_sickle","name":"Falcetto","category":"tool","icon":"res://assets/icons/items/unique_sickle.svg","value":0,"sort_order":40,"description":"L'attrezzo dell'Erborista: ogni raffinazione lo rende più generoso.","equip":{"slot":"tool_herbalism","grade":1,"unique":true,"requirements":{},"modifiers":[{"stat":"skill_interval_pct","value":-5,"scope":"skill:herbalism"}],"heads":[…]}}`.
  Icona segnaposto SVG in `assets/icons/items/`.
- **Valori** delle teste: tabella di F-197 (`02_FORMULAS_M35.md`), trascritta senza cambiarli. Nomi delle teste: Lama larga / Scure fine (`hatchet_wide`, `hatchet_fine`), Punta da filone /
  Martello da cava (`pick_vein`, `pick_quarry`), Rete / Amo fine (`rod_net`, `rod_hook`), Cesto / Mazzo scelto (`sickle_basket`, `sickle_bundle`).
- Regola del validatore (UE): nessuna testa fuori da 9…15 unità equivalenti (F-197); lo verifica un test, non il validatore.
- Un test conferma che nessun file contiene `upgrade_extras`.

## 35.2 `data/config/balance.json`
`tool_upgrade` guadagna `units_per_level_pct` (intero ≥ 0), `head_steps` (3 interi crescenti, ognuno in 1…9) e `respec_pct` (0…100); `start.tools` guadagna `unique_sickle`.
`interval_base_pct`, `interval_per_level_pct`, `levels`, `plate_items`, `handle_items` invariati. Validatore: i tre passi sono nei limiti di `levels`; ogni elemento di
`start.tools` è un attrezzo unico esistente.

## 35.3 `data/config/stats.json` (registro delle stat: un effetto, una formula, un test)
| `id` | `name` | `format` | `min` / `max` | `formula` | Test |
|---|---|---|---|---|---|
| `node_units_pct` | «Resa dei nodi» | `pct` | 0 / 200 | F-198 | `tests/systems/encounters/test_attempts.gd::test_node_units_pct` |
| `node_rich_pct` | «Nodi ricchi» | `pct` | 0 / 100 | F-199 | `tests/systems/encounters/test_node_work.gd::test_node_rich_pct` |
| `byproduct_chance_pct` | «Sottoprodotti» | `pct` | 0 / 100 | F-199 | `tests/systems/actions/test_gathering_resolver.gd::test_byproduct_chance_pct` |
Descrizioni: «Aumenta le unità raccolte in ogni nodo.», «Aumenta la probabilità che un nodo sia ricco.», «Aumenta la probabilità del sottoprodotto di una risorsa.».
Le stat esistenti `double_item_chance` e `rift_shard_chance` restano.

## 35.4 `data/guide/*.json` (M35-02)
Le pagine che parlano degli attrezzi (`mestieri.json`, `equipaggiamento.json`, `deposito.json`) citano i tre attrezzi e le raffinazioni: aggiornare a quattro attrezzi e alle
teste (testo breve a mano). Nessuna tabella nuova: la tabella dei passi legge `balance.json`.

## 35.5 Salvataggio (v12, additivo: `01_GDD_M35.md` §42.5)
Contratto in `05_INTERFACES_M35.md` §6h. Nessun dato in `data/`.
