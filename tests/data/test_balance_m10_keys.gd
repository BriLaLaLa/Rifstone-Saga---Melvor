extends "res://tests/data/m10_base.gd"
## M10-01: the M10 keys of balance.json (04_DATA_SCHEMA.md §3, §18; 02_FORMULAS.md §9): `start` extended,
## `blueprint`, `tool_upgrade`, `combat.kill_xp_mult`, `salvage.component_ratio`, `rarity.craft` removed. The real
## file (res://data/config) is read as it is; the validator rules run on the M10 fixtures (their own balance.json).

const REQUIRED: Array[String] = [
	"combat.kill_xp_mult", "salvage.component_ratio",
	"blueprint.duration_base_min", "blueprint.duration_per_grade_min", "blueprint.xp_mult", "blueprint.rare_base_pct",
	"blueprint.rare_per_forging_level", "blueprint.choose_affix_level", "blueprint.chosen_affix_tier",
	"tool_upgrade.interval_base_pct", "tool_upgrade.interval_per_level_pct", "tool_upgrade.levels",
]
const KIT_KEYS: Array[String] = ["start.armory", "start.tools", "start.purchases", "start.food",
	"tool_upgrade.plate_items", "tool_upgrade.handle_items"]

var _real: GameData = null


func before_all() -> void:
	_real = GameData.load_from_dirs()


func _start(raw: Dictionary) -> Dictionary:
	return balance(raw)["start"] as Dictionary


func _tool_upgrade(raw: Dictionary) -> Dictionary:
	return balance(raw)["tool_upgrade"] as Dictionary


func _level(raw: Dictionary, index: int) -> Dictionary:
	return (_tool_upgrade(raw)["levels"] as Array)[index] as Dictionary


func _erase(raw: Dictionary, path: String) -> void:
	var parent: Dictionary = balance(raw)
	var parts: PackedStringArray = path.split(".")
	for i: int in parts.size() - 1:
		parent = parent[parts[i]] as Dictionary
	parent.erase(parts[parts.size() - 1])


func _put(raw: Dictionary, path: String, value: Variant) -> void:
	var parent: Dictionary = balance(raw)
	var parts: PackedStringArray = path.split(".")
	for i: int in parts.size() - 1:
		parent = parent[parts[i]] as Dictionary
	parent[parts[parts.size() - 1]] = value


# --- the real file ---------------------------------------------------------------------------------------------------

func test_real_balance_is_valid_with_the_m10_keys() -> void:
	assert_true(_real.is_valid(), str(_real.errors))


func test_real_m10_values() -> void:
	assert_eq(_real.balance_value("combat.kill_xp_mult"), 0.064)
	assert_eq(_real.balance_value("salvage.component_ratio"), 0.4)
	assert_eq(_real.balance_value("blueprint.duration_base_min"), 10.0)
	assert_eq(_real.balance_value("blueprint.duration_per_grade_min"), 7.0)
	assert_eq(_real.balance_value("blueprint.xp_mult"), 1.5)
	assert_eq(_real.balance_value("blueprint.rare_base_pct"), 10.0)
	assert_eq(_real.balance_value("blueprint.rare_per_forging_level"), 0.5)
	assert_eq(_real.balance_value("blueprint.choose_affix_level"), 50.0)
	assert_eq(_real.balance_value("blueprint.chosen_affix_tier"), 2.0)
	assert_eq(_real.balance_value("tool_upgrade.interval_base_pct"), 5.0)
	assert_eq(_real.balance_value("tool_upgrade.interval_per_level_pct"), 2.0)


func test_real_tool_upgrade_table_is_the_one_of_f94() -> void:
	var levels: Array = _real.balance_value("tool_upgrade.levels") as Array
	assert_eq(levels.size(), 9)
	var min_levels: Array[int] = [1, 10, 20, 25, 35, 50, 65, 80, 90]
	var grades: Array[int] = [1, 2, 3, 3, 4, 5, 6, 7, 8]
	var plates: Array[int] = [2, 2, 3, 3, 4, 4, 5, 5, 6]
	var handles: Array[int] = [1, 1, 1, 1, 2, 2, 2, 2, 3]
	var gold: Array[int] = [100, 250, 600, 1200, 2500, 5000, 10000, 20000, 40000]
	for i: int in 9:
		var step: Dictionary = levels[i] as Dictionary
		assert_eq(int(step["min_level"]), min_levels[i], "min_level +%d" % (i + 1))
		assert_eq(int(step["grade"]), grades[i], "grade +%d" % (i + 1))
		assert_eq(int(step["plates"]), plates[i], "plates +%d" % (i + 1))
		assert_eq(int(step["handles"]), handles[i], "handles +%d" % (i + 1))
		assert_eq(int(step["gold"]), gold[i], "gold +%d" % (i + 1))


func test_real_item_rarity_stat_points_to_f84() -> void:
	assert_eq(_real.stats.info(&"item_rarity_pct")["formula"], "F-84")


func test_real_start_kit_keys() -> void:
	assert_eq(_real.balance_value("start.items"), [{"item": "seared_brookfin", "qty": 20.0}])
	assert_eq(_real.balance_value("start.food"), "seared_brookfin")
	assert_eq(_real.balance_value("start.purchases"), {"auto_eat_1": 1.0})
	var armory: Array = _real.balance_value("start.armory") as Array
	assert_eq(armory.size(), 3)
	assert_eq(armory[0], {"base": "emberbronze_sword", "equip": "weapon"})
	assert_eq(armory[1], {"base": "emberbronze_greatsword", "equip": ""})
	assert_eq(armory[2], {"base": "emberbronze_shield", "equip": "offhand"})
	assert_eq(_real.balance_value("start.tools"),
			[{"base": "unique_hatchet"}, {"base": "unique_pick"}, {"base": "unique_rod"}])
	assert_eq((_real.balance_value("tool_upgrade.plate_items") as Array).size(), 8)
	assert_eq((_real.balance_value("tool_upgrade.handle_items") as Array).size(), 8)
	assert_eq((_real.balance_value("tool_upgrade.plate_items") as Array)[7], "riftite_plate")
	assert_eq((_real.balance_value("tool_upgrade.handle_items") as Array)[0], "redbirch_handle")


func test_real_legacy_keys_are_gone() -> void:
	var balance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/config/balance.json")) as Dictionary
	assert_false((balance["rarity"] as Dictionary).has("craft"), "rarity.craft is removed")
	assert_false((balance["salvage"] as Dictionary).has("ingot_ratio"), "salvage.ingot_ratio is removed")


# --- required keys -----------------------------------------------------------------------------------------------------

func test_m10_fixture_balance_is_valid() -> void:
	assert_eq(validate(m10_raw()), PackedStringArray())


func test_each_required_key_is_required() -> void:
	for key: String in REQUIRED:
		var raw: Dictionary = m10_raw()
		_erase(raw, key)
		expect_error(raw, [BALANCE, "missing key '%s'" % key])


func test_kit_keys_are_required() -> void:
	for key: String in KIT_KEYS:
		var raw: Dictionary = m10_raw()
		_erase(raw, key)
		expect_error(raw, [BALANCE, "missing key '%s'" % key])


func test_legacy_keys_are_refused() -> void:
	var raw: Dictionary = m10_raw()
	_put(raw, "rarity.craft", {"magic_base_pct": 10})
	expect_error(raw, [BALANCE, "key 'rarity.craft' was removed in M10"])
	raw = m10_raw()
	_put(raw, "salvage.ingot_ratio", 0.4)
	expect_error(raw, [BALANCE, "key 'salvage.ingot_ratio' was removed in M10"])


func test_unknown_balance_key_is_still_refused() -> void:
	var raw: Dictionary = m10_raw()
	_put(raw, "blueprint.surprise", 1)
	expect_error(raw, [BALANCE, "unknown key 'blueprint.surprise'"])


# --- ranges ----------------------------------------------------------------------------------------------------------------

func test_kill_xp_mult_range() -> void:
	for bad: float in [0.0, -0.1, 1.5]:
		var raw: Dictionary = m10_raw()
		_put(raw, "combat.kill_xp_mult", bad)
		expect_error(raw, [BALANCE, "combat.kill_xp_mult"])
	var ok: Dictionary = m10_raw()
	_put(ok, "combat.kill_xp_mult", 1.0)
	assert_eq(validate(ok), PackedStringArray(), "1 is allowed")


func test_component_ratio_range() -> void:
	var raw: Dictionary = m10_raw()
	_put(raw, "salvage.component_ratio", 1.5)
	expect_error(raw, [BALANCE, "salvage.component_ratio"])


func test_blueprint_numbers_are_positive() -> void:
	for key: String in ["duration_base_min", "duration_per_grade_min", "xp_mult", "rare_base_pct", "rare_per_forging_level"]:
		var raw: Dictionary = m10_raw()
		_put(raw, "blueprint." + key, 0)
		expect_error(raw, [BALANCE, "blueprint." + key])


func test_choose_affix_level_range() -> void:
	for bad: int in [0, 100]:
		var raw: Dictionary = m10_raw()
		_put(raw, "blueprint.choose_affix_level", bad)
		expect_error(raw, [BALANCE, "blueprint.choose_affix_level"])


func test_chosen_affix_tier_is_at_least_one() -> void:
	var raw: Dictionary = m10_raw()
	_put(raw, "blueprint.chosen_affix_tier", 0)
	expect_error(raw, [BALANCE, "blueprint.chosen_affix_tier"])


func test_tool_interval_numbers_are_positive() -> void:
	for key: String in ["interval_base_pct", "interval_per_level_pct"]:
		var raw: Dictionary = m10_raw()
		_put(raw, "tool_upgrade." + key, 0)
		expect_error(raw, [BALANCE, "tool_upgrade." + key])


# --- tool_upgrade.levels ---------------------------------------------------------------------------------------------

func test_tool_levels_are_exactly_nine() -> void:
	var raw: Dictionary = m10_raw()
	(_tool_upgrade(raw)["levels"] as Array).pop_back()
	expect_error(raw, [BALANCE, "tool_upgrade.levels", "exactly 9 entries"])


func test_tool_levels_min_level_grows() -> void:
	var raw: Dictionary = m10_raw()
	_level(raw, 3)["min_level"] = 20
	expect_error(raw, [BALANCE, "tool_upgrade.levels[3].min_level", "must grow"])


func test_tool_levels_min_level_range() -> void:
	var raw: Dictionary = m10_raw()
	_level(raw, 8)["min_level"] = 100
	expect_error(raw, [BALANCE, "tool_upgrade.levels[8]", "min_level"])


func test_tool_levels_grade_does_not_decrease() -> void:
	var raw: Dictionary = m10_raw()
	_level(raw, 4)["grade"] = 2
	expect_error(raw, [BALANCE, "tool_upgrade.levels[4].grade", "must not decrease"])


func test_tool_levels_grade_range() -> void:
	var raw: Dictionary = m10_raw()
	_level(raw, 8)["grade"] = 9
	expect_error(raw, [BALANCE, "tool_upgrade.levels[8]", "grade"])


func test_tool_levels_counts_and_gold_are_at_least_one() -> void:
	for field: String in ["plates", "handles", "gold"]:
		var raw: Dictionary = m10_raw()
		_level(raw, 0)[field] = 0
		expect_error(raw, [BALANCE, "tool_upgrade.levels[0]", field])


func test_tool_levels_unknown_field() -> void:
	var raw: Dictionary = m10_raw()
	_level(raw, 0)["bonus"] = 1
	expect_error(raw, [BALANCE, "unknown field 'tool_upgrade.levels[0].bonus'"])


func test_tool_levels_missing_field() -> void:
	var raw: Dictionary = m10_raw()
	_level(raw, 0).erase("gold")
	expect_error(raw, [BALANCE, "tool_upgrade.levels[0]", "gold"])


# --- tool_upgrade.plate_items / handle_items ---------------------------------------------------------------------------

func test_component_lists_have_eight_items() -> void:
	for key: String in ["plate_items", "handle_items"]:
		var raw: Dictionary = m10_raw()
		(_tool_upgrade(raw)[key] as Array).pop_back()
		expect_error(raw, [BALANCE, "tool_upgrade." + key, "exactly 8 items"])


func test_component_lists_hold_components() -> void:
	for key: String in ["plate_items", "handle_items"]:
		var raw: Dictionary = m10_raw()
		(_tool_upgrade(raw)[key] as Array)[2] = "test_log"
		expect_error(raw, [BALANCE, "tool_upgrade." + key, "'test_log' is not a component"])


func test_component_lists_hold_existing_items() -> void:
	for key: String in ["plate_items", "handle_items"]:
		var raw: Dictionary = m10_raw()
		(_tool_upgrade(raw)[key] as Array)[2] = "no_such_item"
		expect_error(raw, [BALANCE, "tool_upgrade." + key, "unknown item 'no_such_item'"])


func test_component_lists_do_not_repeat() -> void:
	var raw: Dictionary = m10_raw()
	(_tool_upgrade(raw)["plate_items"] as Array)[1] = "test_plate_1"
	expect_error(raw, [BALANCE, "tool_upgrade.plate_items", "'test_plate_1' is repeated"])


# --- start ---------------------------------------------------------------------------------------------------------------------

func test_start_armory_base_is_an_equipment_item() -> void:
	var raw: Dictionary = m10_raw()
	((_start(raw)["armory"] as Array)[0] as Dictionary)["base"] = "test_ration"
	expect_error(raw, [BALANCE, "start.armory[0].base", "must be an equipment base"])


func test_start_armory_base_cannot_be_a_tool() -> void:
	var raw: Dictionary = m10_raw()
	((_start(raw)["armory"] as Array)[0] as Dictionary)["base"] = "test_hatchet"
	expect_error(raw, [BALANCE, "start.armory[0].base", "must be an equipment base, not a tool"])


func test_start_armory_base_is_grade_one() -> void:
	var raw: Dictionary = m10_raw()
	((_start(raw)["armory"] as Array)[0] as Dictionary)["base"] = "test_helm_high"
	((_start(raw)["armory"] as Array)[0] as Dictionary)["equip"] = "head"
	expect_error(raw, [BALANCE, "start.armory[0].base", "must be of grade 1"])


func test_start_armory_base_must_exist() -> void:
	var raw: Dictionary = m10_raw()
	((_start(raw)["armory"] as Array)[0] as Dictionary)["base"] = "no_such_piece"
	expect_error(raw, [BALANCE, "start.armory[0].base", "unknown item 'no_such_piece'"])


func test_start_armory_slot_must_fit_the_base() -> void:
	var raw: Dictionary = m10_raw()
	((_start(raw)["armory"] as Array)[0] as Dictionary)["equip"] = "head"
	expect_error(raw, [BALANCE, "start.armory[0].equip", "does not fit 'test_blade'"])


func test_start_armory_sword_fits_the_offhand_and_empty_slot_is_allowed() -> void:
	var raw: Dictionary = m10_raw()
	((_start(raw)["armory"] as Array)[0] as Dictionary)["equip"] = "offhand"
	((_start(raw)["armory"] as Array)[1] as Dictionary)["equip"] = ""
	assert_eq(validate(raw), PackedStringArray())


func test_start_armory_unknown_field() -> void:
	var raw: Dictionary = m10_raw()
	((_start(raw)["armory"] as Array)[0] as Dictionary)["rarity"] = "rare"
	expect_error(raw, [BALANCE, "unknown field 'start.armory[0].rarity'"])


func test_start_tools_are_unique_tools() -> void:
	var raw: Dictionary = m10_raw()
	((_start(raw)["tools"] as Array)[0] as Dictionary)["base"] = "test_blade"
	expect_error(raw, [BALANCE, "start.tools[0].base", "must be a unique tool"])


func test_start_tools_cover_every_tool_slot() -> void:
	var raw: Dictionary = m10_raw()
	(_start(raw)["tools"] as Array).pop_back()
	expect_error(raw, [BALANCE, "start.tools", "lacks a unique tool for slot 'tool_angling'"])


func test_start_tools_have_one_tool_per_slot() -> void:
	var raw: Dictionary = m10_raw()
	((_start(raw)["tools"] as Array)[1] as Dictionary)["base"] = "test_hatchet"
	expect_error(raw, [BALANCE, "start.tools[1].base", "a second tool for slot 'tool_forestry'"])


func test_start_purchases_are_shop_entries() -> void:
	var raw: Dictionary = m10_raw()
	_start(raw)["purchases"] = {"no_such_entry": 1}
	expect_error(raw, [BALANCE, "start.purchases", "unknown shop entry 'no_such_entry'"])


func test_start_purchases_respect_max_purchases() -> void:
	var raw: Dictionary = m10_raw()
	_start(raw)["purchases"] = {"test_upgrade_1": 2}
	expect_error(raw, [BALANCE, "start.purchases", "test_upgrade_1"])
	_start(raw)["purchases"] = {"test_upgrade_1": 0}
	expect_error(raw, [BALANCE, "start.purchases", "test_upgrade_1"])


func test_start_purchases_unlimited_entry_takes_any_count() -> void:
	var raw: Dictionary = m10_raw()
	_start(raw)["purchases"] = {"test_buy_log": 5}
	assert_eq(validate(raw), PackedStringArray())


func test_start_food_is_a_food() -> void:
	var raw: Dictionary = m10_raw()
	_start(raw)["food"] = "test_log"
	expect_error(raw, [BALANCE, "start.food", "'test_log' is not a food"])


func test_start_food_is_in_start_items() -> void:
	var raw: Dictionary = m10_raw()
	_start(raw)["items"] = []
	expect_error(raw, [BALANCE, "start.food", "is not in start.items"])


func test_start_food_must_exist() -> void:
	var raw: Dictionary = m10_raw()
	_start(raw)["food"] = "no_such_food"
	expect_error(raw, [BALANCE, "start.food", "unknown item 'no_such_food'"])
