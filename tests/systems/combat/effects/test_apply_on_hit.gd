extends GutTest
## F-192 `apply_on_hit` (`every`, `condition`, `pct`, `ms`): at every `every`-th base hit that lands the condition is applied to the target.
## Example: every 3, bleed 40%, 4000 ms: the 3rd hit with D 30 -> total 12 -> 3, 3, 3, 3 (the Bleed itself is F-186).


func _hit(kind: StringName = EffectContext.HIT_BASE) -> EffectContext:
	var ctx := EffectContext.new()
	ctx.hit_kind = kind
	return ctx


func _bleed() -> ApplyOnHit:
	return ApplyOnHit.new(&"t", {"every": 3, "condition": "bleed", "pct": 40.0, "ms": 4000})


func test_example_the_third_hit_applies_a_bleed_that_makes_3_3_3_3() -> void:
	var fx: ApplyOnHit = _bleed()
	var first := _hit()
	fx.on_hit(first, 30)
	fx.on_hit(first, 30)
	assert_true(first.applies.is_empty())
	var third := _hit()
	fx.on_hit(third, 30)
	assert_eq(third.applies.size(), 1)
	var app: ConditionApply = third.applies[0]
	assert_eq([app.condition, app.pct, app.ms], [ConditionApply.BLEED, 40.0, 4000])
	var cond := EnemyConditions.new()
	cond.apply(app, 30, 2000, true, ConditionParams.new())
	assert_eq([cond.bleed_left, cond.bleed_ticks], [12, 4])
	assert_eq(third.triggered, [&"t"] as Array[StringName])


func test_the_count_restarts_after_each_application() -> void:
	var fx: ApplyOnHit = _bleed()
	var applied: int = 0
	for i: int in 9:
		var ctx := _hit()
		fx.on_hit(ctx, 10)
		applied += ctx.applies.size()
	assert_eq(applied, 3)
	assert_eq(fx.to_save(), {})


func test_every_1_applies_at_every_hit() -> void:
	var fx := ApplyOnHit.new(&"t", {"every": 1, "condition": "stagger", "ms": 1000})
	var ctx := _hit()
	fx.on_hit(ctx, 4)
	assert_eq(ctx.applies.size(), 1)
	assert_eq(ctx.applies[0].condition, ConditionApply.STAGGER)
	assert_eq(ctx.applies[0].pct, 0.0, "a Stagger has no pct")


func test_only_base_hits_count() -> void:
	var fx: ApplyOnHit = _bleed()
	for kind: StringName in [EffectContext.HIT_ABILITY, EffectContext.HIT_COUNTER, EffectContext.HIT_EXTRA]:
		var ctx := _hit(kind)
		for i: int in 5:
			fx.on_hit(ctx, 9)
		assert_true(ctx.applies.is_empty(), String(kind))
	assert_eq(fx.to_save(), {})


func test_state_round_trip_and_tolerance() -> void:
	var fx: ApplyOnHit = _bleed()
	assert_true(fx.has_state())
	fx.on_hit(_hit(), 5)
	fx.on_hit(_hit(), 5)
	assert_eq(fx.to_save(), {"count": 2})
	var other: ApplyOnHit = _bleed()
	other.from_save(fx.to_save())
	var ctx := _hit()
	other.on_hit(ctx, 5)
	assert_eq(ctx.applies.size(), 1, "the saved count goes on")
	other.from_save({"count": 50})
	assert_eq(other.to_save(), {"count": 2}, "clamped under `every`")
	other.from_save({"count": "x"})
	assert_eq(other.to_save(), {})
