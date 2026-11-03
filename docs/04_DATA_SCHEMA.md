# 04. Schema dei dati

Tutti i dati di gioco sono JSON UTF-8, indentati con 2 spazi, chiavi in inglese, sotto `res://data/`. Testi visibili
(`name`, `description`) in italiano. I file si caricano in classi `*Def` tipizzate (`res://core/data/defs/`), validate
da `DataValidator` (`res://core/data/data_validator.gd`). Un errore di validazione blocca l'ingresso in partita.

Regole comuni a tutti i tipi:
- `id`: `String`, `snake_case` inglese, regex `^[a-z][a-z0-9_]{1,47}$`, **unico nel suo tipo** (gli id degli oggetti sono
  unici tra tutti i file di `data/items/`). In memoria diventa `StringName`.
- I riferimenti (`item`, `skill`, `monster`, `requires`…) devono puntare a id esistenti.
- Livelli: interi 1..99. Durate: interi in ms > 0. Quantità: interi ≥ 1. Probabilità: float 0..100 (punti percentuali).
- Nessun campo sconosciuto (il validatore lo segnala come errore, per scovare refusi). Fa eccezione `_doc`, stringa di
  commento ammessa a qualunque livello e ignorata, anche dentro le mappe `{skill_id: livello}` (`requirements`,
  `requires.skills`); un `_doc` che non è una stringa è un campo sconosciuto.
- Nomi e testi originali: niente nomi di skill, oggetti, mostri, classi, tratti, affissi o valute presi da Melvor Idle,
  Metin2, Path of Exile o No Rest for the Wicked (clean room esteso, `DECISIONS_LOG.md` D1-D6).
- Requisiti di livello (`requirements`, `requires`): la chiave riservata `character` è il livello del personaggio.

## 1. Modificatore (oggetto annidato)

| Campo | Tipo | Vincoli | Default |
|---|---|---|---|
| `stat` | String | id presente in `stats.json` | obbligatorio |
| `value` | float | ≠ 0 | obbligatorio |
| `scope` | String | `global`, `skill:<skill_id>`, `action:<action_id>` (id esistenti) | `global` |

```json
{"stat": "skill_interval_pct", "value": -5, "scope": "skill:forestry"}
```
Classe: `Modifier` (`res://core/modifiers/modifier.gd`), `Modifier.from_dict(d)`.

## 2. `data/config/stats.json`

```json
{"stats": [
  {"id": "skill_interval_pct", "name": "Velocità delle azioni", "format": "pct", "min": -80, "max": 100,
   "description": "Riduce (se negativo) l'intervallo delle azioni.", "formula": "F-03",
   "test": "tests/systems/actions/test_action_math.gd::test_interval_uses_skill_interval_pct"}
]}
```
| Campo | Tipo | Vincoli |
|---|---|---|
| `id` | String | unico |
| `name` | String | etichetta UI, 1-40 caratteri |
| `format` | String | `pct` (mostrato con %), `flat`, `flag` (0/1, mostrato Sì/No) |
| `min`, `max` | float | `min < max`; limiti del **totale** (F-05) |
| `description` | String | effetto in una frase |
| `formula` | String | id `F-xx` esistente in `02_FORMULAS.md` (o sezione, es. `10.6`) |
| `test` | String | `percorso::funzione` di un test GUT; `test_stat_registry_coverage.gd` verifica che esista |

Contenuto iniziale: le 21 stat dell'MVP della tabella `02_FORMULAS.md` §11 (le 2 di M7/M8 si aggiungono in quelle milestone).
Classe: `StatRegistry` (`res://core/modifiers/stat_registry.gd`).

## 3. `data/config/balance.json`

Dizionario annidato; le chiavi e i valori sono quelli di `02_FORMULAS.md` §9. Accesso solo con
`GameData.balance_value("percorso.puntato")`; una chiave mancante è un errore di validazione (il validatore conosce
l'elenco delle chiavi obbligatorie, `DataValidator.REQUIRED_BALANCE_KEYS`).

```json
{
  "tick_ms": 100, "max_catchup_ms": 5000, "autosave_interval_ms": 10000,
  "slots": {"count": 4},
  "player_name": {"min_length": 1, "max_length": 24},
  "start": {"gold": 50, "items": []},
  "xp_curve": {"base": 70, "growth": 1.1, "linear": 8, "max_level": 99, "xp_cap": 50000000},
  "mastery_curve": {"base": 20, "growth": 1.1, "linear": 4, "max_level": 99},
  "mastery": {"base_factor": 1.0, "per_level": 0.1, "ratio_weight": 3.0, "pool_share_pct": 20, "pool_cap_per_item": 300000,
              "pool_warning_pct": 95},
  "action": {"min_interval_ms": 250},
  "gathering": {"rift_shard_base_chance_pct": 0.5},
  "bank": {"base_slots": 24, "slot_cost_base": 400, "slot_cost_growth": 1.09, "slot_cost_cap": 2000000},
  "combat": {
    "acc_level_offset": 8, "acc_bonus_offset": 50,
    "maxhit_level_offset": 10, "maxhit_bonus_offset": 40, "min_hit_ratio": 0.1,
    "hit_chance_min": 0.05, "hit_chance_max": 0.95,
    "triangle": {"advantage_damage_mult": 1.15, "disadvantage_damage_mult": 0.85, "defender_dr_mult": 0.75,
                 "beats": {"blade": "arcana", "arcana": "marksmanship", "marksmanship": "blade"}},
    "min_attack_interval_ms": 800,
    "unarmed": {"style": "blade", "attack_interval_ms": 2400},
    "hp_base": 50, "hp_per_level": 10,
    "dual_wield": {"interval_mult": 0.75},
    "max_pack_size": 6,
    "auto_eat_tiers": [null, {"threshold_pct": 30, "target_pct": 60},
                       {"threshold_pct": 40, "target_pct": 75}, {"threshold_pct": 50, "target_pct": 90}],
    "respawn_ms": 1500, "loot_bag_base_slots": 12
  },
  "character_curve": {"base": 70, "growth": 1.1, "linear": 8, "max_level": 99, "xp_cap": 50000000},
  "character": {"start_class": "rift_blade"},
  "armory": {"base_slots": 40, "slot_cost_base": 1000, "slot_cost_growth": 1.12, "slot_cost_cap": 2000000},
  "rarity": {
    "craft": {"magic_base_pct": 10, "magic_per_mastery_level": 0.4, "rare_base_pct": 1, "rare_per_mastery_level": 0.1},
    "affix_count": {"magic": [1, 2], "rare": [3, 4]}
  },
  "rift": {"sockets": [{"level": 1}, {"level": 20}, {"level": 40}, {"level": 60}, {"level": 80}]},
  "offline": {"cap_ms": 43200000, "min_ms": 60000, "chunk_ms": 60000}
}
```
Riforma di M4 (M4-01, D3): tolte `combat.hp_skill`, `combat.defence_skill`, `combat.hp_per_vitality`,
`combat.xp_per_damage_style`, `combat.xp_per_damage_vitality`. `character.start_class` deve essere l'id di una classe
di `data/classes/`. `rarity.affix_count.*` sono coppie `[min, max]` di interi 0..6 con min ≤ max.
`combat.dual_wield.interval_mult` > 0 e ≤ 1. `combat.max_pack_size` intero 1..6 (limite di formato del validatore).
Chiavi aggiunte dopo (dal task che le usa, `02_FORMULAS.md` §9): `traits`, `abilities` (M6); `rarity.drop`,
`rarity.rift_stone`, `upgrade`, `rift_stone`, `salvage` (M7); `sockets` (M8).
`start.items` è una lista di `{"item": id, "qty": n}`. `player_name.min_length` e `max_length` (lunghezza del nome dopo
`strip_edges`) sono interi ≥ 1 con `min_length` ≤ `max_length`. `mastery.pool_warning_pct` è un numero > 0 e ≤ 100
(percentuale del tetto del pool da cui la UI avvisa che il pool è quasi pieno). In M10 si aggiunge `fractures`, in M11 `parallel` (vedi §11, §12).

## 4. `data/skills/skills.json`

```json
{"skills": [
  {"id": "forestry", "name": "Selvicoltura", "category": "gathering", "order": 1,
   "icon": "res://assets/icons/skills/forestry.svg", "color": "#7fbf6a",
   "description": "Abbatti alberi per ottenere legni.",
   "has_mastery": true,
   "mastery_bonuses": [
     {"every_levels": 10, "modifiers": [{"stat": "double_item_chance", "value": 1}]},
     {"at_level": 99, "modifiers": [{"stat": "double_item_chance", "value": 5}]}
   ]}
]}
```
| Campo | Tipo | Vincoli |
|---|---|---|
| `id` | String | nei dati veri: i 7 id di `00_VISION.md` (lo controlla `tests/data/test_data_validity.gd`, non il validatore, così le fixture possono avere skill di prova). `character` è riservato (chiave dei requisiti del personaggio, §5): nessuna skill può chiamarsi così |
| `name`, `description` | String | |
| `category` | String | `gathering`, `artisan` (Legatura del Rift = `artisan`); `combat` non esiste più (M4-01, D3) |
| `order` | int | posizione nella sidebar, unico |
| `icon` | String | percorso `res://assets/icons/skills/…`, `.svg` o `.png` (se il file manca, icona segnaposto della UI) |
| `color` | String | `#rrggbb` |
| `has_mastery` | bool | |
| `mastery_bonuses` | array | solo se `has_mastery`; ogni regola ha **o** `every_levels` (1..99) **o** `at_level` (1..99) e `modifiers` (lo `scope` qui è ignorato: vale sempre `action:<azione>`) |

Classe: `SkillDef`.

## 5. `data/items/*.json`

File per categoria (`materials.json`, `equipment.json`, `tools.json`, `food.json`, `infusions.json`, `misc.json`),
ognuno `{"items": [...]}`. Campi comuni:

| Campo | Tipo | Vincoli |
|---|---|---|
| `id` | String | unico tra tutti i file |
| `name`, `description` | String | |
| `category` | String | `material`, `equipment`, `tool`, `food`, `infusion`, `misc`; deve corrispondere al file |
| `icon` | String | `res://assets/icons/items/…`, `.svg` o `.png` (i segnaposto di M1-12 sono SVG 64×64) |
| `value` | int ≥ 0 | oro dato dalla vendita (F-18); 0 = non vendibile |
| `sort_order` | int | ordinamento nella bank dentro la categoria |
| `equip` | object | obbligatorio per `equipment` e `tool`, vietato per gli altri |
| `food` | object | obbligatorio per `food`, vietato per gli altri |
| `infusion` | object | obbligatorio per `infusion`, vietato per gli altri |

`equip`:
| Campo | Tipo | Vincoli |
|---|---|---|
| `slot` | String | `head`, `body`, `legs`, `feet`, `hands`, `neck`, `ring`, `weapon`, `offhand`, `tool_forestry`, `tool_quarrying`, `tool_angling` (i `tool_*` solo per `category: tool`, e un `tool` solo negli slot `tool_*`) |
| `requirements` | object | `{skill_id | "character": livello}`, può essere vuoto. `equipment`: solo la chiave `character`; `tool`: solo la skill dello slot (`tool_<skill>`) |
| `modifiers` | array | modificatori (§1): i valori **base** del pezzo (la raffinazione li moltiplica, F-86; gli affissi si aggiungono, §15) |
| `grade` | int | obbligatorio, 1..8: grado del pezzo (affissi, raffinazione, smantellamento) |
| `kind` | String | obbligatorio per `slot: weapon` e `slot: offhand`, vietato per gli altri: `greatsword`, `sword`, `shield` (`greatsword`/`sword` solo con `weapon`, `shield` solo con `slot: offhand`). Una `sword` ha `slot: weapon` ma si può indossare anche nell'`offhand` se la classe lo ammette |
| `weapon` | object | obbligatorio con `slot: weapon`, vietato per gli altri: `style` (`blade`/`marksmanship`/`arcana`), `attack_interval_ms` (≥ 800), `two_handed` (bool; `true` se e solo se `kind: greatsword`) |

`food`: `{"heal": int ≥ 1}`. `infusion`: `{"modifiers": [...], "unique": bool}` (default `false`); `modifiers` ha almeno
1 modificatore (un'infusione senza effetto sarebbe decorativa).

Esempi:
```json
{"id": "redbirch_log", "name": "Legno di betulla rossa", "category": "material",
 "icon": "res://assets/icons/items/redbirch_log.svg", "value": 1, "sort_order": 10,
 "description": "Legno chiaro venato di rosso, comune nelle Pianure di Roccarossa."}
```
```json
{"id": "emberbronze_sword", "name": "Spada di bronzo di brace", "category": "equipment",
 "icon": "res://assets/icons/items/emberbronze_sword.png", "value": 14, "sort_order": 100,
 "description": "Una lama corta, ancora tiepida di forgia.",
 "equip": {"slot": "weapon", "kind": "sword", "grade": 1, "requirements": {"character": 1},
           "modifiers": [{"stat": "accuracy_bonus", "value": 8}, {"stat": "power_bonus", "value": 6}],
           "weapon": {"style": "blade", "attack_interval_ms": 2400, "two_handed": false}}}
```
```json
{"id": "emberbronze_hatchet", "name": "Accetta di bronzo di brace", "category": "tool",
 "icon": "res://assets/icons/items/emberbronze_hatchet.png", "value": 10, "sort_order": 10,
 "description": "Taglia più in fretta.",
 "equip": {"slot": "tool_forestry", "grade": 1, "requirements": {"forestry": 1},
           "modifiers": [{"stat": "skill_interval_pct", "value": -5, "scope": "skill:forestry"}]}}
```
```json
{"id": "seared_brookfin", "name": "Pinnarivo scottato", "category": "food", "value": 2, "sort_order": 10,
 "icon": "res://assets/icons/items/seared_brookfin.png", "description": "Cura 20 punti vita.", "food": {"heal": 20}}
```
```json
{"id": "inf_swift_hands", "name": "Infusione delle mani rapide", "category": "infusion", "value": 0, "sort_order": 10,
 "icon": "res://assets/icons/items/inf_swift_hands.png", "description": "Tutte le azioni sono un poco più rapide.",
 "infusion": {"modifiers": [{"stat": "skill_interval_pct", "value": -3}], "unique": false}}
```
L'oggetto `rift_shard` (categoria `misc`) è obbligatorio: lo usano F-07 e la Legatura del Rift.
Gli oggetti `equipment` e `tool` sono **basi**: nel gioco esistono solo come istanze dell'Armeria (`01_GDD.md` §21);
non entrano mai nella bank e non possono essere in `start.items`. Categorie aggiunte dopo: `stone`, `currency` (M8).
Classi: `ItemDef` (con `EquipInfo`, `WeaponInfo` come sotto-oggetti tipizzati nello stesso file), `ItemQty`.

## 6. `data/actions/<skill>.json`

Un file per ogni skill di raccolta o artigianato (7 file). Le azioni di raccolta non hanno `inputs`.

```json
{"skill": "forestry", "actions": [
  {"id": "cut_redbirch", "name": "Abbattere betulla rossa", "level": 1, "interval_ms": 3000, "xp": 10,
   "mastery": true, "inputs": [], "outputs": [{"item": "redbirch_log", "qty": 1}]}
]}
```
```json
{"skill": "forging", "actions": [
  {"id": "smelt_emberbronze", "name": "Fondere bronzo di brace", "level": 1, "interval_ms": 2000, "xp": 8,
   "mastery": true, "inputs": [{"item": "emberbronze_ore", "qty": 2}], "outputs": [{"item": "emberbronze_ingot", "qty": 1}]}
]}
```
| Campo | Tipo | Vincoli |
|---|---|---|
| `skill` | String | skill di categoria `gathering` o `artisan`; uguale al nome del file |
| `id` | String | unico tra tutte le azioni |
| `name` | String | |
| `level` | int | 1..99 |
| `interval_ms` | int | ≥ `action.min_interval_ms` |
| `xp` | int | ≥ 1 |
| `mastery` | bool | `true` per tutte le azioni dell'MVP (lo controlla `tests/data/test_data_validity.gd`, non il validatore: le fixture hanno un'azione `false`) |
| `inputs` | array di `{item, qty}` | vuoto per `gathering`, non vuoto per `artisan` |
| `outputs` | array di `{item, qty}` | almeno 1 |
| `icon` | String | facoltativo (default: icona del primo output) |

Classe: `ActionDef`.

## 7. `data/mastery/<skill>.json`

```json
{"skill": "forestry", "nodes": [
  {"id": "forestry_n1_quick_axe", "name": "Colpo sicuro", "description": "Azioni di Selvicoltura più rapide.",
   "cost_pct": 5, "requires": [], "pos": [1, 0],
   "modifiers": [{"stat": "skill_interval_pct", "value": -3, "scope": "skill:forestry"}]}
]}
```
| Campo | Tipo | Vincoli |
|---|---|---|
| `skill` | String | skill con `has_mastery: true` |
| `id` | String | unico tra tutti i nodi; prefisso `<skill>_` |
| `cost_pct` | float | 0 < x ≤ 50 |
| `requires` | array di id | nodi della stessa skill; nessun ciclo |
| `pos` | `[col, row]` | interi 0..5, posizione nell'albero della UI, unica nella skill |
| `modifiers` | array | se lo `scope` manca vale `skill:<skill>` |

Classe: `MasteryNodeDef`.

## 8. `data/combat/areas.json` e `monsters.json`

```json
{"areas": [
  {"id": "redrock_plains", "name": "Pianure di Roccarossa", "order": 1,
   "description": "Campi battuti dal vento ai piedi delle rocce rosse.",
   "requirements": {"character": 1},
   "packs": [{"weight": 4, "monsters": ["plains_boar"]},
             {"weight": 2, "monsters": ["ember_rat", "plains_boar"]}]}
]}
```
| Campo | Tipo | Vincoli |
|---|---|---|
| `id`, `name`, `description` | String | |
| `order` | int | unico |
| `requirements` | object | `{"character": livello}`, può essere vuoto |
| `packs` | array | almeno 1 gruppo (D5); ogni gruppo `{weight: int ≥ 1, monsters: array di id}` con 1..`combat.max_pack_size` mostri esistenti (ripetibili) |

`AreaDef.monster_ids` (mostri distinti dei gruppi, in ordine di prima comparsa) lo calcola `from_dict`. Il campo
`monsters` (M1-M3) non esiste più.

```json
{"monsters": [
  {"id": "plains_boar", "name": "Cinghiale delle pianure", "icon": "res://assets/icons/monsters/plains_boar.png",
   "description": "Testardo e affamato.",
   "hp": 20, "style": "blade", "attack_interval_ms": 2800,
   "attack_level": 1, "power_level": 1, "defence_level": 1,
   "accuracy_bonus": 0, "power_bonus": 0, "evasion_bonus": 0, "damage_reduction": 0,
   "gold": [1, 4], "rift_shard_chance": 0.5, "xp": 80,
   "drops": [{"item": "boar_tusk", "chance_pct": 25, "qty": [1, 1]}]}
]}
```
| Campo | Tipo | Vincoli |
|---|---|---|
| `hp` | int | ≥ 1 |
| `xp` | int | ≥ 0, XP del personaggio per uccisione (F-28) |
| `style` | String | `blade`, `marksmanship`, `arcana` |
| `attack_interval_ms` | int | ≥ `combat.min_attack_interval_ms` |
| `attack_level`, `power_level`, `defence_level` | int | 1..99 |
| `accuracy_bonus`, `power_bonus`, `evasion_bonus` | int | ≥ 0 |
| `damage_reduction` | float | 0..80 |
| `gold` | `[min, max]` | 0 ≤ min ≤ max |
| `rift_shard_chance` | float | 0..100 |
| `drops` | array | `{item, chance_pct 0..100, qty [min ≥ 1, max ≥ min]}`, max 4 voci; voci `equipment` e `tool` vietate fino a M7 (da M7 i pezzi cadono come istanze, F-84) |

Classi: `AreaDef`, `PackDef`, `MonsterDef`, `DropEntry`. Icone dei mostri in `res://assets/icons/monsters/`.
Fino a M5-04 i due file esistono vuoti (`{"_doc": …, "areas": []}`, `{"_doc": …, "monsters": []}`, creati da M1-12); lo schema con `packs` e `xp` è di M4-01.
In M7 si aggiunge `data/combat/rift_stones.json` (§16).

## 9. `data/shop/shop.json`

```json
{"entries": [
  {"id": "bank_slot", "name": "Casella della bank", "category": "bank",
   "description": "Una casella in più nella bank.",
   "cost": {"formula": "bank_slot"}, "max_purchases": 150,
   "requires": {}, "effect": {"modifiers": [{"stat": "bank_slots", "value": 1}]}},
  {"id": "auto_eat_2", "name": "Razioni da campo II", "category": "combat",
   "description": "Mangia prima e più a lungo.",
   "cost": {"gold": 25000}, "max_purchases": 1,
   "requires": {"entries": ["auto_eat_1"], "character": 25},
   "effect": {"modifiers": [{"stat": "auto_eat_tier", "value": 1}]}},
  {"id": "novice_hatchet", "name": "Accetta del novizio", "category": "tools",
   "description": "Un'accetta semplice.", "cost": {"gold": 150}, "max_purchases": 0,
   "requires": {}, "effect": {"item": {"item": "novice_hatchet", "qty": 1}}}
]}
```
| Campo | Tipo | Vincoli |
|---|---|---|
| `category` | String | `bank`, `combat`, `tools`, `materials`, `lanes` (ammessa dal validatore solo da M11) |
| `cost` | object | **o** `{"gold": int ≥ 1}` **o** `{"formula": "bank_slot"}` (F-17) **o** `{"formula": "armory_slot"}` (F-82); nessun'altra formula nell'MVP |
| `max_purchases` | int | ≥ 0; 0 = illimitato (solo per effetti `item`) |
| `requires` | object | facoltativi `entries` (id dello shop), `character` (int 1..99), `skills` (`{skill: livello}`), `total_level` (int ≥ 0) |
| `effect` | object | **o** `modifiers` **o** `item` (`{item, qty}`); un `item` `equipment`/`tool` crea `qty` istanze comuni nell'Armeria |

Classe: `ShopEntryDef`. Fino a M3-04 il file esiste vuoto (`{"_doc": …, "entries": []}`, creato da M1-12).

## 10. `data/hints/hints.json` (M9)

```json
{"hints": [{"id": "first_action", "title": "Il primo passo", "text": "Scegli un'azione e premi Avvia.",
            "trigger": "session_started_new"}]}
```
`trigger`: uno di `session_started_new`, `bank_full`, `first_shard`, `mastery_node_affordable`, `player_died`,
`first_level_10`. Classe: `HintDef` (aggiunta in M9 in `core/data/defs/hint_def.gd`).

## 11. `data/fractures/fractures.json` (M10)

```json
{"fractures": [{"id": "verdant_rift", "name": "Frattura verdeggiante", "description": "Il legno cresce più in fretta.",
                "weight": 10, "modifiers": [{"stat": "skill_xp_pct", "value": 25, "scope": "skill:forestry"}],
                "bonus_monster": null}]}
```
`weight` int ≥ 1 (estrazione pesata); `bonus_monster`: `null` o `{"area": id, "monster": id}`.
`balance.json` riceve `"fractures": {"interval_min_ms": 7200000, "interval_max_ms": 14400000, "duration_ms": 1800000}`.
Classe: `FractureDef`.

## 12. Aggiunte di M11

`balance.json`: `"parallel": {"interval_penalty_pct": 40}`; `stats.json`: `parallel_lanes`; `shop.json`: `second_thought`.

## 13. Dati di test (`res://tests/fixtures/data/`)

Stessa struttura di `res://data/`, contenuto minimo e **stabile** (i test non dipendono dal contenuto vero):
2 skill di raccolta (`test_gather`, `test_gather_b`), 1 di artigianato (`test_craft`), `riftbinding` (nessuna skill di
combattimento da M4-01); 4 azioni, gli oggetti di prova (incluso `rift_shard`; pezzi con `kind` `sword`, `greatsword`,
`shield` e un attrezzo), 1 area con 2 mostri in 2 gruppi, 4 voci dello shop, 3 nodi di maestria, 2 classi
(`test_class` con i 4 assetti di `rift_blade`, e una copia di `rift_blade`, richiesta da `character.start_class` del
`balance.json` vero) e `affixes/affixes.json` con almeno 4 affissi (uno per attrezzi).
La cartella delle fixture **non** contiene `config/`: `TestFactory` carica il contenuto dalle fixture e `balance.json`/
`stats.json` da `res://data/config/` con `GameData.load_from_dirs(content_root, config_root)`. Così parametri e stat
restano definiti in un solo posto.

## 14. `data/classes/<id>.json` (M4; tratti e abilità da M6)

Un file per classe (D2). Nell'MVP solo `rift_blade.json`.
```json
{"id": "rift_blade", "name": "Lama del Rift", "order": 1,
 "description": "Combatte solo con le spade, in tre assetti.",
 "weapon_kinds": ["greatsword", "sword"], "offhand_kinds": ["shield", "sword"],
 "setups": [
   {"id": "greatsword", "name": "Spadone", "weapon": "greatsword", "offhand": "", "modifiers": []},
   {"id": "sword_shield", "name": "Spada e scudo", "weapon": "sword", "offhand": "shield", "modifiers": []},
   {"id": "dual_swords", "name": "Due spade", "weapon": "sword", "offhand": "sword", "alternate": true,
    "modifiers": [{"stat": "accuracy_pct", "value": -10}]},
   {"id": "sword", "name": "Spada", "weapon": "sword", "offhand": "", "modifiers": []}
 ],
 "traits": [], "abilities": []}
```
| Campo | Tipo | Vincoli |
|---|---|---|
| `id`, `name`, `description` | String | `id` uguale al nome del file |
| `order` | int | unico |
| `weapon_kinds`, `offhand_kinds` | array di String | valori di `equip.kind` (§5); `weapon_kinds` non vuoto |
| `setups` | array | almeno 1; `id` unico nella classe e diverso da `unarmed` (riservato, F-72); `weapon` in `weapon_kinds`; `offhand` `""` o in `offhand_kinds`; coppia (`weapon`, `offhand`) unica; `alternate` bool (default `false`, ammesso solo se `offhand` è un tipo d'arma); `modifiers` (§1, scope `global`) |
| `traits` | array | da M6 (sotto); in M4 vuoto |
| `abilities` | array | da M6 (sotto); in M4 vuoto |

Tratto (M6):
```json
{"id": "chain_cleave", "name": "Fendente a catena", "description": "Ogni terzo attacco colpisce tutti i nemici.",
 "unlock_level": 5, "setups": [],
 "effects": [{"type": "every_nth_attack_all", "params": {"n": 3}}], "modifiers": []}
```
`unlock_level` 1..99; `setups` id della classe (vuoto = tutti); `effects` **almeno 1** (un tratto di soli modificatori
è vietato), `type` tra quelli di F-81 con i parametri della tabella (tipi e intervalli controllati dal validatore);
`modifiers` facoltativi (sorgente `trait:<id>`).

Abilità (M6):
```json
{"id": "whirl", "name": "Mulinello", "description": "Un giro di spadone che colpisce tutti.",
 "unlock_level": 1, "setups": ["greatsword"], "kind": "cleave", "cooldown_ms": 9000,
 "params": {"power_mult": 1.2, "targets": 0}}
```
`kind`: `strike` (`power_mult` > 0), `cleave` (`power_mult` > 0, `targets` int ≥ 0, 0 = tutti), `heal`
(`heal_pct` 1..100), `buff` (`modifiers` almeno 1, `duration_ms` ≥ 1000); `cooldown_ms` ≥ `combat.min_attack_interval_ms`.
I nomi provvisori dei tratti di `VISIONE_V2.md` §3.3 si possono usare o sostituire (originali). Classi: `ClassDef`,
`SetupDef`, `TraitDef`, `TraitEffectDef`, `AbilityDef`.

## 15. `data/affixes/affixes.json` (M4)

```json
{"affixes": [
  {"id": "keen", "name": "Affilato", "stat": "accuracy_bonus", "slots": ["weapon", "offhand"], "weight": 10,
   "tiers": [{"min_ilvl": 1, "min": 3, "max": 6}, {"min_ilvl": 20, "min": 7, "max": 12},
             {"min_ilvl": 45, "min": 13, "max": 20}]},
  {"id": "woodsman", "name": "del Boscaiolo", "stat": "skill_interval_pct", "slots": ["tool_forestry"], "weight": 10,
   "tiers": [{"min_ilvl": 1, "min": -2, "max": -1}]}
]}
```
| Campo | Tipo | Vincoli |
|---|---|---|
| `id`, `name` | String | `name` è il testo mostrato sul pezzo |
| `stat` | String | stat di `stats.json` (nessuna stat decorativa) |
| `slots` | array | slot di §5 (almeno 1); con un `tool_<skill>` lo scope del modificatore è `skill:<skill>`, altrimenti `global` |
| `weight` | int | ≥ 1 (F-85) |
| `tiers` | array | almeno 1, `min_ilvl` crescente 1..99; `min ≤ max`; `step` facoltativo > 0 (default 1) con `(max − min)` multiplo di `step` |

Classi: `AffixDef`, `AffixTier`. Nell'MVP ogni slot d'equipaggiamento ha almeno 4 affissi ammessi (un raro ne chiede 4).

## 16. Aggiunte di M7 (bottino)

- `data/items/equipment.json`: anelli (`neck`/`ring` con `grade`, requisito `character`) solo da drop (Q30).
- `data/combat/rift_stones.json`: `{"rift_stones": [{"id", "name", "description", "icon", "area", "hp", "xp",
  "pulse_damage", "pulse_ms", "summon_pack" (indice di `packs` dell'area o `null`), "shards": [min, max], "drops": [...]}]}`,
  una per area (F-87).
- `data/items/materials.json`: Sigillo di salvaguardia (`upgrade.seal_item`).
- `balance.json`: `rarity.drop`, `rarity.rift_stone`, `upgrade`, `rift_stone`, `salvage`; `stats.json`: `upgrade_success_pct`.

## 17. Aggiunte di M8 (Legatura)

Categorie di oggetti `stone` (`{"stone": {"modifiers": [...]}}`, almeno 1 modificatore) e `currency`
(`{"currency": {"effect": "to_magic" | "to_rare" | "reroll"}}`) nei file `stones.json` e `currencies.json`;
`balance.json`: `sockets`. Ricette di `riftbinding.json` per infusioni, pietre e valute.
