class_name AuctionDetailTexts
extends RefCounted
## Texts and presentation helpers of the Auction House detail panel (M37-3). Italian strings; no game state.

const SECTION_NOW_TEXT: String = "Subito"
const SECTION_LIST_TEXT: String = "Inserzione"
const SECTION_MARKET_TEXT: String = "Mercato"
const SECTION_IDS: Array[StringName] = [&"now", &"list", &"market"]
const SECTION_NAMES: Dictionary[StringName, String] = {
	&"now": SECTION_NOW_TEXT,
	&"list": SECTION_LIST_TEXT,
	&"market": SECTION_MARKET_TEXT,
}
const MAX_TEXT: String = "Compra max"
const BASE_VALUE_TEXT: String = "Valore base: %s"
const GAP_ABOVE_TEXT: String = "%s sulla media"
const GAP_FLAT_TEXT: String = "In media"
const AVG_PER_PIECE_TEXT: String = "Ricavo medio per pezzo: %s"
const GAP_NONE_TEXT: String = ""
const AVAILABLE_TEXT: String = "Disponibili: %s"
const AVAILABLE_TOOLTIP_TEXT: String = "Somma delle inserzioni dei venditori, meno i pezzi già presi."
const SOLD_OUT_TEXT: String = "Esaurito, torna tra ~%d min"
const REF_TEXT: String = "Media 12 h: %s"
const CONFIRM_TITLE_TEXT: String = "Acquisto enorme"
const CONFIRM_OK_TEXT: String = "Compra"
const CONFIRM_CANCEL_TEXT: String = "Annulla"
const CONFIRM_BODY_TEXT: String = "Stai per comprare %s x %s.\nTotale: %s\nPrezzo medio: %s per pezzo\nQuota del libro: %s %%"
const PPM: int = 1000000
const MIN_MS: int = 60000
## A gap this close to zero (in %) is neutral, not good or bad (§45.3).
const FLAT_LIMIT: int = 1


## "▲ +12 % sulla media", "▼ -8 % sulla media", "= In media" (inside ±1 %); `gap` comes from `AuctionHouse.price_gap`.
static func gap_text(gap: int) -> String:
	if absi(gap) <= FLAT_LIMIT:
		return "= " + GAP_FLAT_TEXT
	var arrow: String = "▲ " if gap > 0 else "▼ "
	return arrow + GAP_ABOVE_TEXT % ("%+d %%" % gap)


## Green = convenient (Compra below the average, Vendi above it), red = not, gold = neutral.
static func gap_color(gap: int, mode: StringName) -> Color:
	if absi(gap) <= FLAT_LIMIT:
		return UiStyle.GOLD
	var good: bool = gap < 0 if mode == &"buy" else gap > 0
	return UiStyle.GOOD if good else UiStyle.BAD


## «Esaurito, torna tra ~N min»; `restock_ms` from `AuctionHouse.restock_ms` (at least 1 min, rounded up).
static func sold_out_text(restock_ms: int) -> String:
	return SOLD_OUT_TEXT % maxi(1, (restock_ms + MIN_MS - 1) / MIN_MS)


## Body of the confirmation: every number comes from `buy_preview` (`total`, `avg`, `share_ppm`); only formatted here.
static func confirm_text(item_name: String, qty: int, preview: Dictionary, currency: CurrencyParams) -> String:
	var share: int = (int(preview["share_ppm"]) + PPM / 200) / (PPM / 100)
	return CONFIRM_BODY_TEXT % [NumberFormat.format_int(qty), item_name, Money.text(int(preview["total"]), currency),
			Money.text(int(preview["avg"]), currency), str(share)]
