class_name RiftTexts
extends RefCounted
## Italian texts and read-only helpers of the Rift Altar page and of the socket / currency UI (docs/01_GDD.md §11, §26).
## No state: everything is read from the session.

const TITLE_TEXT: String = "Altare del Rift"
const INTRO_TEXT: String = "Le rune negli incavi restano attive. Toglierne una la distrugge."
const SOCKET_TITLE_TEXT: String = "Incavo %d"
const LOCKED_TEXT: String = "Si sblocca con %s al livello %d."
const EMPTY_TEXT: String = "Libero — scegli una runa"
const SOCKET_BUTTON_TEXT: String = "Incastona"
const REMOVE_BUTTON_TEXT: String = "Togli"
const CONFIRM_REMOVE_TEXT: String = "Distruggi"
const CANCEL_TEXT: String = "Annulla"
const REMOVE_WARNING_TEXT: String = "Togliere la runa la distrugge."
const PICK_TITLE_TEXT: String = "Scegli una runa dal deposito per l'incavo %d"
const NO_INFUSIONS_TEXT: String = "Non possiedi rune: si incidono con l'Incisore."
const RUNES_TITLE_TEXT: String = "Rune nel deposito"
const RUNE_LINE_TEXT: String = "%s  x%s"
const CRAFT_RUNES_TEXT: String = "Incidi con l'Incisore"
const SUMMARY_TITLE_TEXT: String = "Bonus attivi"
const SUMMARY_NONE_TEXT: String = "Nessun bonus attivo."
const SOCKETED_TEXT: String = "Runa incastonata: %s."
const REMOVED_TEXT: String = "Runa distrutta: %s."
const NO_FREE_SOCKET_TEXT: String = "Nessun incavo libero: libera un incavo all'Altare del Rift."
const UNIQUE_TEXT: String = "unica"
const REFUSED_TEXTS: Dictionary[StringName, String] = {
	Reasons.SOCKET_LOCKED: "L'incavo è ancora bloccato: sali di livello come Incisore.",
	Reasons.SOCKET_OCCUPIED: "L'incavo è già occupato: togli prima la runa (viene distrutta).",
	Reasons.NOT_EQUIPPABLE: "Questo oggetto non si può incastonare.",
	Reasons.REQUIREMENT_NOT_MET: "Questa runa è unica ed è già incastonata.",
	Reasons.NOT_ENOUGH_ITEMS: "Non possiedi più questo oggetto.",
	Reasons.SLOT_EMPTY: "L'incavo è già vuoto.",
	Reasons.UNKNOWN_ID: "Il pezzo non è più nell'Armeria.",
}
const REFUSED_TEXT_DEFAULT: String = "Operazione non riuscita."


static func refused(reason: StringName) -> String:
	return REFUSED_TEXTS.get(reason, REFUSED_TEXT_DEFAULT)


## Riftbinding level that unlocks socket `index` (balance `rift.sockets`); 0 if the index is unknown.
static func unlock_level(session: GameSession, index: int) -> int:
	var entries: Array = session.data.balance_value(RiftAltar.BALANCE_KEY) as Array
	if index < 0 or index >= entries.size():
		return 0
	return int((entries[index] as Dictionary)["level"])


static func skill_name(session: GameSession) -> String:
	var def: SkillDef = session.data.skill(RiftAltar.SKILL)
	return def.name if def != null else String(RiftAltar.SKILL)


## Items of the bank of `category` (infusion / stone / currency), in bank order: [{"item": ItemDef, "count": int}].
static func owned(session: GameSession, category: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for stack: Dictionary in session.bank.stacks():
		var def: ItemDef = session.data.item(stack["item"] as StringName)
		if def != null and def.category == category:
			result.append({"item": def, "count": stack["count"]})
	return result


## Text of the modifiers of an item on one line ("Etichetta +3, ...") without BBCode, for buttons and options.
static func modifiers_inline(mods: Array[Modifier], data: GameData) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for mod: Modifier in mods:
		if not data.stats.has(mod.stat):
			continue
		var info: Dictionary = data.stats.info(mod.stat)
		parts.append("%s %s" % [info["name"], ItemTooltipLines.format_stat(info["format"] as String, mod.value)])
	return ", ".join(parts)


## Modifiers of all the infusions socketed now, as BBCode lines (summed per stat); empty if none.
static func summary_lines(session: GameSession) -> PackedStringArray:
	var mods: Array[Modifier] = []
	for i: int in session.rift.socket_total():
		var item_id: StringName = session.rift.get_socket(i)
		if item_id != &"":
			mods.append_array(session.data.item(item_id).infusion_modifiers)
	return ItemTooltipLines.modifier_lines(mods, session.data)
