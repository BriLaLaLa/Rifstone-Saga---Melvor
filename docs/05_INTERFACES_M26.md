# 05. Interfacce, M26: Alpha 2 (§1c, §3d, §4c, §5.35-§5.37, §6d, §7.r)

Estensione di `05_INTERFACES.md` (che supera le 400 righe): **è contratto** con le stesse regole (lo modifica solo il Reviewer; un task che ha bisogno di una firma
nuova si ferma e la chiede). Dove contraddice `05_INTERFACES.md`, `_M24` o `_M25` vale questo file. Design `01_GDD_M26.md` (§38), formule `02_FORMULAS_M26.md`
(F-166…F-176), dati `04_DATA_SCHEMA_M26.md` (§31). Accanto a ogni firma il task che la scrive.

## 1c. Motivi
**Nessun motivo nuovo**: si usano `recipe_known`, `recipe_unknown`, `invalid_amount`, `max_purchases`, `requirement_not_met`, `not_enough_gold`, `bank_full`, `missing_inputs`.
Il conteggio di `tests/core/common/test_reasons.gd` non cambia.

## 3d. Segnali
**Nessun segnale nuovo.** `shop_purchased(entry_id, count)` (§3): anche da `Shop.buy_many`, **una volta**, con `count` = acquisti totali della voce dopo l'operazione.
La UI della professione si aggiorna con i segnali esistenti: `level_up`, `xp_gained`, `skill_reset`, `recipe_learned`, `bank_changed`, `gold_changed`, `shop_purchased`,
`production_queue_changed`, `discipline_changed`. La Casa d'Aste con `auction_updated` (già emesso a ogni blocco intero).

## 4c. Dati (`core/data/`, M26-02; filone C in M26-08)
```gdscript
# ActionDef: var colors: Dictionary = {}     # §31.1: {&"yellow": int, &"green": int, &"grey": int} o {} ; func has_colors() -> bool
# TrainerDef: var vendor: StringName = &""   # §31.5
# ItemDef: categoria &"reagent" ammessa (nessun campo nuovo)
# GameData (aggiunte)
func shop_entries_of_vendor(vendor: StringName) -> Array[ShopEntryDef]   # ordine di file; [] se nessuna
func shop_entry_selling(item_id: StringName) -> ShopEntryDef             # la voce con effect.item = item_id; null se nessuna (nessun errore)
# M26-08 (filone C): AuctionParams guadagna pop_ref, pop_period_blocks, pop_var_ppm, pop_press_ppm, pop_demand_ppm (int) e bands: Array[AuctionPopulationBand]
class_name AuctionPopulationBand extends RefCounted   # core/data/defs/auction_population_band.gd
var max_value: int = -1; var buyers: int = 0; var sellers: int = 0
```
Validatori: `DataValidatorProfessions` (nuovo, regole di §31.1-§31.5, §31.8); `DataValidatorItems` (`SHOP_VENDORS` + `falegname`, `cuoco`; `SHOP_CATEGORIES` + `profession`;
categoria `reagent`); `DataValidatorDisciplines` (regola cambiata delle Ricette: drop **o** shop, §31.2); `DataValidatorAuction` (§31.7). `Bank.SORT_CATEGORIES` + `reagent`.

## 5.35 Professioni (`systems/professions/`, M26-03) — dipendenze: data, events, skills, disciplines (solo `knows_recipe`, `is_learned`)
```gdscript
class_name ProfessionMath extends RefCounted     # systems/professions/profession_math.gd — logica pura, interi, nessuno stato
const PPM := 1000000
static func color_id(colors: Dictionary, level: int) -> StringName      # F-167: &"orange" | &"yellow" | &"green" | &"grey"; &"" se colors vuoto
static func chance_ppm(colors: Dictionary, level: int) -> int           # F-167: 0..PPM; PPM se colors vuoto
static func split_xp(xp: int, chance: int, frac: int) -> Vector2i       # F-168: (base, nuovo frac); xp < 0 o frac fuori 0..PPM-1 → Log.error e (0, 0)

class_name Professions extends RefCounted        # systems/professions/professions.gd
const SAVE_KEY := &"professions"
func _init(session: GameSession) -> void
func recipe_color(action_id: StringName) -> Dictionary   # {"id": StringName, "chance_ppm": int} al livello attuale; {"id": &"", "chance_ppm": PPM} senza colors; {} se sconosciuta o non artisan
func craft_xp_base(action: ActionDef) -> int             # F-168: aggiorna frac(skill) e restituisce base (0..); lo chiama SOLO ArtisanResolver, una volta per ciclo completato
func frac(skill_id: StringName) -> int                   # 0..PPM-1
func recipe_source(action_id: StringName) -> StringName  # F-169: &"trainer" | &"scheme" | &"drop"; &"" se sconosciuta, non artisan o single
func scheme_entry(action_id: StringName) -> StringName   # id della voce dello shop che vende la Ricetta dell'azione; &"" se nessuna
func vendor(skill_id: StringName) -> StringName          # TrainerDef.vendor; &"" se nessuno
func unlocks(skill_id: StringName) -> Array[Dictionary]  # F-169: [{"level": int, "kind": &"trainer"|&"scheme"|&"reagent", "id": StringName}] (azione per trainer, voce dello shop per gli altri)
func next_unlocks(skill_id: StringName, count: int) -> Array[Dictionary]   # le prime `count` voci di unlocks con level > livello attuale
func new_game() -> void; func to_save() -> Dictionary; func from_save(d: Dictionary) -> void
```
- **Aggancio** (M26-03): in `ArtisanResolver.resolve` la riga `outcome.xp = session.skills.add_xp(action.skill_id, action.xp, ctx)` diventa
  `var base: int = session.professions.craft_xp_base(action)` e, se `base > 0`, `outcome.xp = session.skills.add_xp(action.skill_id, base, ctx)` (altrimenti 0). Nessun altro
  punto cambia: `EngraverResolver`, `BlueprintCraft`, `GatheringResolver`, ricompense della Bacheca e smantellamento chiamano `add_xp` come oggi (Q148, Q156). Con
  `session.professions == null` (sessioni di test minime) il resolver usa `action.xp` come oggi.
- `craft_xp_base` legge il livello con `skills.get_level` **prima** dell'XP del ciclo; non emette segnali; non tira numeri casuali.
- Ascolta `skill_reset(s)`: `frac(s)` a 0. `from_save` tollerante (`Log.warn`): `frac` non oggetto → vuoto; skill sconosciuta o senza ricette con `colors` → scartata; valore non intero o
  fuori `0..PPM-1` → 0. `to_save`: `{"frac": {skill: int}}` solo per `frac > 0` (ordine `order`). Nessun segnale in `new_game`/`from_save`.
- **Sessione**: `var professions: Professions` (M26-03), creato dopo `disciplines` e prima di `actions`; `_join(Professions.SAVE_KEY, …)` senza `rebuild_fn` e senza fase di `advance`.
  `MAX_SESSION_LINES` di `tests/core/session/test_game_session.gd` da 240 a **243** (commento con M26-03).

## 5.36 Shop, Bacheca e migrazione (M26-06)
```gdscript
# Shop (aggiunte; dipendenza nuova: disciplines, letta pigra come village)
func can_buy_many(entry_id: StringName, count: int) -> CommandResult
    # in ordine: invalid_amount (count ≤ 0, o count > 1 su una voce con max_purchases ≠ 0), unknown_id, max_purchases, requirement_not_met, recipe_known, not_enough_gold (count × price), bank_full, armory_full
func buy_many(entry_id: StringName, count: int) -> CommandResult
    # stessi controlli; poi oro count × price speso, effetto applicato count volte (item: qty × count in un solo bank.add), acquisti += count, shop_purchased una volta
```
- `can_buy(entry_id)` = `can_buy_many(entry_id, 1)`; `buy(entry_id)` = `buy_many(entry_id, 1)` (firme e comportamento invariati salvo il controllo nuovo).
- **`recipe_known`** (nuovo controllo, dopo `requirement_not_met`): la voce dà un oggetto `recipe` e `disciplines.knows_recipe(recipe_action)` è vero. Senza `disciplines` nessun controllo.
- **Quests** (F-135, §38.4): un incarico `craft` è candidato solo se l'azione che produce il suo `item` è nota (`disciplines.knows_recipe`); nessun'altra modifica.
- **TestFactory** (`tests/`, li scrive M26-02, li usa M26-04 per riallineare i test): helper `teach_recipes(session, skill_id)` che segna note tutte le ricette `discover` di una skill (uso: test esistenti sui dati veri che mettono in coda
  ricette diventate schemi) e `give_reagents(session, skill_id, qty)`. Gli helper **non** cambiano ciò che i test verificano.
- `SaveMigrator.CURRENT_VERSION` = **10**.

## 5.37 Casa d'Aste a popolazione (M26-08; sostituisce in parte §5.30 di `05_INTERFACES.md`)
```gdscript
# AuctionMath (aggiunte; funzioni pure, interi)
static func wave(item_id: StringName, kind: String, seed_value: int, block: int, p: AuctionParams) -> int   # F-173: w_k (kind "b" o "s")
static func band_of(value: int, p: AuctionParams) -> AuctionPopulationBand                              # F-172: prima fascia con value ≤ max_value (l'ultima se nessuna)
static func population(b0: int, s0: int, wb: int, ws: int) -> Vector2i                                  # F-173: (B, Sv)
static func pressure(buyers: int, sellers: int, p: AuctionParams) -> int                                # F-173
static func liquidity(value: int, band: AuctionPopulationBand, p: AuctionParams) -> Dictionary          # F-172: {"step": int, "rec": int, "refill": int}
static func sale_sum_ppm(eq_ppm: int, sat_ppm: int, qty: int, p: AuctionParams, step_ppm: int = -1) -> int   # CAMBIATA: step_ppm -1 = p.step_ppm (chiamate di oggi invariate)
# AuctionPricing (aggiunta; resto invariato nelle firme, F-174…F-176 dentro)
func population(item_id: StringName) -> Dictionary      # {"buyers": int, "sellers": int, "demand": &"high"|&"normal"|&"low"}; {} se non nell'elenco
# AuctionHouse (aggiunta, pass-through per la UI)
func population(item_id: StringName) -> Dictionary
```
- `AuctionPricing` calcola alla creazione, per ogni oggetto, fascia e liquidità (F-172, costanti); `eq` = F-174; `record_sale` usa `STEP_i`; `advance` usa `REC_i` e `r_i` (F-175);
  `trend` usa F-176. Il confine di V15 resta: `AuctionHouse` e la UI non conoscono la formula.
- **Save invariato** (`modules.auction` come §5.30): nessun campo nuovo; un save v9 si carica uguale (la popolazione non ha stato).
- Test esistenti: `test_auction_math.gd` invariato (le funzioni di M23 non cambiano); `test_auction_pricing.gd`/`test_auction_house.gd` aggiornano i numeri che dipendono da `eq` con gli
  esempi di F-174…F-176 (gli oggetti della fascia 3 tengono quelli di F-148…F-150). Nuovo `tests/systems/auction/test_auction_population.gd`.

## 6d. Salvataggio v10 (M26-03 additivo, M26-06 migrazione)
```json
"professions": {"frac": {"forging": 250000}},
"disciplines": {"learned": {"forging": 3, "hearthcraft": 2}, "recipes": ["brew_tonic_1", "forge_ashlead_plate", "forge_stormzinc_plate", "cook_ashgill"], "extra": []}
```
- **`professions`**: additivo (assente = tutto 0). Lo scrive M26-03 senza cambiare la versione; la versione passa a 10 con la migrazione (M26-06).
- **`core/save/migrations/migration_9_to_10.gd`** (`static func migrate(d) -> Dictionary`, copia profonda; legge `res://data/config/balance.json` (`xp_curve`) e
  `res://data/actions/*.json` (livello e skill delle azioni), come le migrazioni precedenti). Costante storica **`V10_SCHEMES: Array[String]`** (congelata, non dai dati):
  `forge_{ashlead,stormzinc,duskcobalt,glimmerite,palecinnabar,emberheart,riftite}_plate`; `carve_{ashpine,thornalder,duskelm,shardcedar,veilcypress,emberlarch,riftspruce}_shieldcore`;
  `carve_{…stessi legni…}_handle`; `cook_{ashgill,redscale,dusk_eel,shard_gar,mist_barbel,ember_sturgeon,riftmaw}` (28 id). In `modules`:
  1. per ogni `a` in `V10_SCHEMES` con skill `s` appresa (`disciplines.learned[s]` ≥ 1) e `level_for_xp(skills[s].xp) ≥ level(a)` → `a` in `disciplines.recipes` (se manca);
  2. ogni `a` in `V10_SCHEMES` che compare in `actions.jobs` → in `disciplines.recipes`;
  3. un `a` sconosciuto nei dati attuali → saltato (`Log.warn`); tutto il resto invariato (nessun reagente, nessun acquisto dello shop, nessuna XP).
- Catena: v5…v9 → v10. Test: `tests/core/save/test_migration_9_to_10.gd` (casi in `07_TASKS_M26.md`, M26-06); i test che controllano `CURRENT_VERSION` = 9 passano a 10.

## 7.r UI di M26 (nessuno stato di gioco nella UI; `01_GDD_M26.md` §38.8)
- **M26-05 (colori e sblocchi)**: `ui/pages/skill/recipe_row.gd` colora il nome con `CombatTexts.NODE_COLORS[recipe_color.id]` (nessun colore se `id` vuoto); `recipe_detail.gd` mostra
  "Avanzamento: n%" (`chance_ppm`, solo formattazione) e l'origine (`recipe_source`, `scheme_entry` → prezzo e livello letti da `GameData`/`Shop.price`); riquadro nuovo
  `profession_unlocks.gd` (`next_unlocks(skill, 3)`). Filtro "Solo creabili" invariato.
- **M26-07 (mercante)**: scheda **Mercante** nella pagina della professione (`merchant_panel.gd`, nuovo): voci di `GameData.shop_entries_of_vendor(Professions.vendor(skill))`; schemi con
  stato (bloccato con livello, acquistabile, comprato e da imparare → "Impara ora" = `Disciplines.learn_recipe(item)`, noto), reagenti con posseduti e "Compra" 1/10/100
  (`Shop.buy_many`); motivi dei pulsanti disabilitati da `can_buy_many`. Pagina Shop: nomi delle botteghe `falegname`, `cuoco` in `shop_texts.gd`.
- **M26-10 (Casa d'Aste)**: `auction_detail.gd` mostra compratori, venditori e domanda (`AuctionHouse.population`), testi in `auction_texts.gd`.
- Un solo smoke test per pagina toccata; nessun test su testi esatti.
- **Limiti noti (M26-12)**: `auction_detail.gd` non mostra la fascia di valore (resta interna ad `AuctionPricing`: mostrarla chiede una lettura additiva in `population`);
  nessuna vista "Le mie vendite"; nessun sottogruppo dei Materiali (`01_GDD_M26.md` §38.10). Da decidere dopo Alpha 2.
