extends GutTest
## DataValidator, narrow areas (M17-04; docs/04_DATA_SCHEMA.md §8, 02_FORMULAS.md §8.5): levels, contiguity, `map_pos` and the pack
## rules of every area. Each test breaks one thing in a copy of the REAL data (the generated areas) and expects the error.
## The fixtures (old format, no `level_min`) stay valid: test_data_validator.gd.

const V: GDScript = preload("res://tests/core/data/test_data_validator.gd")
const REAL_ROOT: String = "res://data"


func _real_raw() -> Dictionary:
	var errors: PackedStringArray = []
	var raw: Dictionary = {
		"balance": _read([V.CONFIG_ROOT.path_join(GameData.BALANCE_FILE)], errors),
		"stats": _read([V.CONFIG_ROOT.path_join(GameData.STATS_FILE)], errors),
	}
	for section: String in GameData.CONTENT_FILES:
		raw[section] = _read([REAL_ROOT.path_join(GameData.CONTENT_FILES[section])], errors)
	for section: String in GameData.CONTENT_DIRS:
		raw[section] = _read(JsonLoader.list_json_files(REAL_ROOT.path_join(GameData.CONTENT_DIRS[section]), errors), errors)
	raw["dungeons"] = _read(DungeonIndex.list_files(REAL_ROOT, errors), errors)  # M22-03: the real data has the Monkey Den
	assert(errors.is_empty(), "real files must load: %s" % [errors])
	return raw


func _read(paths: PackedStringArray, errors: PackedStringArray) -> Dictionary:
	var files: Dictionary = {}
	for path: String in paths:
		files[path] = JsonLoader.load_file(path, errors)
	return files


func _area(raw: Dictionary, index: int) -> Dictionary:
	return V.entry_of(raw, "areas", "areas.json", "areas", index)


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


func test_the_real_areas_are_valid() -> void:
	assert_eq(V.validate(_real_raw()), PackedStringArray())


func test_the_old_format_without_levels_is_still_valid() -> void:
	assert_eq(V.validate(V.fixture_raw()), PackedStringArray())


func test_every_area_needs_the_new_fields_once_one_has_them() -> void:
	var raw: Dictionary = _real_raw()
	_area(raw, 3).erase("level_max")
	_expect(raw, ["area 'cracked_mines'", "level_max"])
	var raw2: Dictionary = _real_raw()
	_area(raw2, 3).erase("map_pos")
	_expect(raw2, ["area 'cracked_mines'", "map_pos"])


func test_areas_must_be_contiguous_from_level_1_to_the_cap() -> void:
	var raw: Dictionary = _real_raw()
	_area(raw, 2)["level_min"] = 22
	_area(raw, 2)["requirements"] = {"character": 22}
	_expect(raw, ["area 'dry_uplands'", "level_min", "must start at 21"])
	var raw2: Dictionary = _real_raw()
	_area(raw2, 9)["level_max"] = 98
	_expect(raw2, ["the last area ends at level 98"])


func test_an_area_covers_at_most_ten_levels_and_the_range_is_ordered() -> void:
	var raw: Dictionary = _real_raw()
	_area(raw, 0)["level_max"] = 11
	_expect(raw, ["area 'redrock_plains'", "more than 10 levels"])
	var raw2: Dictionary = _real_raw()
	_area(raw2, 1)["level_min"] = 30
	_expect(raw2, ["area 'whisper_wood'", "above level_max"])


func test_the_requirement_is_level_min() -> void:
	var raw: Dictionary = _real_raw()
	_area(raw, 4)["requirements"] = {"character": 40}
	_expect(raw, ["area 'ash_marsh'", "requirements.character", "level_min (41)"])


func test_a_monster_must_be_inside_the_levels_of_its_area() -> void:
	var raw: Dictionary = _real_raw()
	_area(raw, 0)["packs"][0]["monsters"] = ["riftborn_colossus"]
	_expect(raw, ["area 'redrock_plains'", "riftborn_colossus", "outside the levels 1-10"])


func test_map_pos_is_two_numbers_in_0_1_apart_from_each_other() -> void:
	var raw: Dictionary = _real_raw()
	_area(raw, 0)["map_pos"] = [1.5, 0.2]
	_expect(raw, ["area 'redrock_plains'", "map_pos", "two numbers in 0..1"])
	var raw2: Dictionary = _real_raw()
	_area(raw2, 1)["map_pos"] = (_area(raw2, 0)["map_pos"] as Array).duplicate()
	_expect(raw2, ["area 'whisper_wood'", "map_pos", "closer than 0.08"])


func test_every_pack_size_must_be_present() -> void:
	var raw: Dictionary = _real_raw()
	var packs: Array = _area(raw, 5)["packs"] as Array
	for i: int in range(packs.size() - 1, -1, -1):
		if ((packs[i] as Dictionary)["monsters"] as Array).size() == 8:
			packs.remove_at(i)
	_expect(raw, ["area 'weeping_gorge'", "no pack of 8 monsters"])


func test_the_weight_of_each_size_is_the_balance_weight() -> void:
	var raw: Dictionary = _real_raw()
	_area(raw, 6)["packs"][0]["weight"] = 5  # the packs of size 1: 4 -> 5
	_expect(raw, ["area 'rift_threshold'", "packs of 1 monsters weigh 5", "says 4"])


## Puts `weights` in the balance and one pack per size (of the first monster of the area 0) with those weights in the area 0.
func _with_weights(weights: Array) -> Dictionary:
	var raw: Dictionary = _real_raw()
	var balance_weights: Array = (raw["balance"][raw["balance"].keys()[0]]["combat"] as Dictionary)["pack_size_weights"] as Array
	var area: Dictionary = _area(raw, 0)
	var monster: String = ((area["packs"] as Array)[0]["monsters"] as Array)[0]
	var packs: Array = []
	for size: int in range(1, 9):
		balance_weights[size - 1] = weights[size - 1]
		var ids: Array = []
		ids.resize(size)
		ids.fill(monster)
		packs.append({"weight": weights[size - 1], "monsters": ids})
	area["packs"] = packs
	return raw


func test_the_mean_size_stays_between_3_and_5() -> void:
	_expect(_with_weights([4, 4, 4, 4, 4, 4, 16, 60]), ["area 'redrock_plains'", "weighted mean size", "3.0-5.0"])
	_expect(_with_weights([60, 20, 4, 4, 4, 4, 2, 2]), ["area 'redrock_plains'", "weighted mean size"])
	assert_eq(V.validate(_with_weights([4, 12, 22, 26, 18, 10, 5, 3])).size(), 0, "the standard weights are fine")


func test_the_packs_of_one_and_of_the_biggest_size_are_at_most_6_percent_each() -> void:
	_expect(_with_weights([8, 12, 22, 22, 18, 10, 5, 3]), ["area 'redrock_plains'", "packs of 1 monsters are 8.0% of the weight", "at most 6%"])
	_expect(_with_weights([4, 12, 22, 22, 18, 10, 4, 8]), ["area 'redrock_plains'", "packs of 8 monsters are 8.0% of the weight", "at most 6%"])
