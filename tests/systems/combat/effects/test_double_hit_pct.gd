extends GutTest
## F-120 `double_hit_pct` (hook `on_hit`): after a base attack that hurt, `roll_pct(pct)` for a second base hit on the same
## target with new rolls (F-23, F-22). pct 100 -> always two hits.

var _s: GameSession = null


func _ctx(base: bool) -> EffectContext:
	var ctx := EffectContext.new()
	ctx.rng = RngService.new(9)
	ctx.base_attack = base
	return ctx


func test_pct_100_always_asks_for_the_second_hit() -> void:
	var ctx: EffectContext = _ctx(true)
	DoubleHitPct.new(&"t", {"pct": 100.0}).on_hit(ctx, 12)
	assert_true(ctx.extra_hit)
	assert_eq(ctx.triggered, [&"t"] as Array[StringName])


func test_pct_0_never_and_abilities_never() -> void:
	var never: EffectContext = _ctx(true)
	for i: int in 50:
		DoubleHitPct.new(&"t", {"pct": 0.0}).on_hit(never, 12)
	assert_false(never.extra_hit)
	var ability: EffectContext = _ctx(false)
	DoubleHitPct.new(&"t", {"pct": 100.0}).on_hit(ability, 12)
	assert_false(ability.extra_hit, "only the base attack")


func test_the_roll_uses_the_rng_of_the_context() -> void:
	var ctx: EffectContext = _ctx(true)
	var replica := RngService.new(9)
	var expected: bool = replica.roll_pct(40.0)
	DoubleHitPct.new(&"t", {"pct": 40.0}).on_hit(ctx, 12)
	assert_eq(ctx.extra_hit, expected)


func test_engine_a_hit_is_followed_by_a_second_one_on_the_same_target() -> void:
	for seed_value: int in range(1, 60):
		_s = autofree(LegendaryKit.session(seed_value))
		LegendaryKit.sturdy(_s)
		LegendaryKit.wear(_s, &"fx_leg_double")
		var log := LegendaryKit.HitLog.new(_s.events)
		_s.combat.from_save(EffectKit.fight([EffectKit.enemy("test_monster_b", 60000, 999999)], 100))
		_s.combat.advance(100)
		if log.player.is_empty() or not log.player[0][1] or log.player[0][2] <= 0:
			assert_eq(log.player.size(), 1, "a miss or a null hit has no second hit")
			continue
		assert_eq(log.player.size(), 2, "pct 100: exactly two hits, the second does not roll again")
		assert_eq(log.player[1][0], log.player[0][0], "the same target")
		return
	fail_test("no seed hit")


func test_engine_a_weapon_without_the_effect_hits_once() -> void:
	_s = autofree(LegendaryKit.session(4))
	LegendaryKit.sturdy(_s)
	LegendaryKit.wear(_s, &"fx_leg_pierce")  # no double_hit_pct
	var log := LegendaryKit.HitLog.new(_s.events)
	_s.combat.from_save(EffectKit.fight([EffectKit.enemy("test_monster_b", 60000, 999999)], 100))
	_s.combat.advance(100)
	assert_eq(log.player.size(), 1)


# Acceptance: one 1000 ms step = ten 100 ms steps with the effects of the legendaries in play (double hit, kill heal, cap).
func test_one_big_step_equals_many_small_steps_with_legendary_effects() -> void:
	var big: GameSession = _equivalence_session()
	var small: GameSession = _equivalence_session()
	for i: int in 60:
		big.advance(1000)
	for i: int in 600:
		small.advance(100)
	assert_gt(big.combat.total_kills().size(), 0, "something was killed")
	assert_eq(SaveCodec.encode(small.to_save(0)), SaveCodec.encode(big.to_save(0)))


func _equivalence_session() -> GameSession:
	var s: GameSession = autofree(LegendaryKit.session(13))
	LegendaryKit.hero(s)
	LegendaryKit.wear(s, &"fx_leg_double")
	LegendaryKit.wear(s, &"fx_leg_killheal")
	LegendaryKit.wear(s, &"fx_leg_cap")
	TestFactory.make_roomy(s)
	assert_true(s.combat.start(&"test_area").ok)
	return s
