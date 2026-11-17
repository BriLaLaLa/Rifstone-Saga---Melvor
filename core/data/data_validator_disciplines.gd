class_name DataValidatorDisciplines
extends RefCounted
## Discipline rules of DataValidator (internal, M24; docs/04_DATA_SCHEMA_M24.md §29, docs/02_FORMULAS_M24.md F-153…F-158): the
## `discipline` flag of skills, `data/disciplines/trainers.json`, `data/encounters/nodes.json`, the `discover` actions and their
## Recipe items, and the `encounters`, `disciplines`, `trainer` and `production` sections of balance.json.

## The "real data" rules of §29 (a Trainer for every discipline, nodes for every area, a Recipe for every `discover` action
## that drops somewhere) are on once M24-05 writes the content; before that only the structure is checked.
const STRICT_REAL_DATA: bool = true
const DISCIPLINE_CATEGORIES: PackedStringArray = ["gathering", "artisan"]
const GRADE_FIELDS: PackedStringArray = ["id", "name", "cap", "character_level"]
const TRAINER_FIELDS: PackedStringArray = ["skill", "name", "title", "description", "fed_by"]
const NODE_AREA_FIELDS: PackedStringArray = ["area", "max_level", "nodes"]
const NODE_FIELDS: PackedStringArray = ["skill", "weight", "difficulty", "min_level"]
const NODE_WEIGHT_TOTAL: int = 100  # the weights of an area sum to 100 (strict data)
const NODE_WEIGHT_MIN: int = 10  # and none is below 10 (strict data)
const SECTIONS: PackedStringArray = ["encounters", "disciplines", "trainer", "production"]
const ENCOUNTER_KEYS: PackedStringArray = ["travel_ms", "node_chance_pct", "node_min_ms", "node_ms", "skip_ms", "node_units", "colors",
		"attempts", "yield_free_levels", "yield_loss_pct", "yield_min_pct", "rich_chance_pct", "rich_extra_attempts", "rich_units_pct", "rich_ms_pct"]
const COLOR_KEYS: PackedStringArray = ["id", "below", "xp_pct"]
const TRAINER_KEYS: PackedStringArray = ["learn_gold", "gold_base", "gold_growth", "skill_margin", "unlearn_pct", "unlearn_min_gold"]


## True for the sections of balance.json that this validator owns (their fields are checked by `validate_balance`).
static func is_known_key(path: String) -> bool:
	return path in SECTIONS


## `discipline` of a skill entry (the caller started the entry): a boolean, only for the gathering and artisan categories.
static func skill(v: DataValidatorRules, e: Dictionary) -> void:
	if not e.has("discipline"):
		return
	if v.flag(e, "discipline") and e["discipline"] and not DISCIPLINE_CATEGORIES.has(str(e.get("category"))):
		v.fail("field 'discipline' is allowed only for the categories %s, got '%s'" % [DISCIPLINE_CATEGORIES, e.get("category")])


## `discover` of an action entry: a boolean, only for crafting (not gathering, not single-cycle actions).
static func action(v: DataValidatorRules, e: Dictionary, category: String, single: bool) -> void:
	if not e.has("discover"):
		return
	if v.flag(e, "discover") and e["discover"]:
		if category != "artisan":
			v.fail("field 'discover' is allowed only for artisan actions")
		elif single:
			v.fail("field 'discover' is not allowed with 'single'")


## The `recipe` sub-object of a category `recipe` item (the caller checked that the category wants it): the action it teaches.
static func recipe_item(v: DataValidatorRules, e: Dictionary) -> void:
	var recipe: Dictionary = e["recipe"] as Dictionary
	v.keys(recipe, ["action"], "recipe")
	if v.ref(recipe, "action", v.actions, "action", "recipe") and not _is_true(v.actions[StringName(recipe["action"] as String)], "discover"):
		v.fail("field 'recipe.action': '%s' has no 'discover: true'" % recipe["action"])
	if DataValidatorRules.is_int(e.get("value")) and int(e["value"]) != 0:
		v.fail("a Recipe must have value 0 (it cannot be sold)")


## balance.json `encounters`, `disciplines`, `trainer`, `production` (04_DATA_SCHEMA_M24.md §29.6).
static func validate_balance(v: DataValidatorRules, balance: Dictionary) -> void:
	for key: String in SECTIONS:
		if not DataValidator.lookup(balance, key) is Dictionary:
			v.fail("missing key '%s'" % key)
	_encounters(v, DataValidator.lookup(balance, "encounters"))
	var disciplines: Variant = DataValidator.lookup(balance, "disciplines")
	if disciplines is Dictionary:
		v.keys(disciplines as Dictionary, ["max_per_category"], "disciplines")
		v.integer(disciplines as Dictionary, "max_per_category", 1, DataValidatorRules.NO_LIMIT, "disciplines")
	var trainer: Variant = DataValidator.lookup(balance, "trainer")
	if trainer is Dictionary:
		var t: Dictionary = trainer as Dictionary
		v.keys(t, TRAINER_KEYS, "trainer")
		for key: String in ["learn_gold", "gold_base", "skill_margin", "unlearn_min_gold"]:
			v.integer(t, key, 0, DataValidatorRules.NO_LIMIT, "trainer")
		v.number(t, "gold_growth", 1.0, DataValidatorRules.NO_LIMIT, "trainer")
		v.number(t, "unlearn_pct", 0.0, 100.0, "trainer")
	var production: Variant = DataValidator.lookup(balance, "production")
	if production is Dictionary:
		v.keys(production as Dictionary, ["queue_slots", "max_job_count"], "production")
		for key: String in ["queue_slots", "max_job_count"]:
			v.integer(production as Dictionary, key, 1, DataValidatorRules.NO_LIMIT, "production")


## True for the real narrow-area data (an area has `level_min`, as `DataValidatorDungeon` decides): the minimal fixtures are not strict.
static func is_real_data(raw: Dictionary) -> bool:
	var files: Dictionary = raw.get("areas", {}) as Dictionary
	for path: Variant in files:
		for a: Variant in ((files[path] as Dictionary).get("areas", []) as Array):
			if a is Dictionary and (a as Dictionary).has("level_min"):
				return true
	return false


## The balance, the Trainers file and the nodes file (`raw` is the whole raw data of DataValidator), then the cross-checks.
static func validate(v: DataValidatorRules, raw: Dictionary, strict: bool = STRICT_REAL_DATA) -> void:
	var balance_files: Dictionary = raw.get("balance", {}) as Dictionary
	for path: Variant in balance_files:
		v.at_file(str(path))
		validate_balance(v, balance_files[path] as Dictionary)
		_slots(v, balance_files[path] as Dictionary, strict)
	var trainer_files: Dictionary = raw.get("disciplines", {}) as Dictionary
	for path: Variant in trainer_files:
		v.at_file(str(path))
		_trainers_file(v, trainer_files[path] as Dictionary, strict)
	var node_files: Dictionary = raw.get("encounters", {}) as Dictionary
	if node_files.is_empty() and strict:
		v.at_file("section 'encounters'")
		v.fail("data/encounters/nodes.json is missing")
	for path: Variant in node_files:
		v.at_file(str(path))
		_nodes_file(v, node_files[path] as Dictionary, _ids(raw, "areas", "areas"), _first_resources(raw), strict)
	_recipes(v, raw, strict)


# --- balance ----------------------------------------------------------------------------------------------------

# `disciplines.max_per_category` against the disciplines of each category (04_DATA_SCHEMA_M25.md §30.4): never more than the category
# has; strict (real data): every gathering and artisan skill is a discipline and the choice is real (the limit is below the count).
static func _slots(v: DataValidatorRules, balance: Dictionary, strict: bool) -> void:
	var section: Variant = DataValidator.lookup(balance, "disciplines")
	if not section is Dictionary or not DataValidatorRules.is_int((section as Dictionary).get("max_per_category")):
		return
	var max_per: int = int((section as Dictionary)["max_per_category"])
	for category: String in DISCIPLINE_CATEGORIES:
		var total: int = 0
		var count: int = 0
		for skill_id: StringName in v.skills:
			var def: Dictionary = v.skills[skill_id]
			if str(def.get("category")) != category:
				continue
			total += 1
			if _is_true(def, "discipline"):
				count += 1
			elif strict:
				v.fail("skill '%s' (%s) is not a discipline: every %s skill is learned from a Trainer" % [skill_id, category, category])
		if count > 0 and max_per > count:
			v.fail("field 'disciplines.max_per_category' (%d) is above the %d disciplines of the category '%s'" % [max_per, count, category])
		elif strict and total > 0 and max_per >= count:
			v.fail("field 'disciplines.max_per_category' (%d) must be below the %d disciplines of the category '%s'" % [max_per, count, category])

static func _encounters(v: DataValidatorRules, section: Variant) -> void:
	if not section is Dictionary:
		return
	var e: Dictionary = section as Dictionary
	v.keys(e, ENCOUNTER_KEYS, "encounters")
	v.integer(e, "travel_ms", 0, DataValidatorRules.NO_LIMIT, "encounters")
	v.number(e, "node_chance_pct", 0.0, 100.0, "encounters")
	var min_ok: bool = v.integer(e, "node_min_ms", v.min_action_interval_ms, DataValidatorRules.NO_LIMIT, "encounters")
	v.integer(e, "node_ms", float(e["node_min_ms"]) if min_ok else 0.0, DataValidatorRules.NO_LIMIT, "encounters")
	v.integer(e, "skip_ms", 0, DataValidatorRules.NO_LIMIT, "encounters")
	v.integer(e, "node_units", 1, DataValidatorRules.NO_LIMIT, "encounters")
	_attempt_keys(v, e)
	var seen: Dictionary[StringName, bool] = {}
	var previous_below: float = 0.0
	var previous_pct: float = 100.0
	var rows: Array[Dictionary] = v.object_list(e, "colors", "encounters", 1)
	for index: int in rows.size():
		var prefix: String = "encounters.colors[%d]" % index
		var row: Dictionary = rows[index]
		v.keys(row, COLOR_KEYS, prefix)
		if v.text(row, "id", prefix):
			if seen.has(StringName(row["id"] as String)):
				v.fail("field '%s.id': duplicate '%s'" % [prefix, row["id"]])
			seen[StringName(row["id"] as String)] = true
		if v.integer(row, "below", 1, DataValidatorRules.NO_LIMIT, prefix):
			if float(row["below"]) <= previous_below:
				v.fail("field '%s.below' must be strictly increasing" % prefix)
			previous_below = float(row["below"])
		if v.number(row, "xp_pct", 0.0, 100.0, prefix):
			if float(row["xp_pct"]) > previous_pct:
				v.fail("field '%s.xp_pct' must not increase" % prefix)
			previous_pct = float(row["xp_pct"])
	if not rows.is_empty() and v.max_skill_level != DataValidatorRules.NO_LIMIT and previous_below < v.max_skill_level:
		v.fail("the last 'encounters.colors' entry must have below >= xp_curve.max_level (%d)" % int(v.max_skill_level))


# --- trainers.json ----------------------------------------------------------------------------------------------

static func _trainers_file(v: DataValidatorRules, content: Dictionary, strict: bool) -> void:
	v.keys(content, ["grades", "trainers"])
	_grades(v, v.object_list(content, "grades", "", 1))
	var seen: Dictionary[StringName, bool] = {}
	var list: Array[Dictionary] = v.object_list(content, "trainers")
	for index: int in list.size():
		var t: Dictionary = list[index]
		var id: StringName = v.at_entry("trainer", index, {"id": t.get("skill")})
		if id != &"" and seen.has(id):
			v.fail("duplicate trainer '%s'" % id)
		seen[id] = true
		v.keys(t, TRAINER_FIELDS)
		if v.ref(t, "skill", v.skills, "skill") and not _is_true(v.skills[id], "discipline"):
			v.fail("field 'skill': '%s' is not a discipline" % id)
		for key: String in ["name", "title", "description"]:
			if v.text(t, key) and (t[key] as String).strip_edges().is_empty():
				v.fail("field '%s' must not be empty" % key)
		if t.has("fed_by"):
			_fed_by(v, t, id)
	if strict:
		v.at_file("section 'disciplines'")
		for skill_id: StringName in v.skills:
			if _is_true(v.skills[skill_id], "discipline") and not seen.has(skill_id):
				v.fail("discipline '%s' has no Trainer" % skill_id)


# The grade rows: unique ids, `cap` strictly increasing in 1..xp_curve.max_level and ending at it, `character_level` not decreasing.
static func _grades(v: DataValidatorRules, rows: Array[Dictionary]) -> void:
	var seen: Dictionary[StringName, bool] = {}
	var previous_cap: float = 0.0
	var previous_level: float = 1.0
	var last_cap: float = -1.0
	for index: int in rows.size():
		var row: Dictionary = rows[index]
		v.entry("trainer grade", index, row, seen, GRADE_FIELDS)
		if v.integer(row, "cap", 1, v.max_skill_level):
			if float(row["cap"]) <= previous_cap:
				v.fail("field 'cap' must be strictly increasing")
			previous_cap = float(row["cap"])
			last_cap = previous_cap
		if v.integer(row, "character_level", 1, v.max_character_level):
			if float(row["character_level"]) < previous_level:
				v.fail("field 'character_level' must not decrease")
			previous_level = float(row["character_level"])
	if not rows.is_empty() and v.max_skill_level != DataValidatorRules.NO_LIMIT and last_cap >= 0.0 and last_cap != v.max_skill_level:
		v.fail("the last grade 'cap' must be xp_curve.max_level (%d), got %d" % [int(v.max_skill_level), int(last_cap)])


# `fed_by`: gathering disciplines, and only on an artisan discipline.
static func _fed_by(v: DataValidatorRules, t: Dictionary, owner: StringName) -> void:
	if v.skills.has(owner) and v.skills[owner].get("category") != "artisan":
		v.fail("field 'fed_by' is allowed only on an artisan discipline")
	for id: Variant in v.id_list(t, "fed_by", v.skills, "skill", 0):
		var def: Dictionary = v.skills.get(StringName(id as String), {})
		if not def.is_empty() and (def.get("category") != "gathering" or not _is_true(def, "discipline")):
			v.fail("field 'fed_by': '%s' is not a gathering discipline" % id)


# --- nodes.json -------------------------------------------------------------------------------------------------

static func _nodes_file(v: DataValidatorRules, content: Dictionary, areas: Dictionary[StringName, bool],
		first: Dictionary[StringName, bool], strict: bool) -> void:
	v.keys(content, ["areas"])
	var seen: Dictionary[StringName, bool] = {}
	var list: Array[Dictionary] = v.object_list(content, "areas")
	for index: int in list.size():
		var a: Dictionary = list[index]
		var id: StringName = v.at_entry("area nodes", index, {"id": a.get("area")})
		if id != &"" and seen.has(id):
			v.fail("duplicate area '%s'" % id)
		seen[id] = true
		v.keys(a, NODE_AREA_FIELDS)
		if v.text(a, "area") and not areas.has(id):
			v.fail("field 'area': unknown area '%s'" % id)
		v.integer(a, "max_level", 1, v.max_skill_level)
		_node_rows(v, a, first, strict, int(a["max_level"]) if DataValidatorRules.is_int(a.get("max_level")) else 0)
	if strict:
		for area_id: StringName in areas:
			if not seen.has(area_id):
				v.at_file("section 'encounters'")
				v.fail("area '%s' has no nodes" % area_id)


# 04_DATA_SCHEMA_M25.md §30.1: optional `difficulty` and `min_level` (1..max level; `min_level` <= the effective difficulty).
static func _node_levels(v: DataValidatorRules, node: Dictionary, area_cap: int) -> void:
	var difficulty: int = area_cap
	if node.has("difficulty") and v.integer(node, "difficulty", 1, v.max_skill_level, "nodes"):
		difficulty = int(node["difficulty"])
	if node.has("min_level") and v.integer(node, "min_level", 1, v.max_skill_level, "nodes") and int(node["min_level"]) > difficulty:
		v.fail("field 'nodes.min_level' (%d) must not exceed the difficulty (%d)" % [int(node["min_level"]), difficulty])


# 04_DATA_SCHEMA_M25.md §30.2: the keys of the attempts of a node (F-161, F-162, F-164).
static func _attempt_keys(v: DataValidatorRules, e: Dictionary) -> void:
	v.integer(e, "attempts", 1, 10, "encounters")
	v.integer(e, "yield_free_levels", 0, DataValidatorRules.NO_LIMIT, "encounters")
	v.integer(e, "yield_loss_pct", 0, 100, "encounters")
	v.integer(e, "yield_min_pct", 1, 100, "encounters")
	v.integer(e, "rich_chance_pct", 0, 100, "encounters")
	v.integer(e, "rich_extra_attempts", 0, 10, "encounters")
	v.integer(e, "rich_units_pct", 100, DataValidatorRules.NO_LIMIT, "encounters")
	v.integer(e, "rich_ms_pct", 100, DataValidatorRules.NO_LIMIT, "encounters")


static func _node_rows(v: DataValidatorRules, a: Dictionary, first: Dictionary[StringName, bool], strict: bool, area_cap: int) -> void:
	var seen: Dictionary[StringName, bool] = {}
	var total: int = 0
	var smallest: int = 1 << 30
	for node: Dictionary in v.object_list(a, "nodes", "", 1):
		v.keys(node, NODE_FIELDS, "nodes")
		if v.ref(node, "skill", v.skills, "skill", "nodes"):
			var skill_id: StringName = StringName(node["skill"] as String)
			if v.skills[skill_id].get("category") != "gathering":
				v.fail("field 'nodes.skill': '%s' is not a gathering skill" % skill_id)
			elif not first.has(skill_id):
				v.fail("field 'nodes.skill': '%s' has no gathering action of level 1 (F-154 would find no resource)" % skill_id)
			if seen.has(skill_id):
				v.fail("duplicate node skill '%s' in the area" % skill_id)
			seen[skill_id] = true
		_node_levels(v, node, area_cap)
		if v.integer(node, "weight", 1, DataValidatorRules.NO_LIMIT, "nodes"):
			total += int(node["weight"])
			smallest = mini(smallest, int(node["weight"]))
	if not strict:
		return
	for skill_id: StringName in v.skills:
		if _is_true(v.skills[skill_id], "discipline") and v.skills[skill_id].get("category") == "gathering" and not seen.has(skill_id):
			v.fail("the area lacks the node of discipline '%s'" % skill_id)
	if total != NODE_WEIGHT_TOTAL or smallest < NODE_WEIGHT_MIN:
		v.fail("the node weights must sum to %d with none below %d, got sum %d, smallest %d" % [NODE_WEIGHT_TOTAL, NODE_WEIGHT_MIN, total, smallest])


# The skills with an action of level <= 1 (`skill` of the actions file): a node of one of them always has a resource
# (F-154: the skill level is at least 1).
static func _first_resources(raw: Dictionary) -> Dictionary[StringName, bool]:
	var result: Dictionary[StringName, bool] = {}
	var files: Dictionary = raw.get("actions", {}) as Dictionary
	for path: Variant in files:
		var content: Dictionary = files[path] as Dictionary
		for a: Variant in (content.get("actions", []) as Array):
			var level: Variant = (a as Dictionary).get("level") if a is Dictionary else null
			if (level is int or level is float) and float(level) <= 1.0:
				result[StringName(str(content.get("skill", "")))] = true
	return result


# --- Recipes ----------------------------------------------------------------------------------------------------

# One Recipe per `discover` action; strict: every `discover` action has one, and every Recipe drops from a loot table.
static func _recipes(v: DataValidatorRules, raw: Dictionary, strict: bool) -> void:
	v.at_file("section 'items'")
	var taught: Dictionary[StringName, StringName] = {}
	for item_id: StringName in v.items:
		var recipe: Variant = v.items[item_id].get("recipe")
		if v.items[item_id].get("category") != "recipe" or not recipe is Dictionary or not (recipe as Dictionary).get("action") is String:
			continue
		var action_id: StringName = StringName((recipe as Dictionary)["action"] as String)
		if taught.has(action_id):
			v.fail("recipe items '%s' and '%s' teach the same action '%s'" % [taught[action_id], item_id, action_id])
		taught[action_id] = item_id
	if not strict:
		return
	for action_id: StringName in v.actions:
		if _is_true(v.actions[action_id], "discover") and not taught.has(action_id):
			v.fail("`discover` action '%s' has no Recipe item" % action_id)
	var dropped: Dictionary[StringName, bool] = {}
	var tables: Dictionary = raw.get("loot_tables", {}) as Dictionary
	for path: Variant in tables:
		for table: Variant in ((tables[path] as Dictionary).get("tables", []) as Array):
			for entry: Variant in ((table as Dictionary).get("entries", []) as Array if table is Dictionary else []):
				if entry is Dictionary and (entry as Dictionary).get("item") is String:
					dropped[StringName((entry as Dictionary)["item"] as String)] = true
	for item_id: StringName in taught.values():
		if not dropped.has(item_id):
			v.fail("Recipe '%s' is in no loot table" % item_id)


# A boolean field that is `true` (anything else, also a mistyped value, counts as false: the type is reported elsewhere).
static func _is_true(d: Dictionary, key: String) -> bool:
	return d.get(key) is bool and d[key] as bool


# The ids of `list_key` entries of the files of a section.
static func _ids(raw: Dictionary, section: String, list_key: String) -> Dictionary[StringName, bool]:
	var result: Dictionary[StringName, bool] = {}
	var files: Dictionary = raw.get(section, {}) as Dictionary
	for path: Variant in files:
		for e: Variant in ((files[path] as Dictionary).get(list_key, []) as Array):
			if e is Dictionary and (e as Dictionary).get("id") is String:
				result[StringName((e as Dictionary)["id"] as String)] = true
	return result
