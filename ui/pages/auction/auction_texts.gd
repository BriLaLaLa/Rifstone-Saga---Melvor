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
const STOCK_TEXT: String = "Scorta: %s/%s"
const REQUIRES_TEXT: String = "Richiede Casa d'Aste %s"
const TOTAL_TEXT: String = "Totale: %s"
const ALL_TEXT: String = "Tutti"
const SOLD_TEXT: String = "Venduti %s x %s per %s."
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
const AVAILABLE_TEXT: String = "%s/%s"
const REQUIRES_SHORT_TEXT: String = "Liv. %s"
const SORT_ASC_TEXT: String = " ▲"
const SORT_DESC_TEXT: String = " ▼"
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
	Reasons.OUT_OF_STOCK: "Scorta esaurita.",
	Reasons.NOT_ENOUGH_GOLD: "Monete insufficienti.",
	Reasons.BANK_FULL: "Il Deposito è pieno.",
}
const REFUSED_TEXT_DEFAULT: String = "Operazione non riuscita."


static func refused(reason: StringName) -> String:
	return REFUSED.get(reason, REFUSED_TEXT_DEFAULT)


static func trend_text(trend: StringName) -> String:
	return TREND.get(trend, TREND[&"stable"])


static func trend_arrow_text(trend: StringName) -> String:
	return TREND_ARROWS.get(trend, TREND_ARROWS[&"stable"]) + trend_text(trend)


static func demand_text(demand: StringName) -> String:
	return DEMAND.get(demand, DEMAND[&"normal"])


static func demand_hint(demand: StringName) -> String:
	return DEMAND_HINTS.get(demand, DEMAND_HINTS[&"normal"])


static func category_name(category: StringName) -> String:
	return CATEGORIES.get(category, String(category).capitalize())
