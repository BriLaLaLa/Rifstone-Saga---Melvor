class_name BagTexts
extends RefCounted
## Italian texts of the bag slots bar (docs/05_INTERFACES.md §7.w), display only.

const TITLE_TEXT: String = "Slot borsa"
const EMPTY_SLOT_TEXT: String = "Vuoto"
const FILLED_TEXT: String = "%s (+%s)"
const EMPTY_TOOLTIP: String = "Slot libero: scegli una borsa dal Deposito."
const FILLED_TOOLTIP: String = "Clicca per togliere la borsa dallo slot."
const NO_BAGS_TEXT: String = "Nessuna borsa nel Deposito."
const PICK_TEXT: String = "%s (+%s caselle)"
## Reason of a refused bag command -> text; other reasons: REFUSED_DEFAULT.
const REFUSED: Dictionary[StringName, String] = {
	Reasons.DEPOSIT_NOT_EMPTY: "Libera prima le caselle in più: il Deposito non basterebbe senza questa borsa.",
	Reasons.BAG_SLOT_OCCUPIED: "Lo slot è già occupato: togli prima la borsa.",
	Reasons.NOT_A_BAG: "Questo oggetto non è una borsa.",
	Reasons.NOT_ENOUGH_ITEMS: "Non hai questa borsa nel Deposito.",
	Reasons.UNKNOWN_ID: "Borsa sconosciuta.",
	Reasons.SLOT_EMPTY: "Lo slot è già vuoto.",
	Reasons.INVALID_AMOUNT: "Slot non valido.",
}
const REFUSED_DEFAULT: String = "Operazione non riuscita."
const NO_FREE_SLOT_TEXT: String = "Tutti gli slot borsa sono occupati."


static func refused(reason: StringName) -> String:
	return REFUSED.get(reason, REFUSED_DEFAULT)
