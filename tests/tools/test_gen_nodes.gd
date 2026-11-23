extends GutTest
## F-201 (docs/02_FORMULAS_M35B.md): the table of weights per zone, row by row, for the four gathering disciplines; generator errors.

const Gen: GDScript = preload("res://tools/gen_nodes.gd")
const PROFILE: Array = [{"offset": -2, "weight": 5}, {"offset": -1, "weight": 25}, {"offset": 0, "weight": 55}, {"offset": 1, "weight": 15}]
const LEVELS: Array[int] = [1, 10, 20, 30, 45, 60, 75, 90]
## Zone -> [level_min, level_max], the real areas.
const ZONES: Array = [[1, 10], [11, 20], [21, 30], [31, 40], [41, 50], [51, 60], [61, 70], [71, 80], [81, 90], [91, 100]]
## F-201 table: per zone the percentages per ladder step index.
const EXPECTED: Array = [
	{0: 79, 1: 21}, {0: 26, 1: 58, 2: 16}, {0: 5, 1: 25, 2: 55, 3: 15}, {1: 5, 2: 25, 3: 55, 4: 15},
	{2: 5, 3: 25, 4: 55, 5: 15}, {2: 5, 3: 25, 4: 55, 5: 15}, {3: 5, 4: 25, 5: 55, 6: 15},
	{4: 5, 5: 25, 6: 55, 7: 15}, {4: 5, 5: 25, 6: 55, 7: 15}, {5: 6, 6: 29, 7: 65},
]
const SKILL_IDS: Dictionary = {
	"forestry": ["cut_redbirch", "cut_ashpine", "cut_thornalder", "cut_duskelm", "cut_shardcedar", "cut_veilcypress", "cut_emberlarch", "cut_riftspruce"],
	"quarrying": ["quarry_emberbronze", "quarry_ashlead", "quarry_stormzinc", "quarry_duskcobalt", "quarry_glimmerite", "quarry_palecinnabar", "quarry_emberheart", "quarry_riftite"],
	"angling": ["catch_brookfin", "catch_ashgill", "catch_redscale", "catch_dusk_eel", "catch_shard_gar", "catch_mist_barbel", "catch_ember_sturgeon", "catch_riftmaw"],
	"herbalism": ["gather_redrock_clover", "gather_ash_mint", "gather_thorn_sage", "gather_dusk_lily", "gather_shard_bloom", "gather_veil_fern", "gather_ember_thistle", "gather_rift_orchid"],
}


func _ladder(skill: String) -> Array:
	var ladder: Array = []
	for i: int in 8:
		ladder.append({"id": (SKILL_IDS[skill] as Array)[i], "level": LEVELS[i]})
	return ladder


func _all_actions() -> Dictionary:
	var actions: Dictionary = {}
	for skill: String in SKILL_IDS:
		actions[skill] = _ladder(skill)
	return actions


func test_every_zone_and_discipline_matches_f201() -> void:
	for skill: String in SKILL_IDS:
		for zone: int in ZONES.size():
			var table: Array = Gen.resource_table(_ladder(skill), int((ZONES[zone] as Array)[0]), int((ZONES[zone] as Array)[1]), PROFILE)
			var expected: Dictionary = EXPECTED[zone] as Dictionary
			assert_eq(table.size(), expected.size(), "%s z%d size" % [skill, zone + 1])
			var sum: int = 0
			for entry: Variant in table:
				var index: int = (SKILL_IDS[skill] as Array).find((entry as Dictionary)["action"])
				assert_eq(int((entry as Dictionary)["weight"]), int(expected.get(index, -1)), "%s z%d step %d" % [skill, zone + 1, index])
				sum += int((entry as Dictionary)["weight"])
			assert_eq(sum, 100, "%s z%d sum" % [skill, zone + 1])


func test_miner_copper_is_dominant_in_zone_one() -> void:
	var table: Array = Gen.resource_table(_ladder("quarrying"), 1, 10, PROFILE)
	assert_eq(table, [{"action": "quarry_emberbronze", "weight": 79}, {"action": "quarry_ashlead", "weight": 21}])


func test_generate_is_idempotent_and_writes_resources() -> void:
	var areas: Array = [{"id": "redrock_plains", "level_min": 1, "level_max": 10}]
	var first: Dictionary = Gen.generate(areas, _all_actions(), PROFILE)
	var second: Dictionary = Gen.generate(areas, _all_actions(), PROFILE)
	assert_eq((first["errors"] as PackedStringArray).size(), 0)
	assert_eq(first["text"], second["text"])
	assert_string_contains(first["text"] as String, "\"resources\":[{\"action\":\"quarry_emberbronze\",\"weight\":79}")


func test_unsorted_actions_are_ordered_by_level() -> void:
	var shuffled: Array = _ladder("quarrying")
	shuffled.reverse()
	var ladder: Array = Gen._ladder(shuffled)
	assert_eq((ladder[0] as Dictionary)["id"], "quarry_emberbronze")
	assert_eq((ladder[7] as Dictionary)["id"], "quarry_riftite")


func test_too_few_actions_is_an_error_and_writes_nothing() -> void:
	var actions: Dictionary = _all_actions()
	actions["angling"] = (actions["angling"] as Array).slice(0, 3)
	var result: Dictionary = Gen.generate([{"id": "redrock_plains", "level_min": 1, "level_max": 10}], actions, PROFILE)
	assert_gt((result["errors"] as PackedStringArray).size(), 0)
	assert_eq(result["text"], "")


func test_area_without_theme_is_an_error() -> void:
	var result: Dictionary = Gen.generate([{"id": "nowhere", "level_min": 1, "level_max": 10}], _all_actions(), PROFILE)
	assert_gt((result["errors"] as PackedStringArray).size(), 0)
	assert_eq(result["text"], "")


func test_bad_profile_is_an_error() -> void:
	assert_gt(Gen._check_profile([]).size(), 0)
	assert_gt(Gen._check_profile([{"offset": 0, "weight": 5}, {"offset": 0, "weight": 5}]).size(), 0)
	assert_gt(Gen._check_profile([{"offset": 0, "weight": 0}]).size(), 0)
	assert_eq(Gen._check_profile(PROFILE).size(), 0)
