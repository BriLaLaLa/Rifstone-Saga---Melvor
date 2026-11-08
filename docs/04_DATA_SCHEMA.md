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
  "start": {"gold": 50, "items": [{"item": "seared_brookfin", "qty": 20}],
            "armory": [{"base": "<spada T1>", "equip": "weapon"}, {"base": "<spadone T1>", "equip": ""}, {"base": "<scudo T1>", "equip": "offhand"}],
            "tools": [{"base": "<accetta>"}, {"base": "<piccone>"}, {"base": "<canna>"}],
            "purchases": {"auto_eat_1": 1}, "food": "seared_brookfin"},
  "xp_curve": {"base": 70, "growth": 1.1, "linear": 8, "max_level": 99, "xp_cap": 50000000},
  "mastery_curve": {"base": 20, "growth": 1.1, "linear": 4, "max_level": 99},
  "mastery": {"base_factor": 1.0, "per_level": 0.1, "ratio_weight": 3.0, "pool_share_pct": 20, "pool_cap_per_item": 300000,
              "pool_warning_pct": 95,
              "milestones": {"byproduct_at": 25, "resource_at": 50, "trade_at": 99, "byproduct_chance_pct": 2.0}},
  "action": {"min_interval_ms": 250},
  "gathering": {"rift_shard_base_chance_pct": 0.5},
  "deposit": {"base_slots": 60, "bag_slots": 6},
  "helper": {"xp_pct": 25, "mastery_pct": 25,
             "grades": [{"id": "apprentice", "interval_mult": 3.0}, {"id": "journeyman", "interval_mult": 2.5},
                        {"id": "expert", "interval_mult": 2.0}, {"id": "master", "interval_mult": 1.5}]},
  "engraver": {"crystal_chance_min_pct": 40, "crystal_chance_max_pct": 90, "crystal_fail_loss_pct": 50, "merge_ratio": 3},
  "rune": {"upgrade_ratio": 3, "grade_mult": [1, 2, 3, 4, 5]},
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
    "respawn_ms": 1500, "loot_bag_base_slots": 12,
    "kill_xp_mult": 0.15
  },
  "character_curve": {"base": 70, "growth": 1.1, "linear": 8, "max_level": 99, "xp_cap": 50000000},
  "character": {"start_class": "rift_blade"},
  "rarity": {
    "affix_count": {"magic": [1, 2], "rare": [3, 4]}
  },
  "blueprint": {"duration_base_min": 10, "duration_per_grade_min": 7, "xp_mult": 1.5, "rare_base_pct": 10,
                "rare_per_forging_level": 0.5, "choose_affix_level": 50, "chosen_affix_tier": 2},
  "tool_upgrade": {"interval_base_pct": 5, "interval_per_level_pct": 2,
                   "levels": [{"min_level": 1, "grade": 1, "plates": 2, "handles": 1, "gold": 100}],
                   "plate_items": ["<8 id>"], "handle_items": ["<8 id>"]},
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
**Riforma M10 (R1-R3, B1-B2)**: `start` si estende (sotto); `rarity.craft` **tolta**; aggiunte `blueprint`, `tool_upgrade` e
`combat.kill_xp_mult` (> 0, ≤ 1, B1); `salvage.ingot_ratio` diventa `salvage.component_ratio`. Nell'esempio sopra `<…>` sta per
l'id della base nei dati. Regole del validatore: `start.armory[].base` è una base `equipment` di grado 1 (rarità comune,
senza affissi), `equip` è uno slot compatibile con la base o `""`; `start.tools[].base` è un attrezzo unico (uno per slot
`tool_*`, tutti e tre); `start.purchases` è `{id voce dello shop: n ≤ max_purchases}`; `start.food` è un cibo presente in
`start.items`; `blueprint.*` numeri positivi, `chosen_affix_tier` ≥ 1, `choose_affix_level` 1..99; `tool_upgrade.levels` ha
esattamente 9 voci con `min_level` crescente (1..99), `grade` 1..8 non decrescente, `plates`, `handles` ≥ 1, `gold` ≥ 1;
`plate_items` e `handle_items` hanno 8 id di oggetti `component` (uno per grado).
`start.items` è una lista di `{"item": id, "qty": n}`. `player_name.min_length` e `max_length` (lunghezza del nome dopo
`strip_edges`) sono interi ≥ 1 con `min_length` ≤ `max_length`. `mastery.pool_warning_pct` è un numero > 0 e ≤ 100
(percentuale del tetto del pool da cui la UI avvisa che il pool è quasi pieno). In M13 si aggiungerà `fractures` (vedi §11). Le corsie parallele (`parallel`) non esistono più (§12).
**Riforma 2 (M12, W1-W7)**: tolte le chiavi `bank` e `armory`; aggiunte `deposit`, `helper`, `engraver`, `rune` e `mastery.milestones` (esempio sopra; valori e formule in `02_FORMULAS.md` §9, F-100…F-108). Regole del validatore: `deposit.base_slots` ≥ 1, `deposit.bag_slots` 1..12; `helper.grades` ha **4 voci** in ordine di grado con `interval_mult` ≥ 1 non crescente (i più lenti per primi) e `id` unici; `helper.xp_pct` e `helper.mastery_pct` 1..100; **invariante** `3 × helper.xp_pct / (100 × min interval_mult) ≤ 1` (F-102); `mastery.milestones.byproduct_at < resource_at < trade_at` (1..99), `byproduct_chance_pct` 0..100; `engraver.crystal_chance_min_pct ≤ crystal_chance_max_pct` (0..100), `crystal_fail_loss_pct` 0..100, `merge_ratio` ≥ 2; `rune.upgrade_ratio` ≥ 2, `rune.grade_mult` ha 5 numeri > 0, crescente, il primo è 1.

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
| `level_modifiers` | array | facoltativo (M10, F-93): `[{"stat": id, "per_level": numero > 0}]`; valore = `per_level × livello della skill`, modificatore globale con sorgente `skill_level:<skill>`, ricostruito a ogni `level_up` e dopo il caricamento. Oggi solo `forging` con `upgrade_success_pct` 0,4. La stat deve essere nel registro |
| `mastery_bonuses` | array | solo se `has_mastery`; **dal M12 vietato per le skill `gathering`** (la raccolta usa i `milestones` delle azioni, §6); ogni regola ha **o** `every_levels` (1..99) **o** `at_level` (1..99) e `modifiers` (lo `scope` qui è ignorato: vale sempre `action:<azione>`) |

Classe: `SkillDef`.

## 5. `data/items/*.json`

File per categoria (`materials.json`, `components.json` (M10), `blueprints.json` (M10), `equipment.json`, `tools.json`, `food.json`, `infusions.json`, `misc.json`, `bags.json` (M12), `contracts.json` (M12)),
ognuno `{"items": [...]}`. Campi comuni:

| Campo | Tipo | Vincoli |
|---|---|---|
| `id` | String | unico tra tutti i file |
| `name`, `description` | String | |
| `category` | String | `material`, `component` (M10), `blueprint` (M10), `equipment`, `tool`, `food`, `infusion`, `misc`, `bag` (M12), `contract` (M12); deve corrispondere al file |
| `icon` | String | `res://assets/icons/items/…`, `.svg` o `.png` (i segnaposto di M1-12 sono SVG 64×64) |
| `value` | int ≥ 0 | oro dato dalla vendita (F-18); 0 = non vendibile |
| `sort_order` | int | ordinamento nella bank dentro la categoria |
| `equip` | object | obbligatorio per `equipment` e `tool`, vietato per gli altri |
| `food` | object | obbligatorio per `food`, vietato per gli altri |
| `infusion` | object | obbligatorio per `infusion`, vietato per gli altri |
| `blueprint` | object | obbligatorio per `blueprint`, vietato per gli altri (M10, sotto) |
| `bag` | object | obbligatorio per `bag`, vietato per gli altri (M12): `{"slots": int 1..100}` |
| `contract` | object | obbligatorio per `contract`, vietato per gli altri (M12): `{"skill": id di una skill gathering, "grade": id di helper.grades}` |

`equip`:
| Campo | Tipo | Vincoli |
|---|---|---|
| `unique` | bool | facoltativo, solo `category: tool` (M10, R3): **obbligatorio** `true` per tutti gli attrezzi; vedi sotto |
| `slot` | String | `head`, `body`, `legs`, `feet`, `hands`, `neck`, `ring`, `weapon`, `offhand`, `tool_forestry`, `tool_quarrying`, `tool_angling` (i `tool_*` solo per `category: tool`, e un `tool` solo negli slot `tool_*`) |
| `requirements` | object | `{skill_id | "character": livello}`, può essere vuoto. `equipment`: solo la chiave `character`; `tool`: solo la skill dello slot (`tool_<skill>`) |
| `modifiers` | array | modificatori (§1): i valori **base** del pezzo (la raffinazione li moltiplica, F-86; gli affissi si aggiungono, §15) |
| `grade` | int | obbligatorio, 1..8: grado del pezzo (affissi, raffinazione, smantellamento) |
| `kind` | String | obbligatorio per `slot: weapon` e `slot: offhand`, vietato per gli altri: `greatsword`, `sword`, `shield` (`greatsword`/`sword` solo con `weapon`, `shield` solo con `slot: offhand`). Una `sword` ha `slot: weapon` ma si può indossare anche nell'`offhand` se la classe lo ammette |
| `weapon` | object | obbligatorio con `slot: weapon`, vietato per gli altri: `style` (`blade`/`marksmanship`/`arcana`), `attack_interval_ms` (≥ 800), `two_handed` (bool; `true` se e solo se `kind: greatsword`) |

`food`: `{"heal": int ≥ 1}`. `infusion`: `{"modifiers": [...], "unique": bool, "grade": 1..5, "family": id}` (`unique` default `false`; `grade` default 1,
M12); `modifiers` ha almeno 1 modificatore (una runa senza effetto sarebbe decorativa). **Gradi delle rune (M12, F-107)**: la runa di grado I
ha `family` uguale al proprio `id`; le rune di grado 2-5 hanno `family` = id della runa di grado I, id `<family>_<grado>` e ogni
`value` = `value` di grado I × `rune.grade_mult[grado−1]` (lo controlla il validatore); 5 oggetti per famiglia, nessun grado mancante.
**Borse e contratti (M12)**: una `bag` ha `value` 0 e `slots` ≥ 1 (F-100); si può mettere in uno slot borsa. Un `contract` ha `value` 0, ed esiste
**uno per ogni coppia** (mestiere di raccolta, grado): 3 × 4 = 12 oggetti, id `contract_<skill>_<grade>`. Il sottoprodotto di un traguardo
(`milestones`) è un `material`. Pietre e valute (categorie `stone`, `currency`) restano con id `stone_<famiglia>_<chip|stone|heart>` e
`currency_*`: cambiano solo i nomi (`NOMI.md`); `rift_dust` (Polvere del Rift) e `rune_slab` (Lastra runica) sono `material`.

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
{"id": "<accetta>", "name": "Accetta", "category": "tool",
 "icon": "res://assets/icons/items/<accetta>.svg", "value": 0, "sort_order": 10,
 "description": "Taglia più in fretta ad ogni potenziamento.",
 "equip": {"slot": "tool_forestry", "grade": 1, "unique": true, "requirements": {},
           "modifiers": [{"stat": "skill_interval_pct", "value": -5, "scope": "skill:forestry"}],
           "upgrade_extras": [{"at": 5, "modifiers": [{"stat": "double_item_chance", "value": 2, "scope": "skill:forestry"}]},
                              {"at": 9, "modifiers": [{"stat": "double_item_chance", "value": 3, "scope": "skill:forestry"}]}]}}
```
```json
{"id": "seared_brookfin", "name": "Pinnarivo scottato", "category": "food", "value": 2, "sort_order": 10,
 "icon": "res://assets/icons/items/seared_brookfin.png", "description": "Cura 20 punti vita.", "food": {"heal": 20}}
```
```json
{"id": "inf_swift_hands", "name": "Runa delle mani rapide", "category": "infusion", "value": 0, "sort_order": 10,
 "icon": "res://assets/icons/items/inf_swift_hands.png", "description": "Tutte le azioni sono un poco più rapide.",
 "infusion": {"modifiers": [{"stat": "skill_interval_pct", "value": -3}], "unique": false}}
```
**Componenti e progetti (M10)**: la categoria `component` è un oggetto di bank (come `material`, ma separata nella UI) per piastre,
impugnature, telai degli scudi e manici di grado 1-8; i lingotti restano `material`. Un `blueprint` ha `blueprint`:
`{"base": id di una base equipment, "grade": 1..8, "inputs": [{item, qty}] (componenti di grado, almeno 1),
"rare_component": {item, qty}}` (`rare_component.item` è un `material` di drop di un mostro). Il validatore controlla: `base`
esiste, è `equipment` (non `tool`, non anello/amuleto) e ha lo stesso `grade`; `inputs` sono `component` o `material` esistenti;
**una sola** `blueprint` per base; `value` 0 (non vendibile). Esempio:
```json
{"id": "bp_claymore", "name": "Progetto: Claymore", "category": "blueprint", "value": 0, "sort_order": 10,
 "icon": "res://assets/icons/items/bp_claymore.svg", "description": "Lo schema di una Claymore.",
 "blueprint": {"base": "<spadone T4>", "grade": 4, "inputs": [{"item": "<piastra T4>", "qty": 10}, {"item": "<impugnatura T4>", "qty": 2}],
               "rare_component": {"item": "<componente raro>", "qty": 3}}}
```
**Attrezzi unici (M10, R3)**: ogni base `tool` ha `equip.unique: true`, `equip.modifiers` = i valori a +0 (`skill_interval_pct`
−5 con scope della skill) e facoltativo `equip.upgrade_extras`: `[{"at": 1..9, "modifiers": [...]}]` (bonus cumulativi dal passo `at`,
F-94). Ci sono **esattamente tre** attrezzi (uno per slot `tool_*`), `value` 0, `grade` 1, nessun `requirements`. Le 27 basi a gradi
e le loro ricette sono eliminate (id nuovi per i tre attrezzi; gli altri id restano, Q52).

L'oggetto `rift_shard` (categoria `misc`) è obbligatorio: lo usano F-07 e la Legatura del Rift.
Gli oggetti `equipment` e `tool` sono **basi**: nel gioco esistono solo come istanze dell'Armeria (`01_GDD.md` §21);
non entrano mai nella bank e non possono essere in `start.items` (il kit usa `start.armory` e `start.tools`). Categorie aggiunte dopo: `stone`, `currency` (M8).
Classi: `ItemDef` (con `EquipInfo`, `WeaponInfo` come sotto-oggetti tipizzati nello stesso file), `ItemQty`.

## 6. `data/actions/<skill>.json`

Un file per ogni skill di raccolta o artigianato (7 file). Le azioni di raccolta non hanno `inputs`.

```json
{"skill": "forestry", "actions": [
  {"id": "cut_redbirch", "name": "Betulla rossa", "level": 1, "interval_ms": 3000, "xp": 10,
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
| `kind` | String | facoltativo (M12), solo `riftbinding`: `craft` (default) o `crystallize` (F-104: `inputs` = una sola voce Polvere del Rift, `outputs` = un solo Cristallo `currency`, `mastery: true`). Il tiro usa il livello dell'Incisore |
| `milestones` | array | **obbligatorio** per le azioni `gathering` (M12), vietato per le altre: esattamente 3 voci nell'ordine 25, 50, 99 (sotto) |
| `single` | bool | facoltativo (M10), solo `forging`: **azione a ciclo unico**. Vale `false` se assente. Con `single: true` `inputs` e `outputs` possono essere vuoti, `mastery` è `false`, e durata, XP, materiali e prodotto vengono dal progetto scelto (F-90), non dall'azione: `interval_ms` (≥ `action.min_interval_ms`) e `xp` (≥ 1) sono segnaposto. Alla fine l'azione si ferma da sola (`blueprint_done`). Nei dati veri ce n'è una: `blueprint_craft` in `forging.json` (livello 1, il livello vero è quello del grado) |

**Traguardi (`milestones`, M12, F-103, F-108)**: `[{"at": 25, "type": "byproduct", "item": id di un material}, {"at": 50, "type": "resource", "modifiers": [...]},
{"at": 99, "type": "trade", "modifiers": [...]}]`. `at` deve essere uguale a `mastery.milestones.byproduct_at` / `resource_at` / `trade_at`;
`modifiers` ha almeno 1 modificatore; lo `scope` dei `resource` vale `action:<id>` se manca, quello dei `trade` `skill:<skill>` (altri scope sono un errore).
Esempio: `{"id": "cut_redbirch", …, "milestones": [{"at": 25, "type": "byproduct", "item": "<sottoprodotto>"}, {"at": 50, "type": "resource",
"modifiers": [{"stat": "skill_interval_pct", "value": -8}]}, {"at": 99, "type": "trade", "modifiers": [{"stat": "skill_interval_pct", "value": -0.5}]}]}`.
Nota: i sottoprodotti sono 24 `material` diversi (uno per risorsa). **Incisore (M12)**: le azioni di `riftbinding.json` sono quelle di `02_FORMULAS.md` §8.7
(Lastra, `fuse_*`, `crystallize_*`, `engrave_*`, `upgrade_*`); ogni `fuse_*` ha la quantità degli ingredienti = `engraver.merge_ratio` e ogni `upgrade_*`
= `rune.upgrade_ratio` (validatore); le ricette di Legatura precedenti (`bind_*`) sono eliminate.
Classe: `ActionDef` (con `MilestoneDef`).

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
**M12 (W4, Q26 chiusa)**: i file dei tre mestieri di raccolta hanno alberi **diversi** (`02_FORMULAS.md` §8.8b): il validatore rifiuta due
alberi di raccolta in cui meno di 3 nodi su 6 differiscono per l'insieme `(stat, value)`; costo totale per albero 55-65%.

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
| `loot_tables` | array di id | facoltativo (M12): tabelle di `loot_tables.json` (§8b) che valgono per ogni mostro dell'area; ogni id esiste |
| `rift_stone_chance_pct` | float | facoltativo, 0..100: probabilità della Pietra del Rift dopo ogni uccisione in quest'area (F-87, Q46); assente = `rift_stone.chance_pct` di `balance.json`. La garanzia `rift_stone.pity_kills` resta globale |

`AreaDef.monster_ids` (mostri distinti dei gruppi, in ordine di prima comparsa) lo calcola `from_dict`. Il campo
`monsters` (M1-M3) non esiste più.

```json
{"monsters": [
  {"id": "plains_boar", "name": "Cinghiale delle pianure", "icon": "res://assets/icons/monsters/plains_boar.svg",
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
| `icon` | String | obbligatorio, `res://assets/icons/monsters/…`, `.svg` o `.png`; il file deve esistere (validato come le icone degli oggetti; M6-00a) |
| `sprite` | object | facoltativo, **riservato** (nessun uso): `{idle, attack, hit, death}` con percorsi `res://assets/…`; solo schema e validatore |
| `hp` | int | ≥ 1 |
| `xp` | int | ≥ 0, XP del personaggio per uccisione (F-28) |
| `style` | String | `blade`, `marksmanship`, `arcana` |
| `attack_interval_ms` | int | ≥ `combat.min_attack_interval_ms` |
| `attack_level`, `power_level`, `defence_level` | int | 1..99 |
| `accuracy_bonus`, `power_bonus`, `evasion_bonus` | int | ≥ 0 |
| `damage_reduction` | float | 0..80 |
| `gold` | `[min, max]` | 0 ≤ min ≤ max |
| `rift_shard_chance` | float | 0..100 |
| `loot_tables` | array di id | facoltativo (M12): tabelle di `loot_tables.json` (§8b) in aggiunta ai `drops`; ogni id esiste |
| `drops` | array | `{item, chance_pct 0..100, qty [min ≥ 1, max ≥ min]}`, max 8 voci (M10: alzato da 4 per ospitare i 64 progetti, `chance_pct` dei progetti anche sotto 1%, min 0,05); voci `blueprint` ammesse da M10 (cadono nella borsa del bottino come oggetti di bank, `qty` [1, 1]); voci `equipment` ammesse da M7 (`tool` non cade più dall'M10, gli attrezzi sono unici): cadono come istanze con rarità F-84 e affissi F-85 (`ilvl` = massimo dei tre livelli del mostro), `qty` = numero di istanze |

Classi: `AreaDef`, `PackDef`, `MonsterDef`, `DropEntry`. Icone dei mostri in `res://assets/icons/monsters/`.
Fino a M5-04 i due file esistono vuoti (`{"_doc": …, "areas": []}`, `{"_doc": …, "monsters": []}`, creati da M1-12); lo schema con `packs` e `xp` è di M4-01.
In M7 si aggiunge `data/combat/rift_stones.json` (§16).

### 8b. `data/combat/loot_tables.json` (M12, W6)

```json
{"tables": [
  {"id": "area_pianure", "entries": [
    {"item": "rift_dust", "chance_pct": 20, "qty": [1, 2]},
    {"item": "stone_ember_chip", "chance_pct": 1, "qty": [1, 1]},
    {"item": "bag_leather", "chance_pct": 0.05, "qty": [1, 1]}]}
]}
```
| Campo | Tipo | Vincoli |
|---|---|---|
| `id` | String | unico; regex comune |
| `entries` | array | 1..24 voci `{item, chance_pct 0.01..100, qty [min ≥ 1, max ≥ min]}`; `item` di categoria `material`, `stone`, `currency`, `bag`, `contract` (mai `equipment`, `tool`, `blueprint`: restano nei `drops`) |
Ogni uccisione tira, per ogni tabella dell'area, del mostro (e, per un Monolito, della sua voce `loot_tables`), ogni voce con la propria probabilità
(come F-32); gli oggetti vanno nella borsa del bottino. Ogni tabella deve essere usata da almeno un'area, un mostro o un Monolito (il validatore segnala
quelle orfane). Classe: `LootTableDef`. Valori di partenza in `02_FORMULAS.md` §8.5b; file **obbligatorio** da M12 (vuoto non ammesso).

## 9. `data/shop/shop.json`

```json
{"entries": [
  {"id": "auto_eat_2", "name": "Razioni da campo II", "category": "combat", "vendor": "bottegaia",
   "description": "Mangia prima e più a lungo.",
   "cost": {"gold": 25000}, "max_purchases": 1,
   "requires": {"entries": ["auto_eat_1"], "character": 25},
   "effect": {"modifiers": [{"stat": "auto_eat_tier", "value": 1}]}}
]}
```
| Campo | Tipo | Vincoli |
|---|---|---|
| `category` | String | `bank` (UI "Deposito"; oggi senza voci), `combat`, `materials` (**M12**: `lanes` non esiste più) |
| `vendor` | String | bottega della pagina Shop (solo raggruppamento): `bottegaia`, `fabbro`, `armaiolo`, `mercante_armature` (M12: `deposito` tolta, non ha più voci); una bottega senza voci mostra "In arrivo" |
| `cost` | object | `{"gold": int ≥ 1}` (M12: `cost.formula` e le formule F-17/F-82 sono eliminate; ogni voce ha un prezzo fisso) |
| `max_purchases` | int | ≥ 0; 0 = illimitato (solo per effetti `item`) |
| `requires` | object | facoltativi `entries` (id dello shop), `character` (int 1..99), `skills` (`{skill: livello}`), `total_level` (int ≥ 0) |
| `effect` | object | **o** `modifiers` **o** `item` (`{item, qty}`); un `item` `equipment`/`tool` crea `qty` istanze comuni nell'Armeria (da M10 nessuna voce ne ha: la categoria `tools` e gli attrezzi del novizio sono tolti) |

Classe: `ShopEntryDef`. Fino a M3-04 il file esiste vuoto (`{"_doc": …, "entries": []}`, creato da M1-12).

## 10. `data/hints/hints.json` (M9)

```json
{"hints": [{"id": "first_action", "title": "Il primo passo", "text": "Scegli un'azione e premi Avvia.",
            "trigger": "session_started_new"}]}
```
`trigger`: uno di `session_started_new`, `bank_full`, `first_shard`, `mastery_node_affordable`, `player_died`,
`first_level_10`. Classe: `HintDef` (aggiunta in M9 in `core/data/defs/hint_def.gd`).
File singolo e **obbligatorio** (`CONTENT_FILES["hints"]`): se manca `GameData` segnala l'errore (nessun fallback). Un solo
suggerimento per trigger, in ordine di file; `GameData.hint(id)` ritorna `null` per un id sconosciuto. Il salvataggio
dello slot tiene `{"hints": {"seen": [id, ...]}}`.

## 11. `data/fractures/fractures.json` (M13)

```json
{"fractures": [{"id": "verdant_rift", "name": "Frattura verdeggiante", "description": "Il legno cresce più in fretta.",
                "weight": 10, "modifiers": [{"stat": "skill_xp_pct", "value": 25, "scope": "skill:forestry"}],
                "bonus_monster": null}]}
```
`weight` int ≥ 1 (estrazione pesata); `bonus_monster`: `null` o `{"area": id, "monster": id}`.
`balance.json` riceve `"fractures": {"interval_min_ms": 7200000, "interval_max_ms": 14400000, "duration_ms": 1800000}`.
Classe: `FractureDef`.

## 12. Corsie parallele (ELIMINATE in M12)

Non esistono più (W3, sostituite dagli aiutanti): niente `balance.json` `parallel`, niente stat `parallel_lanes`, niente voce `second_thought`, niente
categoria `lanes` dello shop. Gli aiutanti sono descritti in `01_GDD.md` §4.1 e `05_INTERFACES.md` §5.21.

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
 "icon": "res://assets/icons/classes/rift_blade.svg",
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
| `icon` | String | obbligatorio; `res://assets/icons/classes/…`, il file deve esistere (M6-00a) |
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
Per `buff`, `modifiers` e `duration_ms` stanno **dentro `params`**:
```json
{"id": "rift_surge", "name": "Impeto del Rift", "description": "Aumenta la potenza per qualche secondo.",
 "unlock_level": 1, "setups": [], "kind": "buff", "cooldown_ms": 30000,
 "params": {"modifiers": [{"stat": "power_pct", "value": 25}], "duration_ms": 8000}}
```
Nota per M6-04: i `modifiers` dei buff reali devono usare solo stat registrate in `data/config/stats.json` (es. `power_pct`, `evasion_pct`, `damage_reduction`), mai stat inventate.
Intervalli di formato controllati dal validatore (limiti di formato, non valori di design; i valori veri sono nei dati):
`n` int 2..20; `pct` e `hp_pct` in (0, 100]; `mult` e `power_mult` in (0, 10]; `heal_pct` 1..100; `duration_ms` ≥ 1000;
`stat_trade`: almeno una stat in `zero` o `mult`, nessuna in entrambe, fattori > 0, stat presenti in `stats.json`.
Chiavi di `params` diverse da quelle del tipo/`kind` sono errore. `balance.json`: `traits.slot_levels` e
`abilities.slot_levels` (F-78), 1..8 interi in 1..livello massimo, non decrescenti.
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
  una per area (F-87; il validatore rifiuta due Pietre sulla stessa area). `summon_pack` obbligatorio (`null` = nessun gruppo).
  `loot_tables` (array di id, facoltativo, M12), `hp` ≥ 1, `xp` ≥ 0, `pulse_damage` ≥ 1, `pulse_ms` ≥ `combat.min_attack_interval_ms`, `icon` in
  `res://assets/icons/monsters/` (file esistente), `drops` come i mostri (max 8; i pezzi con rarità `rarity.rift_stone`).
  Classe `RiftStoneDef`; `GameData.rift_stone(id)`, `has_rift_stone(id)`, `rift_stone_for_area(area_id)`.
- `data/items/materials.json`: Sigillo di salvaguardia (`upgrade.seal_item`).
- `balance.json`: `rarity.drop`, `rarity.rift_stone`, `upgrade`, `rift_stone`, `salvage`; `stats.json`: `upgrade_success_pct`.

## 17. Aggiunte di M8 (Legatura)

Categorie di oggetti `stone` (`{"stone": {"modifiers": [...]}}`, almeno 1 modificatore) e `currency`
(`{"currency": {"effect": "to_magic" | "to_rare" | "reroll"}}`) nei file `stones.json` e `currencies.json`;
`balance.json`: `sockets`. Ricette di `riftbinding.json` per rune, pietre e valute.

## 18. Aggiunte di M10 (riforma del bottino e dei nomi)

Riepilogo per il validatore e i task M10-01…M10-05 (dettagli nelle sezioni indicate):
- `balance.json` (§3): `start` esteso, `blueprint`, `tool_upgrade`, `combat.kill_xp_mult`; tolta `rarity.craft`; `salvage.component_ratio`.
- `skills.json` (§4): `level_modifiers` (forging → `upgrade_success_pct`).
- Oggetti (§5): categorie `component` e `blueprint`, `equip.unique` e `equip.upgrade_extras` degli attrezzi (tre in tutto).
- Azioni (§6): campo `single` e azione `blueprint_craft`; spariscono le ricette di spade, spadoni, scudi, armature e attrezzi.
- Mostri e Pietre (§8, §16): `drops` con progetti; componenti rari = materiali di drop già esistenti (nomi in `NOMI.md`).
- Shop (§9): nessuna voce `tools`; `auto_eat_1` resta e arriva da `start.purchases`.
- Nomi (Q52): si cambiano solo `name` e `description`; gli **id non cambiano** (tranne i nuovi oggetti: piastre, tre attrezzi, progetti).
  Il validatore non controlla i nomi; un test dei dati controlla che i nomi di `NOMI.md` ci siano (M10-05).
- Stat: nessuna stat nuova (`upgrade_success_pct` esiste dal M7; `double_item_chance` e `rift_shard_chance` pure).

## 19. `data/guide/*.json` (M11, Guida in gioco)

Testi a mano della Guida (`01_GDD.md` §27); un file per sezione (`primi_passi.json`, `combattimento.json`, `bottino.json`, `mestieri.json`,
`altare.json`, `offline.json`, …). Le pagine di oggetti, mostri, aree, mestieri, stat, tratti e abilità **non** si scrivono: le genera la Guida dai dati.
Radice: `{ "pages": [ … ] }`.

| Campo di pagina | Tipo | Note |
|---|---|---|
| `id` | String | unico fra tutti i file (anche rispetto alle pagine generate); snake_case |
| `section` | String | una delle sezioni di `01_GDD.md` §27 (id: `first_steps`, `character`, `loot`, `crafts`, `altar`, `offline`) |
| `title` | String | italiano, nomi da `NOMI.md` |
| `order` | int | ordine nell'indice della sezione |
| `blocks` | Array | blocchi in ordine (sotto) |
| `help_for` | Array[String] (opz.) | id delle pagine di gioco a cui il "?" porta qui (es. `combat`, `armory`, `skill:forging`) |
| `allow_digits` | bool (opz., default false) | ammette cifre nel testo (es. "livello 1", "3 aree"); da usare con parsimonia |

Blocchi (`type`): `text` (`text: String`, paragrafo) · `heading` (`text`) · `table` (`source: String`, id di una tabella generata fra quelle
dichiarate dal contratto di `05_INTERFACES.md` §5.19, es. `affix_tiers`, `refine_costs`, `traits`, `abilities`) · `links` (`targets: Array` di collegamenti).

**Segnaposto** nei testi (unico modo di citare un numero):
- `{balance:<percorso>|<formato>}`: valore di `balance.json` (percorso come `GameData.balance_value`); formato `int`, `pct`, `ore` (ms → ore),
  `min` (ms → minuti), `sec` (ms → secondi).
- `{stat:<id>}`: nome della stat da `stats.json`; `{stat:<id>|desc}` la descrizione; `{stat:<id>|min}` e `{stat:<id>|max}` i limiti.
- `{link:<tipo>:<id>|<testo>}`: collegamento a una pagina (`tipo` = `item`, `monster`, `area`, `skill`, `stat`, `trait`, `ability`, `page`).
Un segnaposto con percorso, formato, id o tipo sconosciuto è un errore di validazione; le graffe letterali non esistono nei testi.

**Eccezioni dichiarate** (`data/guide/exceptions.json`): `{ "no_source": [item_id…], "no_use": [item_id…] }`: oggetti ammessi senza "Si ottiene da"
o senza "Serve a" (es. valute di sola uscita). Ogni id deve esistere; un'eccezione superflua (l'oggetto ha fonte/uso) è un errore.

Regole del validatore: id di pagina unici; `section` valida; `order` ≥ 0; ogni `links.targets`/`{link:…}` punta a un id esistente (o a una pagina di guida
esistente); ogni `help_for` è una rotta nota; ogni `table.source` è dichiarata; nessuna cifra scritta a mano nei testi (le sequenze di cifre fuori da un segnaposto
sono un errore, salvo anni/numeri ordinali dichiarati in `allow_digits: true` sulla pagina); nessun fallback silenzioso (errore e nessun dato in caso di file non valido).

## 20. Aggiunte di M12 (Riforma 2: Deposito, aiutanti, maestria per risorsa, Incisore)

Riepilogo per il validatore e i task M12-01…M12-05 (dettagli nelle sezioni indicate):
- `balance.json` (§3): tolte `bank` e `armory`; aggiunte `deposit`, `helper`, `engraver`, `rune`, `mastery.milestones`; le regole del validatore sono in §3.
- `stats.json` (§2): **tolte** `bank_slots` e `armory_slots` (la capienza viene dalle borse; nessuna stat decorativa). Nessuna stat nuova.
- `shop.json` (§9): tolte `bank_slot` e `armory_slot`; niente `cost.formula`; vendor `deposito` tolta.
- Oggetti (§5): categorie `bag` (5 borse, `bags.json`) e `contract` (12 contratti, `contracts.json`); `infusion.grade`/`family` (45 rune = 9 famiglie × 5 gradi);
  nuovi `material`: `rift_dust`, `rune_slab`, 24 sottoprodotti; nomi di pietre e valute cambiati (`NOMI.md`), id invariati.
- Azioni (§6): `milestones` obbligatori nelle 24 azioni di raccolta; `kind: crystallize`; ricette dell'Incisore riscritte; Falegname: ricette delle borse di tela e rinforzata.
- Maestria (§7): alberi diversi per Boscaiolo, Minatore, Pescatore; `mastery_bonuses` vietato per le skill di raccolta.
- Combattimento (§8, §8b): nuovo `loot_tables.json`; `loot_tables` su aree, mostri e Monoliti.
- Guida (§19): pagine nuove (Deposito e borse, Aiutanti, Maestria per risorsa, Incisore, Monoliti del Rift) e tabelle generate `bags`, `helper_grades`,
  `engraver_recipes`, `mastery_milestones` (`05_INTERFACES.md` §5.19).
- Nomi: solo `name` e `description` (Q52); i nomi di `NOMI.md` (sezione Riforma 2) li controlla un test dei dati.
