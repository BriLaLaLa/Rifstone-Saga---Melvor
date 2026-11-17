# 04. Schema dei dati, §32: Casa d'Aste v2 e monete (M27; V33-V34, `01_GDD_M27.md` §39, `02_FORMULAS_M27.md` F-177…F-184)

Estensione di `04_DATA_SCHEMA.md` (che supera le 400 righe): vale come la sua sezione **§32**. Regole generali di §0-§1 invariate (id `snake_case`, nessun campo
sconosciuto, nessun fallback silenzioso, chiavi sconosciute di `balance.json` → errore). Validatori: `currency` nel validatore di `balance.json` (M27-02), `DataValidatorAuction`
esteso (M27-06), `DataValidatorMail` nuovo (M27-05).

## 32.1 `balance.json` `currency` (M27-02)
```json
"currency": {"copper_per_silver": 100, "silver_per_gold": 100,
             "symbols": {"gold": "o", "silver": "a", "copper": "r"}, "names": {"gold": "Oro", "silver": "Argento", "copper": "Rame"}}
```
| Campo | Tipo | Vincoli |
|---|---|---|
| `copper_per_silver`, `silver_per_gold` | int | ≥ 2 |
| `symbols`, `names` | object | esattamente `gold`, `silver`, `copper`; stringhe non vuote; `symbols` al più 3 caratteri |
Classe `CurrencyParams` (`core/data/defs/currency_params.gd`): `copper_per_silver: int`, `silver_per_gold: int`, `symbols: Dictionary[StringName, String]`,
`names: Dictionary[StringName, String]`, `func copper_per_gold() -> int`. Accessore `GameData.currency() -> CurrencyParams`. Le fixture usano il `balance.json` vero (come oggi).

## 32.2 Conversione dei campi di denaro (×100, una tantum, M27-03; F-177)
Script **una tantum** `tools/convert_money_m27.gd` (`-- <root>`; senza argomenti `res://data`): moltiplica per `V11_COPPER_PER_GOLD` (letto da `migration_10_to_11.gd`) **solo** i campi
qui sotto, in ogni file con lo stesso nome relativo a qualunque profondità sotto la radice (così anche `tests/fixtures/data/`, `…/m10/`, `…/m14/`), preservando l'ordine delle chiavi e
il formato (stesso stile di scrittura dei generatori). Si esegue **una volta** per radice nello stesso commit dei dati convertiti; poi lo script si **cancella** (resta nella storia
di git): un secondo passaggio raddoppierebbe tutto.
| File (relativo) | Campi (intero, coppia `[min, max]` o lista: ogni numero ×100) |
|---|---|
| `items/*.json` | `items[].value` |
| `combat/monsters.json`, `m14/monsters.json` | `monsters[].gold` |
| `dungeons/*.json` | `monsters[].gold`, `boss.gold`, `rooms.entrance.reward.gold`, `rooms.types[].reward.gold`, `stages[].reward.gold` |
| `maps/bosses.json` | `bosses[].gold` |
| `quests/quests.json` | `quests[].reward.gold` |
| `shop/shop.json` | `entries[].cost.gold` |
| `village/buildings.json` | `buildings[].levels[].gold` |
| `config/balance.json` | `start.gold`, `village.gold_base`, `quest.gold_by_tier[]`, `trainer.learn_gold`, `trainer.gold_base`, `trainer.unlearn_min_gold`, `upgrade.levels[].gold_per_grade`, `tool_upgrade.levels[].gold`, `auction.stock.gold` |
| `auction/population.json` | `bands[].max_value` |
**Non** si convertono (rapporti o non denaro): `village.gold_growth`, `trainer.gold_growth`, `trainer.unlearn_pct`, `quest.types.*.gold_mult`, `miniboss.gold_mult`,
`buildings[].cost_spec.gold_weight`, `blueprint.cost_mult`, `reward_mult`, `gold_drop_pct` (stat), `effect_value`, i `value` dei modificatori, `cost_pct` della maestria, `data/guide/**`.
Un campo di denaro **non** in tabella trovato dopo la conversione (es. un file nuovo) è un errore del task: si aggiunge alla tabella (Reviewer) prima di convertire.
**Generatori** (stessa conversione, nessun numero nuovo): `gen_areas`, `gen_dungeon`, `gen_dungeon_legendaries`, `gen_engraver_minor`, `gen_equipment`, `gen_market`, `gen_professions`,
`gen_metin` (se scrive oro), `gen_quests` e `gen_village` (tramite `DataValidatorQuests.quest_for` e `DataValidatorVillage.levels_for`): calcolano **in argento** (importi letti
`÷ copper_per_silver`, scritti `× copper_per_silver`), F-177; `--check` di ognuno esce 0 dopo la conversione. Arrotondamenti dei validatori di F-131 e F-134: a `10 × copper_per_silver`.
**Testi**: le etichette che dicono "oro" per il denaro (`stats.json` di `gold_drop_pct`, descrizioni degli oggetti e delle voci dello shop, pagine della Guida) diventano "monete"
(id invariati); `NOMI.md` registra Oro, Argento, Rame. Nessun numero di denaro nei testi.

## 32.3 `population.json`: campo `stack` (M27-06)
```json
{"bands": [{"max_value": 900, "buyers": 125, "sellers": 115, "stack": 200}, {"max_value": 5900, "buyers": 110, "sellers": 105, "stack": 60},
           {"max_value": 24900, "buyers": 100, "sellers": 100, "stack": 20}, {"buyers": 90, "sellers": 85, "stack": 5}]}
```
`stack` int ≥ 1, obbligatorio in ogni fascia (F-178). `AuctionPopulationBand.stack: int`.

## 32.4 `balance.json` `auction.book` e `auction.listing` (M27-06)
```json
"book": {"persist_blocks": 6, "ask_min_pct": 0, "ask_max_pct": 25, "sellers_per_listing": 10, "min_listings": 4, "max_listings": 12, "fill_pct": 50, "fill_max_pct": 90},
"listing": {"max_active": 10, "cut_pct": 5, "max_price_pct": 1000,
            "durations": [{"id": "short", "hours": 12, "deposit_pct": 1}, {"id": "medium", "hours": 24, "deposit_pct": 2}, {"id": "long", "hours": 48, "deposit_pct": 4}]}
```
Entrambe obbligatorie (dentro `auction`), chiavi sconosciute → errore. Tipi: interi per `persist_blocks`, `sellers_per_listing`, `min_listings`, `max_listings`, `max_active`, `hours`;
float per i `*_pct`. Vincoli di F-182 (anche quello di non-arbitraggio con `index.min_pct`, `index.max_pct`, `buy.spread_pct`) e: ogni oggetto di `auction_items.json` con `value ≤ 1.000.000`.
Classi: `AuctionParams` guadagna `book_persist`, `book_lo_ppm`, `book_hi_ppm`, `book_sellers_per_listing`, `book_min_listings`, `book_max_listings`, `book_fill_ppm`, `book_fill_max_ppm`,
`listing_max_active`, `listing_cut_ppm`, `listing_max_price_ppm` (int) e `durations: Array[AuctionDuration]`; `AuctionDuration` (`core/data/defs/auction_duration.gd`): `id: StringName`,
`hours: int`, `blocks: int` (= `hours × 3.600.000 ÷ block_ms`), `deposit_ppm: int`.
**Fixture**: `tests/fixtures/data/auction/population.json` con `stack`; casi rifiutati (`tests/core/data/test_data_validator_auction.gd`): `stack` 0 o assente, `ask_max_pct ≤ ask_min_pct`,
`fill_max_pct` 100, `min_listings > max_listings`, durata con id doppio o ore non multiple del blocco, vincolo di non-arbitraggio violato (es. `ask_max_pct` 80), chiave sconosciuta.

## 32.5 Posta: `balance.json` `mail` e `data/mail/templates.json` (M27-05)
```json
"mail": {"capacity": 50}
```
```json
{"templates": [
  {"kind": "auction_sold", "sender": "Casa d'Aste", "subject": "<testo originale con {item}>", "body": "<testo originale con {qty}, {item}, {price}, {money}>"},
  {"kind": "auction_sale", "sender": "Casa d'Aste", "subject": "…", "body": "…"},
  {"kind": "auction_expired", "sender": "Casa d'Aste", "subject": "…", "body": "…"},
  {"kind": "auction_cancelled", "sender": "Casa d'Aste", "subject": "…", "body": "…"}]}
```
| Campo | Tipo | Vincoli |
|---|---|---|
| `mail.capacity` | int | ≥ 1 |
| `templates[].kind` | String | uno di `MailBox.KINDS`; ogni tipo ha **almeno un** modello (varianti ammesse) |
| `sender`, `subject`, `body` | String | non vuoti; `subject` ≤ 60 caratteri, `body` ≤ 240; segnaposto solo `{item}`, `{qty}`, `{price}`, `{money}` (graffe bilanciate) |
Classe `MailTemplateDef` (`core/data/defs/mail_template_def.gd`): `kind: StringName`, `sender`, `subject`, `body: String`. Accessore `GameData.mail_templates(kind) -> Array[MailTemplateDef]`
(ordine di file). Testi **originali in italiano**, brevi e "carini" (nessuna frase da WoW o Melvor). Fixture: `tests/fixtures/data/mail/templates.json` con un modello per tipo; casi
rifiutati: tipo sconosciuto, tipo senza modelli, segnaposto sconosciuto, `body` troppo lungo, `capacity` 0.

## 32.6 Guida
`DataValidatorGuide.ROUTES` aggiunge `"mail"`. Pagine scritte a mano (≤ 160 parole, `test_guide_texts`): `data/guide/monete.json` (M27-03), `data/guide/posta.json` (M27-07),
`data/guide/casa_aste.json` aggiornata (M27-08). Nessun numero copiato dalle formule.
