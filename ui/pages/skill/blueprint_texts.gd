class_name BlueprintTexts
extends RefCounted
## Texts of the blueprint section and of the tool panel of the SkillPage (docs/01_GDD.md §5.1, §13; docs/05_INTERFACES.md
## §7.x). The numbers (duration, XP, chance, costs) are read from the systems and only worded here. No state.

const SECTION_TITLE: String = "Progetti"
const EMPTY_TEXT: String = "Non hai nessun progetto. Si trovano combattendo."
const OWNED_TEXT: String = "%s (x%s)"
const RUNNING_ROW_TEXT: String = "%s (in lavorazione)"
const REQUIRES_LEVEL_TEXT: String = "Richiede il livello %s"
const INPUTS_TITLE: String = "Materiali"
const INPUT_LINE: String = "%s: %s / %s"
const INFO_LINE: String = "Durata: %s - XP: %s - Probabilità di raro: %s%%"
const AFFIX_LABEL: String = "Affisso scelto"
const AFFIX_RANDOM_TEXT: String = "Casuale"
const AFFIX_LOCKED_TEXT: String = "La scelta dell'affisso si sblocca al livello %s."
const START_TEXT: String = "Avvia"
const STOP_TEXT: String = "Ferma"
const RUNNING_TEXT: String = "In lavorazione"
const WAITING_TEXT: String = "In attesa di posto nell'Armeria."
const MINUTES_TEXT: String = "%d min"
const MINUTES_SECONDS_TEXT: String = "%d min %d s"

## Italian text of each refusal of `actions.start_blueprint`; other reasons use REFUSED_TEXT_DEFAULT.
const REFUSED_TEXTS: Dictionary[StringName, String] = {
	Reasons.UNKNOWN_ID: "Questo progetto non è nel deposito.",
	Reasons.LEVEL_TOO_LOW: "Livello di Fabbro troppo basso per questo progetto.",
	Reasons.INVALID_CHOICE: "Questo affisso non si può scegliere.",
	Reasons.MISSING_INPUTS: "Materiali insufficienti.",
	Reasons.ARMORY_FULL: "L'Armeria è piena.",
	Reasons.LANE_UNAVAILABLE: "Corsia non disponibile.",
	Reasons.COMBAT_ACTIVE: "Combattimento in corso.",
}
const REFUSED_TEXT_DEFAULT: String = "Impossibile avviare il progetto."


static func refused(reason: StringName) -> String:
	return REFUSED_TEXTS.get(reason, REFUSED_TEXT_DEFAULT)


## "17 min" or "17 min 30 s" from milliseconds (the durations of the blueprints are minutes).
static func duration(ms: int) -> String:
	@warning_ignore("integer_division")
	var minutes: int = ms / 60000
	@warning_ignore("integer_division")
	var seconds: int = (ms % 60000) / 1000
	if minutes <= 0:
		return NumberFormat.format_seconds(ms)
	return MINUTES_TEXT % minutes if seconds == 0 else MINUTES_SECONDS_TEXT % [minutes, seconds]


## "12,5" style percent number.
static func percent(value: float) -> String:
	return NumberFormat.format_number(snappedf(value, 0.1))
