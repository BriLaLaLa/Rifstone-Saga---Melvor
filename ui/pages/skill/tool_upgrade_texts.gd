class_name ToolUpgradeTexts
extends RefCounted
## Texts of the tool refinement panel (docs/01_GDD.md §23.1, F-94). Costs and levels are read from `Armory.tool_next_step`;
## only worded here. No state.

const TITLE: String = "Attrezzo"
const NO_TOOL_TEXT: String = "Nessun attrezzo per questo mestiere."
const NEXT_TITLE: String = "Raffinazione +%d → +%d"
const MAX_TEXT: String = "L'attrezzo è al livello massimo di raffinazione."
const COST_LINE: String = "%s: %s / %s"
const GOLD_NAME: String = "Monete"
const MIN_LEVEL_TEXT: String = "Livello minimo del mestiere: %s"
const NO_EFFECT_TEXT: String = "Nessun effetto."
const UPGRADE_TEXT: String = "Raffina"
const REFUSED_TEXTS: Dictionary[StringName, String] = {
	Reasons.UNKNOWN_ID: "L'attrezzo non è disponibile.",
	Reasons.NOT_A_TOOL: "Questo pezzo non è un attrezzo.",
	Reasons.UPGRADE_MAX: "L'attrezzo è già al livello massimo di raffinazione.",
	Reasons.LEVEL_TOO_LOW: "Livello del mestiere troppo basso per questa raffinazione.",
	Reasons.NOT_ENOUGH_GOLD: "Non hai abbastanza monete.",
	Reasons.NOT_ENOUGH_ITEMS: "Mancano piastre o manici per la raffinazione.",
	Reasons.HEAD_LOCKED: "Questo passo non è ancora raggiunto.",
	Reasons.UNKNOWN_HEAD: "Testa sconosciuta.",
	Reasons.INVALID_STEP: "Passo non valido.",
	Reasons.HEAD_UNCHANGED: "Questa testa è già montata.",
	Reasons.NOT_EQUIPPABLE: "Un attrezzo leggendario non ha teste.",
	Reasons.NOT_LEARNED: "Non hai ancora imparato questa disciplina.",
}
const REFUSED_TEXT_DEFAULT: String = "Operazione non riuscita."


static func refused(reason: StringName) -> String:
	return REFUSED_TEXTS.get(reason, REFUSED_TEXT_DEFAULT)


## The tool of `skill_id` with its "+N" ("" if the discipline has no tool).
static func tool_name(session: GameSession, skill_id: StringName) -> String:
	var uid: int = session.armory.tool_uid(StringName("%s%s" % [ToolUpgrade.SLOT_PREFIX, skill_id]))
	var inst: ItemInstance = session.armory.get_instance(uid) if uid != 0 else null
	return ArmoryTexts.piece_name(inst, session.data.item(inst.base_id)) if inst != null else ""


## The current effects of the tool of `skill_id` ("<stat>: <value>" each, main effect first), read from `modifiers.breakdown`.
static func effect_texts(session: GameSession, skill_id: StringName) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var source: StringName = StringName("equipment:%s%s" % [ToolUpgrade.SLOT_PREFIX, skill_id])
	var ctx: ModifierContext = ModifierContext.for_skill(skill_id)
	for stat: StringName in session.data.stats.ids():
		for entry: Dictionary in session.modifiers.breakdown(stat, ctx):
			if entry["source"] != source:
				continue
			var info: Dictionary = session.data.stats.info(stat)
			out.append("%s: %s" % [info["name"], ItemTooltipLines.format_stat(info["format"] as String, float(entry["value"]))])
	return out
