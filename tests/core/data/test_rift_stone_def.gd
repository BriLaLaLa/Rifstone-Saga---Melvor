extends GutTest
## RiftStoneDef (04_DATA_SCHEMA §22, M15), its loading in GameData and the rules of DataValidatorStones.
## Helpers from test_data_validator.gd.

const V: GDScript = preload("res://tests/core/data/test_data_validator.gd")
const STONES: String = "rift_stones.json"


func _entry(raw: Dictionary) -> Dictionary:
	return V.entry_of(raw, "rift_stones", STONES, "rift_stones", 0)


func _expect(raw: Dictionary, fragment: String) -> void:
	for message: String in V.validate(raw):
		if message.contains(fragment):
			assert_true(true)
			return
	fail_test("no error with '%s' in %s" % [fragment, V.validate(raw)])


func test_fixture_stone_is_valid_and_loads() -> void:
	assert_eq(V.validate(V.fixture_raw()), PackedStringArray())
	var data: GameData = TestFactory.fixture_data()
	var pool: Array[RiftStoneDef] = data.rift_stones_for_area(&"test_stone_area")
	assert_eq(pool.size(), 1)
	var def: RiftStoneDef = pool[0]
	assert_eq(def.id, &"test_stone")
	assert_eq(data.rift_stone(&"test_stone"), def)
	assert_true(data.has_rift_stone(&"test_stone"))
	assert_eq(def.level, 5)
	assert_eq(def.xp, 240)
	assert_eq(def.pulse_ms, 3000)
	assert_eq(def.wave_packs, [] as Array[int], "null means every pack of the area")
	assert_eq([def.shards_min, def.shards_max], [2, 4])
	assert_eq(def.drops.size(), 1)


func test_area_without_stone_is_empty_and_silent() -> void:
	assert_true(TestFactory.fixture_data().rift_stones_for_area(&"test_area").is_empty())
	assert_false(TestFactory.fixture_data().has_rift_stone(&"nothing"))


func test_to_monster_carries_the_stats_inputs() -> void:
	var def: RiftStoneDef = TestFactory.fixture_data().rift_stone(&"test_stone")
	var m: MonsterDef = def.to_monster(&"blade", 450)
	assert_eq([m.id, m.hp, m.xp, m.style, m.attack_interval_ms], [&"test_stone", 450, 240, &"blade", 3000])
	assert_eq([m.attack_level, m.power_level, m.defence_level], [1, 1, 1])


func test_from_dict_missing_field_is_null() -> void:
	var d: Dictionary = {"id": "s", "name": "S", "description": "d", "icon": "res://x.svg", "area": "a", "level": 5,
		"xp": 0, "pulse_ms": 1000, "wave_packs": [0], "shards": [1, 1], "drops": []}
	assert_not_null(RiftStoneDef.from_dict(d))
	assert_eq(RiftStoneDef.from_dict(d).wave_packs, [0] as Array[int])
	var no_packs: Dictionary = d.duplicate()
	no_packs.erase("wave_packs")
	assert_null(RiftStoneDef.from_dict(no_packs))
	var no_level: Dictionary = d.duplicate()
	no_level.erase("level")
	assert_null(RiftStoneDef.from_dict(no_level))
	assert_push_error(2)  # one per missing field


func test_unknown_area_and_duplicate_level() -> void:
	var raw: Dictionary = V.fixture_raw()
	_entry(raw)["area"] = "nowhere"
	_expect(raw, "unknown area 'nowhere'")
	var raw2: Dictionary = V.fixture_raw()
	var list: Array = V.file_of(raw2, "rift_stones", STONES)["rift_stones"] as Array
	var second: Dictionary = (list[0] as Dictionary).duplicate(true)
	second["id"] = "other_stone"
	list.append(second)
	_expect(raw2, "already has a Rift Stone of level 5")


func test_numbers_and_wave_packs() -> void:
	var raw: Dictionary = V.fixture_raw()
	_entry(raw)["level"] = 7
	_entry(raw)["pulse_ms"] = 10
	_entry(raw)["wave_packs"] = [5]
	_entry(raw)["xp"] = -1
	_expect(raw, "field 'level': must be a multiple of 5")
	_expect(raw, "field 'pulse_ms'")
	_expect(raw, "field 'wave_packs'")
	_expect(raw, "field 'xp'")
	var low: Dictionary = V.fixture_raw()
	_entry(low)["level"] = 0
	_expect(low, "field 'level'")


func test_old_fields_are_unknown() -> void:
	var raw: Dictionary = V.fixture_raw()
	_entry(raw)["hp"] = 60
	_entry(raw)["pulse_damage"] = 7
	_entry(raw)["summon_pack"] = null
	_expect(raw, "unknown field 'hp'")
	_expect(raw, "unknown field 'pulse_damage'")
	_expect(raw, "unknown field 'summon_pack'")


func test_shards_drops_and_unknown_fields() -> void:
	var raw: Dictionary = V.fixture_raw()
	_entry(raw)["shards"] = [4, 2]
	_entry(raw)["drops"] = [{"item": "ghost", "chance_pct": 5, "qty": [1, 1]}]
	_entry(raw)["bonus"] = 1
	_entry(raw).erase("wave_packs")
	_expect(raw, "field 'shards'")
	_expect(raw, "unknown item 'ghost'")
	_expect(raw, "unknown field 'bonus'")
	_expect(raw, "missing field 'wave_packs'")


func test_pool_of_an_area_must_be_the_z2_pool() -> void:
	assert_eq(DataValidatorStones.pool(1, 15), [5, 10, 15] as Array[int])
	assert_eq(DataValidatorStones.pool(16, 37), [20, 25, 30, 35] as Array[int])
	assert_eq(DataValidatorStones.pool(38, 64), [40, 45, 50, 55, 60] as Array[int])
	assert_eq(DataValidatorStones.pool(65, 99), [65, 70, 75, 80, 85, 90, 95] as Array[int])
	var raw: Dictionary = V.fixture_raw()
	var areas: Dictionary = V.file_of(raw, "areas", "areas.json")
	for area: Variant in (areas["areas"] as Array):  # the stone area spans levels 10-19: the pool is 10, 15
		var a: Dictionary = area as Dictionary
		if a["id"] == "test_stone_area":
			a["requirements"] = {"character": 10}
		elif a["id"] == "test_loot_area":
			a["requirements"] = {"character": 20}
	_expect(raw, "area 'test_stone_area': the Rift Stone levels must be")


func test_rift_stone_balance_keys() -> void:
	var raw: Dictionary = V.fixture_raw()
	var balance: Dictionary = V.file_of(raw, "balance", "balance.json")
	(balance["rift_stone"] as Dictionary)["chance_pct"] = 101
	(balance["rift_stone"] as Dictionary)["pity_kills"] = 0
	(balance["rarity"] as Dictionary)["drop"]["rare_pct"] = -1
	_expect(raw, "'rift_stone.chance_pct'")
	_expect(raw, "'rift_stone.pity_kills'")
	_expect(raw, "'rarity.drop.rare_pct'")


func test_metin_balance_keys() -> void:
	var raw: Dictionary = V.fixture_raw()
	var balance: Dictionary = V.file_of(raw, "balance", "balance.json")
	(balance["metin"] as Dictionary)["hp_base"] = 0
	(balance["metin"] as Dictionary)["wave_size"] = 31
	(balance["metin"] as Dictionary)["wave_thresholds"] = [50, 75]
	(balance["combat"] as Dictionary)["crowd_threshold"] = 0
	(balance["combat"] as Dictionary)["skip_stone_level"] = 100
	_expect(raw, "'metin.hp_base'")
	_expect(raw, "'metin.wave_size'")
	_expect(raw, "'metin.wave_thresholds'")
	_expect(raw, "'combat.crowd_threshold'")
	_expect(raw, "'combat.skip_stone_level'")
