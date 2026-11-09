class_name DataValidatorStep
extends RefCounted
## Part of DataValidator (internal, not API for other modules): the balance keys `mastery.step` (F-122: a bonus every 10
## levels of mastery) and `fracture.risk_cap` / `fracture.risk_unit` (F-123: the cap of the risk points of a Card), and the
## rule that every Card grade has a modifier whose risk fits the cap (docs/04_DATA_SCHEMA.md §21).

const STEP_KEYS: PackedStringArray = ["every_levels", "gathering", "crafting"]
const KNOWN_KEYS: PackedStringArray = ["mastery.step", "fracture.risk_cap", "fracture.risk_unit"]
const CAP_KEYS: PackedStringArray = ["base", "per_grade"]


static func is_known_key(path: String) -> bool:
	return KNOWN_KEYS.has(path)


static func validate_balance(v: DataValidatorRules, balance: Dictionary) -> void:
	for key: String in KNOWN_KEYS:
		if DataValidator.lookup(balance, key) == null:
			v.fail("missing key '%s'" % key)
	var step: Variant = DataValidator.lookup(balance, "mastery.step")
	if step is Dictionary:
		_step(v, step as Dictionary)
	var cap: Variant = DataValidator.lookup(balance, "fracture.risk_cap")
	if cap is Dictionary:
		v.keys(cap as Dictionary, CAP_KEYS, "fracture.risk_cap")
		if v.number(cap as Dictionary, "base", 0.0, DataValidatorRules.NO_LIMIT, "fracture.risk_cap", true):
			v.risk_cap_base = float((cap as Dictionary)["base"])
		if v.number(cap as Dictionary, "per_grade", 0.0, DataValidatorRules.NO_LIMIT, "fracture.risk_cap"):
			v.risk_cap_per_grade = float((cap as Dictionary)["per_grade"])
	var unit: Variant = DataValidator.lookup(balance, "fracture.risk_unit")
	if unit is Dictionary:
		v.keys(unit as Dictionary, DataValidatorMaps.RISK_TYPES, "fracture.risk_unit")
		for key: Variant in unit as Dictionary:
			if v.number(unit as Dictionary, str(key), 0.0, DataValidatorRules.NO_LIMIT, "fracture.risk_unit", true):
				v.risk_units[str(key)] = float((unit as Dictionary)[key])


static func _step(v: DataValidatorRules, step: Dictionary) -> void:
	v.keys(step, STEP_KEYS, "mastery.step")
	v.integer(step, "every_levels", 1.0, v.max_mastery_level, "mastery.step")
	for kind: String in ["gathering", "crafting"]:
		var entries: Array[Dictionary] = v.object_list(step, kind, "mastery.step", 1)
		for index: int in entries.size():
			var at: String = "mastery.step.%s[%d]" % [kind, index]
			v.keys(entries[index], ["stat", "value"], at)  # no scope: the action is set by the mastery system
			if v.text(entries[index], "stat", at):
				v.step_stats.append(str(entries[index]["stat"]))  # checked against stats.json once it is loaded
			if v.number(entries[index], "value", -DataValidatorRules.NO_LIMIT, DataValidatorRules.NO_LIMIT, at) \
					and float(entries[index]["value"]) == 0.0:
				v.fail("field '%s.value' must not be 0" % at)


## Run once stats.json and the modifiers are loaded: the stats of `mastery.step` exist; F-123: for every grade 1..10 at least one modifier whose risk at its minimum fits the cap of the grade, so that the
## choice of a Card never gets stuck. `mods` are the entries of map_mods.json.
static func validate_cap_candidates(v: DataValidatorRules, mods: Array[Dictionary]) -> void:
	v.at_file("balance.json")  # the errors below are about balance.json
	for stat: String in v.step_stats:
		if not v.stats.has(StringName(stat)):
			v.fail("field 'mastery.step': stat '%s' is not in stats.json" % stat)
	if v.risk_cap_base <= 0.0:
		return
	for grade: int in range(1, DataValidatorMaps.GRADE_COUNT + 1):
		var cap: float = v.risk_cap_base + v.risk_cap_per_grade * float(grade - 1)
		var fits: bool = false
		for e: Dictionary in mods:
			if not (DataValidatorRules.is_number(e.get("min_grade")) and int(e["min_grade"]) <= grade and e.get("risk") is Dictionary):
				continue
			var risk: Dictionary = e["risk"] as Dictionary
			if DataValidatorRules.is_number(risk.get("min")):
				fits = fits or float(risk["min"]) * float(v.risk_units.get(str(risk.get("type")), 1.0)) <= cap
		if not fits:
			v.fail("grade %d has no modifier whose risk fits the cap %s (fracture.risk_cap)" % [grade, str(cap)])
