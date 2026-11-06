class_name LoadoutTexts
extends RefCounted
## Texts of the loadout panel of the character page (traits and abilities of the class), in Italian.

const PANEL_TITLE: String = "Tratti e abilità"
const TRAITS_TITLE: String = "Tratti"
const ABILITIES_TITLE: String = "Abilità"
const SLOTS_OPEN_TEXT: String = "Slot aperti: %d di %d"
const SLOTS_NEXT_TEXT: String = "Slot aperti: %d di %d (il prossimo al livello %d)"
const UNLOCK_TEXT: String = "Si sblocca al livello %d"
const UNLOCKED_TEXT: String = "Sbloccata dal livello %d"
const SLOT_CHOSEN_TEXT: String = "Scelta nello slot %d"
const NO_FREE_SLOT_TEXT: String = "Tutti gli slot aperti sono occupati: togli prima una scelta."
const NOT_FOR_SETUP_TEXT: String = "Non con l'assetto attuale: resta nello slot ma non è attiva."
const COMBAT_ACTIVE_TEXT: String = "Durante un incontro non si può cambiare la scelta."
const REASON_TEXTS: Dictionary[StringName, String] = {
	Reasons.SLOT_LOCKED: "Lo slot non è ancora aperto.",
	Reasons.UNKNOWN_ID: "Scelta non valida.",
	Reasons.LEVEL_TOO_LOW: "Non hai ancora il livello richiesto.",
	Reasons.REQUIREMENT_NOT_MET: "È già scelto in un altro slot.",
	Reasons.COMBAT_ACTIVE: "Non puoi cambiare durante un incontro.",
}
const REASON_DEFAULT_TEXT: String = "Operazione non riuscita."
