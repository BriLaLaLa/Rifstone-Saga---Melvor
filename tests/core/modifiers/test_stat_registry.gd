extends GutTest
## StatRegistry: building from the parsed stats array, errors on malformed entries, info and clamp_total.

const STATS_PATH: String = "res://data/config/stats.json"
const MVP_STAT_COUNT: int = 24


func test_from_array_registers_valid_stats() -> void:
	var errors: PackedStringArray = []
	var registry: StatRegistry = StatRegistry.from_array([_stat("skill_interval_pct", -80, 100),
		_stat("bank_slots", 0, 10000)], errors)
	assert_eq(errors.size(), 0, str(errors))
	assert_true(registry.has(&"skill_interval_pct"))
	assert_true(registry.has(&"bank_slots"))
	assert_false(registry.has(&"unknown_stat"))
	assert_eq(registry.ids(), [&"skill_interval_pct", &"bank_slots"] as Array[StringName])


func test_info_returns_all_fields() -> void:
	var registry: StatRegistry = StatRegistry.from_array([_stat("skill_interval_pct", -80, 100)], [])
	var info: Dictionary = registry.info(&"skill_interval_pct")
	assert_eq(info["name"], "Nome skill_interval_pct")
	assert_eq(info["format"], "pct")
	assert_eq(info["min"], -80.0)
	assert_eq(info["max"], 100.0)
	assert_eq(info["description"], "Effetto.")
	assert_eq(info["formula"], "F-03")
	assert_eq(info["test"], "tests/x.gd::test_y")


func test_info_is_a_copy() -> void:
	var registry: StatRegistry = StatRegistry.from_array([_stat("skill_xp_pct", 0, 1000)], [])
	registry.info(&"skill_xp_pct")["max"] = 1.0
	assert_eq(registry.info(&"skill_xp_pct")["max"], 1000.0)


func test_info_of_unknown_stat_is_empty_and_errors() -> void:
	var registry: StatRegistry = StatRegistry.from_array([], [])
	assert_eq(registry.info(&"nope"), {})
	assert_push_error(1)


func test_clamp_total_limits_to_min_and_max() -> void:
	var registry: StatRegistry = StatRegistry.from_array([_stat("skill_interval_pct", -80, 100)], [])
	assert_eq(registry.clamp_total(&"skill_interval_pct", -95.0), -80.0)
	assert_eq(registry.clamp_total(&"skill_interval_pct", 150.0), 100.0)
	assert_eq(registry.clamp_total(&"skill_interval_pct", -10.0), -10.0)


func test_clamp_total_unknown_stat_errors_and_returns_value() -> void:
	var registry: StatRegistry = StatRegistry.from_array([], [])
	assert_eq(registry.clamp_total(&"nope", 7.0), 7.0)
	assert_push_error(1)


func test_duplicate_id_is_an_error() -> void:
	var errors: PackedStringArray = []
	var registry: StatRegistry = StatRegistry.from_array([_stat("skill_xp_pct", 0, 1000),
		_stat("skill_xp_pct", 0, 5)], errors)
	assert_eq(errors.size(), 1)
	assert_eq(registry.info(&"skill_xp_pct")["max"], 1000.0, "the first definition is kept")


func test_min_not_lower_than_max_is_an_error() -> void:
	var errors: PackedStringArray = []
	var registry: StatRegistry = StatRegistry.from_array([_stat("skill_xp_pct", 10, 10)], errors)
	assert_eq(errors.size(), 1)
	assert_false(registry.has(&"skill_xp_pct"))


func test_malformed_entries_are_errors_and_skipped() -> void:
	var errors: PackedStringArray = []
	var no_id: Dictionary = _stat("a", 0, 1)
	no_id.erase("id")
	var bad_format: Dictionary = _stat("b", 0, 1)
	bad_format["format"] = "percent"
	var text_limits: Dictionary = _stat("c", 0, 1)
	text_limits["max"] = "1"
	var no_test: Dictionary = _stat("d", 0, 1)
	no_test.erase("test")
	var registry: StatRegistry = StatRegistry.from_array(["not an object", no_id, bad_format, text_limits,
		no_test, _stat("ok", 0, 1)], errors)
	assert_eq(errors.size(), 5, str(errors))
	assert_eq(registry.ids(), [&"ok"] as Array[StringName])


func test_real_stats_json_is_accepted() -> void:
	var text: String = FileAccess.get_file_as_string(STATS_PATH)
	var parsed: Variant = JSON.parse_string(text)
	assert_true(parsed is Dictionary, "stats.json parses")
	var errors: PackedStringArray = []
	var registry: StatRegistry = StatRegistry.from_array((parsed as Dictionary)["stats"] as Array, errors)
	assert_eq(errors.size(), 0, str(errors))
	assert_eq(registry.ids().size(), MVP_STAT_COUNT)
	assert_eq(registry.clamp_total(&"skill_interval_pct", -95.0), -80.0)


func _stat(id: String, low: float, high: float) -> Dictionary:
	return {
		"id": id, "name": "Nome %s" % id, "format": "pct", "min": low, "max": high,
		"description": "Effetto.", "formula": "F-03", "test": "tests/x.gd::test_y",
	}
