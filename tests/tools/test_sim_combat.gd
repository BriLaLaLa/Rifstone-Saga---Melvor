extends GutTest
## tools/sim_combat.gd (M5-06): argument parsing, the scenario helpers and short, seeded measurements on real data.

const Sim := preload("res://tools/sim_combat.gd")
const SimXp := preload("res://tools/sim_xp.gd")
const PLAINS: StringName = &"redrock_plains"

var _data: GameData = null


func before_all() -> void:
	_data = TestFactory.real_data()


func _opts(extra: Dictionary = {}) -> Dictionary:
	var opts: Dictionary = Sim.parse_args(PackedStringArray())
	opts["hours"] = "0.05"
	opts.merge(extra, true)
	return opts


func test_parse_args_defaults_and_overrides() -> void:
	var opts: Dictionary = Sim.parse_args(PackedStringArray(["area=cracked_mines", "seed=7"]))
	assert_eq(opts["area"], "cracked_mines")
	assert_eq(opts["seed"], "7")
	assert_eq(opts["hours"], "1")
	assert_false(opts.has("error"))


func test_parse_args_rejects_unknown_keys() -> void:
	assert_true(Sim.parse_args(PackedStringArray(["nope=1"])).has("error"))
	assert_true(Sim.parse_args(PackedStringArray(["area"])).has("error"))


func test_scopes() -> void:
	assert_eq(Sim.scopes("both"), ["easiest", "all"] as Array[String])
	assert_eq(Sim.scopes("3"), ["3"] as Array[String])


func test_easiest_pack_is_the_lowest_total_hp() -> void:
	var index: int = Sim.easiest_pack(_data, _data.area(PLAINS))
	assert_eq(_data.area(PLAINS).packs[index].monster_ids, [&"plains_boar"] as Array[StringName])


func test_auto_grade_follows_the_character_requirement() -> void:
	assert_eq(Sim.auto_grade(_data, 1), 1)
	assert_eq(Sim.auto_grade(_data, 29), 6)  # M14-05: 15 piece grades (level 29 -> grade 6, level 25)
	assert_eq(Sim.auto_grade(_data, 90), 15)


func test_auto_tier_counts_the_ration_purchases_the_level_allows() -> void:
	assert_eq(Sim.auto_tier(_data, 1), 1)
	assert_eq(Sim.auto_tier(_data, 25), 2)
	assert_eq(Sim.auto_tier(_data, 50), 3)


func test_auto_level_is_the_mean_monster_level() -> void:
	assert_eq(Sim.auto_level(_data, _data.area(PLAINS)), 4, "(1 + 4 + 8) / 3")


func test_food_for_grade_is_clamped_to_the_foods() -> void:
	assert_eq(Sim.food_for_grade(_data, 1), &"seared_brookfin")
	assert_eq(Sim.food_for_grade(_data, 2), &"seared_ashgill")
	assert_eq(Sim.food_for_grade(_data, 99), &"seared_riftmaw")


func test_measure_is_deterministic_and_restores_the_area() -> void:
	var area: AreaDef = _data.area(PLAINS)
	var packs_before: int = area.packs.size()
	var first: Dictionary = Sim.measure(_data, area, "easiest", _opts())
	var second: Dictionary = Sim.measure(_data, area, "easiest", _opts())
	assert_eq(first, second, "same seed, same result")
	assert_eq(area.packs.size(), packs_before)
	assert_gt(int(first["kills"]), 0)
	assert_eq(first["deaths"], 0)
	assert_gt(int(first["xp"]), 0)
	assert_gt(int(first["gold"]), 0)
	assert_eq(first["ms"], 180000)


func test_measure_xp_is_the_f28_xp_per_kill() -> void:
	var row: Dictionary = Sim.measure(_data, _data.area(PLAINS), "easiest", _opts())
	var each: int = SimXp.monster_kill_xp(_data, _data.monster(&"plains_boar"), int(row["level"]))  # F-28 with F-130
	assert_gt(each, 0)
	assert_eq(int(row["xp"]), int(row["kills"]) * each, "easiest pack = one boar: floor(80 x kill_xp_mult x level factor) each")


func test_report_has_a_header_and_a_row_per_scope() -> void:
	var lines: PackedStringArray = Sim.report(_data, _opts({"area": "redrock_plains"}))
	assert_eq(lines.size(), 4)
	assert_true(lines[2].begins_with("| redrock_plains | easiest |"))
	assert_true(lines[3].begins_with("| redrock_plains | all |"))
