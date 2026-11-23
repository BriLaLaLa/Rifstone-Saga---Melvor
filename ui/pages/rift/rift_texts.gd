class_name RiftTexts
extends RefCounted
## Italian texts and read-only helpers of the Rift Altar page and of the socket / currency UI (docs/01_GDD.md §11, §26).
## No state: everything is read from the session.

const TITLE_TEXT: String = "Altare del Rift"
const INTRO_TEXT: String = "Incastona le rune negli incavi: restano attive finché non le togli, e toglierle le distrugge."
const NOT_LEARNED_TEXT: String = "Le rune si incidono con l'Incisore: imparalo dai Maestri del Villaggio."
const OFF_TEXT: String = "Runa spenta: l'incavo è bloccato, si riaccende quando si sblocca."
const SOCKET_TITLE_TEXT: String = "Incavo %d"
const SOCKET_BUTTON_TEXT: String = "Incastona"
const STEP1_TITLE_TEXT: String = "Incavo"
const STEP1_HINT_TEXT: String = "Scegli dove agire. Gli incavi si sbloccano salendo di livello come Incisore."
const STEP2_TITLE_TEXT: String = "Runa"
const STEP2_HINT_TEXT: String = "Le rune che hai nel Deposito. Una runa incastonata si consuma."
const STEP3_TITLE_TEXT: String = "Conferma"
const STEP3_HINT_TEXT: String = "Cosa succede e cosa costa."
const PICK_SOCKET_TEXT: String = "Scegli un incavo nella colonna a sinistra."
const PICK_RUNE_TEXT: String = "L'incavo è libero: scegli una runa nella colonna centrale."
const FREE_TEXT: String = "Libero"
const LOCKED_SHORT_TEXT: String = "Bloccato · Incisore liv. %d"
const OFF_SHORT_TEXT: String = "spenta"
const LOCKED_LONG_TEXT: String = "Incavo bloccato: si sblocca con %s al livello %d (ora sei al livello %d)."
const COST_TEXT: String = "Costo: 1 × %s dal Deposito (ne hai %s, ne resteranno %s)."
const SUMMARY_AFTER_TEXT: String = "Dopo l'incastonatura"
const REMOVE_BUTTON_TEXT: String = "Togli"
const CONFIRM_REMOVE_TEXT: String = "Distruggi"
const CANCEL_TEXT: String = "Annulla"
const REMOVE_WARNING_TEXT: String = "Togliere la runa la distrugge."
const NO_INFUSIONS_TEXT: String = "Non possiedi rune: si incidono con l'Incisore, che si impara dai Maestri."
const CRAFT_RUNES_TEXT: String = "Incidi con l'Incisore"
const LEARN_ENGRAVER_TEXT: String = "Impara l'Incisore dai Maestri"
const SUMMARY_TITLE_TEXT: String = "Bonus attivi"
const SUMMARY_NONE_TEXT: String = "Nessun bonus attivo."
const SOCKETED_TEXT: String = "Runa incastonata: %s."
const REMOVED_TEXT: String = "Runa distrutta: %s."
const NO_FREE_SOCKET_TEXT: String = "Nessun incavo libero: libera un incavo all'Altare del Rift."
const UNIQUE_TEXT: String = "unica"
const REFUSED_TEXTS: Dictionary[StringName, String] = {
	Reasons.SOCKET_LOCKED: "L'incavo è ancora bloccato: sali di livello come Incisore (si impara dai Maestri).",
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
static func summary_lines(session: GameSession, extra: Array[Modifier] = []) -> PackedStringArray:
	var mods: Array[Modifier] = extra.duplicate()
	for i: int in session.rift.socket_total():
		var item_id: StringName = session.rift.get_socket(i)
		if session.rift.is_active(i):
			mods.append_array(session.data.item(item_id).infusion_modifiers)
	return ItemTooltipLines.modifier_lines(mods, session.data)


## Why `item_id` cannot be socketed now, in Italian; "" if it can. Read-only mirror of the checks of `RiftAltar.socket`
## (the command stays the authority and refuses with the same reasons).
static func rune_block_reason(session: GameSession, item_id: StringName) -> String:
	var def: ItemDef = session.data.item(item_id)
	if def == null or def.category != &"infusion":
		return refused(Reasons.NOT_EQUIPPABLE)
	if def.infusion_unique:
		for i: int in session.rift.socket_total():
			if session.rift.get_socket(i) == item_id:
				return refused(Reasons.REQUIREMENT_NOT_MET)
	return ""
