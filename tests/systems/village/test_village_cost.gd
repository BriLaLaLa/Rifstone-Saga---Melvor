extends GutTest
## F-131 (docs/02_FORMULAS.md §5h): the cost of a Village level, with the examples of the document, the regeneration
## check (the file equals what tools/gen_village.gd writes) and the validator's comparison with the regeneration.

const GenVillage := preload("res://tools/gen_village.gd")
const BUILDINGS_PATH: String = "res://data/village/buildings.json"

var _data: GameData
var _params: Dictionary


func before_all() -> void:
	_data = TestFactory.real_data()
	_params = _data.balance_value("village") as Dictionary


func _level(building: StringName, level: int) -> Dictionary:
	return _data.village_building(building).levels[level - 1]


func _qty(row: Dictionary, item: StringName) -> int:
	for entry: Dictionary in row["items"] as Array:
		if entry["item"] == item:
			return int(entry["qty"])
	return -1


func test_storehouse_level_3() -> void:
	var row: Dictionary = _level(&"storehouse", 3)
	assert_eq(_qty(row, &"thornalder_shieldcore"), 40)
	assert_eq(_qty(row, &"stormzinc_plate"), 8)
	assert_eq((row["items"] as Array).size(), 2)
	assert_eq(row["gold"], 590, "588 rounds to 590")
	assert_eq(row["requires_woodwright"], 20)


func test_inn_level_8() -> void:
	var row: Dictionary = _level(&"inn", 8)
	assert_eq(_qty(row, &"riftspruce_grip"), 90)
	assert_eq(_qty(row, &"seared_riftmaw"), 58)
	assert_eq(row["gold"], 2530, "0.8 x 3162.4 = 2529.9 -> 2530")
	assert_eq(row["requires_woodwright"], 90)


func test_forge_level_1() -> void:
	var row: Dictionary = _level(&"forge", 1)
	assert_eq(_qty(row, &"redbirch_handle"), 20)
	assert_eq(_qty(row, &"emberbronze_plate"), 8)
	assert_eq(row["gold"], 300)
	assert_eq(row["requires_woodwright"], 1)


func test_sawmill_level_5() -> void:
	var row: Dictionary = _level(&"sawmill", 5)
	assert_eq(_qty(row, &"shardcedar_grip"), 90)
	assert_eq(_qty(row, &"shardcedar_handle"), 90)
	assert_eq(row["gold"], 690, "0.6 x 1152.48 = 691.5 -> 690")
	assert_eq(row["requires_woodwright"], 45)


func test_loot_shed_level_2() -> void:
	var row: Dictionary = _level(&"loot_shed", 2)
	assert_eq(_qty(row, &"ashpine_handle"), 30)
	assert_eq(_qty(row, &"ashlead_plate"), 6)
	assert_eq(row["gold"], 340, "0.8 x 420 = 336 -> 340")
	assert_eq(row["requires_woodwright"], 10)


func test_base_gold_table() -> void:
	var gold: Array[int] = []
	var spec: Dictionary = {"cost_spec": {"wood": [{"component": "grip", "weight": 1.0}], "plate": 0.0, "food": 0.0,
			"gold_weight": 1.0}, "effect": {"per_level": 1.0}}
	for level: int in range(1, 9):
		gold.append(int(GenVillage.levels_for(spec, _params, level)["gold"]))
	assert_eq(gold, [300, 420, 590, 820, 1150, 1610, 2260, 3160] as Array[int])


func test_base_quantity_tables() -> void:
	var spec: Dictionary = {"cost_spec": {"wood": [{"component": "grip", "weight": 1.0}], "plate": 1.0, "food": 1.0,
			"gold_weight": 1.0}, "effect": {"per_level": 1.0}}
	var wood: Array[int] = []
	var plate: Array[int] = []
	var food: Array[int] = []
	for level: int in range(1, 9):
		var row: Dictionary = GenVillage.levels_for(spec, _params, level)
		wood.append(int((row["items"] as Array)[0]["qty"]))
		plate.append(int((row["items"] as Array)[1]["qty"]))
		food.append(int((row["items"] as Array)[2]["qty"]))
	assert_eq(wood, [40, 60, 80, 100, 120, 140, 160, 180] as Array[int])
	assert_eq(plate, [8, 12, 16, 20, 24, 28, 32, 36] as Array[int])
	assert_eq(food, [16, 22, 28, 34, 40, 46, 52, 58] as Array[int])


func test_a_wood_line_is_at_least_one() -> void:
	var spec: Dictionary = {"cost_spec": {"wood": [{"component": "grip", "weight": 0.001}], "plate": 0.0, "food": 0.0,
			"gold_weight": 1.0}, "effect": {"per_level": 1.0}}
	assert_eq(int((GenVillage.levels_for(spec, _params, 1)["items"] as Array)[0]["qty"]), 1)


func test_requirements_follow_the_woodwright_levels() -> void:
	var levels: Array[int] = []
	for level: int in range(1, 9):
		levels.append(int(_level(&"storehouse", level)["requires_woodwright"]))
	assert_eq(levels, [1, 10, 20, 30, 45, 60, 75, 90] as Array[int])


func test_file_equals_the_regeneration() -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BUILDINGS_PATH)) as Dictionary
	var result: Dictionary = GenVillage.generate(source, _params, GenVillage.item_ids())
	assert_eq((result["errors"] as PackedStringArray).size(), 0, "every item of the levels exists")
	assert_true(result["text"] == FileAccess.get_file_as_string(BUILDINGS_PATH), "buildings.json is what gen_village.gd writes")


func test_generation_fails_for_a_missing_item() -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BUILDINGS_PATH)) as Dictionary
	var items: Dictionary = GenVillage.item_ids()
	items.erase("riftspruce_grip")
	var result: Dictionary = GenVillage.generate(source, _params, items)
	assert_gt((result["errors"] as PackedStringArray).size(), 0)
	assert_eq(result["text"], "")


func test_validator_rejects_a_hand_edited_level() -> void:
	var raw: Dictionary = _raw()
	var buildings: Array = (raw["village"][BUILDINGS_PATH] as Dictionary)["buildings"] as Array
	((buildings[0] as Dictionary)["levels"] as Array)[2]["gold"] = 600
	var errors: PackedStringArray = []
	DataValidator.validate(raw, errors)
	assert_eq(errors.size(), 1, str(errors))
	assert_true(errors[0].contains("gold"), errors[0])


func test_validator_accepts_the_real_data() -> void:
	var errors: PackedStringArray = []
	DataValidator.validate(_raw(), errors)
	assert_eq(errors.size(), 0, str(errors))


# The `raw` of the real data (deep copy): balance, stats, content files and folders.
func _raw() -> Dictionary:
	var errors: PackedStringArray = []
	var raw: Dictionary = {
		"balance": DataBuildUtil.read_files(["res://data/config/balance.json"], errors),
		"stats": DataBuildUtil.read_files(["res://data/config/stats.json"], errors),
	}
	for section: String in GameData.CONTENT_FILES:
		raw[section] = DataBuildUtil.read_files(["res://data".path_join(GameData.CONTENT_FILES[section])], errors)
	for section: String in GameData.CONTENT_DIRS:
		raw[section] = DataBuildUtil.read_files(JsonLoader.list_json_files("res://data".path_join(GameData.CONTENT_DIRS[section]), errors), errors)
	raw["guide"] = DataBuildUtil.read_files(DataValidatorGuide.list_files("res://data", errors), errors)
	raw["dungeons"] = DataBuildUtil.read_files(DungeonIndex.list_files("res://data", errors), errors)
	assert_eq(errors.size(), 0, str(errors))
	return raw
