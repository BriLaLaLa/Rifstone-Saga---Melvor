class_name DataValidatorM10Balance
extends RefCounted
## Part of DataValidator (internal, not API for other modules): the M10 keys of balance.json
## (docs/04_DATA_SCHEMA.md §3, §18): `combat.kill_xp_mult`, `blueprint`, `tool_upgrade`, the extended `start` and the
## keys removed by the reform. Rules of the other M10 content: DataValidatorM10.

const M10_REQUIRED_KEYS: PackedStringArray = ["start.armory", "start.tools", "start.purchases", "start.food",
	"tool_upgrade.plate_items", "tool_upgrade.handle_items"]
## Keys of balance.json removed by M10 (R-01): present means an error.
const LEGACY_KEYS: PackedStringArray = ["rarity.craft", "salvage.ingot_ratio"]
const BLUEPRINT_NUMBERS: PackedStringArray = ["duration_base_min", "duration_per_grade_min", "xp_mult", "rare_base_pct",
	"rare_per_forging_level"]
const TOOL_STEPS: int = 9  # refinement steps +1..+9 (F-94)
const LEVEL_FIELDS: PackedStringArray = ["min_level", "grade", "plates", "handles", "gold"]
const GRADE_COUNT: int = 8
const START_ARMORY_GRADE: int = 1
const OFFHAND_SLOT: String = "offhand"
const SWORD_KIND: String = "sword"


# --- balance.json ------------------------------------------------------------------------------------------------

## Ranges of the M10 keys, the required keys and the removed keys. Wrong types are already reported.
static func validate_balance(v: DataValidatorRules, balance: Dictionary) -> void:
	var combat: Variant = DataValidator.lookup(balance, "combat")
	if combat is Dictionary and DataValidatorRules.is_number((combat as Dictionary).get("kill_xp_mult")):
		v.number(combat as Dictionary, "kill_xp_mult", 0.0, 1.0, "combat", true)  # B1: > 0 and <= 1
	var blueprint: Variant = DataValidator.lookup(balance, "blueprint")
	if blueprint is Dictionary:
		_blueprint_keys(v, blueprint as Dictionary)
	var tool_upgrade: Variant = DataValidator.lookup(balance, "tool_upgrade")
	if tool_upgrade is Dictionary:
		_tool_upgrade(v, tool_upgrade as Dictionary)
	for key: String in M10_REQUIRED_KEYS:
		if DataValidator.lookup(balance, key) == null:
			v.fail("missing key '%s'" % key)
	for key: String in LEGACY_KEYS:
		if DataValidator.lookup(balance, key) != null:
			v.fail("key '%s' was removed in M10" % key)


## M17 (F-130, V4, V11): `combat.pack_size_weights` (one non-negative integer per pack size 1..`max_pack_size`, summing to
## 100), `combat.xp_level`, `combat.monster_xp` and `combat.summon_drop_pct`. Wrong types are already reported.
static func validate_m17_combat(v: DataValidatorRules, combat: Variant) -> void:
	if not combat is Dictionary:
		return
	var c: Dictionary = combat as Dictionary
	var weights: Variant = c.get("pack_size_weights")
	if weights is Array:
		var total: float = 0.0
		var valid: bool = true
		for w: Variant in weights as Array:
			if not DataValidatorRules.is_int(w) or float(w) < 0.0:
				valid = false
			else:
				total += float(w)
		var expected: Variant = c.get("max_pack_size")
		if valid and DataValidatorRules.is_number(expected) and (weights as Array).size() != int(expected):
			v.fail("key 'combat.pack_size_weights' must have max_pack_size (%d) entries" % int(expected))
		elif not valid:
			v.fail("key 'combat.pack_size_weights' must hold integers >= 0")
		elif total != 100.0:
			v.fail("key 'combat.pack_size_weights' must sum to 100, got %s" % total)
	var xp_level: Variant = c.get("xp_level")
	if xp_level is Dictionary:
		var x: Dictionary = xp_level as Dictionary
		if DataValidatorRules.is_number(x.get("zero_gap")):
			v.integer(x, "zero_gap", 1, 99, "combat.xp_level")
		if DataValidatorRules.is_number(x.get("up_per_level")):
			v.number(x, "up_per_level", 0.0, DataValidatorRules.NO_LIMIT, "combat.xp_level", true)
		if DataValidatorRules.is_number(x.get("up_cap")):
			v.number(x, "up_cap", 1.0, DataValidatorRules.NO_LIMIT, "combat.xp_level")
	var monster_xp: Variant = c.get("monster_xp")
	if monster_xp is Dictionary:
		var m: Dictionary = monster_xp as Dictionary
		if DataValidatorRules.is_number(m.get("base")):
			v.integer(m, "base", 1, DataValidatorRules.NO_LIMIT, "combat.monster_xp")
		if DataValidatorRules.is_number(m.get("growth")):
			v.number(m, "growth", 1.0, DataValidatorRules.NO_LIMIT, "combat.monster_xp")
	if DataValidatorRules.is_number(c.get("summon_drop_pct")):
		v.number(c, "summon_drop_pct", 0.0, 100.0, "combat")


static func _blueprint_keys(v: DataValidatorRules, blueprint: Dictionary) -> void:
	for key: String in BLUEPRINT_NUMBERS:
		if DataValidatorRules.is_number(blueprint.get(key)):
			v.number(blueprint, key, 0.0, DataValidatorRules.NO_LIMIT, "blueprint", true)
	if DataValidatorRules.is_number(blueprint.get("choose_affix_level")):
		v.integer(blueprint, "choose_affix_level", 1.0, v.max_skill_level, "blueprint")
	if DataValidatorRules.is_number(blueprint.get("chosen_affix_tier")):
		v.integer(blueprint, "chosen_affix_tier", 1.0, DataValidatorRules.NO_LIMIT, "blueprint")


static func _tool_upgrade(v: DataValidatorRules, tool_upgrade: Dictionary) -> void:
	for key: String in ["interval_base_pct", "interval_per_level_pct"]:
		if DataValidatorRules.is_number(tool_upgrade.get(key)):
			v.number(tool_upgrade, key, 0.0, DataValidatorRules.NO_LIMIT, "tool_upgrade", true)
	if not tool_upgrade.get("levels") is Array:
		return
	var levels: Array[Dictionary] = v.object_list(tool_upgrade, "levels", "tool_upgrade")
	if (tool_upgrade["levels"] as Array).size() != TOOL_STEPS:
		v.fail("field 'tool_upgrade.levels' needs exactly %d entries (one per step), got %d" % [TOOL_STEPS,
				(tool_upgrade["levels"] as Array).size()])
	var previous_level: float = 0.0
	var previous_grade: float = 1.0
	for index: int in levels.size():
		var prefix: String = "tool_upgrade.levels[%d]" % index
		var level: Dictionary = levels[index]
		v.keys(level, LEVEL_FIELDS, prefix)
		if v.integer(level, "min_level", 1.0, v.max_skill_level, prefix):
			if float(level["min_level"]) <= previous_level:
				v.fail("field '%s.min_level' must grow from one step to the next" % prefix)
			previous_level = float(level["min_level"])
		if v.integer(level, "grade", 1.0, float(GRADE_COUNT), prefix):
			if float(level["grade"]) < previous_grade:
				v.fail("field '%s.grade' must not decrease" % prefix)
			previous_grade = float(level["grade"])
		for field: String in ["plates", "handles", "gold"]:
			v.integer(level, field, 1.0, DataValidatorRules.NO_LIMIT, prefix)


## References of the M10 keys of balance.json, checked once items and shop entries are known (each one when present).
static func validate_balance_refs(v: DataValidatorRules, balance: Dictionary) -> void:
	var start: Variant = DataValidator.lookup(balance, "start")
	if start is Dictionary:
		_start_armory(v, start as Dictionary)
		_start_tools(v, start as Dictionary)
		_start_purchases(v, start as Dictionary)
		_start_food(v, start as Dictionary)
	var tool_upgrade: Variant = DataValidator.lookup(balance, "tool_upgrade")
	if tool_upgrade is Dictionary:
		for key: String in ["plate_items", "handle_items"]:
			_component_ids(v, tool_upgrade as Dictionary, key)


static func _start_armory(v: DataValidatorRules, start: Dictionary) -> void:
	if not start.has("armory"):
		return
	var list: Array[Dictionary] = v.object_list(start, "armory", "start")
	for index: int in list.size():
		var entry: Dictionary = list[index]
		var prefix: String = "start.armory[%d]" % index
		v.keys(entry, ["base", "equip"], prefix)
		var base: Dictionary = DataValidatorM10.item_of(v, entry, "base", prefix)
		var equip: Variant = base.get("equip")
		if not equip is Dictionary:
			if not base.is_empty():
				v.fail("field '%s.base': '%s' must be an equipment base" % [prefix, entry["base"]])
		else:
			if str(base.get("category")) != "equipment":
				v.fail("field '%s.base': '%s' must be an equipment base, not a %s" % [prefix, entry["base"],
						base.get("category")])
			if DataValidatorRules.is_number((equip as Dictionary).get("grade")) \
					and int((equip as Dictionary)["grade"]) != START_ARMORY_GRADE:
				v.fail("field '%s.base': '%s' must be of grade %d" % [prefix, entry["base"], START_ARMORY_GRADE])
		if v.text(entry, "equip", prefix) and not (entry["equip"] as String).is_empty() and equip is Dictionary \
				and not _slot_fits(equip as Dictionary, entry["equip"] as String):
			v.fail("field '%s.equip': slot '%s' does not fit '%s'" % [prefix, entry["equip"], entry.get("base")])


# A sword (slot weapon) can also be worn in the offhand.
static func _slot_fits(equip: Dictionary, slot: String) -> bool:
	return slot == str(equip.get("slot")) or (slot == OFFHAND_SLOT and str(equip.get("kind")) == SWORD_KIND)


static func _start_tools(v: DataValidatorRules, start: Dictionary) -> void:
	if not start.has("tools"):
		return
	var list: Array[Dictionary] = v.object_list(start, "tools", "start")
	var slots: Dictionary[String, bool] = {}
	for index: int in list.size():
		var prefix: String = "start.tools[%d]" % index
		v.keys(list[index], ["base"], prefix)
		var base: Dictionary = DataValidatorM10.item_of(v, list[index], "base", prefix)
		if base.is_empty():
			continue
		var equip: Variant = base.get("equip")
		var is_unique_tool: bool = str(base.get("category")) == "tool" and equip is Dictionary \
				and DataValidatorM10.is_true(equip as Dictionary, "unique")
		if not is_unique_tool:
			v.fail("field '%s.base': '%s' must be a unique tool" % [prefix, list[index]["base"]])
			continue
		var slot: String = str((equip as Dictionary).get("slot"))
		if slots.has(slot):
			v.fail("field '%s.base': a second tool for slot '%s'" % [prefix, slot])
		slots[slot] = true
	if start.get("tools") is Array:
		for slot: String in DataValidatorM10.TOOL_SLOTS:
			if not slots.has(slot):
				v.fail("field 'start.tools' lacks a unique tool for slot '%s'" % slot)


static func _start_purchases(v: DataValidatorRules, start: Dictionary) -> void:
	if not start.has("purchases"):
		return
	var purchases: Dictionary = v.object(start, "purchases", "start")
	for key: Variant in purchases:
		var id := StringName(str(key))
		if not v.shop_entries.has(id):
			v.fail("field 'start.purchases': unknown shop entry '%s'" % key)
			continue
		var limit: Variant = v.shop_entries[id].get("max_purchases")
		var high: float = float(limit) if DataValidatorRules.is_number(limit) and float(limit) > 0.0 \
				else DataValidatorRules.NO_LIMIT  # max_purchases 0 = unlimited
		v.integer(purchases, str(key), 1.0, high, "start.purchases")


static func _start_food(v: DataValidatorRules, start: Dictionary) -> void:
	if not start.has("food"):
		return
	var food: Dictionary = DataValidatorM10.item_of(v, start, "food", "start")
	if food.is_empty():
		return
	if str(food.get("category")) != "food":
		v.fail("field 'start.food': '%s' is not a food" % start["food"])
		return
	var found: bool = false
	if start.get("items") is Array:
		for entry: Variant in start["items"] as Array:
			found = found or (entry is Dictionary and (entry as Dictionary).get("item") == start["food"])
	if not found:
		v.fail("field 'start.food': '%s' is not in start.items" % start["food"])


# `plate_items` / `handle_items`: 8 distinct `component` items (one per grade).
static func _component_ids(v: DataValidatorRules, tool_upgrade: Dictionary, key: String) -> void:
	if not tool_upgrade.has(key):
		return
	var path: String = "tool_upgrade.%s" % key
	var ids: Array = v.id_list(tool_upgrade, key, v.items, "item", 0, "tool_upgrade")
	if ids.size() != GRADE_COUNT:
		v.fail("field '%s' needs exactly %d items (one per grade), got %d" % [path, GRADE_COUNT, ids.size()])
	var seen: Dictionary[String, bool] = {}
	for id: Variant in ids:
		if seen.has(id as String):
			v.fail("field '%s': '%s' is repeated" % [path, id])
		seen[id as String] = true
		if v.items.has(StringName(id as String)) and str(v.items[StringName(id as String)].get("category")) != "component":
			v.fail("field '%s': '%s' is not a component" % [path, id])

