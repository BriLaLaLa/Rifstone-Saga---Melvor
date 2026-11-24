class_name AuctionTexts
extends RefCounted
## Italian texts of the Auction House page (docs/01_GDD.md §34.7, docs/05_INTERFACES.md §7.p). Presentation only: no game number here.

const TITLE_TEXT: String = "Casa d'Aste"
const LEVEL_TEXT: String = "Livello %s"
const TAB_SELL_TEXT: String = "Vendi"
const TAB_BUY_TEXT: String = "Compra"
const NOT_BUILT_TEXT: String = "Costruisci la Casa d'Aste al Villaggio"
const EMPTY_SELL_TEXT: String = "Non hai niente da vendere qui."
const EMPTY_BUY_TEXT: String = "Niente da comprare."
const EMPTY_FILTER_TEXT: String = "Nessun oggetto corrisponde alla ricerca."
const GOLD_CAPTION: String = "Monete:"
const OWNED_TEXT: String = "Posseduti: %s"
const PRICE_TEXT: String = "%s a pezzo"
const DEPOSIT_TEXT: String = "Al Deposito: %s"
const REQUIRES_TEXT: String = "Richiede Casa d'Aste %s"
const TOTAL_TEXT: String = "Totale: %s"
const ALL_TEXT: String = "Tutti"
const SOLD_TEXT: String = "Venduti %s x %s per %s. Il ricavo ti aspetta in Posta."
const BOUGHT_TEXT: String = "Comprati %s x %s per %s."
## Search field, category tree, list columns and detail panel.
const SEARCH_PLACEHOLDER_TEXT: String = "Cerca per nome"
const ALL_CATEGORIES_TEXT: String = "Tutte le categorie"
const CATEGORY_COUNT_TEXT: String = "%s (%s)"
const COLUMN_NAME_TEXT: String = "Oggetto"
const COLUMN_OWNED_TEXT: String = "Posseduti"
const COLUMN_AVAILABLE_TEXT: String = "Disponibili"
const COLUMN_PRICE_TEXT: String = "Prezzo"
const COLUMN_TREND_TEXT: String = "Tendenza"
const COLUMN_DEPOSIT_TEXT: String = "Al Deposito"
const AVAILABLE_TEXT: String = "%s"
const REQUIRES_SHORT_TEXT: String = "Liv. %s"
const SORT_ASC_TEXT: String = " ▲"
const SORT_DESC_TEXT: String = " ▼"
## Book, instant sale, listing form and "Le mie inserzioni" (M27-08).
const TAB_MINE_TEXT: String = "Le mie vendite"
const SELL_NOW_TEXT: String = "Vendi subito"
const SELL_NOW_NOTE_TEXT: String = "Il ricavo arriva in Posta."
const BOOK_TITLE_TEXT: String = "Inserzioni, dalla meno cara"
const BOOK_EMPTY_TEXT: String = "Nessuna inserzione in vendita."
const BOOK_QTY_TEXT: String = "x %s"
const BOOK_MINE_TEXT: String = "(tua)"
const LISTINGS_TEXT: String = "Inserzioni: %s, pezzi: %s"
const LIST_TITLE_TEXT: String = "Metti in vendita"
const LIST_BUTTON_TEXT: String = "Metti in vendita"
const SUGGESTED_TEXT: String = "Prezzo suggerito"
const DURATION_TEXT: String = "Durata: %s ore"
const DEPOSIT_LIST_TEXT: String = "Deposito (non rimborsato): %s"
const NET_TEXT: String = "Ricavo se vendi tutto: %s"
const LISTED_TEXT: String = "Messi in vendita %s x %s."
const CANCELLED_TEXT: String = "Inserzione annullata: gli oggetti tornano per Posta."
const MINE_COUNT_TEXT: String = "Inserzioni attive: %s su %s"
const MINE_NOTE_TEXT: String = "Gli incassi e le inserzioni scadute arrivano in Posta. Annullando, il deposito non torna."
const MINE_EMPTY_TEXT: String = "Non hai inserzioni attive."
const MINE_SOLD_TEXT: String = "Venduti"
const MINE_TIME_TEXT: String = "Resta"
const MINE_STATUS_TEXT: String = "Stato"
const CANCEL_TEXT: String = "Annulla"
const STATUS: Dictionary[StringName, String] = {
	&"selling": "In vendita",
	&"undercut": "Superata da prezzi più bassi",
}
const STATUS_PARTIAL_TEXT: String = "%s, venduta in parte"
const TIME_HOURS_TEXT: String = "%s h %s min"
const TIME_MINUTES_TEXT: String = "%s min"
const SELECT_ITEM_TEXT: String = "Seleziona un oggetto"
const QUANTITY_TEXT: String = "Quantità"
const UNIT_PRICE_TEXT: String = "Prezzo unitario"
const UNIT_PRICE_VALUE_TEXT: String = "%s"
## Market population block of the detail panel (values come from `AuctionHouse.population`).
const MARKET_TITLE_TEXT: String = "Mercato"
const BUYERS_TEXT: String = "Compratori: %s"
const SELLERS_TEXT: String = "Venditori: %s"
const DEMAND_TEXT: String = "Domanda: %s"
const DEMAND: Dictionary[StringName, String] = {
	&"high": "Alta",
	&"normal": "Nella media",
	&"low": "Bassa",
}
const DEMAND_HINTS: Dictionary[StringName, String] = {
	&"high": "Molti compratori: il mercato assorbe bene le vendite.",
	&"normal": "Il mercato è in equilibrio.",
	&"low": "Pochi compratori: i prezzi scendono più in fretta.",
}
## Item category (`ItemDef.category`) -> Italian name shown in the tree.
const CATEGORIES: Dictionary[StringName, String] = {
	&"material": "Materiali",
	&"stone": "Pietre",
	&"currency": "Valute",
	&"equipment": "Equipaggiamento",
	&"tool": "Attrezzi",
	&"food": "Consumabili",
	&"infusion": "Rune",
	&"misc": "Varie",
	&"bag": "Borse",
	&"recipe": "Ricette",
	&"component": "Componenti",
	&"blueprint": "Progetti",
	&"map": "Mappe",
}
## Presentation of the trend read from `AuctionHouse.trend`.
const TREND: Dictionary[StringName, String] = {
	&"up": "In salita",
	&"down": "In calo",
	&"stable": "Stabile",
}
const TREND_ARROWS: Dictionary[StringName, String] = {
	&"up": "▲ ",
	&"down": "▼ ",
	&"stable": "= ",
}
## Reason of `can_sell` / `can_buy` -> text; other reasons: REFUSED_TEXT_DEFAULT.
const REFUSED: Dictionary[StringName, String] = {
	Reasons.INVALID_AMOUNT: "Quantità non valida.",
	Reasons.UNKNOWN_ID: "Oggetto sconosciuto.",
	Reasons.NOT_TRADABLE: "Non si scambia qui.",
	Reasons.REQUIREMENT_NOT_MET: "Casa d'Aste di livello troppo basso.",
	Reasons.ITEM_LOCKED: "Oggetto bloccato nel Deposito.",
	Reasons.NOT_ENOUGH_ITEMS: "Non ne hai abbastanza.",
	Reasons.NOT_SELLABLE: "Il totale sarebbe 0 monete.",
	Reasons.OUT_OF_STOCK: "Esaurito.",
	Reasons.NOT_ENOUGH_GOLD: "Monete insufficienti.",
	Reasons.BANK_FULL: "Il Deposito è pieno.",
	Reasons.INVALID_PRICE: "Prezzo non valido: zero o oltre il massimo.",
	Reasons.LISTINGS_FULL: "Hai già il massimo di inserzioni.",
	Reasons.MAILBOX_FULL: "La Posta è piena: ritira qualcosa.",
}
const REFUSED_TEXT_DEFAULT: String = "Operazione non riuscita."
## M37-4: price gap column, filters, post, "Le mie vendite" and history.
const NO_GAP: int = AuctionHouse.NO_GAP
const GAP_NEUTRAL_PCT: int = 1
const COLUMN_GAP_TEXT: String = "% media"
const COLUMN_TOTAL_TEXT: String = "Ricavo totale"
const GAP_NONE_TEXT: String = "–"
const GAP_STABLE_TEXT: String = "= Stabile"
const GAP_UP_TEXT: String = "▲ +%s %%"
const GAP_DOWN_TEXT: String = "▼ −%s %%"
const FILTER_OWNED_TEXT: String = "Posseduti"
const FILTER_BUYABLE_TEXT: String = "Comprabili ora"
const POST_BADGE_TEXT: String = "Posta: %s da ritirare"
const POST_BADGE_EMPTY_TEXT: String = "Posta"
const POST_FULL_TEXT: String = "Posta piena: non puoi vendere né mettere in vendita."
const NOT_LISTED_TEXT: String = "Questo oggetto non si tratta alla Casa d'Aste."
const SECTION_ACTIVE_TEXT: String = "Attive"
const SECTION_HISTORY_TEXT: String = "Storico"
const SUMMARY_TEXT: String = "%s inserzioni, %s pezzi in vendita, incasso atteso netto: "
const CONFIRM_CANCEL_TEXT: String = "Conferma"
const KEEP_TEXT: String = "Indietro"
const CONFIRM_CANCEL_NOTE_TEXT: String = "Già venduta in parte: annullare?"
const HISTORY_EMPTY_TEXT: String = "Nessuna vendita registrata."
const HISTORY_NOTE_TEXT: String = "Le ultime vendite, dalla più recente. Gli acquisti non si registrano."
const COLUMN_KIND_TEXT: String = "Esito"
const COLUMN_QTY_TEXT: String = "Pezzi"
const COLUMN_UNIT_TEXT: String = "Unitario"
const COLUMN_NET_TEXT: String = "Netto"
const COLUMN_AGE_TEXT: String = "Quando"
const KIND: Dictionary[StringName, String] = {
	&"listing_sold": "Venduta",
	&"instant_sold": "Venduta subito",
	&"expired": "Scaduta",
	&"cancelled": "Annullata",
}
const AGE_NOW_TEXT: String = "adesso"
const AGE_MINUTES_TEXT: String = "%s min fa"
const AGE_HOURS_TEXT: String = "%s h fa"
const AGE_DAYS_TEXT: String = "%s g fa"
## Categories in the order of use (not alphabetical); a category that is not here goes last.
const CATEGORY_ORDER: Array[StringName] = [&"component", &"food", &"equipment", &"tool", &"material", &"infusion", &"stone",
		&"bag", &"blueprint", &"recipe", &"map", &"currency", &"misc"]


static func refused(reason: StringName) -> String:
	return REFUSED.get(reason, REFUSED_TEXT_DEFAULT)


static func trend_text(trend: StringName) -> String:
	return TREND.get(trend, TREND[&"stable"])


static func trend_arrow_text(trend: StringName) -> String:
	return TREND_ARROWS.get(trend, TREND_ARROWS[&"stable"]) + trend_text(trend)


static func status_text(status: StringName, partial: bool) -> String:
	var text: String = STATUS.get(status, STATUS[&"selling"])
	return STATUS_PARTIAL_TEXT % text if partial else text


## "3 h 20 min" / "45 min" from a time left in milliseconds (presentation only).
static func time_left_text(ms: int) -> String:
	var minutes: int = maxi(ms, 0) / 60000
	if minutes >= 60:
		return TIME_HOURS_TEXT % [minutes / 60, minutes % 60]
	return TIME_MINUTES_TEXT % minutes


static func demand_text(demand: StringName) -> String:
	return DEMAND.get(demand, DEMAND[&"normal"])


static func demand_hint(demand: StringName) -> String:
	return DEMAND_HINTS.get(demand, DEMAND_HINTS[&"normal"])


static func category_name(category: StringName) -> String:
	return CATEGORIES.get(category, String(category).capitalize())


## "▲ +12 %" / "▼ −8 %" / "= Stabile" (|gap| <= 1 %) / "–" from `AuctionHouse.price_gap` (the module decides the number).
static func gap_text(gap: int) -> String:
	if gap == NO_GAP:
		return GAP_NONE_TEXT
	if absi(gap) <= GAP_NEUTRAL_PCT:
		return GAP_STABLE_TEXT
	return GAP_UP_TEXT % gap if gap > 0 else GAP_DOWN_TEXT % -gap


## Compact amount for the list: with gold, only gold and silver ("12g 5s"); otherwise `Money.text`.
static func money_short(copper: int, currency: CurrencyParams) -> String:
	var parts: Vector3i = Money.split(copper, currency)
	if copper <= 0 or parts.x <= 0:
		return Money.text(copper, currency)
	var text: String = "%s%s" % [NumberFormat.format_compact(parts.x), currency.symbols[&"gold"]]
	if parts.y > 0 and parts.x < 1000:
		text += " %d%s" % [parts.y, currency.symbols[&"silver"]]
	return text


## "adesso" / "12 min fa" / "3 h fa" / "2 g fa" from a duration in milliseconds (`AuctionHouse.history_age_ms`).
static func age_text(ms: int) -> String:
	var minutes: int = maxi(ms, 0) / 60000
	if minutes < 1:
		return AGE_NOW_TEXT
	if minutes < 60:
		return AGE_MINUTES_TEXT % minutes
	if minutes < 1440:
		return AGE_HOURS_TEXT % (minutes / 60)
	return AGE_DAYS_TEXT % (minutes / 1440)


static func kind_text(kind: StringName) -> String:
	return KIND.get(kind, String(kind))


## Index of a category in the order of use (unknown ones last).
static func category_rank(category: StringName) -> int:
	var index: int = CATEGORY_ORDER.find(category)
	return index if index >= 0 else CATEGORY_ORDER.size()
