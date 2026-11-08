class_name DataValidatorEngraver
extends RefCounted
## Engraver rules of DataValidator (internal, M12; docs/04_DATA_SCHEMA.md §3, §5, §6, F-104..F-107): the `engraver` and
## `rune` sections of balance.json, `kind` and the `fuse_*`/`upgrade_*` recipes of the Engraver, the grades of the runes.
## Missing or mistyped balance keys are already reported by the key checks, so these rules skip what is not the right type.

const SKILL: String = "riftbinding"
const KINDS: PackedStringArray = ["craft", "crystallize"]
const DUST_ITEM: String = "rift_dust"
const FUSE_PREFIX: String = "fuse_"
const UPGRADE_PREFIX: String = "upgrade_"
const GRADE_COUNT: int = 5  # F-107: a rune has 5 grades
const GRADE_TOLERANCE: float = 1e-6
const MIN_RATIO: int = 2


static func validate_balance(v: DataValidatorRules, balance: Dictionary) -> void:
	var engraver: Variant = DataValidator.lookup(balance, "engraver")
	if engraver is Dictionary:
		var e: Dictionary = engraver as Dictionary
		for key: String in ["crystal_chance_min_pct", "crystal_chance_max_pct", "crystal_fail_loss_pct"]:
			if DataValidatorRules.is_number(e.get(key)):
				v.number(e, key, 0.0, 100.0, "engraver")
		if DataValidatorRules.is_number(e.get("crystal_chance_min_pct")) \
				and DataValidatorRules.is_number(e.get("crystal_chance_max_pct")) \
				and float(e["crystal_chance_min_pct"]) > float(e["crystal_chance_max_pct"]):
			v.fail("key 'engraver.crystal_chance_min_pct' must be <= 'crystal_chance_max_pct'")
		if DataValidatorRules.is_number(e.get("merge_ratio")) \
				and v.integer(e, "merge_ratio", MIN_RATIO, DataValidatorRules.NO_LIMIT, "engraver"):
			v.merge_ratio = int(e["merge_ratio"])
	var rune: Variant = DataValidator.lookup(balance, "rune")
	if rune is Dictionary:
		var r: Dictionary = rune as Dictionary
		if DataValidatorRules.is_number(r.get("upgrade_ratio")) \
				and v.integer(r, "upgrade_ratio", MIN_RATIO, DataValidatorRules.NO_LIMIT, "rune"):
			v.upgrade_ratio = int(r["upgrade_ratio"])
		if r.get("grade_mult") is Array:
			_grade_mult(v, r["grade_mult"] as Array)


static func _grade_mult(v: DataValidatorRules, list: Array) -> void:
	if list.size() != GRADE_COUNT:
		v.fail("key 'rune.grade_mult' needs exactly %d numbers, got %d" % [GRADE_COUNT, list.size()])
		return
	var previous: float = 0.0
	var parsed: Array[float] = []
	for index: int in list.size():
		if not DataValidatorRules.is_number(list[index]) or float(list[index]) <= previous:
			v.fail("key 'rune.grade_mult' must be increasing positive numbers, got %s" % JSON.stringify(list))
			return
		previous = float(list[index])
		parsed.append(previous)
	if parsed[0] != 1.0:
		v.fail("key 'rune.grade_mult' must start with 1 (grade I), got %s" % JSON.stringify(list))
		return
	v.grade_mult = parsed


## `kind` and the recipe quantities of one action entry (`v` is already positioned on the entry).
static func action(v: DataValidatorRules, e: Dictionary, skill: String) -> void:
	if e.has("kind"):
		if skill != SKILL:
			v.fail("field 'kind' is allowed only for the actions of '%s'" % SKILL)
		elif v.one_of(e, "kind", KINDS) and e["kind"] == "crystallize":
			_crystallize(v, e)
	if skill != SKILL:
		return
	var id: String = str(e.get("id", ""))
	if id.begins_with(FUSE_PREFIX):
		_ratio(v, e, v.merge_ratio, "engraver.merge_ratio")
	elif id.begins_with(UPGRADE_PREFIX):
		_ratio(v, e, v.upgrade_ratio, "rune.upgrade_ratio")


# F-104: one input (the Rift Dust), one output (one Crystal, a currency), mastery on.
static func _crystallize(v: DataValidatorRules, e: Dictionary) -> void:
	var inputs: Array = (e["inputs"] as Array) if e.get("inputs") is Array else []
	var outputs: Array = (e["outputs"] as Array) if e.get("outputs") is Array else []
	if inputs.size() != 1 or not inputs[0] is Dictionary or (inputs[0] as Dictionary).get("item") != DUST_ITEM:
		v.fail("a 'crystallize' action needs exactly one input: '%s'" % DUST_ITEM)
	if outputs.size() != 1 or not outputs[0] is Dictionary:
		v.fail("a 'crystallize' action needs exactly one output (a Crystal)")
	else:
		var out: Dictionary = outputs[0] as Dictionary
		var item: Dictionary = v.items.get(StringName(str(out.get("item"))), {})
		if str(item.get("category")) != "currency" or not DataValidatorRules.is_int(out.get("qty")) or int(out["qty"]) != 1:
			v.fail("the output of a 'crystallize' action must be 1 currency (Crystal)")
	if e.get("mastery") != true:
		v.fail("a 'crystallize' action needs 'mastery': true")


# F-105 / F-106: every ingredient has the quantity of the balance ratio (when the ratio is known and valid).
static func _ratio(v: DataValidatorRules, e: Dictionary, ratio: int, key: String) -> void:
	if ratio <= 0 or not e.get("inputs") is Array:
		return
	for input: Variant in e["inputs"] as Array:
		if input is Dictionary and DataValidatorRules.is_int((input as Dictionary).get("qty")) \
				and int((input as Dictionary)["qty"]) != ratio:
			v.fail("recipe '%s': input '%s' has qty %d, expected %s = %d" % [e.get("id"), (input as Dictionary).get("item"),
					int((input as Dictionary)["qty"]), key, ratio])


## The shape of the `grade` and `family` fields of an `infusion` object.
static func infusion_fields(v: DataValidatorRules, infusion: Dictionary) -> void:
	if infusion.has("grade"):
		v.integer(infusion, "grade", 1, GRADE_COUNT, "infusion")
	if infusion.has("family"):
		v.text(infusion, "family", "infusion")


## F-107 over the whole item set: a rune of grade 2..5 has a family with a grade I rune whose id is the family, the id
## `<family>_<grade>` and the same modifiers with `value` = grade I x `rune.grade_mult[grade-1]`; a family with any
## higher grade has all 5. Only families with a grade above I are checked (the real runes get their grades in M12-05).
static func validate_runes(v: DataValidatorRules, files: Dictionary[String, Dictionary]) -> void:
	var by_family: Dictionary[String, Dictionary] = {}  # family -> {grade: [file, index, entry]}
	var graded: Dictionary[String, bool] = {}  # families with a rune above grade I
	for path: String in files:
		var list: Array[Dictionary] = []
		list.assign((files[path].get("items", []) as Array).filter(func(x: Variant) -> bool: return x is Dictionary))
		for index: int in list.size():
			var infusion: Variant = list[index].get("infusion")
			if not infusion is Dictionary:
				continue
			var grade: int = int((infusion as Dictionary)["grade"]) \
					if DataValidatorRules.is_int((infusion as Dictionary).get("grade")) else 1
			var family: String = str((infusion as Dictionary).get("family", list[index].get("id")))
			if grade > 1:
				graded[family] = true
			(by_family.get_or_add(family, {}) as Dictionary)[grade] = [path, index, list[index]]
	for family: String in graded:
		var grades: Dictionary = by_family[family]
		var first: Array = (grades.get(1, grades[grades.keys()[0]]) as Array)
		_at(v, first)
		if not grades.has(1) or (grades[1] as Array)[2].get("id") != family:
			v.fail("rune family '%s': the grade I rune must exist and have the id of the family" % family)
			continue
		for grade: int in range(1, GRADE_COUNT + 1):
			if not grades.has(grade):
				_at(v, first)
				v.fail("rune family '%s': grade %d is missing" % [family, grade])
			else:
				_at(v, grades[grade] as Array)
				_check_grade(v, family, grade, (grades[grade] as Array)[2] as Dictionary, (grades[1] as Array)[2] as Dictionary)


static func _at(v: DataValidatorRules, where: Array) -> void:
	v.at_file(where[0] as String)
	v.at_entry("item", where[1] as int, where[2] as Dictionary)


static func _check_grade(v: DataValidatorRules, family: String, grade: int, item: Dictionary, base: Dictionary) -> void:
	var id: String = str(item.get("id"))
	if grade > 1 and id != "%s_%d" % [family, grade]:
		v.fail("rune '%s' (family '%s', grade %d): the id must be '%s_%d'" % [id, family, grade, family, grade])
	if grade == 1 or v.grade_mult.size() != GRADE_COUNT:
		return
	var mods: Array = (item["infusion"] as Dictionary).get("modifiers", []) as Array
	var base_mods: Array = (base["infusion"] as Dictionary).get("modifiers", []) as Array
	if mods.size() != base_mods.size():
		v.fail("rune '%s': %d modifiers, grade I has %d" % [id, mods.size(), base_mods.size()])
		return
	for index: int in mods.size():
		if not mods[index] is Dictionary or not base_mods[index] is Dictionary:
			continue
		var base_mod: Dictionary = base_mods[index] as Dictionary
		var mod: Dictionary = mods[index] as Dictionary
		var want: float = float(base_mod.get("value", 0.0)) * v.grade_mult[grade - 1]
		if mod.get("stat") != base_mod.get("stat") or absf(float(mod.get("value", 0.0)) - want) > GRADE_TOLERANCE:
			v.fail("rune '%s': modifier %d must be grade I x rune.grade_mult[%d] (%s %s)" % [id, index, grade - 1,
					base_mod.get("stat"), str(want)])
