class_name CrowdTexts
extends RefCounted
## Italian texts of the crowded combat view (docs/METIN.md Z6) and of the stone skip setting (Z7), display only.

const GROUP_TEXT: String = "%s ×%d"
const STONE_TEXT: String = "%s · livello %d"
const STONE_HP_TEXT: String = "%s / %s PV"
const SKIP_LABEL_TEXT: String = "Salta i Monoliti fino al livello"
const SKIP_TIP_TEXT: String = "I Monoliti di questo livello o inferiore vengono scartati senza combattere. 0 = disattivato."
const LOG_PLAYER_TEXT: String = "Colpisci %s per %s in totale."
const LOG_ENEMY_TEXT: String = "%s ti colpiscono per %s in totale."
const LOG_KILL_TEXT: String = "%s sconfitti."


## "Name ×N", the label of a group of the same type.
static func group_text(name: String, count: int) -> String:
	return GROUP_TEXT % [name, count]
