class_name DataValidatorM10
extends RefCounted
## Part of DataValidator (internal, not API for other modules): the rules of the loot reform, M10
## (docs/04_DATA_SCHEMA.md §18): blueprints and components, unique tools, `level_modifiers`, single-cycle actions and
## the M10 keys of balance.json (those are in DataValidatorM10Balance).
##
## Transition (until M10-04 brings the M10 content): the keys that reference M10 items (`start.armory`, `start.tools`,
## `start.purchases`, `start.food`, `tool_upgrade.plate_items`, `tool_upgrade.handle_items`) are optional and checked
## when present. The data is in "M10 mode" (`DataValidatorRules.m10_mode`) when `start.tools` exists: then those keys are
## required, the legacy keys are errors, there are exactly three unique tools, no recipe produces equipment or tools,
## the shop has no `tools` entries and tools no longer drop. M10-04 makes this the only mode.

const MODE_MARKER_KEY: String = "start.tools"
const TOOL_STEPS: int = 9  # refinement steps +1..+9 (F-94)
const BLUEPRINT_FIELDS: PackedStringArray = ["base", "grade", "inputs", "rare_component"]
const BLUEPRINT_INPUT_CATEGORIES: PackedStringArray = ["component", "material"]
const NO_BLUEPRINT_SLOTS: PackedStringArray = ["ring", "neck"]
const TOOL_SLOTS: PackedStringArray = ["tool_forestry", "tool_quarrying", "tool_angling"]
const GRADE_COUNT: int = 8
const SINGLE_SKILL: String = "forging"
const NO_RECIPE_CATEGORIES: PackedStringArray = ["equipment", "tool"]


static func is_m10(balance: Dictionary) -> bool:
	return DataValidator.lookup(balance, MODE_MARKER_KEY) != null


# --- skills ------------------------------------------------------------------------------------------------------

## `level_modifiers` of a skill (F-93): `[{"stat", "per_level" > 0}]`.
static func level_modifiers(v: DataValidatorRules, e: Dictionary) -> void:
	if not e.has("level_modifiers"):
		return
	var list: Array[Dictionary] = v.object_list(e, "level_modifiers")
	for index: int in list.size():
		var prefix: String = "level_modifiers[%d]" % index
		v.keys(list[index], ["stat", "per_level"], prefix)
		if v.text(list[index], "stat", prefix) and not v.stats.has(StringName(list[index]["stat"] as String)):
			v.fail("field '%s.stat': stat '%s' is not in stats.json" % [prefix, list[index]["stat"]])
		v.number(list[index], "per_level", 0.0, DataValidatorRules.NO_LIMIT, prefix, true)


# --- items -------------------------------------------------------------------------------------------------------

## The `blueprint` object of a `blueprint` item (§5, M10).
static func blueprint(v: DataValidatorRules, e: Dictionary) -> void:
	var bp: Dictionary = e["blueprint"] as Dictionary
	v.keys(bp, BLUEPRINT_FIELDS, "blueprint")
	if DataValidatorRules.is_int(e.get("value")) and int(e["value"]) != 0:
		v.fail("a blueprint must have 'value' 0 (not sellable)")
	v.integer(bp, "grade", 1.0, float(GRADE_COUNT), "blueprint")
	var base: Dictionary = item_of(v, bp, "base", "blueprint")
	if not base.is_empty():
		_blueprint_base(v, bp, base)
	var inputs: Array[Dictionary] = v.object_list(bp, "inputs", "blueprint", 1)
	for index: int in inputs.size():
		var prefix: String = "blueprint.inputs[%d]" % index
		v.item_qty(inputs[index], prefix)
		var item: Dictionary = v.items.get(StringName(str(inputs[index].get("item"))), {})
		if not item.is_empty() and not BLUEPRINT_INPUT_CATEGORIES.has(str(item.get("category"))):
			v.fail("field '%s.item': '%s' must be a component or a material" % [prefix, inputs[index]["item"]])
	if bp.get("rare_component") is Dictionary:
		var rare: Dictionary = bp["rare_component"] as Dictionary
		v.item_qty(rare, "blueprint.rare_component")
		var rare_item: Dictionary = v.items.get(StringName(str(rare.get("item"))), {})
		if not rare_item.is_empty() and str(rare_item.get("category")) != "material":
			v.fail("field 'blueprint.rare_component.item': '%s' must be a material" % rare["item"])
	else:
		v.object(bp, "rare_component", "blueprint")


static func _blueprint_base(v: DataValidatorRules, bp: Dictionary, base: Dictionary) -> void:
	var equip: Variant = base.get("equip")
	if str(base.get("category")) != "equipment" or not equip is Dictionary:
		v.fail("field 'blueprint.base': '%s' must be an equipment base, not a %s" % [bp["base"], base.get("category")])
		return
	if NO_BLUEPRINT_SLOTS.has(str((equip as Dictionary).get("slot"))):
		v.fail("field 'blueprint.base': '%s' is a ring or an amulet, they have no blueprint" % bp["base"])
	if DataValidatorRules.is_int(bp.get("grade")) and DataValidatorRules.is_number((equip as Dictionary).get("grade")) \
			and int(bp["grade"]) != int((equip as Dictionary)["grade"]):
		v.fail("field 'blueprint.grade': %d differs from the grade %d of '%s'" % [int(bp["grade"]),
				int((equip as Dictionary)["grade"]), bp["base"]])


## `unique` and `upgrade_extras` of an `equip` object (§5, M10); both belong to tools only.
static func tool_fields(v: DataValidatorRules, equip: Dictionary, category: String) -> void:
	for key: String in ["unique", "upgrade_extras"]:
		if equip.has(key) and category != "tool":
			v.fail("field 'equip.%s' is allowed only for category 'tool'" % key)
	if category != "tool":
		return
	if equip.has("unique"):
		v.flag(equip, "unique", "equip")
	if not equip.has("upgrade_extras"):
		return
	var seen: Dictionary[int, bool] = {}
	var extras: Array[Dictionary] = v.object_list(equip, "upgrade_extras", "equip")
	for index: int in extras.size():
		var prefix: String = "equip.upgrade_extras[%d]" % index
		v.keys(extras[index], ["at", "modifiers"], prefix)
		if v.integer(extras[index], "at", 1.0, float(TOOL_STEPS), prefix):
			if seen.has(int(extras[index]["at"])):
				v.fail("field '%s.at': step %d is given twice" % [prefix, int(extras[index]["at"])])
			seen[int(extras[index]["at"])] = true
		v.modifiers(extras[index], "modifiers", prefix)
		if extras[index].get("modifiers") is Array and (extras[index]["modifiers"] as Array).is_empty():
			v.fail("field '%s.modifiers' needs at least 1 entries" % prefix)


## Constraints across items, after every item passed its own rules: one blueprint per base; in M10 mode exactly
## three unique tools (one per `tool_*` slot, value 0, grade 1, no requirements).
static func validate_items(v: DataValidatorRules, files: Dictionary[String, Dictionary]) -> void:
	var by_base: Dictionary[String, StringName] = {}
	var tool_slots: Dictionary[String, bool] = {}
	var tools: int = 0
	for path: String in files:
		v.at_file(path)
		var list: Variant = files[path].get("items")
		for index: int in (list as Array).size() if list is Array else 0:
			var e: Variant = (list as Array)[index]
			if not e is Dictionary:
				continue
			var id: StringName = v.at_entry("item", index, e as Dictionary)
			var category: String = str((e as Dictionary).get("category"))
			var bp: Variant = (e as Dictionary).get("blueprint")
			if category == "blueprint" and bp is Dictionary and (bp as Dictionary).get("base") is String:
				var base: String = (bp as Dictionary)["base"] as String
				if by_base.has(base):
					v.fail("blueprint for base '%s' is already given by '%s'" % [base, by_base[base]])
				by_base[base] = id
			if category == "tool" and v.m10_mode:
				tools += 1
				_unique_tool(v, e as Dictionary, tool_slots)
	if v.m10_mode:
		v.at_file("section 'items'" if files.is_empty() else (files.keys()[0] as String).get_base_dir())
		if tools != TOOL_SLOTS.size():
			v.fail("expected exactly %d tools (one unique tool per tool slot), got %d" % [TOOL_SLOTS.size(), tools])


# M10 mode: a tool is unique, free (value 0), of grade 1 and has no requirements.
static func _unique_tool(v: DataValidatorRules, e: Dictionary, slots: Dictionary[String, bool]) -> void:
	var equip: Variant = e.get("equip")
	if not equip is Dictionary:
		return
	if not is_true(equip as Dictionary, "unique"):
		v.fail("field 'equip.unique' must be true for every tool (M10)")
	if DataValidatorRules.is_int(e.get("value")) and int(e["value"]) != 0:
		v.fail("a unique tool must have 'value' 0")
	if DataValidatorRules.is_number((equip as Dictionary).get("grade")) and int((equip as Dictionary)["grade"]) != 1:
		v.fail("a unique tool must have 'equip.grade' 1")
	var reqs: Variant = (equip as Dictionary).get("requirements")
	if reqs is Dictionary and not (reqs as Dictionary).is_empty():
		v.fail("a unique tool must have no 'equip.requirements'")
	var slot: String = str((equip as Dictionary).get("slot"))
	if slots.has(slot):
		v.fail("a second tool for slot '%s'" % slot)
	slots[slot] = true


# --- actions, shop, monsters ---------------------------------------------------------------------------------------

## The `single` flag of an action; returns true for a single-cycle action (which may have no inputs and outputs).
static func single_action(v: DataValidatorRules, e: Dictionary, skill: String) -> bool:
	if not e.has("single"):
		return false
	if not v.flag(e, "single") or not is_true(e, "single"):
		return false
	if skill != SINGLE_SKILL:
		v.fail("field 'single' is allowed only in the '%s' skill" % SINGLE_SKILL)
	if is_true(e, "mastery"):
		v.fail("a single-cycle action must have 'mastery' false")
	return true


## M10 mode: a recipe never produces equipment or tools (they come from blueprints and the kit).
static func recipe_outputs(v: DataValidatorRules, e: Dictionary) -> void:
	if not v.m10_mode or not e.get("outputs") is Array:
		return
	for output: Variant in e["outputs"] as Array:
		if not output is Dictionary:
			continue
		var item: Dictionary = v.items.get(StringName(str((output as Dictionary).get("item"))), {})
		if NO_RECIPE_CATEGORIES.has(str(item.get("category"))):
			v.fail("field 'outputs': '%s' is %s, recipes no longer produce pieces (M10)" % [(output as Dictionary)["item"],
					item.get("category")])


## M10 mode: no `tools` category in the shop.
static func shop_entry(v: DataValidatorRules, e: Dictionary) -> void:
	if v.m10_mode and e.get("category") == "tools":
		v.fail("category 'tools' no longer exists (M10)")


## A drop entry of a monster or a Rift Stone: a blueprint drops once (`qty` [1, 1]); in M10 mode tools do not drop.
static func drop(v: DataValidatorRules, drop_entry: Dictionary, prefix: String) -> void:
	var item: Dictionary = v.items.get(StringName(str(drop_entry.get("item"))), {})
	var category: String = str(item.get("category"))
	if category == "blueprint" and drop_entry.get("qty") is Array:
		var qty: Array = drop_entry["qty"] as Array
		if qty.size() != 2 or qty[0] != 1.0 or qty[1] != 1.0:
			v.fail("field '%s.qty': a blueprint drops as [1, 1]" % prefix)
	if category == "tool" and v.m10_mode:
		v.fail("field '%s.item': '%s' is a tool, tools no longer drop (M10)" % [prefix, drop_entry["item"]])


static func is_true(d: Dictionary, key: String) -> bool:
	return d.get(key) is bool and d[key] as bool


# The raw item entry referenced by `d[key]`, {} (after an error) if it is not an existing item.
static func item_of(v: DataValidatorRules, d: Dictionary, key: String, prefix: String) -> Dictionary:
	if v.ref(d, key, v.items, "item", prefix):
		return v.items[StringName(d[key] as String)]
	return {}
