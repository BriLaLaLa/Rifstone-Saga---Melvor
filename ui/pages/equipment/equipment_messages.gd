class_name EquipmentMessages
extends RefCounted
## Texts of the answers to the commands of the Equipment page (docs/UI_GDR.md §3): the Italian reason of a refusal and
## the lines for the outcome of a refinement or a salvage. No state.

const REFUSED_TEXTS: Dictionary[StringName, String] = {
	Reasons.UNKNOWN_ID: "Il pezzo non è più nell'Armeria.",
	Reasons.NOT_EQUIPPABLE: "Questo pezzo non si può mettere in quello slot.",
	Reasons.REQUIREMENT_NOT_MET: "Requisiti non soddisfatti.",
	Reasons.COMBAT_ACTIVE: "Non puoi cambiare arma durante il combattimento.",
	Reasons.ARMORY_FULL: "L'Armeria è piena: non c'è posto per i pezzi che tornano indietro.",
	Reasons.SLOT_EMPTY: "Lo slot è già vuoto.",
	Reasons.ITEM_LOCKED: "Il pezzo è bloccato: sbloccalo per venderlo o smantellarlo.",
	Reasons.ITEM_EQUIPPED: "Il pezzo è indossato: rimuovilo prima di venderlo o smantellarlo.",
	Reasons.NOT_SELLABLE: "Questo pezzo non si vende.",
	Reasons.NOT_FOOD: "Questo oggetto non è un cibo.",
	Reasons.NOT_ENOUGH_ITEMS: "Mancano dei materiali: lingotti, frammenti del Rift o Sigillo.",
	Reasons.NOT_ENOUGH_GOLD: "Non hai abbastanza oro.",
	Reasons.UPGRADE_MAX: "Il pezzo è già al livello massimo di raffinazione.",
	Reasons.BANK_FULL: "Il deposito è pieno: fai posto per i materiali dello smantellamento.",
	Reasons.INVALID_AMOUNT: "Valore del filtro non valido.",
}
const REFUSED_TEXT_DEFAULT: String = "Operazione non riuscita."
const UPGRADE_OK_TEXT: String = "Raffinazione riuscita: %s è ora a +%d."
const UPGRADE_FAIL_TEXT: String = "Raffinazione fallita: %s è ora a +%d."
const SALVAGED_TEXT: String = "Smantellato: %s."
const SALVAGED_AUTO_TEXT: String = "Smantellato dal filtro: %s."


static func refused(reason: StringName) -> String:
	return REFUSED_TEXTS.get(reason, REFUSED_TEXT_DEFAULT)


## Outcome of `item_upgraded`: the piece name is read from the armory.
static func upgraded_text(session: GameSession, uid: int, success: bool, new_level: int) -> String:
	var inst: ItemInstance = session.armory.get_instance(uid)
	if inst == null:
		return ""
	return (UPGRADE_OK_TEXT if success else UPGRADE_FAIL_TEXT) % [session.data.item(inst.base_id).name, new_level]


## Outcome of `item_salvaged`.
static func salvaged_text(session: GameSession, base_id: StringName, auto: bool) -> String:
	return (SALVAGED_AUTO_TEXT if auto else SALVAGED_TEXT) % session.data.item(base_id).name
