extends GutTest
## F-81 `stat_trade`: ER 1632 -> 0; DR 12 x 2 -> 24; DR 50 x 2 -> 80 (limit of stats.json); and the hook in player_stats.

var _session: GameSession


func before_each() -> void:
	_session = autofree(TestFactory.session(9))


func after_each() -> void:
	EffectKit.cleanup()


func _stats() -> CombatantStats:
	var s := CombatantStats.new()
	s.evasion = 1632
	s.armor = 12
	s.accuracy = 1000
	s.max_hit = 30
	s.max_hp = 100
	return s


func test_zero_evasion() -> void:
	var s: CombatantStats = _stats()
	StatTrade.new(&"t", {"zero": ["evasion_bonus"], "mult": {}}).modify_stats(s, _session.data)
	assert_eq(s.evasion, 0)
	assert_eq(s.armor, 12, "the others are untouched")


func test_multiplier_is_limited_by_the_stat_range() -> void:
	var s: CombatantStats = _stats()
	var effect := StatTrade.new(&"t", {"zero": [], "mult": {"armor": 2.0, "barrier": 2.0}})
	s.barrier = 7
	effect.modify_stats(s, _session.data)
	assert_eq([s.armor, s.barrier], [24, 14])
	s.armor = 80000
	effect.modify_stats(s, _session.data)
	assert_eq(s.armor, 100000, "160000 limited to the 100000 of stats.json")


func test_power_scales_max_and_min_hit() -> void:
	var s: CombatantStats = _stats()
	StatTrade.new(&"t", {"zero": [], "mult": {"power_pct": 2.0, "accuracy_pct": 0.5}}).modify_stats(s, _session.data)
	assert_eq(s.max_hit, 60)
	assert_eq(s.min_hit, 6, "F-22: floor(60 x 0.1)")
	assert_eq(s.accuracy, 500)


func test_engine_player_stats_follow_the_trait() -> void:
	assert_eq(_session.combat.player_stats().evasion, 450, "F-21 at level 1")
	EffectKit.equip_trait(_session, &"t_trade", [{"type": "stat_trade", "params": {"zero": ["evasion_bonus"], "mult": {}}}])
	assert_eq(_session.combat.player_stats().evasion, 0, "recomputed when the loadout changes")
	_session.loadout.set_trait(0, &"")
	assert_eq(_session.combat.player_stats().evasion, 450)
