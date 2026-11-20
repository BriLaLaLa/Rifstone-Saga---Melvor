extends GutTest
## F-192 `after_ability_mult` (`mult`): after an ability the next base attack has the factor `mult` (B, all its targets), then it is spent,
## even if it misses. Example: x1.5, roll 20, DR 0 -> 30.


func _hit(kind: StringName = EffectContext.HIT_BASE) -> EffectContext:
	var ctx := EffectContext.new()
	ctx.hit_kind = kind
	return ctx


func _effect() -> AfterAbilityMult:
	return AfterAbilityMult.new(&"t", {"mult": 1.5})


func test_example_the_next_base_attack_is_charged() -> void:
	var fx: AfterAbilityMult = _effect()
	assert_eq(fx.hit_mult(_hit()), 1.0, "not charged yet")
	fx.on_ability(EffectContext.new())
	var attack := EffectContext.new()
	fx.on_before_attack(attack)
	assert_eq(attack.triggered, [&"t"] as Array[StringName])
	assert_eq(int(floor(20.0 * fx.hit_mult(_hit()) + CombatMath.EPSILON)), 30)
	assert_eq(int(floor(20.0 * fx.hit_mult(_hit()) + CombatMath.EPSILON)), 30, "every target of the same attack")


func test_it_is_spent_by_the_attack_even_if_it_misses() -> void:
	var fx: AfterAbilityMult = _effect()
	fx.on_ability(EffectContext.new())
	fx.on_before_attack(EffectContext.new())  # this attack misses: no hit_mult is ever asked
	fx.on_before_attack(EffectContext.new())  # the next one
	assert_eq(fx.hit_mult(_hit()), 1.0)
	assert_eq(fx.to_save(), {})


func test_other_hits_are_never_charged_and_two_abilities_charge_once() -> void:
	var fx: AfterAbilityMult = _effect()
	fx.on_ability(EffectContext.new())
	fx.on_ability(EffectContext.new())
	fx.on_before_attack(EffectContext.new())
	for kind: StringName in [EffectContext.HIT_ABILITY, EffectContext.HIT_COUNTER, EffectContext.HIT_EXTRA]:
		assert_eq(fx.hit_mult(_hit(kind)), 1.0, String(kind))
	fx.on_before_attack(EffectContext.new())
	assert_eq(fx.hit_mult(_hit()), 1.0)


func test_state_is_the_armed_flag() -> void:
	var fx: AfterAbilityMult = _effect()
	assert_true(fx.has_state())
	assert_eq(fx.to_save(), {})
	fx.on_ability(EffectContext.new())
	assert_eq(fx.to_save(), {"armed": true})
	var other: AfterAbilityMult = _effect()
	other.from_save(fx.to_save())
	other.on_before_attack(EffectContext.new())
	assert_eq(other.hit_mult(_hit()), 1.5)
	other.from_save({"armed": "yes"})
	assert_eq(other.to_save(), {})
