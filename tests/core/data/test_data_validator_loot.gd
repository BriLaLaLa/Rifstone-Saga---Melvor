extends GutTest
## DataValidator, part 6 (M7-01/02): the `upgrade` (F-86) and `salvage` (F-88) keys of balance.json.
## One test per rule on a broken copy of the fixtures; helpers from test_data_validator.gd.

const V: GDScript = preload("res://tests/core/data/test_data_validator.gd")


func _expect(raw: Dictionary, fragment: String) -> void:
	for message: String in V.validate(raw):
		if message.contains(fragment):
			assert_true(true)
			return
	fail_test("no error with '%s' in %s" % [fragment, V.validate(raw)])


func _upgrade(raw: Dictionary) -> Dictionary:
	return V.file_of(raw, "balance", "balance.json")["upgrade"] as Dictionary


func _salvage(raw: Dictionary) -> Dictionary:
	return V.file_of(raw, "balance", "balance.json")["salvage"] as Dictionary


func test_fixtures_with_the_loot_keys_are_valid() -> void:
	assert_eq(V.validate(V.fixture_raw()), PackedStringArray())


func test_upgrade_level_rows() -> void:
	var raw: Dictionary = V.fixture_raw()
	var levels: Array = _upgrade(raw)["levels"] as Array
	(levels[0] as Dictionary)["success_pct"] = 0
	(levels[1] as Dictionary)["ingots"] = 1.5
	(levels[2] as Dictionary)["bonus"] = 1
	(levels[3] as Dictionary).erase("shards")
	_expect(raw, "upgrade.levels[0]")
	_expect(raw, "'upgrade.levels[1].ingots'")
	_expect(raw, "unknown field 'upgrade.levels[2].bonus'")
	_expect(raw, "missing field 'upgrade.levels[3].shards'")


func test_upgrade_level_count_and_threshold() -> void:
	var raw: Dictionary = V.fixture_raw()
	_upgrade(raw)["levels"] = []
	_upgrade(raw)["downgrade_from"] = 12
	_expect(raw, "upgrade.levels")
	var raw2: Dictionary = V.fixture_raw()
	_upgrade(raw2)["downgrade_from"] = 12
	_expect(raw2, "upgrade.downgrade_from")


func test_upgrade_ingot_items() -> void:
	var raw: Dictionary = V.fixture_raw()
	(_upgrade(raw)["ingot_items"] as Array)[2] = "no_such_ingot"
	_expect(raw, "unknown item 'no_such_ingot'")
	var raw2: Dictionary = V.fixture_raw()
	(_upgrade(raw2)["ingot_items"] as Array).pop_back()
	_expect(raw2, "needs exactly 8 items")


func test_upgrade_scalar_keys() -> void:
	var raw: Dictionary = V.fixture_raw()
	_upgrade(raw)["mod_pct_per_level"] = 0
	_upgrade(raw)["seal_item"] = ""
	_expect(raw, "upgrade.mod_pct_per_level")
	_expect(raw, "'upgrade.seal_item' must be a non-empty id")


func test_salvage_rules() -> void:
	var raw: Dictionary = V.fixture_raw()
	_salvage(raw)["ingot_ratio"] = 1.5
	(_salvage(raw)["shards_by_rarity"] as Dictionary).erase("rare")
	(_salvage(raw)["shards_by_rarity"] as Dictionary)["magic"] = -1
	_expect(raw, "salvage.ingot_ratio")
	_expect(raw, "'salvage.shards_by_rarity.rare' is required")
	_expect(raw, "salvage.shards_by_rarity")


func test_missing_sections_are_reported() -> void:
	var raw: Dictionary = V.fixture_raw()
	V.file_of(raw, "balance", "balance.json").erase("salvage")
	_expect(raw, "missing key 'salvage.ingot_ratio'")
