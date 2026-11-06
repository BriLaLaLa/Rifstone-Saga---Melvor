extends GutTest
## RiftStoneDef (04_DATA_SCHEMA §16), its loading in GameData and the rules of DataValidatorStones (M7-04).
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
	var def: RiftStoneDef = data.rift_stone_for_area(&"test_stone_area")
	assert_not_null(def)
	assert_eq(def.id, &"test_stone")
	assert_eq(data.rift_stone(&"test_stone"), def)
	assert_true(data.has_rift_stone(&"test_stone"))
	assert_eq(def.hp, 60)
	assert_eq(def.xp, 240)
	assert_eq(def.pulse_damage, 7)
	assert_eq(def.pulse_ms, 3000)
	assert_eq(def.summon_pack, -1, "null means nobody is summoned")
	assert_eq([def.shards_min, def.shards_max], [2, 4])
	assert_eq(def.drops.size(), 1)


func test_area_without_stone_is_null_and_silent() -> void:
	assert_null(TestFactory.fixture_data().rift_stone_for_area(&"test_area"))
	assert_false(TestFactory.fixture_data().has_rift_stone(&"nothing"))


func test_to_monster_carries_the_stats_inputs() -> void:
	var def: RiftStoneDef = TestFactory.fixture_data().rift_stone(&"test_stone")
	var m: MonsterDef = def.to_monster(&"blade")
	assert_eq([m.id, m.hp, m.xp, m.style, m.attack_interval_ms], [&"test_stone", 60, 240, &"blade", 3000])
	assert_eq([m.attack_level, m.power_level, m.defence_level], [1, 1, 1])


func test_from_dict_missing_field_is_null() -> void:
	var d: Dictionary = {"id": "s", "name": "S", "description": "d", "icon": "res://x.svg", "area": "a", "hp": 1,
		"xp": 0, "pulse_damage": 1, "pulse_ms": 1000, "summon_pack": 0, "shards": [1, 1], "drops": []}
	assert_not_null(RiftStoneDef.from_dict(d))
	assert_eq(RiftStoneDef.from_dict(d).summon_pack, 0)
	var no_pack: Dictionary = d.duplicate()
	no_pack.erase("summon_pack")
	assert_null(RiftStoneDef.from_dict(no_pack))
	var no_hp: Dictionary = d.duplicate()
	no_hp.erase("hp")
	assert_null(RiftStoneDef.from_dict(no_hp))
	assert_push_error(2)  # one per missing field


func test_unknown_area_and_duplicate_area() -> void:
	var raw: Dictionary = V.fixture_raw()
	_entry(raw)["area"] = "nowhere"
	_expect(raw, "unknown area 'nowhere'")
	var raw2: Dictionary = V.fixture_raw()
	var list: Array = V.file_of(raw2, "rift_stones", STONES)["rift_stones"] as Array
	var second: Dictionary = (list[0] as Dictionary).duplicate(true)
	second["id"] = "other_stone"
	list.append(second)
	_expect(raw2, "already has a Rift Stone")


func test_numbers_and_summon_pack() -> void:
	var raw: Dictionary = V.fixture_raw()
	_entry(raw)["hp"] = 0
	_entry(raw)["pulse_damage"] = 0
	_entry(raw)["pulse_ms"] = 10
	_entry(raw)["summon_pack"] = 5
	_expect(raw, "field 'hp'")
	_expect(raw, "field 'pulse_damage'")
	_expect(raw, "field 'pulse_ms'")
	_expect(raw, "field 'summon_pack'")


func test_shards_drops_and_unknown_fields() -> void:
	var raw: Dictionary = V.fixture_raw()
	_entry(raw)["shards"] = [4, 2]
	_entry(raw)["drops"] = [{"item": "ghost", "chance_pct": 5, "qty": [1, 1]}]
	_entry(raw)["bonus"] = 1
	_entry(raw).erase("summon_pack")
	_expect(raw, "field 'shards'")
	_expect(raw, "unknown item 'ghost'")
	_expect(raw, "unknown field 'bonus'")
	_expect(raw, "missing field 'summon_pack'")


func test_rift_stone_balance_keys() -> void:
	var raw: Dictionary = V.fixture_raw()
	var balance: Dictionary = V.file_of(raw, "balance", "balance.json")
	(balance["rift_stone"] as Dictionary)["chance_pct"] = 101
	(balance["rift_stone"] as Dictionary)["pity_kills"] = 0
	(balance["rarity"] as Dictionary)["drop"]["rare_pct"] = -1
	_expect(raw, "'rift_stone.chance_pct'")
	_expect(raw, "'rift_stone.pity_kills'")
	_expect(raw, "'rarity.drop.rare_pct'")
