# 05. Interfacce, M37: Casa d'Aste più bella e comoda (V47)

Estensione di `05_INTERFACES.md` e `05_INTERFACES_M27.md` (contratto: lo cambia solo il Reviewer). Design `01_GDD_M37.md` (§45), formule `02_FORMULAS_M37.md` (F-209…F-213), dati `04_DATA_SCHEMA_M37.md` (§38).
Task: `07_TASKS_M37.md`. **Save v12 → v13** (additivo). Nessun segnale nuovo, nessun motivo di rifiuto nuovo, nessuna formula di prezzo cambiata.

## 5.49 Storico e letture (`systems/auction/`, M37-1)
```gdscript
class_name AuctionHistory extends RefCounted                       # systems/auction/auction_history.gd, F-209; no signals
const KINDS: Array[StringName] = [&"listing_sold", &"instant_sold", &"expired", &"cancelled"]
func _init(params: AuctionParams, data: GameData) -> void
func entries() -> Array[Dictionary]                                # newest first: {"kind","item","qty","unit","net","block","listing"} (copies)
func count() -> int
func record_listing_sold(item_id: StringName, qty: int, unit: int, net: int, block: int, listing: int) -> void   # merges by listing id
func record_instant_sold(item_id: StringName, qty: int, net: int, block: int) -> void
func record_closed(kind: StringName, item_id: StringName, qty: int, unit: int, block: int, listing: int) -> void  # &"expired" or &"cancelled"
func clear() -> void
func to_save() -> Array                                            # [{"k","item","qty","unit","net","block","listing"}]
func from_save(raw: Variant) -> void                               # tolerant (04_DATA_SCHEMA_M37.md §38.2); missing/invalid = empty
static func age_ms(entry_block: int, block_now: int, pending_ms: int, block_ms: int) -> int   # F-212
```
`AuctionHouse` (aggiunte; tutte le altre firme di `05_INTERFACES_M27.md` §5.39 invariate):
```gdscript
const NO_GAP: int = -2147483648                                    # price_gap "not available"
func history() -> Array[Dictionary]                                # AuctionHistory.entries()
func history_age_ms(entry: Dictionary) -> int                      # F-212 (block now and pending_ms from AuctionPricing, block_ms from params)
func price_gap(item_id: StringName, mode: StringName) -> int       # F-210; mode &"buy" | &"sell"; NO_GAP if not available
func max_buyable(item_id: StringName) -> int                       # F-211
func listings_summary() -> Dictionary                              # F-213: {"count","units","expected_net"}
func value_of(item_id: StringName) -> int                          # pass-through of AuctionPricing.value_of (base value, copper); 0 if not listed
func history_max() -> int                                          # auction.history_max
```
Scrittori dello storico (solo in `AuctionHouse`): `_deliver` (eventi `sold` → `record_listing_sold`; `expired` → `record_closed(&"expired", …)`), `sell` (→ `record_instant_sold`), `cancel_listing`
(→ `record_closed(&"cancelled", …)`); `closed` non scrive. `new_game` e `from_save` svuotano/caricano lo storico. Emette `auction_listings_changed` come oggi (nessun segnale nuovo: lo storico cambia
sempre insieme a un evento già esistente: `auction_sold`, `auction_listings_changed`).
`AuctionView` (statici, puri): `static func gap_pct(unit: int, value: int) -> int` (F-210, `NO_GAP`), `static func max_buy(unit: int, stock: int, gold: int) -> int` (F-211 senza il vincolo del Deposito),
`static func summary(listings: Array[Dictionary], quote: Callable) -> Dictionary` (F-213).
`AuctionParams.history_max: int` (balance `auction.history_max`, validato 1..200).

## 6i. Save (v13, `core/save/migrations/migration_12_to_13.gd`)
`auction.history` come in `04_DATA_SCHEMA_M37.md` §38.2. `AuctionHouse.to_save()`: `result["history"] = _history.to_save()`. `SaveMigrator.CURRENT_VERSION` = 13. Gli slot v12 si migrano con `history = []`.

## 7.af Pagina della Casa d'Aste (`ui/pages/auction/`, M37-3, M37-4, M37-5)
Solo UI; nessuno stato di gioco. Presentazione (non salvata): sezione scelta nel dettaglio, filtri, ordinamento, categoria, ultimo oggetto, per scheda.
```gdscript
# AuctionPage (M37-4)
func show_item(item_id: StringName, tab: StringName = &"sell") -> void   # selects the item on `tab`; no-op with a refusal text if the item is not listed
# route: page id &"auction:<item_id>" (page_host route_of/argument_of): bind() calls show_item(argument, &"sell") when the argument is not empty
# AuctionDetail (M37-3): same signals as today (trade_requested, list_requested); new sections "Subito" / "Inserzione" / "Mercato" (SectionBar), fixed footer (TradeButton, MessageLabel)
#   buttons: Shortcut_1, Shortcut_10, Shortcut_100, Shortcut_all, Shortcut_max (Compra only; quantity = max(max_buyable, 1))
# AuctionList (M37-4): sort keys add &"gap" (price_gap) and &"total" (sell tab: sell_quote(owned)); filters FilterOwned, FilterBuyable (CheckButtons in AuctionCategoryTree or the page header)
# AuctionMine (M37-4): tab "Le mie vendite" with two sections Attive / Storico (AuctionHistoryView, new): reads AuctionHouse.my_listings(), listings_summary(), history(), history_age_ms()
# BankItemPanel (M37-5): signal auction_requested(item_id: StringName); BankPage forwards it as page_requested(&"auction:<id>")
```
Nomi dei nodi (per test e screenshot): `SectionBar`, `Section_now`, `Section_list`, `Section_market`, `PriceGapLabel`, `BandLabel`, `PostBadge`, `PostFullLabel`, `HistoryRows`, `MineSummary`,
`Cancel_<id>`, `ConfirmCancel_<id>`, `SellAtAuctionButton` (Deposito).
**Regola dei file di testi**: `ui/pages/auction/auction_texts.gd` lo modifica **solo** M37-4; M37-3 usa un file nuovo `auction_detail_texts.gd`; M37-5 usa `bank_texts.gd`.
