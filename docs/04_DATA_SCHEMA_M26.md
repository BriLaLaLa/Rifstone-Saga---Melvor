# 04. Schema dei dati, §31: Alpha 2 (M26; V31-V32, `01_GDD_M26.md` §38, `02_FORMULAS_M26.md` F-166…F-176)

Estensione di `04_DATA_SCHEMA.md` (che supera le 400 righe): vale come la sua sezione **§31**. Regole generali di §0-§1 invariate (id `snake_case`, nessun campo
sconosciuto, nessun fallback silenzioso). Validatore nuovo dei filoni A-B: `core/data/data_validator_professions.gd` (`DataValidatorProfessions`, agganciato in
`data_validator.gd`); filone C: `DataValidatorAuction` esteso. Le regole "dei dati veri" valgono con `DataValidatorDisciplines.is_real_data(raw)` come in §29.

## 31.1 Azioni: campo `colors` (filone A, F-166)
```json
{"id": "forge_ashlead_plate", "level": 10, "...": "...", "colors": {"yellow": 20, "green": 30, "grey": 40}}
```
| Campo | Tipo | Vincoli |
|---|---|---|
| `colors` | object | facoltativo; esattamente `yellow`, `green`, `grey` interi con `level < yellow < green < grey ≤ 200`; ammesso solo per azioni di skill `artisan` **non** `single` |
Dati veri (generati da `tools/gen_professions.gd`): tutte le azioni non `single` di `forging.json`, `woodwright.json`, `hearthcraft.json`; nessuna in `riftbinding.json` (Q148).
Con dati veri il validatore controlla che queste tre skill abbiano `colors` su ogni azione non `single`. Classe: `ActionDef.colors: Dictionary` (`{}` se assente; chiavi `&"yellow"`,
`&"green"`, `&"grey"`). Fixture: una ricetta con `colors` e una senza.

## 31.2 Ricette-schema: `discover`, oggetti `recipe`, reagenti negli `inputs` (filone B, F-169, F-171)
- Le 28 ricette di F-169 diventano `"discover": true` (le altre restano come sono). Ognuna ha la sua Ricetta in `data/items/recipes.json` (§29.4, stesso schema):
  id `recipe_<action>`, nome "Schema: <prodotto>" (testi originali), `value` 0, `recipe.action` = l'azione.
- Ogni ricetta-schema del gradino `t` ha **in fondo** a `inputs` una voce `{"item": "reagent_<skill>_<fascia>", "qty": 1}` (fascia di F-171).
- **Regola cambiata** (§29.4, con dati veri): ogni azione `discover` ha la sua Ricetta e la Ricetta compare in **almeno una tabella di drop oppure in una voce dello shop**
  (`effect.item`), mai in entrambe (Tonici: solo drop; schemi: solo shop).

## 31.3 Oggetti: categoria `reagent` (`data/items/reagents.json`, nuovo, generato)
```json
{"items": [{"id": "reagent_forging_1", "name": "<nome originale>", "category": "reagent", "icon": "res://assets/icons/items/reagent_forging_1.svg",
            "value": 0, "sort_order": 10, "description": "<una frase>"}]}
```
| Campo | Tipo | Vincoli |
|---|---|---|
| `category` | String | nuova `reagent`; nessun campo speciale (`food`, `recipe`, …) |
| `value` | int | ≥ 0 (F-171: `floor(prezzo × 25 / 100)`) |
12 voci (`reagent_{forging,woodwright,hearthcraft}_{1..4}`). Regole: un `reagent` non è output di nessuna azione, non è in `auction_items.json` (la regola di
generazione di §28 lo esclude già per categoria), compare negli `inputs` solo di ricette `discover` della sua skill (id) e della sua fascia. `Bank.SORT_CATEGORIES` include
`reagent` (subito dopo `material`). Icone: SVG nuove originali (`tools/gen_icons_m24.gd` o uno script nuovo), altrimenti `missing`.

## 31.4 `data/shop/shop.json`: botteghe dei mercanti (filone B)
- `vendor` aggiunge `falegname` e `cuoco` (`SHOP_VENDORS`); `fabbro` esiste già (oggi senza voci). `category` aggiunge `profession` (`SHOP_CATEGORIES`).
- Voci **generate** (id `buy_recipe_<action>` e `buy_reagent_<skill>_<fascia>`; le altre voci del file restano come sono):
```json
{"id": "buy_recipe_forge_ashlead_plate", "name": "Schema: Piastra di ferro", "category": "profession", "vendor": "fabbro",
 "description": "<una frase>", "cost": {"gold": 1050}, "max_purchases": 1, "requires": {"skills": {"forging": 10}},
 "effect": {"item": {"item": "recipe_forge_ashlead_plate", "qty": 1}}},
{"id": "buy_reagent_forging_1", "name": "<nome del reagente>", "category": "profession", "vendor": "fabbro",
 "description": "<una frase>", "cost": {"gold": 2}, "max_purchases": 0, "requires": {"skills": {"forging": 10}},
 "effect": {"item": {"item": "reagent_forging_1", "qty": 1}}}
```
- **Regole del validatore** (sempre): una voce `profession` ha `effect.item` con un oggetto `recipe` (allora `max_purchases` 1) o `reagent` (allora `max_purchases` 0), `requires.skills` con
  **una sola** skill = la skill dell'azione della Ricetta o del reagente, `vendor` = il `vendor` del Maestro di quella skill (§31.5); per **ogni** voce con `effect.item`:
  `cost.gold > value(item) × qty` (F-171). Con dati veri: livello del requisito = livello dell'azione (schema) o del primo gradino della fascia (reagente), prezzi = F-170/F-171.
- `ShopEntryDef` invariato (i campi esistono già: `vendor`, `effect_item`, `req_skills`).

## 31.5 `data/disciplines/trainers.json`: campo `vendor`
| Campo | Tipo | Vincoli |
|---|---|---|
| `trainers[].vendor` | String | facoltativo; solo per discipline `artisan`; uno di `SHOP_VENDORS`; unico tra i Maestri. Dati veri: `forging` → `fabbro`, `woodwright` → `falegname`, `hearthcraft` → `cuoco`; assente per `riftbinding` (Q148) |
Classe: `TrainerDef.vendor: StringName` (`&""` se assente).

## 31.6 Generatore `tools/gen_professions.gd` (nuovo, M26-04)
Legge `data/actions/{forging,woodwright,hearthcraft}.json`, `data/items/*.json` (valori dei prodotti) e `data/disciplines/trainers.json`; **scrive**: `colors` e `discover` nelle azioni
(preserva tutti gli altri campi e l'ordine), la voce reagente in fondo agli `inputs` delle ricette-schema, `data/items/recipes.json` (aggiunge gli schemi, preserva i Tonici),
`data/items/reagents.json`, le voci `profession` di `shop.json` (preserva le altre). Costanti dello script (unica fonte, finiscono nei dati): offset 10/20/30 (F-166), famiglie di
schemi (F-169), `SCHEME_VALUE_MULT` 50, `SCHEME_MIN_GOLD` 100 (F-170), fasce e `REAGENT_PRICE_PCT` 10, `REAGENT_VALUE_PCT` 25 (F-171). Idempotente; `--check` (esce con 1 se i file
divergono dalla rigenerazione, come `gen_market.gd`). Nomi e descrizioni degli schemi e dei reagenti: tabella di testi originali nello script (o in `NOMI.md` e copiata), mai generici.

## 31.7 Casa d'Aste: `data/auction/population.json` (nuovo, a mano) e `balance.json` (filone C)
```json
{"bands": [{"max_value": 9, "buyers": 125, "sellers": 115}, {"max_value": 59, "buyers": 110, "sellers": 105},
           {"max_value": 249, "buyers": 100, "sellers": 100}, {"buyers": 90, "sellers": 85}]}
```
| Campo | Tipo | Vincoli |
|---|---|---|
| `bands` | array | almeno 1 voce; `max_value` interi ≥ 1 strettamente crescenti, **assente solo nell'ultima** (fascia aperta); `buyers`, `sellers` interi ≥ 1 |
`balance.json` `auction.population` (obbligatoria, chiavi sconosciute → errore): `ref` int ≥ 1; `period_blocks` int ≥ 1; `variation_pct` float 0..99; `pressure_pct` float ≥ 0;
`demand_threshold_pct` float ≥ 0. Valori in `02_FORMULAS_M26.md` §9d (e `index.max_pct` 126, `saturation.max_pct` 56). **Regole del validatore** nuove: i vincoli di F-174 (con `PB+`,
`PB−` calcolati sulle fasce) al posto di quelli di F-147 su `AMP` soltanto; recupero completo ≤ `offline.max_hours` per ogni fascia (F-172). Classi: `AuctionPopulationBand` (`max_value: int`,
`-1` per l'ultima, `buyers: int`, `sellers: int`); `AuctionParams` guadagna `pop_ref`, `pop_period_blocks`, `pop_var_ppm`, `pop_press_ppm`, `pop_demand_ppm`, `bands: Array[AuctionPopulationBand]`
(caricate da `population.json` insieme ai parametri; nessun accessore nuovo in `GameData`: `auction_params()` le contiene).
**Fixture**: `tests/fixtures/data/auction/population.json` con le 4 fasce di partenza e `balance.json` con `auction.population` e i due valori nuovi. Casi rifiutati: `max_value` non crescenti o
presente nell'ultima, `buyers` 0, `MAX` sotto `BASE + AMP + PB+`, `CAP` troppo piccolo, recupero oltre 12 h, chiave sconosciuta in `population`.

## 31.8 Fixture dei filoni A-B (`tests/fixtures/data/`, M26-02)
Una skill `artisan` di prova con: una ricetta con `colors` e senza `discover`, una ricetta-schema (`discover`, `colors`, un reagente negli `inputs`) con la sua Ricetta e la sua voce `profession`
nello shop, un reagente `reagent` con la sua voce, il Maestro con `vendor`. Casi rifiutati (`tests/core/data/test_data_validator_professions.gd`): `colors` non crescenti o ≤ `level`,
`colors` su un'azione di raccolta o `single`, voce `profession` con `requires.skills` di un'altra skill o `vendor` diverso dal Maestro, schema con `max_purchases` ≠ 1, reagente con
`max_purchases` ≠ 0, `cost.gold ≤ value × qty`, reagente output di un'azione, Ricetta sia in drop sia nello shop, `trainers[].vendor` doppio o su una raccolta.
