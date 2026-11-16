# 04. Schema dei dati, §29: Incontri e Mestieri (M24; V16-V24, `01_GDD_M24.md` §35, `02_FORMULAS_M24.md` F-153…F-160)

Estensione di `04_DATA_SCHEMA.md` (che supera le 400 righe): vale come la sua sezione **§29**. Regole generali di §0-§1 invariate (id `snake_case`,
nessun campo sconosciuto, nessun fallback silenzioso). Il validatore nuovo è `core/data/data_validator_disciplines.gd` (M24-02) con
`STRICT_REAL_DATA = false` finché M24-05 non scrive i dati veri (poi `true`, come in M23).

## 29.1 `data/skills/skills.json`: campo `discipline`
| Campo | Tipo | Vincoli |
|---|---|---|
| `discipline` | bool | facoltativo, default `false`. `true` = si impara dai Maestri (§35.3). Ammesso solo per `category` `gathering` o `artisan` |
Dati veri (M24-02 per le 6 skill esistenti, M24-05 per la nuova): `true` per `forestry`, `quarrying`, `angling`, `herbalism`, `forging`, `woodwright`,
`hearthcraft`; `false` (assente) per `riftbinding`. `tests/data/test_data_validity.gd` (M24-05) controlla **4** discipline `gathering` e **3** `artisan`.
Skill nuova (M24-05): `{"id": "herbalism", "name": "Erborista", "category": "gathering", "order": …, "icon": "res://assets/icons/skills/herbalism.svg",
"color": "#…", "description": "…", "has_mastery": true, "discipline": true}`; `hearthcraft.name` = "Cuoco e alchimista" (Q113). Classe: `SkillDef.discipline: bool`.

## 29.2 `data/disciplines/trainers.json` (nuovo)
```json
{"grades": [
   {"id": "novice", "name": "Novizio", "cap": 20, "character_level": 1},
   {"id": "worker", "name": "Lavorante", "cap": 40, "character_level": 15},
   {"id": "skilled", "name": "Provetto", "cap": 60, "character_level": 35},
   {"id": "foreman", "name": "Capomastro", "cap": 80, "character_level": 55},
   {"id": "luminary", "name": "Luminare", "cap": 99, "character_level": 75}],
 "trainers": [
   {"skill": "forging", "name": "<nome del Maestro>", "title": "<titolo>", "description": "<una frase>", "fed_by": ["quarrying"]}]}
```
| Campo | Tipo | Vincoli |
|---|---|---|
| `grades` | array | **obbligatorio** (M24-02 lo scrive con i valori di F-158): almeno 1 voce; `id` unici; `cap` interi strettamente crescenti in 1..`xp_curve.max_level`, l'ultimo = `xp_curve.max_level`; `character_level` interi 1..99 non decrescenti |
| `grades[].name` | String | nome visibile del grado (originale) |
| `trainers` | array | una voce per disciplina, `skill` unica e con `discipline: true`; `name`, `title`, `description` stringhe non vuote (testi originali, M24-05) |
| `trainers[].fed_by` | array di id | facoltativo; solo per discipline `artisan`; ogni id è una disciplina `gathering`; solo presentazione (pagina dei Maestri, §35.8) |
Con `STRICT_REAL_DATA = true`: ogni disciplina ha il suo Maestro. Classi: `TrainerGradeDef` (`id`, `name`, `cap`, `character_level`), `TrainerDef`
(`skill`, `name`, `title`, `description`, `fed_by: Array[StringName]`).

## 29.3 `data/encounters/nodes.json` (nuovo, **generato** da `tools/gen_nodes.gd`, M24-05)
```json
{"areas": [
   {"area": "redrock_plains", "max_level": 10,
    "nodes": [{"skill": "forestry", "weight": 35}, {"skill": "quarrying", "weight": 15},
              {"skill": "angling", "weight": 30}, {"skill": "herbalism", "weight": 20}]}]}
```
| Campo | Tipo | Vincoli |
|---|---|---|
| `area` | String | area esistente, unica nel file |
| `max_level` | int | 1..99; il generatore usa il `level_max` dell'area (F-154) |
| `nodes` | array | non vuoto; `skill` = disciplina `gathering`, unica nell'area; `weight` intero ≥ 1 |
Con `STRICT_REAL_DATA = true`: ogni area di `areas.json` ha una voce; ogni voce ha **tutte** le discipline di raccolta; i pesi di un'area sommano a 100 e
nessuno è sotto 10 (temi dell'area scelti dal Data Designer: es. più Miniera nelle Miniere, più Pesca e Erboristeria nelle Paludi). Un file assente è
ammesso solo con `STRICT_REAL_DATA = false` (nessun nodo: F-153 dà sempre `fight`). Classi: `AreaNodesDef` (`area`, `max_level`,
`entries: Array[NodeEntryDef]`), `NodeEntryDef` (`skill`, `weight`).

## 29.4 Oggetti: categoria `recipe` (`data/items/recipes.json`, nuovo)
```json
{"items": [{"id": "recipe_tonic_1", "name": "Ricetta: …", "category": "recipe", "icon": "res://assets/icons/items/….svg", "value": 0,
            "sort_order": 10, "description": "…", "recipe": {"action": "brew_tonic_1"}}]}
```
| Campo | Tipo | Vincoli |
|---|---|---|
| `recipe.action` | String | obbligatorio per `category: recipe` e vietato per le altre; un'azione esistente con `discover: true`; al più una Ricetta per azione |
`value` = 0 (non vendibile, mai nella Casa d'Aste: categoria fuori da §34.2). Con `STRICT_REAL_DATA = true` ogni azione `discover` ha la sua Ricetta e la
Ricetta compare in almeno una tabella di drop. `ItemDef.recipe_action: StringName`, `ItemDef.is_recipe()`. `Bank.SORT_CATEGORIES` include `recipe`
(dopo `bag`). Le tabelle di drop (`04_DATA_SCHEMA.md` §8b) ammettono la categoria `recipe`.

## 29.5 Azioni: campo `discover` e ricette nuove
| Campo | Tipo | Vincoli |
|---|---|---|
| `discover` | bool | facoltativo, default `false`; ammesso solo per skill `artisan` (anche `riftbinding`), vietato con `single: true` e per la raccolta |
Ricette nuove (M24-05): 8 **Tonici** in `data/actions/hearthcraft.json` (`brew_tonic_1`…`brew_tonic_8`, tabella `02_FORMULAS_M24.md` §8.11, `discover: true`);
8 cibi nuovi in `data/items/food.json` (`tonic_1`…`tonic_8`, `food.heal` di §8.11). `data/actions/herbalism.json`: 8 azioni di raccolta con `milestones`
(stesse regole di §6), `data/mastery/herbalism.json`: albero proprio; 8 erbe e 8 sottoprodotti `material` in `data/items/materials.json`.
Lastra runica (`make_rune_slab` in `riftbinding.json`): `inputs` = `rift_dust` × 3, `rift_shard` × 1.

## 29.6 `balance.json`: sezioni nuove e tolte (valori in `02_FORMULAS_M24.md` §9b)
- `encounters` (obbligatoria): `travel_ms` int ≥ 0; `node_chance_pct` 0..100; `node_min_ms` int ≥ `action.min_interval_ms`; `node_ms` int ≥ `node_min_ms`;
  `skip_ms` int ≥ 0; `node_units` int ≥ 1; `colors` array non vuoto di `{id, below, xp_pct}` con `id` unici, `below` interi ≥ 1 strettamente crescenti e
  l'ultimo ≥ `xp_curve.max_level`, `xp_pct` 0..100 non crescenti.
- `disciplines` (obbligatoria): `max_per_category` int ≥ 1.
- `trainer` (obbligatoria): `learn_gold` int ≥ 0; `gold_base` int ≥ 0; `gold_growth` ≥ 1; `skill_margin` int ≥ 0; `unlearn_pct` 0..100; `unlearn_min_gold` int ≥ 0.
- `production` (obbligatoria): `queue_slots` int ≥ 1; `max_job_count` int ≥ 1.
- **Tolta** `helper` (una chiave `helper` è ora sconosciuta → errore). `village.woodwright_levels` invariata nello schema (ora livello del personaggio, Q114).

## 29.7 Tolto (V22)
Categoria `contract` (campo `contract`, file `data/items/contracts.json`, voci delle tabelle di drop, regole dei validatori degli oggetti, delle tabelle e del
Dungeon); `balance.json` `helper`; tabella della Guida `helper_grades`; pagina `guide_helpers`. Le fixture perdono `items/contracts.json` (anche
`m10/items/contracts.json`, snapshot non validato).

## 29.8 Altri dati toccati da M24-05 (stesso schema di prima)
- `data/combat/loot_tables.json` (da `tools/gen_areas.gd`): senza Contratti; con le Ricette (§8.11).
- `data/quests/quests.json` (da `tools/gen_quests.gd`): incarichi `gather` anche per `herbalism` (64 voci).
- `data/auction/auction_items.json` (da `tools/gen_auction.gd`, **script invariato**): rigenerato con la regola di §34.2 (entrano erbe, sottoprodotti e Tonici).
- `data/guide/*.json`: tolta `guide_helpers`; nuove pagine `guide_disciplines` (Mestieri e Maestri, con la tabella generata `trainer_grades`) e
  `guide_travel` (Viaggio e nodi); testi di Primi passi, Mestieri e Deposito allineati. Eccezioni della Guida aggiornate.
- `NOMI.md`: Erborista, Cuoco e alchimista, erbe, Tonici, Ricette, Maestri e gradi.

## 29.9 Fixture (`tests/fixtures/data/`, M24-02)
`skills/skills.json` con `discipline` (almeno 2 `gathering` e 2 `artisan` discipline e una skill non disciplina), `disciplines/trainers.json` (3 gradi bastano),
`encounters/nodes.json` per le aree di fixture, una ricetta `discover` e la sua Ricetta, `balance.json` con le sezioni di §29.6; casi rifiutati
(`tests/core/data/test_data_validator_disciplines.gd`): `discipline` su una skill di un'altra categoria, `cap` non crescenti o ultimo ≠ 99, Maestro di una
skill non disciplina, `fed_by` non di raccolta, area sconosciuta o doppia in `nodes.json`, nodo di una skill non di raccolta, peso 0, `recipe.action`
sconosciuta o senza `discover`, `discover` su un'azione di raccolta, chiavi di `encounters` fuori intervallo, `colors` non crescenti, chiave `helper`.
**Fixture e test esistenti**: nel `balance.json` delle fixture `encounters.node_chance_pct` = **0** e `encounters.travel_ms` = `combat.respawn_ms` della
fixture, così i test di combattimento di oggi restano validi cambiando solo il nome dello stato (`between` → `travel`); i test del ciclo (M24-04) alzano
`node_chance_pct` nel proprio dato di prova.
