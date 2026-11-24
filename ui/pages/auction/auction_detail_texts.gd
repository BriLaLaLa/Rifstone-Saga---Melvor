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
