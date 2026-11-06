extends GutTest
## F-81 `leech_pct`: heals floor(damage dealt x pct/100) (60 x 5% -> 3), capped at the maximum hp.

var _session: GameSession


func after_each() -> void:
	EffectKit.cleanup()


func test_example() -> void:
	var ctx := EffectContext.new()
	LeechPct.new(&"t", {"pct": 5.0}).on_hit(ctx, 60)
	assert_eq(ctx.heal, 3)
	assert_eq(ctx.triggered, [&"t"] as Array[StringName])


func test_small_damage_heals_nothing() -> void:
	var ctx := EffectContext.new()
	LeechPct.new(&"t", {"pct": 5.0}).on_hit(ctx, 19)
	assert_eq(ctx.heal, 0)
	assert_true(ctx.triggered.is_empty())


func test_engine_heals_the_damage_dealt() -> void:
	var found: bool = false
	for seed_value: int in range(1, 40):
		_session = autofree(TestFactory.session(seed_value))
		EffectKit.equip_trait(_session, &"t_leech", [{"type": "leech_pct", "params": {"pct": 100}}])
		var dealt: Array[int] = []
		_session.events.combat_hit.connect(func(a: int, _t: int, _h: bool, d: int, _b: bool) -> void:
			if a == CombatEngine.PLAYER:
				dealt.append(d))
		_session.combat.from_save(EffectKit.fight([EffectKit.enemy("test_monster_b", 60, 2400)], 100, 30))
		_session.combat.advance(100)
		if dealt[0] > 0:
			assert_eq(_session.combat.get_state()["player_hp"], 30 + dealt[0])
			found = true
			break
		EffectKit.cleanup()
	assert_true(found)
