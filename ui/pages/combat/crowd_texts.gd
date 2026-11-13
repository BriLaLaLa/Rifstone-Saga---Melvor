class_name CrowdTexts
extends RefCounted
## Italian texts of the crowded combat view (docs/METIN.md Z6) and of the stone skip setting (Z7), display only.

const GROUP_TEXT: String = "%s ×%d"
const GROUP_LEVEL_TEXT: String = "%s (Liv %d) ×%d"
const STONE_TEXT: String = "%s · livello %d"
const STONE_HP_TEXT: String = "%s / %s PV"
const SKIP_LABEL_TEXT: String = "Salta i Monoliti fino al livello"
const SKIP_TIP_TEXT: String = "I Monoliti di questo livello o inferiore vengono scartati senza combattere. 0 = disattivato."
const LOG_PLAYER_TEXT: String = "Colpisci %s per %s in totale."
const LOG_ENEMY_TEXT: String = "%s ti colpiscono per %s in totale."
const LOG_KILL_TEXT: String = "%s sconfitti."


## "Name ×N", the label of a group of the same type.
## With a `level` > 0 the monster level is shown too ("Name (Liv N) ×N").
static func group_text(name: String, count: int, level: int = 0) -> String:
	return GROUP_LEVEL_TEXT % [name, level, count] if level > 0 else GROUP_TEXT % [name, count]
