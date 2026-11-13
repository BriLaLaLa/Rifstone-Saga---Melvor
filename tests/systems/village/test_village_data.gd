extends GutTest
## Village data (docs/04_DATA_SCHEMA.md §24): GameData accessors and the rules of DataValidatorVillage.

const PATH: String = "res://data/village/buildings.json"


func _buildings() -> Array:
	return JSON.parse_string(FileAccess.get_file_as_string(PATH))["buildings"] as Array


# Errors of the real data with `change` applied to the parsed buildings and the balance `village` section.
func _errors(change: Callable) -> PackedStringArray:
	var raw: Dictionary = {}
	var errors: PackedStringArray = []
	raw["balance"] = DataBuildUtil.read_files(["res://data/config/balance.json"], errors)
	raw["stats"] = DataBuildUtil.read_files(["res://data/config/stats.json"], errors)
	for section: String in GameData.CONTENT_FILES:
		raw[section] = DataBuildUtil.read_files(["res://data".path_join(GameData.CONTENT_FILES[section])], errors)
	for section: String in GameData.CONTENT_DIRS:
		raw[section] = DataBuildUtil.read_files(JsonLoader.list_json_files("res://data".path_join(GameData.CONTENT_DIRS[section]), errors), errors)
	raw["guide"] = DataBuildUtil.read_files(DataValidatorGuide.list_files("res://data", errors), errors)
	change.call(raw)
	var found: PackedStringArray = []
	DataValidator.validate(raw, found)
	return found


func _first(raw: Dictionary) -> Array:
	return (raw["village"][PATH] as Dictionary)["buildings"] as Array


func test_accessors_of_the_real_data() -> void:
	var data: GameData = TestFactory.real_data()
	assert_eq(data.village_buildings().size(), 7)
	assert_eq(data.village_buildings()[0].id, &"storehouse", "ordered by `order`")
	var storehouse: VillageBuildingDef = data.village_building(&"storehouse")
	assert_eq(storehouse.effect_stat, &"deposit_slots")
	assert_eq(storehouse.effect_per_level, 4.0)
	assert_eq(storehouse.levels.size(), 8)
	assert_eq(data.village_building(&"market").levels.size(), 8)
	assert_true(data.village_building(&"market").unlocks_shop)
	assert_eq(data.village_building(&"noticeboard").effect_stat, &"quest_slots")
	assert_true(data.village_building(&"market").buildable)


func test_empty_file_is_valid_on_the_fixtures() -> void:
	assert_eq(TestFactory.fixture_data().village_buildings().size(), 0)


func test_a_placeholder_with_an_effect_is_rejected() -> void:
	var errors: PackedStringArray = _errors(func(raw: Dictionary) -> void:
		var b: Dictionary = _first(raw)[6] as Dictionary
		b["buildable"] = false
		b["milestone"] = 20
		b["levels"] = []
		b.erase("cost_spec")
		b["effect"] = {"stat": "armor", "scope": "global", "per_level": 1})
	assert_eq(errors.size(), 1, str(errors))
	assert_true(errors[0].contains("placeholder"), errors[0])


func test_effect_and_unlocks_shop_exclude_each_other() -> void:
	var errors: PackedStringArray = _errors(func(raw: Dictionary) -> void:
		(_first(raw)[5] as Dictionary)["effect"] = {"stat": "armor", "scope": "global", "per_level": 1})
	assert_true(str(errors).contains("exclude each other"), str(errors))


func test_the_effect_is_required_without_unlocks_shop() -> void:
	var errors: PackedStringArray = _errors(func(raw: Dictionary) -> void:
		(_first(raw)[5] as Dictionary).erase("unlocks_shop"))
	assert_gt(errors.size(), 0, "the Market without `unlocks_shop` needs an effect")


func _shop_first(raw: Dictionary) -> Array:
	return (raw["shop"]["res://data/shop/shop.json"] as Dictionary)["entries"] as Array


func test_requires_village_needs_an_unlocks_shop_building() -> void:
	var errors: PackedStringArray = _errors(func(raw: Dictionary) -> void:
		var shop: Array = _shop_first(raw)
		var entry: Dictionary = shop[shop.size() - 1] as Dictionary
		entry["requires"] = {"village": {"storehouse": 1}})
	assert_eq(errors.size(), 1, str(errors))
	assert_true(errors[0].contains("unlocks_shop"), errors[0])


func test_requires_village_level_is_limited_to_max_level() -> void:
	var errors: PackedStringArray = _errors(func(raw: Dictionary) -> void:
		var shop: Array = _shop_first(raw)
		(shop[shop.size() - 1] as Dictionary)["requires"] = {"village": {"market": 9}})
	assert_eq(errors.size(), 1, str(errors))


func test_a_buildable_with_a_wrong_number_of_levels_is_rejected() -> void:
	var errors: PackedStringArray = _errors(func(raw: Dictionary) -> void:
		((_first(raw)[1] as Dictionary)["levels"] as Array).pop_back())
	assert_eq(errors.size(), 1, str(errors))
	assert_true(errors[0].contains("exactly 8"), errors[0])


func test_an_unknown_stat_is_rejected() -> void:
	var errors: PackedStringArray = _errors(func(raw: Dictionary) -> void:
		((_first(raw)[1] as Dictionary)["effect"] as Dictionary)["stat"] = "no_such_stat")
	assert_gt(errors.size(), 0)
	assert_true(errors[0].contains("no_such_stat"), errors[0])


func test_two_buildings_cannot_share_a_stat_and_scope() -> void:
	var errors: PackedStringArray = _errors(func(raw: Dictionary) -> void:
		((_first(raw)[4] as Dictionary)["effect"] as Dictionary)["stat"] = "food_healing_pct")
	assert_gt(errors.size(), 0)
	assert_true(str(errors).contains("already used"), str(errors))


func test_the_woodwright_levels_must_increase() -> void:
	var errors: PackedStringArray = _errors(func(raw: Dictionary) -> void:
		var village: Dictionary = (raw["balance"]["res://data/config/balance.json"] as Dictionary)["village"] as Dictionary
		(village["woodwright_levels"] as Array)[3] = 5)
	assert_gt(errors.size(), 0)
	assert_true(str(errors).contains("woodwright_levels"), str(errors))
