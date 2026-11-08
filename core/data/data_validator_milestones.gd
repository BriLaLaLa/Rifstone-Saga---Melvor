class_name DataValidatorMilestones
extends RefCounted
## Mastery milestone rules of DataValidator (internal, M12; docs/04_DATA_SCHEMA.md §3, §4, §6, F-103, F-108): the
## `mastery.milestones` balance section, the 3 `milestones` of every gathering action (25/50/99), `mastery_bonuses`
## forbidden for gathering skills and the mastery trees of the gathering trades not being identical.
## Transition (M12-05 brings the contents): the rules that need milestones in the data (required on every gathering
## action, no `mastery_bonuses` on gathering skills, different trees) apply as soon as one gathering action has `milestones`.

const BALANCE_KEYS: PackedStringArray = ["byproduct_at", "resource_at", "trade_at"]
const TYPES: PackedStringArray = ["byproduct", "resource", "trade"]
const MILESTONE_FIELDS: PackedStringArray = ["at", "type", "item", "modifiers"]
const GATHERING: String = "gathering"
const MIN_DIFFERENT_NODES: int = 3  # 02_FORMULAS §8.8: the trees differ in at least 3 nodes


static func validate_balance(v: DataValidatorRules, balance: Dictionary) -> void:
	var section: Variant = DataValidator.lookup(balance, "mastery.milestones")
	if not section is Dictionary:
		return
	var milestones: Dictionary = section as Dictionary
	var previous: float = 0.0
	var found: Array[int] = []
	for key: String in BALANCE_KEYS:
		if not v.integer(milestones, key, previous + 1.0, v.max_mastery_level, "mastery.milestones"):
			return
		previous = float(milestones[key])
		found.append(int(previous))
	v.milestone_thresholds = found
	if DataValidatorRules.is_number(milestones.get("byproduct_chance_pct")):
		v.number(milestones, "byproduct_chance_pct", 0.0, 100.0, "mastery.milestones")


## True when at least one gathering action of the data has `milestones` (the M12 rules are then enforced).
static func is_active(v: DataValidatorRules, action_files: Dictionary[String, Dictionary]) -> bool:
	for path: String in action_files:
		var skill: Dictionary = v.skills.get(StringName(str(action_files[path].get("skill", ""))), {})
		if str(skill.get("category", "")) != GATHERING or not action_files[path].get("actions") is Array:
			continue
		for e: Variant in action_files[path]["actions"]:
			if e is Dictionary and (e as Dictionary).has("milestones"):
				return true
	return false


## The `milestones` of one action entry (`v` is already positioned on the entry).
static func action(v: DataValidatorRules, e: Dictionary, skill: String, category: String, active: bool) -> void:
	if category != GATHERING:
		if e.has("milestones"):
			v.fail("field 'milestones' is allowed only for gathering actions")
		return
	if not e.has("milestones"):
		if active:
			v.fail("missing field 'milestones' (gathering actions need the 3 mastery milestones)")
		return
	var list: Array[Dictionary] = v.object_list(e, "milestones")
	if list.size() != TYPES.size():
		v.fail("field 'milestones' needs exactly %d entries (%s), got %d" % [TYPES.size(), "/".join(TYPES), list.size()])
		return
	for index: int in list.size():
		_milestone(v, list[index], index, str(e.get("id", "")), skill)


static func _milestone(v: DataValidatorRules, m: Dictionary, index: int, action_id: String, skill: String) -> void:
	var prefix: String = "milestones[%d]" % index
	var type: String = TYPES[index]
	v.keys(m, MILESTONE_FIELDS, prefix)
	if v.integer(m, "at", 1, v.max_mastery_level, prefix) and v.milestone_thresholds.size() == TYPES.size() \
			and int(m["at"]) != v.milestone_thresholds[index]:
		v.fail("field '%s.at' must be mastery.milestones.%s (%d), got %d" % [prefix, BALANCE_KEYS[index],
				v.milestone_thresholds[index], int(m["at"])])
	if v.one_of(m, "type", TYPES, prefix) and m["type"] != type:
		v.fail("field '%s.type' must be '%s' (order %s), got '%s'" % [prefix, type, "/".join(TYPES), m["type"]])
	if type == "byproduct":
		_byproduct(v, m, prefix)
		return
	if m.has("item"):
		v.fail("field '%s.item' is allowed only for a byproduct" % prefix)
	v.object_list(m, "modifiers", prefix, 1)
	v.modifiers(m, "modifiers", prefix)
	var expected: String = ("action:%s" % action_id) if type == "resource" else ("skill:%s" % skill)
	var mods: Variant = m.get("modifiers")
	for mod: Variant in (mods as Array) if mods is Array else []:
		if mod is Dictionary and (mod as Dictionary).has("scope") and (mod as Dictionary)["scope"] != expected:
			v.fail("field '%s.modifiers': scope must be '%s' (or absent), got '%s'" % [prefix, expected,
					(mod as Dictionary)["scope"]])


static func _byproduct(v: DataValidatorRules, m: Dictionary, prefix: String) -> void:
	if m.has("modifiers"):
		v.fail("field '%s.modifiers' is not allowed for a byproduct" % prefix)
	if v.ref(m, "item", v.items, "item", prefix):
		var category: String = str(v.items[StringName(m["item"] as String)].get("category"))
		if category != "material":
			v.fail("field '%s.item': '%s' is not a material (category '%s')" % [prefix, m["item"], category])


## `mastery_bonuses` are not allowed for gathering skills once the milestones are in the data.
static func validate_skills(v: DataValidatorRules, skill_files: Dictionary[String, Dictionary], active: bool) -> void:
	if not active:
		return
	for path: String in skill_files:
		v.at_file(path)
		var list: Array[Dictionary] = v.object_list(skill_files[path], "skills")
		for index: int in list.size():
			var e: Dictionary = list[index]
			if str(e.get("category", "")) == GATHERING and e.has("mastery_bonuses"):
				v.at_entry("skill", index, e)
				v.fail("field 'mastery_bonuses' is not allowed for gathering skills (use the action milestones)")


## The trees of any two gathering trades differ in at least 3 nodes (by position; a node is its set of stat:value pairs).
static func validate_trees(v: DataValidatorRules, mastery_files: Dictionary[String, Dictionary], active: bool) -> void:
	if not active:
		return
	var trees: Dictionary[String, Array] = {}
	var files_of: Dictionary[String, String] = {}
	for path: String in mastery_files:
		var skill: String = str(mastery_files[path].get("skill", ""))
		var def: Dictionary = v.skills.get(StringName(skill), {})
		if str(def.get("category", "")) != GATHERING or not mastery_files[path].get("nodes") is Array:
			continue
		var signature: Array = []
		for node: Variant in mastery_files[path]["nodes"]:
			signature.append(_node_signature(node))
		trees[skill] = signature
		files_of[skill] = path
	var skill_ids: Array = trees.keys()
	for i: int in skill_ids.size():
		for j: int in range(i + 1, skill_ids.size()):
			var a: Array = trees[skill_ids[i]]
			var b: Array = trees[skill_ids[j]]
			var different: int = 0
			for n: int in mini(a.size(), b.size()):
				different += 1 if a[n] != b[n] else 0
			if different < MIN_DIFFERENT_NODES:
				v.at_file(files_of[skill_ids[j]])
				v.fail("mastery tree of '%s' is too similar to '%s' (%d different nodes, needs %d)" % [skill_ids[j],
						skill_ids[i], different, MIN_DIFFERENT_NODES])


static func _node_signature(node: Variant) -> String:
	var pairs: PackedStringArray = []
	if node is Dictionary and (node as Dictionary).get("modifiers") is Array:
		for m: Variant in (node as Dictionary)["modifiers"]:
			if m is Dictionary:
				pairs.append("%s:%s" % [(m as Dictionary).get("stat"), (m as Dictionary).get("value")])
	pairs.sort()
	return ",".join(pairs)
