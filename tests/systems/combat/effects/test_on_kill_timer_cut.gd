extends GutTest
## F-81 `on_kill_timer_cut`: timer_base = floor(timer_base x (1 - pct/100)) (2000 ms, 50 -> 1000), and the hook in the engine.

var _session: GameSession


func after_each() -> void:
	EffectKit.cleanup()


func test_cut_examples() -> void:
	var cases: Array = [[2000, 50.0, 1000], [2001, 50.0, 1000], [2400, 25.0, 1800], [0, 50.0, 0]]
	for row: Array in cases:
		var ctx := EffectContext.new()
		ctx.player_timer_ms = row[0]
		OnKillTimerCut.new(&"t", {"pct": row[1]}).on_kill(ctx)
		assert_eq(ctx.player_timer_ms, row[2], "timer %d, pct %s" % [row[0], row[1]])


func test_triggers_only_when_the_timer_shrinks() -> void:
	var ctx := EffectContext.new()
	ctx.player_timer_ms = 1000
	OnKillTimerCut.new(&"t", {"pct": 50.0}).on_kill(ctx)
	assert_eq(ctx.triggered, [&"t"] as Array[StringName])
	var none := EffectContext.new()
	OnKillTimerCut.new(&"t", {"pct": 50.0}).on_kill(none)
	assert_true(none.triggered.is_empty())


func test_engine_kill_cuts_the_base_timer() -> void:
	var found: bool = false
	for seed_value: int in range(1, 40):
		_session = autofree(TestFactory.session(seed_value))
		EffectKit.equip_trait(_session, &"t_cut", [{"type": "on_kill_timer_cut", "params": {"pct": 50}}])
		EffectKit.sturdy(_session)
		_session.modifiers.set_source(&"test:power", [Modifier.make(&"power_bonus", 5000.0)] as Array[Modifier])
		_session.combat.from_save(EffectKit.fight([EffectKit.enemy("test_monster_a", 20, 2800),
			EffectKit.enemy("test_monster_b", 60, 2400)], 2400))
		_session.combat.advance(2400)
		if _session.combat.kills(&"test_monster_a") == 1:
			assert_eq(_session.combat.get_state()["player_timer_ms"], 1200, "2400 ms interval cut by 50%")
			found = true
			break
		EffectKit.cleanup()
	assert_true(found, "some seed kills at the first attack")


func test_a_hundred_percent_starts_the_next_attack_at_once() -> void:
	var ctx := EffectContext.new()
	ctx.player_timer_ms = 2000
	OnKillTimerCut.new(&"equipment:hands", {"pct": 100.0}).on_kill(ctx)
	assert_eq(ctx.player_timer_ms, 0, "F-120: timer 2000 -> 0")


func test_engine_the_legendary_gloves_cut_the_timer_to_zero_on_a_kill() -> void:
	for seed_value: int in range(1, 40):
		_session = autofree(LegendaryKit.session(seed_value))
		LegendaryKit.wear(_session, &"fx_leg_timer")
		LegendaryKit.hero(_session)
		var log := LegendaryKit.HitLog.new(_session.events)
		_session.combat.from_save(EffectKit.fight([EffectKit.enemy("test_monster_a", 20, 999999),
			EffectKit.enemy("test_monster_b", 60000, 999999)], 2400))
		_session.combat.advance(2400)
		if _session.combat.kills(&"test_monster_a") == 1:
			assert_eq(log.player.size(), 2, "the kill and, at the same instant, the next attack (timer 2400 -> 0)")
			return
	fail_test("no seed kills at the first attack")
