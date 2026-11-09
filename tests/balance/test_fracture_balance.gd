extends GutTest
## Balance guards of the Fractures (docs/02_FORMULAS.md §7, Q63-Q65, M13-06): the real tables keep the shape the design wants
## (the scale only grows inside an area, one boss per grade) and, through tools/sim_fracture.gd
## on the real data, a Fracture of the recommended level is won in a time the design accepts. The full measures are printed by
## `godot --headless --path . -s tools/sim_fracture.gd`; this test only checks two grades with fixed seeds.

const SIM: String = "res://tools/sim_fracture.gd"
const MAX_MINUTES: float = 40.0
const MIN_MINUTES: float = 5.0

var _data: GameData = null


func before_all() -> void:
	_data = TestFactory.real_data()


func _grades() -> Array:
	return _data.balance_value("fracture.grades")


func test_the_scale_never_goes_down() -> void:
	var grades: Array = _grades()
	assert_eq(grades.size(), 10)
	for i: int in range(1, grades.size()):
		var prev: Dictionary = grades[i - 1]
		var cur: Dictionary = grades[i]
		if (cur["areas"] as Array) != (prev["areas"] as Array):
			continue  # a new area restarts the scale
		for key: String in ["hp_mult", "damage_mult", "reward_mult", "recommended_level", "piece_grade"]:
			assert_true(float(cur[key]) >= float(prev[key]), "%s of grade %d does not drop" % [key, i + 1])
		assert_lt(float(cur["recommended_level"]), 100.0)


func test_every_grade_has_one_boss_with_hp_and_an_ability() -> void:
	for grade: int in range(1, 11):
		var boss: BossDef = _data.boss_for_grade(grade)
		assert_not_null(boss, "boss of grade %d" % grade)
		if boss != null:
			assert_gt(boss.hp, 0)
			assert_not_null(boss.ability)


func test_card_drops_stay_rare_outside_the_fractures() -> void:
	var drop: Dictionary = _data.balance_value("fracture.card_drop")
	assert_lt(float(drop["monster_pct"]), 2.0, "a Card from a normal kill must stay rare")
	assert_between(float(drop["boss_pct"]), 30.0, 100.0)
	assert_eq(int(_data.balance_value("fracture.groups")) > 0, true)


func _measure(grade: int, seed_value: int) -> Dictionary:
	var sim: GDScript = load(SIM) as GDScript
	var level: int = int((_grades()[grade - 1] as Dictionary)["recommended_level"])
	return sim.call("measure", _data, grade, level, seed_value, sim.call("parse_args", PackedStringArray(["rarity=common"])))


func test_grade_one_at_the_recommended_level_is_won_in_a_reasonable_time() -> void:
	var row: Dictionary = _measure(1, 1)
	assert_eq(row["outcome"], "won")
	assert_between(float(row["ms"]) / 60000.0, MIN_MINUTES, MAX_MINUTES, "minutes")
	assert_eq(row["deaths"], 0)


func test_grade_five_at_the_recommended_level_is_won_in_a_reasonable_time() -> void:
	var row: Dictionary = _measure(5, 1)
	assert_eq(row["outcome"], "won")
	assert_between(float(row["ms"]) / 60000.0, MIN_MINUTES, MAX_MINUTES, "minutes")
