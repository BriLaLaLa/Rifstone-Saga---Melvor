class_name LoadoutTexts
extends RefCounted
## Texts of the loadout panel of the character page (traits and abilities of the class), in Italian.

const PANEL_TITLE: String = "Tratti e abilità"
const TRAITS_TITLE: String = "Tratti"
const ABILITIES_TITLE: String = "Abilità"
const ONLY_CURRENT_TEXT: String = "Solo assetto attuale"
const SLOTS_CAPTION_TEXT: String = "Slot occupati"
const NEXT_SLOT_TEXT: String = "Il prossimo slot si apre al livello %d (aperti %d di %d)"
const ALL_SLOTS_TEXT: String = "Tutti i %d slot sono aperti"
const FREE_SLOTS_TEXT: String = "Slot liberi: %d"
const NO_FREE_TEXT: String = "Nessuno slot libero"
const ALL_SETUPS_TEXT: String = "Tutti gli assetti"
const STATUS_ACTIVE_TEXT: String = "Attivo · slot %d"
const STATUS_INACTIVE_TEXT: String = "Scelto · non attivo con questo assetto"
const STATUS_AVAILABLE_TEXT: String = "Disponibile"
const STATUS_LOCKED_TEXT: String = "Bloccato · livello %d"
const DETAIL_CHOOSE_TEXT: String = "Clic per sceglierlo."
const DETAIL_REMOVE_TEXT: String = "Clic per toglierlo dallo slot."
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
