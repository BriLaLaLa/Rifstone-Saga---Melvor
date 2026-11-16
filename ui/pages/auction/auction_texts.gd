class_name AuctionTexts
extends RefCounted
## Italian texts of the Auction House page (docs/01_GDD.md §34.7, docs/05_INTERFACES.md §7.p). Presentation only: no game number here.

const TITLE_TEXT: String = "Casa d'Aste"
const TAB_SELL_TEXT: String = "Vendi"
const TAB_BUY_TEXT: String = "Compra"
const NOT_BUILT_TEXT: String = "Costruisci la Casa d'Aste al Villaggio"
const EMPTY_SELL_TEXT: String = "Non hai niente da vendere qui."
const EMPTY_BUY_TEXT: String = "Niente da comprare."
const GOLD_TEXT: String = "Oro: %s"
const OWNED_TEXT: String = "Posseduti: %s"
const PRICE_TEXT: String = "%s oro a pezzo"
const DEPOSIT_TEXT: String = "Al Deposito: %s"
const STOCK_TEXT: String = "Scorta: %s/%s"
const REQUIRES_TEXT: String = "Richiede Casa d'Aste %s"
const TOTAL_TEXT: String = "Totale: %s oro"
const ALL_TEXT: String = "Tutti"
const SOLD_TEXT: String = "Venduti %s x %s per %s oro."
const BOUGHT_TEXT: String = "Comprati %s x %s per %s oro."
## Presentation of the trend read from `AuctionHouse.trend`.
const TREND: Dictionary[StringName, String] = {
	&"up": "In salita",
	&"down": "In calo",
	&"stable": "Stabile",
}
## Reason of `can_sell` / `can_buy` -> text; other reasons: REFUSED_TEXT_DEFAULT.
const REFUSED: Dictionary[StringName, String] = {
	Reasons.INVALID_AMOUNT: "Quantità non valida.",
	Reasons.UNKNOWN_ID: "Oggetto sconosciuto.",
	Reasons.NOT_TRADABLE: "Non si scambia qui.",
	Reasons.REQUIREMENT_NOT_MET: "Casa d'Aste di livello troppo basso.",
	Reasons.ITEM_LOCKED: "Oggetto bloccato nel Deposito.",
	Reasons.NOT_ENOUGH_ITEMS: "Non ne hai abbastanza.",
	Reasons.NOT_SELLABLE: "Il totale sarebbe 0 oro.",
	Reasons.OUT_OF_STOCK: "Scorta esaurita.",
	Reasons.NOT_ENOUGH_GOLD: "Oro insufficiente.",
	Reasons.BANK_FULL: "Il Deposito è pieno.",
}
const REFUSED_TEXT_DEFAULT: String = "Operazione non riuscita."


static func refused(reason: StringName) -> String:
	return REFUSED.get(reason, REFUSED_TEXT_DEFAULT)


static func trend_text(trend: StringName) -> String:
	return TREND.get(trend, TREND[&"stable"])
