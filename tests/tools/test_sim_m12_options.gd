extends GutTest
## tools/sim_m12.gd (M12-07): the options `helpers`, `engraver`, `deposit` of sim_combat and the seeded measurements.

const Sim := preload("res://tools/sim_combat.gd")
const M12 := preload("res://tools/sim_m12.gd")
const PLAINS: StringName = &"redrock_plains"

var _data: GameData = null


func before_all() -> void:
	_data = TestFactory.real_data()


func _opts(extra: Dictionary = {}) -> Dictionary:
	var opts: Dictionary = Sim.parse_args(PackedStringArray())
	opts["hours"] = "0.25"
	opts.merge(extra, true)
	return opts


func test_parse_args_accepts_the_m12_options() -> void:
	var opts: Dictionary = Sim.parse_args(PackedStringArray(["helpers=1", "engraver=1", "deposit=1", "collect=30"]))
	assert_false(opts.has("error"))
	assert_eq(opts["collect"], "30")
	assert_eq(Sim.parse_args(PackedStringArray())["helpers"], "0")


func test_heart_hours() -> void:
	# 3 Stones: 9 Chips at 3 per hour = 3 Stones per hour of flow 1 -> 3 hours; direct Stones add to the flow.
	assert_almost_eq(M12.heart_hours(3.0, 0.0), 3.0, 0.0001)
	assert_almost_eq(M12.heart_hours(3.0, 2.0), 1.0, 0.0001)
	assert_true(is_inf(M12.heart_hours(0.0, 0.0)))


func test_crystal_hours_counts_the_failures_of_f104() -> void:
	# spark: level 5 -> chance 40 + 50 x 4 / 98 = 42.04%, 10 Dust, a failure costs 5: 10 x (1 + (1/p - 1) x 0.5) Dust.
	var chance: float = (40.0 + 50.0 * 4.0 / 98.0) / 100.0
	var dust: float = 10.0 * (1.0 + (1.0 / chance - 1.0) * 0.5)
	assert_almost_eq(M12.crystal_hours(_data, {&"rift_dust": 100.0}, &"crystallize_spark"), dust / 100.0, 0.0001)
	assert_true(is_inf(M12.crystal_hours(_data, {}, &"crystallize_spark")))


func test_best_action_is_unlocked_and_the_best_xp_per_second() -> void:
	var best: Object = M12.best_action(_data, &"forestry")
	assert_true(best.level <= M12.HELPER_LEVEL)
	for action: ActionDef in _data.actions_for_skill(&"forestry"):
		if action.level <= M12.HELPER_LEVEL:
			assert_true(float(best.xp) / best.interval_ms >= float(action.xp) / action.interval_ms)


func test_helpers_never_beat_the_player_on_one_trade() -> void:
	var opts: Dictionary = _opts({"helpers": "1"})
	var trade: StringName = &"forestry"
	var action: Object = M12.best_action(_data, trade)
	var player: int = M12._gather_xp(_data, opts, trade, action.id, false)
	var helper: int = M12._gather_xp(_data, opts, trade, action.id, true)
	assert_gt(player, 0)
	assert_gt(helper, 0)
	assert_true(3 * helper <= player, "3 Master helpers stay under the player on one trade (F-102)")


func test_loot_run_is_deterministic_and_counts_drops() -> void:
	var opts: Dictionary = _opts({"collect": "5"})
	var first: Dictionary = M12.loot_run(_data, _data.area(PLAINS), opts)
	var second: Dictionary = M12.loot_run(_data, _data.area(PLAINS), opts)
	assert_eq(first["drops"], second["drops"])
	assert_eq(first["kills"], second["kills"])
	assert_gt(first["kills"], 0)
	assert_gt(int(first["drops"].get(&"rift_dust", 0)), 0, "the Plains table drops Rift Dust")
	assert_eq(first["capacity"], 60)


func test_report_prints_each_requested_section() -> void:
	var lines: PackedStringArray = M12.report(_data, _opts({"area": String(PLAINS), "engraver": "1", "deposit": "1"}))
	var text: String = "\n".join(lines)
	assert_string_contains(text, "hours to full")
	assert_string_contains(text, "h first Perfect Stone")
	assert_string_contains(text, "grade V rune")
	assert_eq(M12.report(_data, _opts()).size(), 0)
