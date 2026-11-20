extends GutTest
## F-192 `stack_damage` (`gain`, `pct`, `max`, `lose`): `s` stacks, factor `1 + s x pct/100` in `M` (B, A, C). Slancio: 3 kills -> x1.15;
## a hit taken (hp lost) -> 0; a block or a hit that the Ward takes entirely never reaches `on_damaged`, so the stacks stay.


func _hit(kind: StringName) -> EffectContext:
	var ctx := EffectContext.new()
	ctx.hit_kind = kind
	return ctx


func _effect(gain: String = "kill", lose: String = "damaged", pct: float = 5.0, max_stacks: int = 5) -> StackDamage:
	return StackDamage.new(&"t", {"gain": gain, "pct": pct, "max": max_stacks, "lose": lose})


func test_example_three_kills_then_a_hit_taken() -> void:
	var fx: StackDamage = _effect()
	var ctx := EffectContext.new()
	for i: int in 3:
		fx.on_kill(ctx)
	assert_almost_eq(fx.hit_mult(_hit(EffectContext.HIT_BASE)), 1.15, 0.0000001)
	fx.on_damaged(ctx, 12)
	assert_eq(fx.hit_mult(_hit(EffectContext.HIT_BASE)), 1.0)
	assert_eq(ctx.triggered, [&"t"] as Array[StringName])


func test_the_factor_is_for_b_a_and_c_but_not_for_the_extra_hit() -> void:
	var fx: StackDamage = _effect()
	fx.on_kill(EffectContext.new())
	for kind: StringName in [EffectContext.HIT_BASE, EffectContext.HIT_ABILITY, EffectContext.HIT_COUNTER]:
		assert_almost_eq(fx.hit_mult(_hit(kind)), 1.05, 0.0000001, String(kind))
	assert_eq(fx.hit_mult(_hit(EffectContext.HIT_EXTRA)), 1.0)


func test_the_stacks_stop_at_max() -> void:
	var fx: StackDamage = _effect("kill", "damaged", 5.0, 2)
	for i: int in 6:
		fx.on_kill(EffectContext.new())
	assert_almost_eq(fx.hit_mult(_hit(EffectContext.HIT_BASE)), 1.10, 0.0000001)


func test_every_gain_event() -> void:
	for event: String in ["kill", "hit", "block", "evade"]:
		var fx: StackDamage = _effect(event)
		var ctx := EffectContext.new()
		ctx.hit_kind = EffectContext.HIT_ABILITY
		fx.on_kill(ctx)
		fx.on_hit(ctx, 5)
		fx.on_block(ctx)
		fx.on_evade(ctx)
		assert_almost_eq(fx.hit_mult(_hit(EffectContext.HIT_BASE)), 1.05, 0.0000001, "only '%s' gains" % event)


func test_hit_gains_for_b_a_c_that_land_not_for_the_extra_hit() -> void:
	var fx: StackDamage = _effect("hit")
	for kind: StringName in [EffectContext.HIT_BASE, EffectContext.HIT_ABILITY, EffectContext.HIT_COUNTER, EffectContext.HIT_EXTRA]:
		fx.on_hit(_hit(kind), 9)
	assert_almost_eq(fx.hit_mult(_hit(EffectContext.HIT_BASE)), 1.15, 0.0000001, "three of the four kinds")


func test_lose_encounter_and_none() -> void:
	var by_encounter: StackDamage = _effect("kill", "encounter")
	var never: StackDamage = _effect("kill", "none")
	for fx: StackDamage in [by_encounter, never]:
		fx.on_kill(EffectContext.new())
		fx.on_damaged(EffectContext.new(), 50)
	assert_eq(by_encounter.hit_mult(_hit(EffectContext.HIT_BASE)), 1.05, "damage does not end it")
	by_encounter.on_encounter_start(EffectContext.new())
	never.on_encounter_start(EffectContext.new())
	assert_eq(by_encounter.hit_mult(_hit(EffectContext.HIT_BASE)), 1.0)
	assert_almost_eq(never.hit_mult(_hit(EffectContext.HIT_BASE)), 1.05, 0.0000001)


func test_lose_damaged_does_not_end_on_a_new_encounter() -> void:
	var fx: StackDamage = _effect()
	fx.on_kill(EffectContext.new())
	fx.on_encounter_start(EffectContext.new())
	assert_almost_eq(fx.hit_mult(_hit(EffectContext.HIT_BASE)), 1.05, 0.0000001)


func test_state_round_trip_and_tolerance() -> void:
	var fx: StackDamage = _effect()
	assert_true(fx.has_state())
	assert_eq(fx.to_save(), {})
	for i: int in 3:
		fx.on_kill(EffectContext.new())
	assert_eq(fx.to_save(), {"stacks": 3})
	var other: StackDamage = _effect()
	other.from_save(fx.to_save())
	assert_eq(other.to_save(), {"stacks": 3})
	other.from_save({"stacks": 99})
	assert_eq(other.to_save(), {"stacks": 5}, "clamped to max")
	other.from_save({"stacks": "x"})
	assert_eq(other.to_save(), {})
