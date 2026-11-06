class_name LoadoutTexts
extends RefCounted
## Texts of the loadout panel of the character page (traits and abilities of the class), in Italian.

const PANEL_TITLE: String = "Tratti e abilità"
const TRAITS_TITLE: String = "Tratti"
const ABILITIES_TITLE: String = "Abilità"
const SLOT_TEXT: String = "Slot %d"
const SLOT_LOCKED_TEXT: String = "Si apre al livello %d"
const EMPTY_TEXT: String = "Vuoto"
const OPTION_LEVEL_TEXT: String = "%s (liv. %d)"
const OPTION_IN_USE_TEXT: String = "%s (già in uso)"
const NOT_FOR_SETUP_TEXT: String = "Non con l'assetto attuale: resta nello slot ma non è attivo."
const COMBAT_ACTIVE_TEXT: String = "Durante un incontro non si può cambiare la scelta."
const REASON_TEXTS: Dictionary[StringName, String] = {
	Reasons.SLOT_LOCKED: "Lo slot non è ancora aperto.",
	Reasons.UNKNOWN_ID: "Scelta non valida.",
	Reasons.LEVEL_TOO_LOW: "Non hai ancora il livello richiesto.",
	Reasons.REQUIREMENT_NOT_MET: "È già scelto in un altro slot.",
	Reasons.COMBAT_ACTIVE: "Non puoi cambiare durante un incontro.",
}
const REASON_DEFAULT_TEXT: String = "Operazione non riuscita."
