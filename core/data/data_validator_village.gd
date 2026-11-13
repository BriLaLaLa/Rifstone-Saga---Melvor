class_name DataValidatorVillage
extends RefCounted
## Village rules of DataValidator (internal, M19; docs/04_DATA_SCHEMA.md §24, docs/02_FORMULAS.md F-131/F-132): the
## `village` section of balance.json and data/village/buildings.json. `levels_for` is the pure F-131/F-132 function: the
## validator compares every written level with it, tools/gen_village.gd writes them with it and the tests call it.

const WOODS: PackedStringArray = ["redbirch", "ashpine", "thornalder", "duskelm", "shardcedar", "veilcypress", "emberlarch", "riftspruce"]
const METALS: PackedStringArray = ["emberbronze", "ashlead", "stormzinc", "duskcobalt", "glimmerite", "palecinnabar", "emberheart", "riftite"]
const FISH: PackedStringArray = ["brookfin", "ashgill", "redscale", "dusk_eel", "shard_gar", "mist_barbel", "ember_sturgeon", "riftmaw"]
const COMPONENTS: PackedStringArray = ["grip", "handle", "shieldcore"]
const QTY_KINDS: PackedStringArray = ["wood", "plate", "food"]
const BUILDING_FIELDS: PackedStringArray = ["id", "name", "description", "icon", "order", "buildable", "milestone", "effect",
	"cost_spec", "levels"]
const SPEC_FIELDS: PackedStringArray = ["wood", "plate", "food", "gold_weight"]
const LEVEL_FIELDS: PackedStringArray = ["level", "requires_woodwright", "gold", "items", "effect_value"]
const FORBIDDEN_CATEGORIES: PackedStringArray = ["equipment", "tool", "map"]  # they live in the Armory, not in the Deposit
const WEIGHT_EPSILON: float = 0.000001


## True for the `village` section of balance.json (its fields are checked by `validate_balance`).
static func is_known_key(path: String) -> bool:
	return path == "village"


## F-131/F-132: the generated level `level` (1..max_level) of a building `spec` (the hand-written parts of its entry: `effect`,
## `cost_spec`) with the `village` parameters of balance.json. Items are `{"item": String, "qty": int}`.
static func levels_for(spec: Dictionary, params: Dictionary, level: int) -> Dictionary:
	var cost: Dictionary = spec["cost_spec"] as Dictionary
	var qty: Dictionary = params["qty"] as Dictionary
	var items: Array[Dictionary] = []
	for line: Variant in cost["wood"] as Array:
		var row: Dictionary = line as Dictionary
		items.append({"item": "%s_%s" % [WOODS[level - 1], row["component"]],
				"qty": maxi(1, _ceil(float(row["weight"]) * _base(qty, "wood", level)))})
	if float(cost["plate"]) > 0.0:
		items.append({"item": "%s_plate" % METALS[level - 1], "qty": _ceil(float(cost["plate"]) * _base(qty, "plate", level))})
	if float(cost["food"]) > 0.0:
		items.append({"item": "seared_%s" % FISH[level - 1], "qty": _ceil(float(cost["food"]) * _base(qty, "food", level))})
	var gold: float = float(params["gold_base"]) * pow(float(params["gold_growth"]), level - 1) * float(cost["gold_weight"])
	var effect: Dictionary = spec["effect"] as Dictionary
	return {"level": level, "requires_woodwright": int((params["woodwright_levels"] as Array)[level - 1]),
			"gold": int(floorf(gold / 10.0 + 0.5)) * 10, "items": items,
			"effect_value": float(effect["per_level"]) * float(level)}


static func validate_balance(v: DataValidatorRules, balance: Dictionary) -> void:
	var section: Variant = DataValidator.lookup(balance, "village")
	if not section is Dictionary:
		v.fail("missing key 'village'")
		return
	var village: Dictionary = section as Dictionary
	v.keys(village, ["max_level", "woodwright_levels", "gold_base", "gold_growth", "qty"], "village")
	var count: int = 0
	if v.integer(village, "max_level", 1.0, 99.0, "village"):
		count = int(village["max_level"])
		if count > WOODS.size():
			v.fail("key 'village.max_level' is %d: there are only %d grades of materials" % [count, WOODS.size()])
	_woodwright_levels(v, village, count)
	v.integer(village, "gold_base", 1.0, DataValidatorRules.NO_LIMIT, "village")
	v.number(village, "gold_growth", 1.0, DataValidatorRules.NO_LIMIT, "village")
	var qty: Dictionary = v.object(village, "qty", "village")
	v.keys(qty, QTY_KINDS, "village.qty")
	for kind: String in QTY_KINDS:
		var line: Dictionary = v.object(qty, kind, "village.qty")
		var prefix: String = "village.qty.%s" % kind
		v.keys(line, ["base", "per_level"], prefix)
		var ok: bool = v.integer(line, "base", 0.0, DataValidatorRules.NO_LIMIT, prefix)
		ok = v.integer(line, "per_level", 0.0, DataValidatorRules.NO_LIMIT, prefix) and ok
		if ok and int(line["base"]) + int(line["per_level"]) < 1:
			v.fail("key '%s': base + per_level must be >= 1" % prefix)


## data/village/buildings.json. `balance_files` gives the parameters for the generated levels (skipped when invalid).
static func validate(v: DataValidatorRules, files: Dictionary[String, Dictionary], balance_files: Dictionary[String, Dictionary]) -> void:
	var params: Dictionary = _valid_params(balance_files)
	var seen: Dictionary[StringName, bool] = {}
	var orders: Dictionary[int, bool] = {}
	var effect_keys: Dictionary[String, bool] = {}
	for path: String in files:
		v.at_file(path)
		var list: Array[Dictionary] = DataValidator.entries(v, files[path], "buildings")
		for index: int in list.size():
			var e: Dictionary = list[index]
			v.entry("building", index, e, seen, BUILDING_FIELDS, orders)
			v.text(e, "icon")
			if DataValidatorRules.is_int(e.get("order")) and float(e["order"]) < 1.0:
				v.fail("field 'order' must be >= 1")
			if not v.flag(e, "buildable"):
				continue
			if e["buildable"] as bool:
				_buildable(v, e, params, effect_keys)
			else:
				_placeholder(v, e)


static func _buildable(v: DataValidatorRules, e: Dictionary, params: Dictionary, effect_keys: Dictionary[String, bool]) -> void:
	if e.has("milestone"):
		v.fail("field 'milestone' is only for placeholders (buildable false)")
	var effect_ok: bool = _effect(v, e, effect_keys)
	var spec_ok: bool = _cost_spec(v, e)
	var levels: Array[Dictionary] = v.object_list(e, "levels")
	if params.is_empty():
		return
	if levels.size() != int(params["max_level"]):
		v.fail("field 'levels' needs exactly %d entries (village.max_level), got %d" % [int(params["max_level"]), levels.size()])
	if effect_ok and spec_ok:
		for index: int in mini(levels.size(), int(params["max_level"])):
			_level(v, levels[index], levels_for(e, params, index + 1), index + 1)


static func _placeholder(v: DataValidatorRules, e: Dictionary) -> void:
	v.integer(e, "milestone", 1.0)
	for key: String in ["effect", "cost_spec"]:
		if e.has(key):
			v.fail("field '%s' is not allowed on a placeholder (buildable false)" % key)
	if not e.get("levels") is Array or not (e["levels"] as Array).is_empty():
		v.fail("field 'levels' must be [] on a placeholder")


static func _effect(v: DataValidatorRules, e: Dictionary, effect_keys: Dictionary[String, bool]) -> bool:
	var effect: Dictionary = v.object(e, "effect")
	v.keys(effect, ["stat", "scope", "per_level"], "effect")
	var ok: bool = v.text(effect, "stat", "effect")
	ok = v.text(effect, "scope", "effect") and ok
	ok = v.number(effect, "per_level", -DataValidatorRules.NO_LIMIT, DataValidatorRules.NO_LIMIT, "effect") and ok
	if not ok:
		return false
	var before: int = v.errors.size()
	v.modifiers({"m": [{"stat": effect["stat"], "value": effect["per_level"], "scope": effect["scope"]}]}, "m", "effect")
	var key: String = "%s|%s" % [effect["scope"], effect["stat"]]
	if effect_keys.has(key):
		v.fail("field 'effect': stat '%s' with scope '%s' is already used by another building" % [effect["stat"], effect["scope"]])
	effect_keys[key] = true
	return v.errors.size() == before


static func _cost_spec(v: DataValidatorRules, e: Dictionary) -> bool:
	var spec: Dictionary = v.object(e, "cost_spec")
	v.keys(spec, SPEC_FIELDS, "cost_spec")
	var before: int = v.errors.size()
	var used: Dictionary[String, bool] = {}
	for row: Dictionary in v.object_list(spec, "wood", "cost_spec"):
		v.keys(row, ["component", "weight"], "cost_spec.wood")
		v.one_of(row, "component", COMPONENTS, "cost_spec.wood")
		v.number(row, "weight", 0.0, DataValidatorRules.NO_LIMIT, "cost_spec.wood", true)
		if row.get("component") is String:
			if used.has(row["component"] as String):
				v.fail("field 'cost_spec.wood': duplicate component '%s'" % row["component"])
			used[row["component"] as String] = true
	v.number(spec, "plate", 0.0, DataValidatorRules.NO_LIMIT, "cost_spec")
	v.number(spec, "food", 0.0, DataValidatorRules.NO_LIMIT, "cost_spec")
	v.number(spec, "gold_weight", 0.0, DataValidatorRules.NO_LIMIT, "cost_spec", true)
	if v.errors.size() == before and used.is_empty() and float(spec["plate"]) < WEIGHT_EPSILON \
			and float(spec["food"]) < WEIGHT_EPSILON:
		v.fail("field 'cost_spec' needs at least one line of items")
	return v.errors.size() == before


# One written level against the regeneration of F-131/F-132.
static func _level(v: DataValidatorRules, written: Dictionary, expected: Dictionary, n: int) -> void:
	var prefix: String = "levels[%d]" % (n - 1)
	v.keys(written, LEVEL_FIELDS, prefix)
	for key: String in ["level", "requires_woodwright", "gold"]:
		if v.integer(written, key, 0.0, DataValidatorRules.NO_LIMIT, prefix) and int(written[key]) != int(expected[key]):
			v.fail("field '%s.%s' is %d, F-131 gives %d (rerun tools/gen_village.gd)" % [prefix, key, int(written[key]), int(expected[key])])
	if v.number(written, "effect_value", -DataValidatorRules.NO_LIMIT, DataValidatorRules.NO_LIMIT, prefix) \
			and not is_equal_approx(float(written["effect_value"]), float(expected["effect_value"])):
		v.fail("field '%s.effect_value' is %s, F-132 gives %s" % [prefix, written["effect_value"], expected["effect_value"]])
	v.item_qty_list(written, "items", 1, prefix)
	var rows: Array = written.get("items", []) as Array if written.get("items") is Array else []
	var known: Dictionary[String, bool] = {}
	for row: Variant in rows:
		if row is Dictionary and (row as Dictionary).get("item") is String:
			var id: String = (row as Dictionary)["item"] as String
			if known.has(id):
				v.fail("field '%s.items': duplicate item '%s'" % [prefix, id])
			known[id] = true
			var category: String = str(v.items[StringName(id)].get("category")) if v.items.has(StringName(id)) else ""
			if FORBIDDEN_CATEGORIES.has(category):
				v.fail("field '%s.items': '%s' is %s, which cannot be paid from the Deposit" % [prefix, id, category])
	if _items_differ(rows, expected["items"] as Array):
		v.fail("field '%s.items' differs from the F-131 regeneration (rerun tools/gen_village.gd)" % prefix)


static func _items_differ(written: Array, expected: Array) -> bool:
	if written.size() != expected.size():
		return true
	for index: int in written.size():
		var a: Variant = written[index]
		var b: Dictionary = expected[index] as Dictionary
		if not a is Dictionary or str((a as Dictionary).get("item")) != str(b["item"]) \
				or int(float((a as Dictionary).get("qty", -1))) != int(b["qty"]):
			return true
	return false


# `village` of balance.json when valid ({} otherwise; the balance errors are reported by validate_balance).
static func _valid_params(balance_files: Dictionary[String, Dictionary]) -> Dictionary:
	for path: String in balance_files:
		var probe := DataValidatorRules.new()
		validate_balance(probe, balance_files[path])
		if probe.errors.is_empty():
			return DataValidator.lookup(balance_files[path], "village") as Dictionary
	return {}


static func _woodwright_levels(v: DataValidatorRules, village: Dictionary, count: int) -> void:
	if not village.get("woodwright_levels") is Array:
		v.fail("key 'village.woodwright_levels' must be an array")
		return
	var list: Array = village["woodwright_levels"] as Array
	if count > 0 and list.size() != count:
		v.fail("key 'village.woodwright_levels' needs exactly max_level (%d) entries, got %d" % [count, list.size()])
	var previous: float = 0.0
	for value: Variant in list:
		if not DataValidatorRules.is_int(value) or float(value) < 1.0 or float(value) > 99.0 or float(value) <= previous:
			v.fail("key 'village.woodwright_levels' must be strictly increasing integers in 1..99, got %s" % JSON.stringify(list))
			return
		previous = float(value)


static func _base(qty: Dictionary, kind: String, level: int) -> float:
	var line: Dictionary = qty[kind] as Dictionary
	return float(int(line["base"]) + int(line["per_level"]) * level)


static func _ceil(x: float) -> int:
	return ceili(x - WEIGHT_EPSILON)
