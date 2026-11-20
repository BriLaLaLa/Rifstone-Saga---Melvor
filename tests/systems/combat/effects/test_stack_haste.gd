extends GutTest
## F-192 `stack_haste`: the next base timer is max(min interval, floor(interval x (1 - s x pct/100))): interval 2000, pct 3: s 4 -> 1760;
## s 8 -> 1520; interval 900, s 8 -> 684 -> 800. The engine applies the floor and the minimum (`CombatFight._next_base_timer`).

const MIN_INTERVAL_MS: int = 800  # combat.min_attack_interval_ms


func _effect(stacks: int) -> StackHaste:
	var fx := StackHaste.new(&"t", {"gain": "kill", "pct": 3.0, "max": 8, "lose": "encounter"})
	fx.from_save({"stacks": stacks})
	return fx


func _timer(interval: int, fx: StackHaste) -> int:
	var mult: float = fx.base_timer_mult(EffectContext.new())
	return maxi(MIN_INTERVAL_MS, int(floor(float(interval) * mult + CombatMath.EPSILON)))


func test_examples() -> void:
	assert_eq(_timer(2000, _effect(4)), 1760)
	assert_eq(_timer(2000, _effect(8)), 1520)
	assert_eq(_timer(900, _effect(8)), 800, "684 -> the minimum")


func test_no_stacks_is_neutral() -> void:
	assert_eq(_effect(0).base_timer_mult(EffectContext.new()), 1.0)
	assert_eq(_timer(2000, _effect(0)), 2000)


func test_the_factor_never_goes_negative() -> void:
	var fx := StackHaste.new(&"t", {"gain": "kill", "pct": 50.0, "max": 20, "lose": "none"})
	fx.from_save({"stacks": 20})
	assert_eq(fx.base_timer_mult(EffectContext.new()), 0.0)


func test_gain_and_lose_rules_are_the_ones_of_stack_damage() -> void:
	var fx := StackHaste.new(&"t", {"gain": "evade", "pct": 3.0, "max": 8, "lose": "damaged"})
	fx.on_kill(EffectContext.new())
	assert_eq(fx.to_save(), {}, "a kill is not an evade")
	fx.on_evade(EffectContext.new())
	fx.on_evade(EffectContext.new())
	assert_eq(fx.to_save(), {"stacks": 2})
	assert_almost_eq(fx.base_timer_mult(EffectContext.new()), 0.94, 0.0000001)
	fx.on_damaged(EffectContext.new(), 3)
	assert_eq(fx.to_save(), {})
	assert_true(fx.has_state())
