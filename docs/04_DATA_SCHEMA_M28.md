# 04. Schema dei dati, §33: Abilità e tratti v2 (M28; V35-V36, `01_GDD_M28.md` §40, `02_FORMULAS_M28.md` F-185…F-194)

Estensione di `04_DATA_SCHEMA.md` (che supera le 400 righe): vale come la sua sezione **§33** ed estende §14 (`data/classes/<id>.json`). Regole generali di §0-§1 invariate (id
`snake_case`, nessun campo sconosciuto, nessun fallback silenzioso, chiavi sconosciute di `balance.json` → errore). Gli intervalli qui sotto sono **limiti di formato** del validatore,
non valori di design (i valori sono nei dati). Validatori: `DataValidatorTraits` (tratti) e `DataValidatorAbilities` (abilità, nuovo file estratto in M28-02), `balance.json` per §33.1.

## 33.1 `balance.json` (M28-03)
```json
"combat": { …, "conditions": {"tick_ms": 1000, "stagger_immunity_ms": 4000} }
```
`tick_ms` int 100..10000; `stagger_immunity_ms` int 0..60000. Entrambe obbligatorie da M28-03. `traits.slot_levels` e `abilities.slot_levels` invariati.

## 33.2 Applicazione di una condizione (`apply` delle abilità, `apply_on_hit` dei tratti)
```json
{"condition": "bleed", "pct": 30, "ms": 4000}
{"condition": "weaken", "pct": 25, "ms": 6000}
{"condition": "expose", "pct": 15, "ms": 6000}
{"condition": "stagger", "ms": 1500}
```
| `condition` | `pct` | `ms` |
|---|---|---|
| `bleed` | obbligatorio, (0, 300] (percentuale del danno del colpo) | 1000..60000 |
| `weaken` | obbligatorio, (0, 90] | 1000..60000 |
| `expose` | obbligatorio, (0, 100] | 1000..60000 |
| `stagger` | **assente** | 100..5000 |
Altre chiavi o altri valori di `condition` → errore. `ward` non è un'applicazione: è un tipo di abilità (§33.3) o di effetto (§33.4).

## 33.3 Abilità (estende §14)
Campi invariati (`id`, `name`, `description`, `unlock_level`, `setups`, `kind`, `cooldown_ms`, `params`). `kind` ∈ `strike`, `cleave`, `heal`, `buff`, **`ward`**.
| `kind` | `params` obbligatori | `params` facoltativi (M28) |
|---|---|---|
| `strike` | `power_mult` (0, 10] | `hits` int 1..5 (default 1); `target` ∈ `first`, `lowest_hp`, `highest_hp`; `execute` `{"hp_pct": (0, 100], "mult": (1, 10]}`; `apply` lista di §33.2 (1..3 voci, condizioni diverse); `drain_pct` (0, 100] |
| `cleave` | `power_mult` (0, 10], `targets` int ≥ 0 | `execute`, `apply`, `drain_pct` (come sopra; **non** `hits` né `target`) |
| `heal` | `heal_pct` 1..100 | — |
| `buff` | `modifiers` (≥ 1, stat del registro), `duration_ms` ≥ 1000 | — |
| `ward` | `ward_pct` 1..100, `duration_ms` 1000..60000 | — |
Esempi:
```json
{"id": "cross_cuts", "name": "Tagli incrociati", "description": "Tre tagli rapidi che lasciano ferite aperte.",
 "unlock_level": 25, "setups": ["dual_swords"], "kind": "strike", "cooldown_ms": 8000,
 "params": {"power_mult": 0.5, "hits": 3, "apply": [{"condition": "bleed", "pct": 30, "ms": 4000}]}}
{"id": "high_guard", "name": "Guardia alta", "description": "Alzi lo scudo e assorbi i colpi in arrivo.",
 "unlock_level": 25, "setups": ["sword_shield"], "kind": "ward", "cooldown_ms": 18000,
 "params": {"ward_pct": 15, "duration_ms": 6000}}
{"id": "final_thrust", "name": "Stoccata finale", "description": "Un affondo che cerca chi sta per cadere.",
 "unlock_level": 65, "setups": ["sword"], "kind": "strike", "cooldown_ms": 9000,
 "params": {"power_mult": 1.3, "target": "lowest_hp", "execute": {"hp_pct": 30, "mult": 2.5}}}
```

## 33.4 Tratti (estende §14)
Campi invariati. `effects[].type` ∈ i tipi di F-81, i tipi di combattimento di F-120 ammessi nei tratti (`execute_mult`, `hit_cap_pct`, `armor_pierce_pct`, `kill_heal_pct`, `block_heal_pct`,
`stat_convert`, `double_hit_pct`, con gli intervalli di F-120) e i tipi di F-192:
| Tipo | `params` |
|---|---|
| `stack_damage`, `stack_haste` | `gain` ∈ `kill`, `hit`, `block`, `evade`; `pct` (0, 50]; `max` int 1..20; `lose` ∈ `damaged`, `encounter`, `none` |
| `focus_combo` | `pct` (0, 50]; `max` int 1..20 |
| `riposte` | `on` ∈ `block`, `evade`; `mult` (0, 10] |
| `damage_trade` | `dealt_pct` (0, 200]; `taken_pct` (0, 200] (entrambi obbligatori: è uno scambio) |
| `apply_on_hit` | `every` int 1..20 più i campi di §33.2 (`condition`, `pct`, `ms`) allo stesso livello |
| `status_damage_mult` | `condition` ∈ `bleed`, `weaken`, `expose`, `stagger`; `pct` (0, 200] |
| `kill_cooldown_cut` | `ms` int 1..60000 |
| `after_ability_mult` | `mult` (1, 10] |
| `ward_on` | `on` ∈ `kill`, `block`, `encounter_start`; `pct` (0, 100]; `ms` int 1000..60000 |
| `ability_mult` | `kinds` lista non vuota senza doppioni di `strike`, `cleave`, `heal`, `ward`; `pct` (0, 200] |
| `lone_target_mult` | `pct` (0, 200] |
Regole in più: **al massimo un effetto con stato per tratto** (con stato: `every_nth_attack_all`, `stack_damage`, `stack_haste`, `focus_combo`, `apply_on_hit`, `after_ability_mult`); un tratto
ha almeno un effetto (invariato). I tipi di raccolta, Monoliti e Carte di F-120 nei tratti → errore. I tipi di F-192 negli effetti dei leggendari → errore (`DataValidatorLegendary`
invariato: l'elenco di F-120 resta chiuso).
Esempi:
```json
{"id": "momentum", "name": "Slancio", "description": "Ogni nemico abbattuto ti spinge avanti, finché qualcuno non ti ferisce.",
 "unlock_level": 3, "setups": [],
 "effects": [{"type": "stack_damage", "params": {"gain": "kill", "pct": 5, "max": 5, "lose": "damaged"}}], "modifiers": []}
{"id": "heavy_iron", "name": "Peso del ferro", "description": "I colpi dello spadone fanno barcollare chi li para.",
 "unlock_level": 28, "setups": ["greatsword"],
 "effects": [{"type": "apply_on_hit", "params": {"every": 2, "condition": "stagger", "ms": 1000}}], "modifiers": []}
{"id": "colossus", "name": "Colosso", "description": "Lento come una montagna, e come una montagna non crolli.",
 "unlock_level": 52, "setups": ["greatsword"],
 "effects": [{"type": "hit_cap_pct", "params": {"pct": 25}}], "modifiers": [{"stat": "attack_interval_pct", "value": 10}]}
```

## 33.5 Contenuto di `data/classes/rift_blade.json` (M28-06)
- I 12 tratti e le 6 abilità esistenti restano **primi e invariati** (id, ordine, valori; `sim_combat loadout=auto` sceglie i primi sbloccati nel file: F-194 (4)). Unica eccezione possibile:
  il `name` di `blade_volley` (Q174).
- Dopo, in ordine di `unlock_level`: i 19 tratti nuovi e le 13 abilità nuove di `01_GDD_M28.md` §40.6-§40.7 con i valori di quelle tabelle.
- `description`: testo di colore originale, **senza cifre** (i numeri li genera `LoadoutDescribe`, P-03). `_doc` aggiornato ("31 tratti e 19 abilità").
- Fixture `tests/fixtures/data/classes/`: almeno un'abilità per tipo e parametro nuovi e un tratto per tipo nuovo (M28-04/05), così `validate_data` sulle fixture copre lo schema.

## 33.6 Casi rifiutati dal validatore (test)
`hits` su `cleave`; `hits` 0 o 6; `target` sconosciuto; `execute.mult` 1; `apply` vuota, con 4 voci o con due `bleed`; `stagger` con `pct`; `weaken` 95; `ward_pct` 0; `ward` senza
`duration_ms`; `stack_damage` con `gain` sconosciuto o `max` 0; `damage_trade` con un solo campo; `ability_mult` con `kinds` vuota o `buff`; due effetti con stato nello stesso tratto
(`stack_damage` + `apply_on_hit`); `gather_bonus_item` o `card_drop_mult` in un tratto; `stack_damage` in un leggendario; `combat.conditions` mancante o `tick_ms` 50.
