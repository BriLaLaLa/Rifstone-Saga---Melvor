extends "res://tests/data/m10_base.gd"
## M10-01: unique tools, `level_modifiers`, single-cycle actions and the M10-mode rules of the validator
## (04_DATA_SCHEMA.md §4, §5, §6, §9, §18), then the Defs (EquipInfo, ToolExtra, LevelModifier, ActionDef) and
## `GameData.unique_tool`. One test per rule, on a broken copy of the M10 fixtures.

const TOOLS: String = "tools.json"
const SKILLS: String = "skills.json"
const FORGING: String = "forging.json"


func _equip(raw: Dictionary, id: String = "test_hatchet") -> Dictionary:
	return item_of(raw, TOOLS, id)["equip"] as Dictionary


func _extras(raw: Dictionary, id: String = "test_hatchet") -> Array:
	return _equip(raw, id)["upgrade_extras"] as Array


func _skill(raw: Dictionary, id: String) -> Dictionary:
	for e: Variant in file_of(raw, "skills", SKILLS)["skills"] as Array:
		if (e as Dictionary)["id"] == id:
			return e as Dictionary
	return {}


func _forging_action(raw: Dictionary, index: int) -> Dictionary:
	return entry_of(raw, "actions", FORGING, "actions", index)


# --- unique tools --------------------------------------------------------------------------------------------------

func test_tool_must_be_unique_in_m10_mode() -> void:
	var raw: Dictionary = m10_raw()
	_equip(raw)["unique"] = false
	expect_error(raw, [TOOLS, "item 'test_hatchet'", "field 'equip.unique' must be true for every tool"])
	_equip(raw).erase("unique")
	expect_error(raw, [TOOLS, "item 'test_hatchet'", "field 'equip.unique' must be true for every tool"])


func test_unique_must_be_a_boolean() -> void:
	var raw: Dictionary = m10_raw()
	_equip(raw)["unique"] = "yes"
	expect_error(raw, [TOOLS, "item 'test_hatchet'", "field 'equip.unique' must be a boolean"])


func test_unique_is_only_for_tools() -> void:
	var raw: Dictionary = m10_raw()
	(item_of(raw, "equipment.json", "test_blade")["equip"] as Dictionary)["unique"] = true
	expect_error(raw, ["equipment.json", "item 'test_blade'", "field 'equip.unique' is allowed only for category 'tool'"])


func test_upgrade_extras_are_only_for_tools() -> void:
	var raw: Dictionary = m10_raw()
	(item_of(raw, "equipment.json", "test_blade")["equip"] as Dictionary)["upgrade_extras"] = []
	expect_error(raw, ["equipment.json", "item 'test_blade'", "field 'equip.upgrade_extras' is allowed only for category 'tool'"])


func test_exactly_three_tools() -> void:
	var raw: Dictionary = m10_raw()
	var list: Array = file_of(raw, "items", TOOLS)["items"] as Array
	list.pop_back()
	expect_error(raw, ["expected exactly 3 tools", "got 2"])


func test_one_tool_per_slot() -> void:
	var raw: Dictionary = m10_raw()
	_equip(raw, "test_rod")["slot"] = "tool_forestry"
	expect_error(raw, [TOOLS, "item 'test_rod'", "a second tool for slot 'tool_forestry'"])


func test_a_fourth_tool_is_refused() -> void:
	var raw: Dictionary = m10_raw()
	var copy: Dictionary = item_of(raw, TOOLS, "test_rod").duplicate(true)
	copy["id"] = "test_rod_two"
	(file_of(raw, "items", TOOLS)["items"] as Array).append(copy)
	expect_error(raw, ["expected exactly 3 tools", "got 4"])


func test_unique_tool_is_free() -> void:
	var raw: Dictionary = m10_raw()
	item_of(raw, TOOLS, "test_hatchet")["value"] = 10
	expect_error(raw, [TOOLS, "item 'test_hatchet'", "must have 'value' 0"])


func test_unique_tool_is_grade_one() -> void:
	var raw: Dictionary = m10_raw()
	_equip(raw)["grade"] = 2
	expect_error(raw, [TOOLS, "item 'test_hatchet'", "'equip.grade' 1"])


func test_unique_tool_has_no_requirements() -> void:
	var raw: Dictionary = m10_raw()
	_equip(raw)["requirements"] = {"forestry": 5}
	expect_error(raw, [TOOLS, "item 'test_hatchet'", "no 'equip.requirements'"])


# --- upgrade_extras ------------------------------------------------------------------------------------------------

func test_upgrade_extras_step_range() -> void:
	var raw: Dictionary = m10_raw()
	(_extras(raw)[0] as Dictionary)["at"] = 0
	expect_error(raw, [TOOLS, "item 'test_hatchet'", "equip.upgrade_extras[0]"])
	(_extras(raw)[0] as Dictionary)["at"] = 10
	expect_error(raw, [TOOLS, "item 'test_hatchet'", "equip.upgrade_extras[0]"])


func test_upgrade_extras_step_is_not_repeated() -> void:
	var raw: Dictionary = m10_raw()
	(_extras(raw)[1] as Dictionary)["at"] = 5
	expect_error(raw, [TOOLS, "item 'test_hatchet'", "step 5 is given twice"])


func test_upgrade_extras_need_modifiers() -> void:
	var raw: Dictionary = m10_raw()
	(_extras(raw)[0] as Dictionary)["modifiers"] = []
	expect_error(raw, [TOOLS, "item 'test_hatchet'", "equip.upgrade_extras[0].modifiers' needs at least 1"])


func test_upgrade_extras_stat_must_exist() -> void:
	var raw: Dictionary = m10_raw()
	((((_extras(raw)[0] as Dictionary)["modifiers"]) as Array)[0] as Dictionary)["stat"] = "no_such_stat"
	expect_error(raw, [TOOLS, "item 'test_hatchet'", "stat 'no_such_stat' is not in stats.json"])


func test_upgrade_extras_scope_must_exist() -> void:
	var raw: Dictionary = m10_raw()
	((((_extras(raw)[0] as Dictionary)["modifiers"]) as Array)[0] as Dictionary)["scope"] = "skill:no_such_skill"
	expect_error(raw, [TOOLS, "item 'test_hatchet'", "equip.upgrade_extras[0].modifiers[0].scope"])


func test_upgrade_extras_unknown_field() -> void:
	var raw: Dictionary = m10_raw()
	(_extras(raw)[0] as Dictionary)["bonus"] = 1
	expect_error(raw, [TOOLS, "item 'test_hatchet'", "unknown field 'equip.upgrade_extras[0].bonus'"])


# --- other M10-mode rules --------------------------------------------------------------------------------------------

func test_recipes_do_not_produce_equipment() -> void:
	var raw: Dictionary = m10_raw()
	((_forging_action(raw, 0)["outputs"]) as Array)[0] = {"item": "test_blade", "qty": 1}
	expect_error(raw, [FORGING, "action 'smelt_test'", "'test_blade' is equipment, recipes no longer produce pieces"])


func test_recipes_do_not_produce_tools() -> void:
	var raw: Dictionary = m10_raw()
	((_forging_action(raw, 0)["outputs"]) as Array)[0] = {"item": "test_hatchet", "qty": 1}
	expect_error(raw, [FORGING, "action 'smelt_test'", "'test_hatchet' is tool, recipes no longer produce pieces"])


func test_shop_has_no_tools_category() -> void:
	var raw: Dictionary = m10_raw()
	entry_of(raw, "shop", "shop.json", "entries", 1)["category"] = "tools"
	expect_error(raw, ["shop.json", "shop entry 'test_upgrade_1'", "category 'tools' no longer exists"])


func test_tools_do_not_drop() -> void:
	var raw: Dictionary = m10_raw()
	var drops: Array = entry_of(raw, "monsters", "monsters.json", "monsters", 1)["drops"] as Array
	drops.append({"item": "test_hatchet", "chance_pct": 1, "qty": [1, 1]})
	expect_error(raw, ["monster 'test_monster_b'", "tools no longer drop"])


func test_legacy_data_keeps_the_old_tools() -> void:
	## Outside M10 mode (no `start.tools`) the old fixtures with non-unique tools stay valid.
	var errors: PackedStringArray = PackedStringArray()
	var legacy: GameData = GameData.load_from_dirs("res://tests/fixtures/data", "res://data/config")
	errors.append_array(legacy.errors)
	assert_eq(errors, PackedStringArray())
	assert_false(legacy.item(&"test_hatchet").equip.unique)


# --- level_modifiers -------------------------------------------------------------------------------------------------

func test_level_modifier_stat_must_exist() -> void:
	var raw: Dictionary = m10_raw()
	((_skill(raw, "forging")["level_modifiers"] as Array)[0] as Dictionary)["stat"] = "no_such_stat"
	expect_error(raw, [SKILLS, "skill 'forging'", "stat 'no_such_stat' is not in stats.json"])


func test_level_modifier_per_level_is_positive() -> void:
	var raw: Dictionary = m10_raw()
	((_skill(raw, "forging")["level_modifiers"] as Array)[0] as Dictionary)["per_level"] = 0
	expect_error(raw, [SKILLS, "skill 'forging'", "level_modifiers[0]"])


func test_level_modifier_unknown_field() -> void:
	var raw: Dictionary = m10_raw()
	((_skill(raw, "forging")["level_modifiers"] as Array)[0] as Dictionary)["scope"] = "global"
	expect_error(raw, [SKILLS, "skill 'forging'", "unknown field 'level_modifiers[0].scope'"])


func test_level_modifiers_must_be_a_list() -> void:
	var raw: Dictionary = m10_raw()
	_skill(raw, "forging")["level_modifiers"] = {"stat": "upgrade_success_pct"}
	expect_error(raw, [SKILLS, "skill 'forging'", "level_modifiers"])


# --- single-cycle actions --------------------------------------------------------------------------------------------

func test_single_action_may_have_no_inputs_and_outputs() -> void:
	assert_eq(validate(m10_raw()), PackedStringArray(), "blueprint_craft has empty inputs and outputs")


func test_single_is_only_for_forging() -> void:
	var raw: Dictionary = m10_raw()
	var action: Dictionary = entry_of(raw, "actions", "test_gather.json", "actions", 2)
	action["single"] = true
	action["mastery"] = false
	expect_error(raw, ["test_gather.json", "action 'gather_bundle'", "field 'single' is allowed only in the 'forging' skill"])


func test_single_has_no_mastery() -> void:
	var raw: Dictionary = m10_raw()
	_forging_action(raw, 1)["mastery"] = true
	expect_error(raw, [FORGING, "action 'blueprint_craft'", "'mastery' false"])


func test_single_must_be_a_boolean() -> void:
	var raw: Dictionary = m10_raw()
	_forging_action(raw, 1)["single"] = 1
	expect_error(raw, [FORGING, "action 'blueprint_craft'", "field 'single' must be a boolean"])


func test_regular_artisan_action_still_needs_inputs() -> void:
	var raw: Dictionary = m10_raw()
	_forging_action(raw, 0)["inputs"] = []
	expect_error(raw, [FORGING, "action 'smelt_test'", "inputs"])


func test_single_action_def() -> void:
	var data: GameData = GameData.load_from_dirs(M10_ROOT, M10_CONFIG)
	var craft: ActionDef = data.action(&"blueprint_craft")
	assert_true(craft.single)
	assert_true(craft.is_artisan(), "a single-cycle action belongs to the artisan side")
	assert_true(craft.inputs.is_empty())
	assert_false(data.action(&"smelt_test").single)
	assert_true(data.action(&"smelt_test").is_artisan())
	assert_false(data.action(&"gather_twig").single)
	assert_false(data.action(&"gather_twig").is_artisan())


# --- Defs and GameData ---------------------------------------------------------------------------------------------

func test_unique_tool_per_slot() -> void:
	var data: GameData = GameData.load_from_dirs(M10_ROOT, M10_CONFIG)
	assert_eq(data.unique_tool(&"tool_forestry").id, &"test_hatchet")
	assert_eq(data.unique_tool(&"tool_quarrying").id, &"test_pickaxe")
	assert_eq(data.unique_tool(&"tool_angling").id, &"test_rod")


func test_unique_tool_of_an_unknown_slot_is_null_with_error() -> void:
	var data: GameData = GameData.load_from_dirs(M10_ROOT, M10_CONFIG)
	assert_null(data.unique_tool(&"tool_cooking"))
	assert_push_error(1)


func test_tool_def_fields() -> void:
	var data: GameData = GameData.load_from_dirs(M10_ROOT, M10_CONFIG)
	var rod: EquipInfo = data.item(&"test_rod").equip
	assert_true(rod.unique)
	assert_eq(rod.slot, &"tool_angling")
	assert_eq(rod.upgrade_extras.size(), 2)
	assert_eq(rod.upgrade_extras[0].at, 5)
	assert_eq(rod.upgrade_extras[0].modifiers[0].stat, &"rift_shard_chance")
	assert_eq(rod.upgrade_extras[0].modifiers[0].value, 10.0)
	assert_eq(rod.upgrade_extras[1].at, 9)
	assert_eq(rod.upgrade_extras[1].modifiers[0].value, 15.0)
	assert_eq(rod.modifiers[0].stat, &"skill_interval_pct")
	assert_eq(rod.modifiers[0].value, -5.0)
	assert_eq(data.item(&"test_blade").equip.upgrade_extras.size(), 0)
	assert_false(data.item(&"test_blade").equip.unique)


func test_level_modifier_def() -> void:
	var data: GameData = GameData.load_from_dirs(M10_ROOT, M10_CONFIG)
	var forging: SkillDef = data.skill(&"forging")
	assert_eq(forging.level_modifiers.size(), 1)
	assert_eq(forging.level_modifiers[0].stat, &"upgrade_success_pct")
	assert_eq(forging.level_modifiers[0].per_level, 0.4)
	assert_eq(data.skill(&"quarrying").level_modifiers.size(), 0)


func test_level_modifier_from_dict_errors() -> void:
	assert_null(LevelModifier.from_dict({"stat": "upgrade_success_pct"}))
	assert_push_error("missing field 'per_level'")


func test_tool_extra_from_dict_errors() -> void:
	assert_null(ToolExtra.from_dict({"modifiers": []}))
	assert_push_error("missing field 'at'")


func test_real_data_has_no_serial_recipes_and_no_shop_tools() -> void:
	pending("M10-04: the real recipes of swords, armor and tools and the shop `tools` entries go away with the M10 content")


func test_real_data_has_three_unique_tools() -> void:
	pending("M10-04: the 27 graded tools become the 3 unique tools in data/items/tools.json")
