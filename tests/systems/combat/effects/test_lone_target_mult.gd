extends GutTest
## F-192 `lone_target_mult` (`pct`): factor `1 + pct/100` in `M` (B, A, C) if exactly one enemy is alive as the hit is rolled.
## Example: 1 alive -> x1.25; 2 alive -> x1.


func _ctx(alive: int, kind: StringName = EffectContext.HIT_BASE) -> EffectContext:
	var ctx := EffectContext.new()
	ctx.alive_count = alive
	ctx.hit_kind = kind
	return ctx


func test_example() -> void:
	var fx := LoneTargetMult.new(&"t", {"pct": 25.0})
	assert_eq(fx.hit_mult(_ctx(1)), 1.25)
	assert_eq(fx.hit_mult(_ctx(2)), 1.0)
	assert_eq(fx.hit_mult(_ctx(0)), 1.0, "nobody alive: nothing to hit")


func test_b_a_and_c_but_not_the_extra_hit() -> void:
	var fx := LoneTargetMult.new(&"t", {"pct": 25.0})
	for kind: StringName in [EffectContext.HIT_BASE, EffectContext.HIT_ABILITY, EffectContext.HIT_COUNTER]:
		assert_eq(fx.hit_mult(_ctx(1, kind)), 1.25, String(kind))
	assert_eq(fx.hit_mult(_ctx(1, EffectContext.HIT_EXTRA)), 1.0)


func test_no_state() -> void:
	assert_false(LoneTargetMult.new(&"t", {"pct": 5.0}).has_state())
