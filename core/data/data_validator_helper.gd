class_name DataValidatorHelper
extends RefCounted
## Helper rules of DataValidator (internal, M12; docs/04_DATA_SCHEMA.md §3, §5, F-101, F-102): the `helper` section of
## balance.json and the `contract` items. Missing or mistyped keys are already reported by the key checks.

const GRADE_COUNT: int = 4
const GRADE_FIELDS: PackedStringArray = ["id", "interval_mult"]
const CONTRACT_FIELDS: PackedStringArray = ["skill", "grade"]
const GATHERING: String = "gathering"
const MAX_SIMULTANEOUS: int = 3  # helpers working at once (one per gathering trade), F-102 invariant


static func validate_balance(v: DataValidatorRules, balance: Dictionary) -> void:
	var helper: Variant = DataValidator.lookup(balance, "helper")
	if not helper is Dictionary:
		return
	var section: Dictionary = helper as Dictionary
	for key: String in ["xp_pct", "mastery_pct"]:
		if DataValidatorRules.is_number(section.get(key)):
			v.number(section, key, 1.0, 100.0, "helper")
	var grades: Variant = section.get("grades")
	if not grades is Array:
		return
	var list: Array = grades as Array
	if list.size() != GRADE_COUNT:
		v.fail("key 'helper.grades' needs exactly %d entries, got %d" % [GRADE_COUNT, list.size()])
	var min_mult: float = INF
	var previous: float = INF
	for index: int in list.size():
		if not list[index] is Dictionary:
			v.fail("key 'helper.grades[%d]' must be an object" % index)
			continue
		var grade: Dictionary = list[index] as Dictionary
		var prefix: String = "helper.grades[%d]" % index
		v.keys(grade, GRADE_FIELDS, prefix)
		if v.text(grade, "id", prefix):
			if v.helper_grade_ids.has(grade["id"] as String):
				v.fail("field '%s.id': duplicate '%s'" % [prefix, grade["id"]])
			v.helper_grade_ids.append(grade["id"] as String)
		if not v.number(grade, "interval_mult", 1.0, DataValidatorRules.NO_LIMIT, prefix):
			continue
		var mult: float = float(grade["interval_mult"])
		if mult > previous:
			v.fail("field '%s.interval_mult': the grades must go from the slowest to the fastest (not increasing)" % prefix)
		previous = mult
		min_mult = minf(min_mult, mult)
	if DataValidatorRules.is_number(section.get("xp_pct")) and min_mult < INF:
		var ratio: float = float(MAX_SIMULTANEOUS) * float(section["xp_pct"]) / (100.0 * min_mult)
		if ratio > 1.0:
			v.fail("key 'helper': 3 x xp_pct / (100 x min interval_mult) = %s must be <= 1 (F-102)" % ratio)


## The `contract` sub-object of an item (the caller checked that the category wants it).
static func contract(v: DataValidatorRules, e: Dictionary) -> void:
	var c: Dictionary = e["contract"] as Dictionary
	v.keys(c, CONTRACT_FIELDS, "contract")
	if v.ref(c, "skill", v.skills, "skill", "contract"):
		var category: String = str(v.skills[StringName(c["skill"] as String)].get("category", ""))
		if category != GATHERING:
			v.fail("field 'contract.skill': '%s' is not a gathering skill" % c["skill"])
	v.one_of(c, "grade", v.helper_grade_ids, "contract")
	if DataValidatorRules.is_int(e.get("value")) and int(e["value"]) != 0:
		v.fail("a contract must have value 0 (it cannot be sold)")
	if e.get("id") is String and c.get("skill") is String and c.get("grade") is String \
			and e["id"] != "contract_%s_%s" % [c["skill"], c["grade"]]:
		v.fail("a contract id must be 'contract_<skill>_<grade>'")


## One contract per (gathering skill, grade), but only when the data has contracts at all (the file is M12-05 content).
static func validate_contract_set(v: DataValidatorRules) -> void:
	var present: Dictionary[String, bool] = {}
	for id: StringName in v.items:
		var c: Variant = v.items[id].get("contract")
		if v.items[id].get("category") == "contract" and c is Dictionary:
			present["%s|%s" % [(c as Dictionary).get("skill"), (c as Dictionary).get("grade")]] = true
	if present.is_empty():
		return
	for skill_id: StringName in v.skills:
		if v.skills[skill_id].get("category") != GATHERING:
			continue
		for grade: String in v.helper_grade_ids:
			if not present.has("%s|%s" % [skill_id, grade]):
				v.fail("missing contract for skill '%s', grade '%s'" % [skill_id, grade])
