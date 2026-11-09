extends GutTest
## F-120 `stat_convert` (hook `modify_stats`): after the stats are computed, `to` += floor(from x pct/100), then the limits of
## stats.json apply: barrier 100, 50% -> armor +50.

var _s: GameSession = null


func test_example() -> void:
	var data: GameData = LegendaryKit.session(1).data
	var stats := CombatantStats.new()
	stats.barrier = 100
	StatConvert.new(&"t", {"from": "barrier", "to": "armor", "pct": 50.0}).modify_stats(stats, data)
	assert_eq(stats.armor, 50)
	assert_eq(stats.barrier, 100, "the source is not consumed")


func test_it_adds_to_what_there_is_and_floors() -> void:
	var data: GameData = LegendaryKit.session(1).data
	var stats := CombatantStats.new()
	stats.barrier = 101
	stats.armor = 30
	StatConvert.new(&"t", {"from": "barrier", "to": "armor", "pct": 50.0}).modify_stats(stats, data)
	assert_eq(stats.armor, 80, "30 + floor(50.5)")


func test_the_limits_of_stats_json_apply() -> void:
	var data: GameData = LegendaryKit.session(1).data
	var stats := CombatantStats.new()
	stats.armor = 99990
	stats.barrier = 100
	StatConvert.new(&"t", {"from": "barrier", "to": "armor", "pct": 100.0}).modify_stats(stats, data)
	assert_eq(stats.armor, 100000, "armor is limited to 100000")


func test_other_stats_work_and_an_empty_source_changes_nothing() -> void:
	var data: GameData = LegendaryKit.session(1).data
	var stats := CombatantStats.new()
	stats.armor = 40
	StatConvert.new(&"t", {"from": "armor", "to": "block_chance", "pct": 50.0}).modify_stats(stats, data)
	assert_eq(stats.block_chance, 20.0)
	var none := CombatantStats.new()
	StatConvert.new(&"t", {"from": "barrier", "to": "armor", "pct": 50.0}).modify_stats(none, data)
	assert_eq(none.armor, 0)


func test_engine_the_worn_legendary_converts_the_barrier_of_the_player() -> void:
	_s = autofree(LegendaryKit.session(2))
	assert_eq(_s.combat.player_stats().armor, 0)
	LegendaryKit.wear(_s, &"fx_leg_convert")
	var stats: CombatantStats = _s.combat.player_stats()
	assert_eq(stats.barrier, 140, "the legendary has its modifiers x1.4 (F-120)")
	assert_eq(stats.armor, 70, "floor(140 x 50%)")
	_s.equipment.unequip(&"legs")
	assert_eq(_s.combat.player_stats().armor, 0, "gone with the piece")
