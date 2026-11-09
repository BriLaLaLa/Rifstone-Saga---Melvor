extends GutTest
## DataValidator, M13-01: Cards (category `map`), `data/maps/map_mods.json`, `data/maps/bosses.json` and the `fracture`
## section of balance.json (docs/04_DATA_SCHEMA.md §11). One test per rule on a broken copy of the fixtures (helpers of
## test_data_validator.gd); the Defs and the GameData accessors; no leftover of the timed Fracture in the code.

const V: GDScript = preload("res://tests/core/data/test_data_validator.gd")
const FORBIDDEN_LEFTOVERS: Array[String] = ["Fracture" + "Def", "fractures." + "interval", "interval_min" + "_ms", "interval_max" + "_ms"]


func _expect(raw: Dictionary, fragment: String) -> void:
	for message: String in V.validate(raw):
		if message.contains(fragment):
			assert_true(true)
			return
	fail_test("no error with '%s' in %s" % [fragment, V.validate(raw)])


func _mods(raw: Dictionary) -> Array:
	return V.file_of(raw, "map_mods", "map_mods.json")["mods"] as Array


func _bosses(raw: Dictionary) -> Array:
	return V.file_of(raw, "bosses", "bosses.json")["bosses"] as Array


func _cards(raw: Dictionary) -> Array:
	return V.file_of(raw, "items", "maps.json")["items"] as Array


func _fracture(raw: Dictionary) -> Dictionary:
	return V.file_of(raw, "balance", "balance.json")["fracture"] as Dictionary


# --- valid data and the Defs -----------------------------------------------------------------------------------------

func test_fixtures_are_valid() -> void:
	assert_eq(V.validate(V.fixture_raw()), PackedStringArray())


func test_real_data_may_have_empty_map_files() -> void:
	var data: GameData = TestFactory.real_data()
	assert_true(data.is_valid())
	assert_eq(data.map_mods().size(), 0)


func test_game_data_accessors() -> void:
	var data: GameData = TestFactory.fixture_data()
	assert_eq(data.map_base(3).id, &"fracture_card_3")
	assert_eq(data.map_base(3).map_grade, 3)
	assert_true(data.item(&"fracture_card_10").is_map())
	assert_false(data.item(&"test_log").is_map())
	assert_eq(data.map_mods().size(), 12)
	assert_eq(data.map_mod(&"sturdy").risk.type, &"monster_hp_pct")
	assert_eq(data.map_mod(&"sturdy").reward.max_value, 15.0)
	assert_eq(data.map_mod(&"hordes").min_grade, 2)
	assert_null(data.map_mod(&"nope"))
	var boss: BossDef = data.boss_for_grade(4)
	assert_eq(boss.id, &"boss_grade_4")
	assert_eq(data.boss(&"boss_grade_4"), boss)
	assert_eq(boss.ability.type, &"heavy_strike")
	assert_eq(boss.dust_min, 20)
	assert_eq(boss.dust_max, 30)
	assert_true(boss is MonsterDef, "a boss is a MonsterDef")
	assert_eq(data.boss_for_grade(3).ability.monsters, [&"test_monster_a"] as Array[StringName])
	assert_eq(data.fracture_grade(1).areas, [&"cracked_mines"] as Array[StringName])
	assert_eq(data.fracture_grade(4).areas, [&"rift_threshold"] as Array[StringName])
	assert_eq(data.fracture_grade(10).reward_mult, 3.5)
	assert_eq(data.fracture_grade(7).piece_grade, 8)


func test_value_at_follows_f109() -> void:
	var effect: MapEffectDef = TestFactory.fixture_data().map_mod(&"sturdy").risk
	assert_eq(effect.value_at(5, 10), 40.0)
	assert_eq(effect.value_at(0, 10), 20.0)
	assert_eq(effect.value_at(10, 10), 60.0)


# --- Cards ------------------------------------------------------------------------------------------------------------

func test_card_rules() -> void:
	var raw: Dictionary = V.fixture_raw()
	(_cards(raw)[0] as Dictionary)["map"]["grade"] = 11
	(_cards(raw)[1] as Dictionary)["value"] = 5
	(_cards(raw)[2] as Dictionary)["id"] = "fracture_card_9"
	(_cards(raw)[3] as Dictionary).erase("map")
	_expect(raw, "field 'map.grade' must be >= 1 and <= 10")
	_expect(raw, "a Card must have value 0")
	_expect(raw, "a Card id must be 'fracture_card_<grade>'")
	_expect(raw, "missing field 'map'")


func test_a_card_set_needs_every_grade() -> void:
	var raw: Dictionary = V.fixture_raw()
	_cards(raw).pop_back()
	_expect(raw, "missing the Card of grade 10")


func test_map_sub_object_only_for_the_map_category() -> void:
	var raw: Dictionary = V.fixture_raw()
	var items: Array = V.file_of(raw, "items", "materials.json")["items"] as Array
	(items[0] as Dictionary)["map"] = {"grade": 1}
	_expect(raw, "field 'map' is not allowed for category")


func test_a_card_is_not_a_start_item_a_monster_drop_or_a_loot_entry_with_qty() -> void:
	var raw: Dictionary = V.fixture_raw()
	var balance: Dictionary = V.file_of(raw, "balance", "balance.json")
	(balance["start"]["items"] as Array).append({"item": "fracture_card_1", "qty": 1})
	_expect(raw, "pieces live in the Armory")
	var raw2: Dictionary = V.fixture_raw()
	var drops: Array = V.entry_of(raw2, "monsters", "monsters.json", "monsters", 0)["drops"] as Array
	drops.append({"item": "fracture_card_1", "chance_pct": 1, "qty": [1, 1]})
	_expect(raw2, "Cards come only from loot tables and Fractures")
	var raw3: Dictionary = V.fixture_raw()
	var table: Dictionary = (V.file_of(raw3, "loot_tables", "loot_tables.json")["tables"] as Array)[0] as Dictionary
	(table["entries"] as Array).append({"item": "fracture_card_1", "chance_pct": 5, "qty": [1, 2]})
	_expect(raw3, "a Card drops as [1, 1]")
	var raw4: Dictionary = V.fixture_raw()
	var table4: Dictionary = (V.file_of(raw4, "loot_tables", "loot_tables.json")["tables"] as Array)[0] as Dictionary
	(table4["entries"] as Array).append({"item": "fracture_card_1", "chance_pct": 5, "qty": [1, 1]})
	assert_eq(V.validate(raw4), PackedStringArray(), "a Card [1, 1] is a valid loot entry")


# --- modifiers --------------------------------------------------------------------------------------------------------

func test_unknown_risk_and_reward_types() -> void:
	var raw: Dictionary = V.fixture_raw()
	(_mods(raw)[0] as Dictionary)["risk"]["type"] = "monster_haste"
	(_mods(raw)[1] as Dictionary)["reward"]["type"] = "free_lunch"
	_expect(raw, "field 'risk.type' must be one of")
	_expect(raw, "field 'reward.type' must be one of")


func test_intensity_ranges() -> void:
	var raw: Dictionary = V.fixture_raw()
	(_mods(raw)[0] as Dictionary)["risk"]["min"] = 0
	(_mods(raw)[1] as Dictionary)["risk"]["max"] = 5
	_expect(raw, "field 'risk.min' must be > 0")
	_expect(raw, "field 'risk': min must be <= max")


func test_type_limits() -> void:
	var raw: Dictionary = V.fixture_raw()
	(_mods(raw)[4] as Dictionary)["risk"]["max"] = 6  # pack_bonus above combat.max_pack_size - 1
	(_mods(raw)[2] as Dictionary)["risk"]["max"] = 150  # food_heal_pct above 100
	(_mods(raw)[1] as Dictionary)["risk"]["max"] = 95  # monster_speed_pct above 90
	_expect(raw, "pack_bonus must be <= combat.max_pack_size - 1")
	_expect(raw, "food_heal_pct must be <= 100")
	_expect(raw, "monster_speed_pct must be <= 90")
	var raw2: Dictionary = V.fixture_raw()
	(_mods(raw2)[4] as Dictionary)["risk"]["min"] = 1.5
	_expect(raw2, "pack_bonus must be an integer")


func test_modifier_fields() -> void:
	var raw: Dictionary = V.fixture_raw()
	(_mods(raw)[0] as Dictionary)["min_grade"] = 0
	(_mods(raw)[1] as Dictionary)["weight"] = 0
	(_mods(raw)[2] as Dictionary)["colour"] = 1
	(_mods(raw)[3] as Dictionary).erase("reward")
	_expect(raw, "field 'min_grade' must be >= 1")
	_expect(raw, "field 'weight' must be >= 1")
	_expect(raw, "unknown field 'colour'")
	_expect(raw, "missing field 'reward'")


func test_at_least_twelve_modifiers() -> void:
	var raw: Dictionary = V.fixture_raw()
	_mods(raw).pop_back()
	_expect(raw, "needs at least 12 modifiers")


func test_four_distinct_risk_types_at_every_grade() -> void:
	var raw: Dictionary = V.fixture_raw()
	for mod: Variant in _mods(raw):
		(mod as Dictionary)["min_grade"] = maxi(int((mod as Dictionary)["min_grade"]), 2)
	_expect(raw, "grade 1 has 0 distinct risk types, needs at least 4")
	var raw2: Dictionary = V.fixture_raw()
	(_mods(raw2)[3] as Dictionary)["risk"]["type"] = "monster_hp_pct"  # grade 1: two monster_hp_pct, so only 3 distinct
	_expect(raw2, "grade 1 has 3 distinct risk types, needs at least 4")


func test_empty_modifier_file_is_valid_on_real_data() -> void:
	var raw: Dictionary = V.fixture_raw()
	V.file_of(raw, "map_mods", "map_mods.json")["mods"] = []
	assert_eq(V.validate(raw), PackedStringArray())


# --- bosses -----------------------------------------------------------------------------------------------------------

func test_boss_ability_rules() -> void:
	var raw: Dictionary = V.fixture_raw()
	(_bosses(raw)[0] as Dictionary)["ability"]["type"] = "teleport"
	(_bosses(raw)[3] as Dictionary)["ability"]["every_ms"] = 1000
	(_bosses(raw)[3] as Dictionary)["ability"]["mult"] = 9.0
	(_bosses(raw)[1] as Dictionary)["ability"]["shield_pct"] = 80
	(_bosses(raw)[1] as Dictionary)["ability"]["duration_ms"] = 20000
	(_bosses(raw)[2] as Dictionary)["ability"]["monsters"] = ["no_such_monster"]
	(_bosses(raw)[5] as Dictionary)["ability"]["count"] = 4
	(_bosses(raw)[5] as Dictionary)["ability"]["max_alive"] = 6
	_expect(raw, "field 'ability.type' must be one of")
	_expect(raw, "field 'ability.every_ms' must be >= 2000")
	_expect(raw, "field 'ability.mult' must be >= 1.2 and <= 4")
	_expect(raw, "field 'ability.shield_pct' must be >= 5 and <= 50")
	_expect(raw, "field 'ability.duration_ms' must be >= 1000 and <= 10000")
	_expect(raw, "unknown monster 'no_such_monster'")
	_expect(raw, "field 'ability.count' must be >= 1 and <= 3")
	_expect(raw, "field 'ability.max_alive'")


func test_boss_fields_and_rewards() -> void:
	var raw: Dictionary = V.fixture_raw()
	(_bosses(raw)[0] as Dictionary)["rewards"]["dust"] = [0, 5]
	(_bosses(raw)[1] as Dictionary)["grade"] = 1
	(_bosses(raw)[2] as Dictionary)["hp"] = 0
	(_bosses(raw)[3] as Dictionary).erase("ability")
	_expect(raw, "rewards.dust")
	_expect(raw, "duplicate boss grade 1")
	_expect(raw, "field 'hp' must be >= 1")
	_expect(raw, "missing field 'ability'")


func test_one_boss_per_grade() -> void:
	var raw: Dictionary = V.fixture_raw()
	_bosses(raw).pop_back()
	_expect(raw, "missing the boss of grade 10")


# --- balance.json `fracture` ------------------------------------------------------------------------------------------

func test_fracture_section_is_required() -> void:
	var raw: Dictionary = V.fixture_raw()
	V.file_of(raw, "balance", "balance.json").erase("fracture")
	_expect(raw, "missing key 'fracture'")


func test_the_old_timed_fractures_section_is_unknown() -> void:
	var raw: Dictionary = V.fixture_raw()
	V.file_of(raw, "balance", "balance.json")["fractures"] = {"interval_min_ms": 1, "interval_max_ms": 2, "duration_ms": 3}
	_expect(raw, "unknown key 'fractures'")


func test_fracture_scalar_and_table_rules() -> void:
	var raw: Dictionary = V.fixture_raw()
	_fracture(raw)["groups"] = 0
	_fracture(raw)["intensity_steps"] = 0
	_fracture(raw)["pulse_ms"] = 10
	_fracture(raw)["mod_count"]["common"] = [0, 1]
	_fracture(raw)["mod_count"]["rare"] = [3, 5]
	_fracture(raw)["card_rarity"] = {"magic_pct": 70, "rare_pct": 40}
	_fracture(raw)["card_drop"]["monster_delta"] = [0, 0, 0]
	_fracture(raw)["card_drop"]["boss_pct"] = 101
	_fracture(raw)["salvage"]["dust_per_grade"] = 0
	_fracture(raw)["salvage"]["rarity_mult"]["rare"] = 0.5
	_expect(raw, "field 'fracture.groups' must be >= 1")
	_expect(raw, "field 'fracture.intensity_steps' must be >= 1")
	_expect(raw, "field 'fracture.pulse_ms'")
	_expect(raw, "key 'fracture.mod_count.common' must be [0, 0]")
	_expect(raw, "fracture.mod_count.rare")
	_expect(raw, "magic_pct + rare_pct must be <= 100")
	_expect(raw, "fracture.card_drop.monster_delta")
	_expect(raw, "field 'fracture.card_drop.boss_pct'")
	_expect(raw, "field 'fracture.salvage.dust_per_grade'")
	_expect(raw, "field 'fracture.salvage.rarity_mult.rare'")


func test_fracture_grades_table() -> void:
	var raw: Dictionary = V.fixture_raw()
	var grades: Array = _fracture(raw)["grades"] as Array
	(grades[1] as Dictionary)["hp_mult"] = 0.5
	(grades[2] as Dictionary)["areas"] = ["no_such_area"]
	(grades[4] as Dictionary)["piece_grade"] = 9
	(grades[6] as Dictionary)["recommended_level"] = 5
	(grades[7] as Dictionary)["level_bonus"] = -1
	_expect(raw, "fracture.grades[1].hp_mult")
	_expect(raw, "unknown area 'no_such_area'")
	_expect(raw, "fracture.grades[4].piece_grade")
	_expect(raw, "fracture.grades[6].recommended_level' must not decrease")
	_expect(raw, "fracture.grades[7].level_bonus")
	var raw2: Dictionary = V.fixture_raw()
	(_fracture(raw2)["grades"] as Array).pop_back()
	_expect(raw2, "needs exactly 10 rows")


func test_multipliers_may_reset_when_the_area_changes() -> void:
	var raw: Dictionary = V.fixture_raw()
	assert_eq(V.validate(raw), PackedStringArray(), "grade 4 restarts at hp_mult 1.0 on another area")
	var grades: Array = _fracture(raw)["grades"] as Array
	(grades[4] as Dictionary)["areas"] = ["cracked_mines"]  # same area as grade 4 -> a decrease is now an error
	(grades[4] as Dictionary)["hp_mult"] = 1.0
	(grades[3] as Dictionary)["areas"] = ["cracked_mines"]
	(grades[3] as Dictionary)["hp_mult"] = 1.2
	_expect(raw, "fracture.grades[4].hp_mult' must not decrease")


# --- no leftover of the timed Fracture --------------------------------------------------------------------------------

func test_no_reference_to_the_timed_fracture_in_code_data_and_tests() -> void:
	var hits: Array[String] = []
	for root: String in ["res://core", "res://systems", "res://data", "res://tests"]:
		_scan(root, hits)
	assert_eq(hits, [] as Array[String], "the timed Fracture is gone")


func _scan(dir_path: String, hits: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	for sub: String in dir.get_directories():
		_scan(dir_path.path_join(sub), hits)
	for file_name: String in dir.get_files():
		if not (file_name.ends_with(".gd") or file_name.ends_with(".json")) or file_name == "test_map_data_validation.gd":
			continue
		var text: String = FileAccess.get_file_as_string(dir_path.path_join(file_name))
		for word: String in FORBIDDEN_LEFTOVERS:
			if text.contains(word):
				hits.append("%s: %s" % [dir_path.path_join(file_name), word])
