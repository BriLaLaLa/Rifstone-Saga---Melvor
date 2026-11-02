extends GutTest
## DataValidator, part 2: items (04_DATA_SCHEMA.md §5) and actions (§6). One test per rule, on a broken copy of the
## fixture data; helpers from test_data_validator.gd.

const V: GDScript = preload("res://tests/core/data/test_data_validator.gd")
const GATHER: String = "test_gather.json"
const CRAFT: String = "test_craft.json"


func _expect(raw: Dictionary, fragments: Array[String]) -> void:
	var errors: PackedStringArray = V.validate(raw)
	for message: String in errors:
		var matched: bool = true
		for fragment: String in fragments:
			matched = matched and message.contains(fragment)
		if matched:
			assert_true(true)
			return
	fail_test("no error with %s in %s" % [fragments, errors])


func _item(raw: Dictionary, file_name: String) -> Dictionary:
	return V.entry_of(raw, "items", file_name, "items", 0)


func _action(raw: Dictionary, file_name: String, index: int) -> Dictionary:
	return V.entry_of(raw, "actions", file_name, "actions", index)


func _equip(raw: Dictionary, file_name: String) -> Dictionary:
	return _item(raw, file_name)["equip"] as Dictionary


# --- items -------------------------------------------------------------------------------------------------------

func test_item_ids_are_unique_across_files() -> void:
	var raw: Dictionary = V.fixture_raw()
	_item(raw, "food.json")["id"] = "test_twig"
	_expect(raw, ["materials.json", "item 'test_twig'", "duplicate item 'test_twig'"])


func test_items_file_name_must_be_a_category_file() -> void:
	var raw: Dictionary = V.fixture_raw()
	var path: String = V.FIXTURE_ROOT.path_join("items/weapons.json")
	raw["items"][path] = {"items": []}
	_expect(raw, ["weapons.json", "unknown items file 'weapons'"])


func test_item_category_must_match_its_file() -> void:
	var raw: Dictionary = V.fixture_raw()
	_item(raw, "materials.json")["category"] = "misc"
	_expect(raw, ["materials.json", "item 'test_twig'", "category 'misc' does not match its file"])


func test_item_category_must_be_known() -> void:
	var raw: Dictionary = V.fixture_raw()
	_item(raw, "materials.json")["category"] = "junk"
	_expect(raw, ["materials.json", "item 'test_twig'", "field 'category' must be one of"])


func test_item_value_is_not_negative() -> void:
	var raw: Dictionary = V.fixture_raw()
	_item(raw, "materials.json")["value"] = -1
	_expect(raw, ["materials.json", "item 'test_twig'", "field 'value' must be >= 0"])


func test_item_icon_must_be_under_the_item_icons() -> void:
	var raw: Dictionary = V.fixture_raw()
	_item(raw, "materials.json")["icon"] = "twig.png"
	_expect(raw, ["materials.json", "item 'test_twig'", "must be a path under res://assets/icons/items/"])


func test_equip_is_required_for_equipment_and_tools() -> void:
	var raw: Dictionary = V.fixture_raw()
	_item(raw, "tools.json").erase("equip")
	_expect(raw, ["tools.json", "item 'test_hatchet'", "missing field 'equip'"])


func test_sub_objects_are_forbidden_outside_their_category() -> void:
	var raw: Dictionary = V.fixture_raw()
	_item(raw, "materials.json")["equip"] = {"slot": "head", "requirements": {}, "modifiers": []}
	_item(raw, "materials.json")["food"] = {"heal": 5}
	_item(raw, "food.json")["infusion"] = {"modifiers": []}
	_expect(raw, ["materials.json", "item 'test_twig'", "field 'equip' is not allowed for category 'material'"])
	_expect(raw, ["materials.json", "item 'test_twig'", "field 'food' is not allowed for category 'material'"])
	_expect(raw, ["food.json", "item 'test_ration'", "field 'infusion' is not allowed for category 'food'"])


func test_food_needs_heal_of_at_least_1() -> void:
	var raw: Dictionary = V.fixture_raw()
	(_item(raw, "food.json")["food"] as Dictionary)["heal"] = 0
	_expect(raw, ["food.json", "item 'test_ration'", "field 'food.heal' must be >= 1"])


func test_infusion_object_is_required_and_checked() -> void:
	var raw: Dictionary = V.fixture_raw()
	(_item(raw, "infusions.json")["infusion"] as Dictionary)["unique"] = "yes"
	_expect(raw, ["infusions.json", "item 'test_infusion'", "field 'infusion.unique' must be a boolean"])
	_item(raw, "infusions.json").erase("infusion")
	_expect(raw, ["infusions.json", "item 'test_infusion'", "missing field 'infusion'"])


func test_equip_slot_must_be_known() -> void:
	var raw: Dictionary = V.fixture_raw()
	_equip(raw, "equipment.json")["slot"] = "tail"
	_expect(raw, ["equipment.json", "item 'test_blade'", "field 'equip.slot' must be one of"])


func test_tool_slots_are_only_for_tools() -> void:
	var raw: Dictionary = V.fixture_raw()
	_equip(raw, "equipment.json")["slot"] = "tool_angling"
	_expect(raw, ["equipment.json", "item 'test_blade'", "slot 'tool_angling' is only for category 'tool'"])


func test_equip_requirements_need_known_skills_and_levels() -> void:
	var raw: Dictionary = V.fixture_raw()
	_equip(raw, "equipment.json")["requirements"] = {"sorcery": 1, "blade": 120}
	_expect(raw, ["equipment.json", "item 'test_blade'", "field 'equip.requirements.sorcery': unknown skill"])
	_expect(raw, ["equipment.json", "item 'test_blade'", "field 'equip.requirements.blade' must be >= 1 and <= 99"])


func test_equip_modifier_scope_must_point_to_known_ids() -> void:
	var raw: Dictionary = V.fixture_raw()
	var mods: Array = _equip(raw, "tools.json")["modifiers"] as Array
	mods.append({"stat": "skill_xp_pct", "value": 1, "scope": "action:cut_nothing"})
	mods.append({"stat": "skill_xp_pct", "value": 1, "scope": "zone:plains"})
	(mods[0] as Dictionary)["scope"] = "skill:forestry"
	_expect(raw, ["tools.json", "item 'test_hatchet'", "scope 'skill:forestry' points to an unknown skill"])
	_expect(raw, ["tools.json", "item 'test_hatchet'", "scope 'action:cut_nothing' points to an unknown action"])
	_expect(raw, ["tools.json", "item 'test_hatchet'", "scope 'zone:plains' must be global, skill:<id> or action:<id>"])


func test_weapon_is_only_for_the_weapon_slot() -> void:
	var raw: Dictionary = V.fixture_raw()
	_equip(raw, "equipment.json")["slot"] = "offhand"
	_expect(raw, ["equipment.json", "item 'test_blade'", "field 'equip.weapon' is allowed only with slot 'weapon'"])


func test_weapon_fields_are_checked() -> void:
	var raw: Dictionary = V.fixture_raw()
	var weapon: Dictionary = _equip(raw, "equipment.json")["weapon"] as Dictionary
	weapon["style"] = "fists"
	weapon["attack_interval_ms"] = 799
	_expect(raw, ["equipment.json", "item 'test_blade'", "field 'equip.weapon.style' must be one of"])
	_expect(raw, ["equipment.json", "item 'test_blade'", "field 'equip.weapon.attack_interval_ms' must be >= 800"])


func test_rift_shard_is_required() -> void:
	var raw: Dictionary = V.fixture_raw()
	_item(raw, "misc.json")["id"] = "rift_dust"
	_expect(raw, ["items", "required item 'rift_shard' (category misc) is missing"])


# --- actions -----------------------------------------------------------------------------------------------------

func test_action_file_skill_must_match_the_file_name() -> void:
	var raw: Dictionary = V.fixture_raw()
	V.file_of(raw, "actions", CRAFT)["skill"] = "test_gather_b"
	_expect(raw, [CRAFT, "skill 'test_gather_b' must be equal to the file name"])


func test_action_file_skill_must_exist() -> void:
	var raw: Dictionary = V.fixture_raw()
	var path: String = V.FIXTURE_ROOT.path_join("actions/sorcery.json")
	raw["actions"][path] = {"skill": "sorcery", "actions": []}
	_expect(raw, ["sorcery.json", "field 'skill': unknown skill 'sorcery'"])


func test_action_file_skill_must_be_gathering_or_artisan() -> void:
	var raw: Dictionary = V.fixture_raw()
	var path: String = V.FIXTURE_ROOT.path_join("actions/blade.json")
	raw["actions"][path] = {"skill": "blade", "actions": []}
	_expect(raw, ["blade.json", "skill 'blade' has category 'combat'"])


func test_action_ids_are_unique_across_files() -> void:
	var raw: Dictionary = V.fixture_raw()
	_action(raw, CRAFT, 0)["id"] = "gather_twig"
	_expect(raw, [GATHER, "action 'gather_twig'", "duplicate action 'gather_twig'"])


func test_action_level_is_1_to_max_level() -> void:
	var raw: Dictionary = V.fixture_raw()
	_action(raw, GATHER, 0)["level"] = 0
	_expect(raw, [GATHER, "action 'gather_log'", "field 'level' must be >= 1 and <= 99"])


func test_action_interval_is_at_least_the_minimum() -> void:
	var raw: Dictionary = V.fixture_raw()
	_action(raw, GATHER, 0)["interval_ms"] = 249
	_expect(raw, [GATHER, "action 'gather_log'", "field 'interval_ms' must be >= 250"])


func test_action_xp_is_at_least_1() -> void:
	var raw: Dictionary = V.fixture_raw()
	_action(raw, GATHER, 0)["xp"] = 0
	_expect(raw, [GATHER, "action 'gather_log'", "field 'xp' must be >= 1"])


func test_gathering_actions_have_no_inputs() -> void:
	var raw: Dictionary = V.fixture_raw()
	_action(raw, GATHER, 0)["inputs"] = [{"item": "test_twig", "qty": 1}]
	_expect(raw, [GATHER, "action 'gather_log'", "gathering actions must have no inputs"])


func test_artisan_actions_need_inputs() -> void:
	var raw: Dictionary = V.fixture_raw()
	_action(raw, CRAFT, 0)["inputs"] = []
	_expect(raw, [CRAFT, "action 'craft_plank'", "field 'inputs' needs at least 1 entries"])


func test_actions_need_outputs() -> void:
	var raw: Dictionary = V.fixture_raw()
	_action(raw, GATHER, 1)["outputs"] = []
	_expect(raw, [GATHER, "action 'gather_twig'", "field 'outputs' needs at least 1 entries"])


func test_action_items_must_exist_with_quantity_at_least_1() -> void:
	var raw: Dictionary = V.fixture_raw()
	_action(raw, CRAFT, 0)["outputs"] = [{"item": "gold_bar", "qty": 0}]
	_expect(raw, [CRAFT, "action 'craft_plank'", "field 'outputs[0].item': unknown item 'gold_bar'"])
	_expect(raw, [CRAFT, "action 'craft_plank'", "field 'outputs[0].qty' must be >= 1"])


func test_action_optional_icon_must_be_a_string() -> void:
	var raw: Dictionary = V.fixture_raw()
	_action(raw, GATHER, 0)["icon"] = false
	_expect(raw, [GATHER, "action 'gather_log'", "field 'icon' must be a string"])


func test_infusion_needs_at_least_one_modifier() -> void:
	var raw: Dictionary = V.fixture_raw()
	(_item(raw, "infusions.json")["infusion"] as Dictionary)["modifiers"] = []
	_expect(raw, ["infusions.json", "item 'test_infusion'", "field 'infusion.modifiers' needs at least 1 entries"])


func test_doc_in_a_level_map_is_allowed() -> void:
	var raw: Dictionary = V.fixture_raw()
	(_equip(raw, "equipment.json")["requirements"] as Dictionary)["_doc"] = "minimum levels"
	assert_eq(V.validate(raw), PackedStringArray())
	(_equip(raw, "equipment.json")["requirements"] as Dictionary)["_doc"] = 5
	_expect(raw, ["equipment.json", "item 'test_blade'", "field 'equip.requirements._doc': unknown skill '_doc'"])
