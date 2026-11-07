class_name ToolUpgradeTexts
extends RefCounted
## Texts of the tool refinement panel (docs/01_GDD.md §23.1, F-94). Costs and levels are read from `Armory.tool_next_step`;
## only worded here. No state.

const TITLE: String = "Attrezzo"
const NO_TOOL_TEXT: String = "Nessun attrezzo per questo mestiere."
const NEXT_TITLE: String = "Raffinazione +%d → +%d"
const MAX_TEXT: String = "L'attrezzo è al livello massimo di raffinazione."
const COST_LINE: String = "%s: %s / %s"
const GOLD_NAME: String = "Oro"
const MIN_LEVEL_TEXT: String = "Livello minimo del mestiere: %s"
const NO_EFFECT_TEXT: String = "Nessun effetto."
const UPGRADE_TEXT: String = "Raffina"
const REFUSED_TEXTS: Dictionary[StringName, String] = {
	Reasons.UNKNOWN_ID: "L'attrezzo non è disponibile.",
	Reasons.NOT_A_TOOL: "Questo pezzo non è un attrezzo.",
	Reasons.UPGRADE_MAX: "L'attrezzo è già al livello massimo di raffinazione.",
	Reasons.LEVEL_TOO_LOW: "Livello del mestiere troppo basso per questa raffinazione.",
	Reasons.NOT_ENOUGH_GOLD: "Non hai abbastanza oro.",
	Reasons.NOT_ENOUGH_ITEMS: "Mancano piastre o manici per la raffinazione.",
}
const REFUSED_TEXT_DEFAULT: String = "Raffinazione non riuscita."


static func refused(reason: StringName) -> String:
	return REFUSED_TEXTS.get(reason, REFUSED_TEXT_DEFAULT)
