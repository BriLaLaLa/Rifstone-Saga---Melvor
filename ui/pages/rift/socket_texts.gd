class_name SocketTexts
extends RefCounted
## Italian texts of the sockets and Rift currencies UI: the piece panel boxes, the bank item panel (docs/01_GDD.md §26).
## Read-only helpers, no state.

const SOCKETS_TITLE_TEXT: String = "Castoni: %d"
const INACTIVE_TITLE_TEXT: String = "%d pietre inattive"
const NO_SOCKETS_TEXT: String = "Il pezzo non ha castoni: salgono con la rarità e con la raffinazione."
const FREE_SOCKET_TEXT: String = "Castone libero"
const INACTIVE_TEXT: String = "inattiva"
const REMOVE_TEXT: String = "Togli pietra"
const CONFIRM_REMOVE_TEXT: String = "Distruggi la pietra"
const CANCEL_TEXT: String = "Annulla"
const REMOVE_WARNING_TEXT: String = "Togliere la pietra la distrugge."
const SOCKET_BUTTON_TEXT: String = "Incastona"
const NO_STONES_TEXT: String = "Non possiedi pietre da incastonare."
const NO_FREE_SOCKET_TEXT: String = "Tutti i castoni sono occupati."
const STONE_OPTION_TEXT: String = "%s  x%s  -  %s"
const CURRENCY_TITLE_TEXT: String = "Valute del Rift"
const NO_CURRENCIES_TEXT: String = "Non possiedi valute del Rift: si cristallizzano con l'Incisore."
const USE_TEXT: String = "Usa valuta"
const CONFIRM_USE_TEXT: String = "Conferma il ritiro"
const FITS_TEXT: String = "Adatta a questo pezzo."
const NOT_FITS_TEXT: String = "Non adatta a questo pezzo: %s"
const REROLL_WARNING_TEXT: String = "Gli affissi attuali andranno persi."
const BANK_SOCKET_TITLE_TEXT: String = "Incastona la pietra su un pezzo"
const BANK_NO_PIECES_TEXT: String = "Nessun pezzo dell'Armeria ha un castone libero."
const BANK_INFUSION_BUTTON_TEXT: String = "Incastona all'Altare"
const SOCKETED_TEXT: String = "Pietra incastonata: %s."
const CLEARED_TEXT: String = "Pietra distrutta."
const CURRENCY_USED_TEXT: String = "Valuta usata: %s."
## Effect of each currency (docs/01_GDD.md §26) and the rarity of the piece it needs.
const EFFECT_TEXTS: Dictionary[StringName, String] = {
	CurrencyUse.TO_MAGIC: "Il pezzo comune diventa magico e riceve affissi nuovi.",
	CurrencyUse.TO_RARE: "Il pezzo magico diventa raro: si aggiungono affissi, quelli attuali restano.",
	CurrencyUse.REROLL: "Gli affissi del pezzo vengono ritirati (la rarità resta la stessa).",
}
const EFFECT_NEEDS_TEXTS: Dictionary[StringName, String] = {
	CurrencyUse.TO_MAGIC: "serve un pezzo comune.",
	CurrencyUse.TO_RARE: "serve un pezzo magico.",
	CurrencyUse.REROLL: "serve un pezzo magico o raro.",
}
## Reasons of a refused socket or currency command on a piece.
const REFUSED_TEXTS: Dictionary[StringName, String] = {
	Reasons.UNKNOWN_ID: "Il pezzo non è più nell'Armeria.",
	Reasons.NOT_EQUIPPABLE: "Questo oggetto non si può usare così.",
	Reasons.SOCKET_LOCKED: "Il pezzo non ha castoni.",
	Reasons.SOCKET_OCCUPIED: "Tutti i castoni del pezzo sono occupati.",
	Reasons.SLOT_EMPTY: "Il castone è già vuoto.",
	Reasons.ITEM_LOCKED: "Il pezzo è bloccato: sbloccalo per modificarlo.",
	Reasons.ITEM_EQUIPPED: "Il pezzo è indossato: rimuovilo prima di usare una valuta.",
	Reasons.REQUIREMENT_NOT_MET: "La rarità del pezzo non è adatta a questa valuta.",
	Reasons.NOT_ENOUGH_ITEMS: "Non possiedi più questo oggetto.",
}


static func refused(reason: StringName) -> String:
	return REFUSED_TEXTS.get(reason, RiftTexts.REFUSED_TEXT_DEFAULT)


## Preview of the effect of `currency` on the piece `inst`: the effect and whether the rarity fits.
static func currency_preview(effect: StringName, inst: ItemInstance) -> String:
	var text: String = EFFECT_TEXTS.get(effect, "")
	if CurrencyUse.accepts(effect, inst.rarity):
		return text + "\n" + FITS_TEXT
	return text + "\n" + NOT_FITS_TEXT % EFFECT_NEEDS_TEXTS.get(effect, "")
