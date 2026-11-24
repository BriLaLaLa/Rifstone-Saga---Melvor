# 05. Interfacce, M38: Casa d'Aste, libro unico (V48)

Estensione di `05_INTERFACES.md`, `05_INTERFACES_M27.md` (§5.39) e `05_INTERFACES_M37.md` (§5.49); contratto: lo cambia solo il Reviewer. Design `01_GDD_M38.md` (§46), formule `02_FORMULAS_M38.md` (F-214…F-218),
dati `04_DATA_SCHEMA_M38.md` (§39). Task: `07_TASKS_M38.md`. **Save v13 → v14** (additivo). Nessun segnale nuovo; nessun motivo di rifiuto nuovo (`out_of_stock` cambia significato: nessun pezzo disponibile).

## 5.50 Libro d'acquisto, `taken`, riferimento (`systems/auction/`, M38-1)
```gdscript
# AuctionPricing (aggiunte e modifiche; il resto di 5.30/5.37/5.39 invariato)
func available(item_id: StringName) -> int                          # F-215: max(0, V - taken) at the current block; 0 if not buyable   (REPLACES stock(); stock_max() REMOVED)
func volume(item_id: StringName) -> int                             # V of F-178 now (PNG pieces); 0 if not listed
func taken(item_id: StringName) -> int                              # F-216
func buy_unit(item_id: StringName) -> int                           # F-215: price of the cheapest available piece; 0 if none
func buy_quote(item_id: StringName, qty: int) -> int                # F-215: cost of the qty cheapest available pieces (walk of the book); 0 if qty <= 0, not buyable or qty > available
func buy_book(item_id: StringName) -> Array[Dictionary]             # PNG listings in order: {"j","price"(ask),"buy_price"(F-215),"qty","left"(not yet taken)}
func restock_blocks(item_id: StringName) -> int                     # F-216: blocks until available > 0 (0 if available > 0)
func reference(item_id: StringName, mode: StringName) -> int        # F-214; mode &"buy" | &"sell"; 0 = not available
func record_purchase(item_id: StringName, qty: int) -> void         # taken += qty (F-216)  (kept name; semantic changed from stock -= qty)
func advance(delta_ms: int) -> int                                  # unchanged signature; taken decays by n*r_i (F-216) instead of stock refilling
func to_save() -> Dictionary                                        # "items" without "stock"; plus "taken" (04_DATA_SCHEMA_M38.md §39.2)
```
`AuctionMath` (statici, puri): `static func buy_price_ppm(...)` → sostituire `buy_unit(v, index, params)` con `static func piece_price(ask: int, markup_ppm: int) -> int` (`ceil_div(ask × (PPM + MK), PPM)`), `static func buy_cost(book: Array[Vector2i], taken: int, qty: int, ...)`,
`static func median(values: PackedInt64Array) -> int` (F-214, indice `n ÷ 2`), `static func restock_rate(band: Dictionary, params: AuctionParams) -> int` (`r_i`), `static func eq_min(params, bands) -> int` (EQMIN); **tolti** `stock_max` e `buy_unit` di M23.
`AuctionHouse` (aggiunte; il resto di §5.39 e §5.49 invariato):
```gdscript
func available(item_id: StringName) -> int                          # = AuctionPricing.available            (replaces stock/stock_max, which are REMOVED from AuctionHouse)
func buy_unit(item_id: StringName) -> int                           # price of the cheapest available piece
func buy_book(item_id: StringName) -> Array[Dictionary]
func restock_ms(item_id: StringName) -> int                         # restock_blocks * block_ms - pending_ms (>= 0); 0 if available > 0
func reference_price(item_id: StringName, mode: StringName) -> int  # F-214
func buy_preview(item_id: StringName, qty: int) -> Dictionary       # F-218: {"total","avg","best","share_ppm","premium_ppm","large": bool}; {} if qty <= 0 or nothing available
# price_gap(item, mode) and max_buyable(item): same signatures as M37, new computation (F-210, F-211)
# can_buy(item, qty): out_of_stock if qty > available (was: stock); the other reasons unchanged. buy(item, qty): record_purchase after paying.
```
`buy_preview` è la sola lettura per la conferma di F-218; `AuctionHouse.buy` non conosce la conferma (nessun tetto). Eventi: invariati (`auction_bought`, `auction_updated`); `auction_updated(blocks)` copre anche il rientro di `taken`.
`AuctionView.book(...)` (§5.39) aggiunge a ogni riga PNG `"buy_price"` e `"left"` (le righe del giocatore: 0 e `qty`); `AuctionView.gap_pct(unit, ref)` e `AuctionView.max_buy(...)` calcolano F-210/F-211 con i nuovi argomenti.
`AuctionParams`: `markup_ppm`, `confirm_share_ppm`, `confirm_premium_ppm`, `reference_epochs`, `refill_ppm` (legge `supply`); tolti `stock_gold`, `stock_min`, `stock_max`, `spread_ppm`.

## 6j. Save (v14, `core/save/migrations/migration_13_to_14.gd`)
`auction.taken` come in `04_DATA_SCHEMA_M38.md` §39.2; `auction.items[<id>].stock` non si scrive più. `SaveMigrator.CURRENT_VERSION` = 14. Gli slot v13 si migrano con `taken = {}` e senza `stock`.

## 7.ag Pagina della Casa d'Aste (`ui/pages/auction/`, M38-3, M38-4)
Solo UI; nessuno stato di gioco. Nomi dei nodi nuovi (per test e screenshot): `AvailableLabel` («Disponibili: N» da `available`; spiegazione «somma delle inserzioni» nel tooltip), `SoldOutLabel` («Esaurito, torna tra ~N min» da `restock_ms`),
`RefLabel` («Media 12 h: <prezzo>» da `reference_price`), `BuyConfirm` (dialogo con totale, prezzo medio e quota del libro da `buy_preview`, solo se `large`), `BuyRow_<j>` (riga del libro d'acquisto con `buy_price` e `left`; le righe con `left` 0 sono attenuate).
```gdscript
# AuctionDetail (M38-3): trade_requested(item, qty) emesso come oggi; per Compra, prima di emetterlo chiama AuctionHouse.buy_preview(item, qty) e, se large, mostra BuyConfirm (Annulla / Compra); nessuna conferma altrimenti.
# AuctionList / AuctionRow (M38-4): colonna «Disponibili» = available (senza «/ max»); «% sulla media» = price_gap (F-210); ordinamento per disponibili e per gap; nessun calcolo nella UI.
```
**Regola dei file di testi**: `auction_texts.gd` lo modifica **solo** M38-4; M38-3 usa `auction_detail_texts.gd`. `STOCK_TEXT`/`AVAILABLE_TEXT` con «%d / %d» spariscono: il nuovo testo è «Disponibili: %s».
