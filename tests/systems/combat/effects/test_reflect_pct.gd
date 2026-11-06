extends GutTest
## F-81 `reflect_pct`: the attacker loses floor(damage taken x pct/100) (37 x 20% -> 7); it can kill it.

var _session: GameSession


func after_each() -> void:
	EffectKit.cleanup()


func test_example() -> void:
	var ctx := EffectContext.new()
	ReflectPct.new(&"t", {"pct": 20.0}).on_damaged(ctx, 37)
	assert_eq(ctx.reflect_damage, 7)
	assert_eq(ctx.triggered, [&"t"] as Array[StringName])


func test_small_damage_reflects_nothing() -> void:
	var ctx := EffectContext.new()
	ReflectPct.new(&"t", {"pct": 20.0}).on_damaged(ctx, 4)
	assert_eq(ctx.reflect_damage, 0)
	assert_true(ctx.triggered.is_empty())


func test_engine_reflection_can_kill_the_attacker() -> void:
	var found: bool = false
	for seed_value: int in range(1, 40):
		_session = autofree(TestFactory.session(seed_value))
		EffectKit.equip_trait(_session, &"t_reflect", [{"type": "reflect_pct", "params": {"pct": 100}}])
		EffectKit.sturdy(_session)
		_session.combat.from_save(EffectKit.fight([EffectKit.enemy("test_monster_a", 1, 100)], 5000))
		watch_signals(_session.events)
		_session.combat.advance(100)
		if _session.combat.kills(&"test_monster_a") == 1:
			assert_eq(_session.combat.state(), CombatEngine.STATE_BETWEEN)
			assert_signal_emitted_with_parameters(_session.events, "trait_triggered", [&"t_reflect"])
			found = true
			break
		EffectKit.cleanup()
	assert_true(found, "some seed lets the 1-hp enemy hit and die")
