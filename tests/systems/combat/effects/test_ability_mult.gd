extends GutTest
## F-192 `ability_mult` (`kinds`, `pct`): factor `1 + pct/100` in `M` for the hits of `strike` and `cleave`, on the amount of a `heal` (F-191)
## or a `ward` (F-189) if listed. Example: a heal of 20% of 170 hp with 25 -> floor(42.5) = 42.


func _ability_hit(kind: StringName) -> EffectContext:
	var ctx := EffectContext.new()
	ctx.hit_kind = EffectContext.HIT_ABILITY
	ctx.ability_kind = kind
	return ctx


func _amount(kind: StringName) -> EffectContext:
	var ctx := EffectContext.new()
	ctx.ability_kind = kind
	return ctx


func test_example_heal_amount() -> void:
	var fx := AbilityMult.new(&"t", {"kinds": ["heal"], "pct": 25.0})
	assert_eq(fx.amount_mult(_amount(&"heal")), 1.25)
	assert_eq(int(floor(170.0 * 20.0 / 100.0 * fx.amount_mult(_amount(&"heal")) + CombatMath.EPSILON)), 42)


func test_the_ward_amount_f189_example() -> void:
	var fx := AbilityMult.new(&"t", {"kinds": ["ward"], "pct": 25.0})
	assert_eq(int(floor(400.0 * 15.0 / 100.0 * fx.amount_mult(_amount(&"ward")) + CombatMath.EPSILON)), 75)


func test_only_the_listed_kinds() -> void:
	var fx := AbilityMult.new(&"t", {"kinds": ["strike", "heal"], "pct": 25.0})
	assert_eq(fx.hit_mult(_ability_hit(&"strike")), 1.25)
	assert_eq(fx.hit_mult(_ability_hit(&"cleave")), 1.0)
	assert_eq(fx.amount_mult(_amount(&"heal")), 1.25)
	assert_eq(fx.amount_mult(_amount(&"ward")), 1.0)
	assert_eq(fx.amount_mult(_amount(&"buff")), 1.0)


func test_never_on_the_hits_that_are_not_of_an_ability() -> void:
	var fx := AbilityMult.new(&"t", {"kinds": ["strike", "cleave"], "pct": 25.0})
	for kind: StringName in [EffectContext.HIT_BASE, EffectContext.HIT_COUNTER, EffectContext.HIT_EXTRA]:
		var ctx := EffectContext.new()
		ctx.hit_kind = kind
		ctx.ability_kind = &"strike"
		assert_eq(fx.hit_mult(ctx), 1.0, String(kind))


func test_no_state() -> void:
	assert_false(AbilityMult.new(&"t", {"kinds": ["heal"], "pct": 5.0}).has_state())
