class_name CombatTexts
extends RefCounted
## Italian texts of the combat page and of the combat values on the character page (docs/01_GDD.md §10.11, F-70),
## display only. Presentation constants: `UiStyle.COMBAT_*`. Area and monster names come from the data.

const AREAS_TITLE: String = "Aree"
const LOOT_TITLE: String = "Bottino"
const STATS_TITLE: String = "Valori di combattimento"
const STATE_TEXTS: Dictionary[StringName, String] = {
	CombatEngine.STATE_IDLE: "In attesa",
	CombatEngine.STATE_ENCOUNTER: "In combattimento",
	CombatEngine.STATE_BETWEEN: "Il prossimo gruppo sta arrivando",
	CombatEngine.STATE_RIFTSTONE: "Pietra del Rift",
}
const STATE_TEXT_DEFAULT: String = "In attesa"
const NO_AREA_TEXT: String = "Scegli un'area per combattere."
const CURRENT_AREA_TEXT: String = "In corso"
const STOP_TEXT: String = "Ferma"
const EAT_TEXT: String = "Mangia"
const COLLECT_TEXT: String = "Raccogli tutto"
const FOOD_TEXT: String = "Cibo: %s (x%s)"
const NO_FOOD_TEXT: String = "Nessun cibo scelto"
const LOOT_COUNT_TEXT: String = "Borsa: %s / %s"
const LOOT_LINE_TEXT: String = "%s x%s"
const LOOT_EMPTY_TEXT: String = "La borsa è vuota."
const HP_TEXT: String = "%s / %s PV"
const INTERVAL_TEXT: String = "Attacco ogni %s s"
const MISS_TEXT: String = "Mancato"
const BLOCKED_TEXT: String = "Parato"
const HIT_TEXT: String = "-%s"
const REASON_TEXTS: Dictionary[StringName, String] = {
	Reasons.UNKNOWN_ID: "Area non valida.",
	Reasons.REQUIREMENT_NOT_MET: "Non hai ancora il livello richiesto.",
	Reasons.NO_FOOD: "Non hai cibo da mangiare.",
	Reasons.NOT_RUNNING: "Nessun combattimento in corso.",
	Reasons.BANK_FULL: "La bank è piena: parte del bottino è rimasta nella borsa.",
}
const REASON_TEXT_DEFAULT: String = "Operazione non riuscita."
const DEFEAT_TEXT: String = "Sei stato sconfitto: il bottino della borsa è andato perso."
## Character page, values of F-70 (CombatantStats.for_player).
const STAT_ACCURACY_TEXT: String = "Precisione: %s"
const STAT_EVASION_TEXT: String = "Evasione: %s"
const STAT_DAMAGE_TEXT: String = "Danno: %s - %s"
const STAT_HP_TEXT: String = "PV massimi: %s"


## Interval in milliseconds as seconds with one decimal and a comma ("2,0").
static func seconds_text(ms: int) -> String:
	return String.num(ms / 1000.0, 1).replace(".", ",")
