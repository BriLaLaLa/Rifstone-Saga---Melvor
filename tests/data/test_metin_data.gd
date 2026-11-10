extends GutTest
## Data checks of M15 (docs/04_DATA_SCHEMA.md §22): Rift Stone pools per area (Z2) and the new balance keys.

const EXPECTED: Dictionary = {
	"redrock_plains": [5, 10, 15], "whisper_wood": [20, 25, 30, 35], "cracked_mines": [40, 45, 50, 55, 60],
	"rift_threshold": [65, 70, 75, 80, 85, 90, 95]}


func _json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path)) as Dictionary


func test_pool_of_every_area_is_the_z2_pool() -> void:
	var levels: Dictionary = {}
	var ids: Dictionary = {}
	for s: Variant in (_json("res://data/combat/rift_stones.json")["rift_stones"] as Array):
		var e: Dictionary = s as Dictionary
		assert_false(ids.has(e["id"]), "duplicate id %s" % e["id"])
		ids[e["id"]] = true
		assert_false(e.has("hp") or e.has("pulse_damage") or e.has("summon_pack"), "old field in %s" % e["id"])
		assert_eq(e["id"], "%s_stone_%d" % [e["area"], int(e["level"])])
		if not levels.has(e["area"]):
			levels[e["area"]] = []
		(levels[e["area"]] as Array).append(int(e["level"]))
	for area: String in EXPECTED:
		assert_eq(levels.get(area), EXPECTED[area], "pool of %s" % area)


func test_balance_has_the_metin_keys() -> void:
	var b: Dictionary = _json("res://data/config/balance.json")
	var m: Dictionary = b["metin"] as Dictionary
	for key: String in ["hp_base", "hp_per_level", "pulse_damage", "wave_size", "wave_thresholds", "rarity_bonus_pct", "guaranteed_pieces"]:
		assert_true(m.has(key), key)
	assert_eq(m["wave_thresholds"], [75.0, 50.0, 25.0])
	assert_eq(int((b["combat"] as Dictionary)["crowd_threshold"]), 8)
	assert_eq(int((b["combat"] as Dictionary)["skip_stone_level"]), 0)


func test_plains_have_a_stone_chance() -> void:
	var area: Dictionary = (_json("res://data/combat/areas.json")["areas"] as Array)[0] as Dictionary
	assert_eq(area["id"], "redrock_plains")
	assert_almost_eq(float(area["rift_stone_chance_pct"]), 0.6, 0.0001)
