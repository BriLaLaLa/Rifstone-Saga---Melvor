class_name ArmoryFilter
extends RefCounted
## Automatic Armory filter (docs/01_GDD.md §25): per equipment slot a minimum rarity and a minimum grade to keep.
## A slot without a rule keeps everything. State of the Armory (saved with it); Armory applies it to the drops.

const LOG_CATEGORY: String = "armory"
const RARITY_ORDER: Array[StringName] = [&"common", &"magic", &"rare"]
const MIN_GRADE: int = 1
const KEY_RARITY: String = "min_rarity"
const KEY_GRADE: String = "min_grade"

var _max_grade: int
# slot -> {min_rarity: StringName, min_grade: int}; only slots whose rule is not "keep everything".
var _rules: Dictionary[StringName, Dictionary] = {}


func _init(max_grade: int) -> void:
	_max_grade = max_grade


## The rule of a slot (a copy); "keep everything" when the slot has none.
func rule(slot: StringName) -> Dictionary:
	if _rules.has(slot):
		return _rules[slot].duplicate()
	return {KEY_RARITY: RARITY_ORDER[0], KEY_GRADE: MIN_GRADE}


## All the rules that are not "keep everything" (copy).
func rules() -> Dictionary:
	return _rules.duplicate(true)


## unknown_id: not an equipment slot or unknown rarity; invalid_amount: grade outside 1..max grade.
func set_rule(slot: StringName, min_rarity: StringName, min_grade: int) -> CommandResult:
	if not Equipment.SLOTS.has(slot) or not RARITY_ORDER.has(min_rarity):
		return CommandResult.fail(Reasons.UNKNOWN_ID)
	if min_grade < MIN_GRADE or min_grade > _max_grade:
		return CommandResult.fail(Reasons.INVALID_AMOUNT)
	if min_rarity == RARITY_ORDER[0] and min_grade == MIN_GRADE:
		_rules.erase(slot)
	else:
		_rules[slot] = {KEY_RARITY: min_rarity, KEY_GRADE: min_grade}
	return CommandResult.success()


## True when a piece of `slot` with this rarity and grade is under the rule of the slot.
func rejects(slot: StringName, rarity: StringName, grade: int) -> bool:
	if not _rules.has(slot):
		return false
	var r: Dictionary = _rules[slot]
	return RARITY_ORDER.find(rarity) < RARITY_ORDER.find(r[KEY_RARITY]) or grade < int(r[KEY_GRADE])


func clear() -> void:
	_rules.clear()


func to_save() -> Dictionary:
	var saved: Dictionary = {}
	for slot: StringName in Equipment.SLOTS:
		if _rules.has(slot):
			saved[String(slot)] = {KEY_RARITY: String(_rules[slot][KEY_RARITY]), KEY_GRADE: int(_rules[slot][KEY_GRADE])}
	return saved


## Invalid entries (unknown slot or rarity, bad grade, not an object) are reported and dropped.
func from_save(d: Variant) -> void:
	_rules.clear()
	if d == null:
		return
	if not d is Dictionary:
		Log.warn(LOG_CATEGORY, "filter is not an object: keeping everything")
		return
	for key: Variant in (d as Dictionary):
		var entry: Variant = (d as Dictionary)[key]
		var ok: bool = entry is Dictionary and (entry as Dictionary).get(KEY_RARITY) is String \
				and DataValidatorRules.is_int((entry as Dictionary).get(KEY_GRADE))
		if ok:
			ok = set_rule(StringName(str(key)), StringName((entry as Dictionary)[KEY_RARITY] as String),
					int((entry as Dictionary)[KEY_GRADE])).ok
		if not ok:
			Log.warn(LOG_CATEGORY, "filter rule dropped (invalid): %s = %s" % [str(key), str(entry)])
