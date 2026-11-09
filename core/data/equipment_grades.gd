class_name EquipmentGrades
extends RefCounted
## F-118 tables indexed by the piece grade (1..15): `equipment.grade_levels` and `equipment.grade_material`
## (helper of GameData, docs/02_FORMULAS.md §8.4).

const LOG_CATEGORY: String = "data"


## `list[piece_grade - 1]` of the balance array at `path`; out of range: error, 0.
static func entry(data: GameData, path: String, piece_grade: int) -> int:
	var list: Array = data.balance_value(path) as Array
	if piece_grade >= 1 and piece_grade <= list.size():
		return int(list[piece_grade - 1])
	Log.error(LOG_CATEGORY, "piece grade %d is out of range for '%s'" % [piece_grade, path])
	return 0
