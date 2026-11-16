extends GutTest
## M23-05, smoke of `tools/sim_market.gd` (docs/02_FORMULAS.md §5k "Simulazione"): few cases of every check on the real data end
## without failures. The full run (10.000 strategies per item) is the tool itself: `godot --headless --path . -s tools/sim_market.gd`.

const SIM: String = "res://tools/sim_market.gd"


func _sim() -> GDScript:
	return load(SIM) as GDScript


func test_arguments_are_parsed() -> void:
	assert_eq(_sim().call("parse_args", PackedStringArray(["states=5", "strategies=7", "seed=3"])), {"states": 5, "strategies": 7, "seed": 3})
	assert_true((_sim().call("parse_args", PackedStringArray(["nonsense=1"])) as Dictionary).has("error"))
	assert_true((_sim().call("parse_args", PackedStringArray(["states=x"])) as Dictionary).has("error"))


func test_unit_prices_and_strategies_have_no_failure() -> void:
	var data: GameData = TestFactory.real_data()
	var unit: Dictionary = _sim().call("unit_prices", data, 20, 11)
	assert_eq(unit["failures"], [])
	assert_eq(unit["items"], 48)
	assert_gt(float(unit["min_over_max"]), 1.0)
	var strat: Dictionary = _sim().call("strategies", data, 6, 11)
	assert_eq(strat["failures"], [])
	assert_lte(float(strat["best_net"]), 0.0)
	assert_lt(float(strat["best_saturate"]), 0.0)
	assert_gt(float(strat["min_round_trip_loss"]), 0.0)


func test_transformations_clock_and_production_have_no_failure() -> void:
	var data: GameData = TestFactory.real_data()
	var tr: Dictionary = _sim().call("transformations", data)
	assert_eq(tr["failures"], [])
	assert_eq(tr["blueprints"], 120)
	assert_gte(float(tr["worst_ratio"]), 1.03)
	var clock: Dictionary = _sim().call("clock", data, 5)
	assert_eq(clock["failures"], [])
	assert_true(clock["same"])
	var prod: Dictionary = _sim().call("production", data)
	assert_eq(prod["failures"], [])
