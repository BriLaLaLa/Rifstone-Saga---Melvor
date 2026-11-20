extends GutTest
## F-192 `focus_combo` (`pct` 6, `max` 5): always the same main target -> x1.00, 1.06, 1.12, 1.18, 1.24, 1.30, 1.30; another main target -> x1.00.

func _ctx(target: int, primary: int, kind: StringName = EffectContext.HIT_BASE) -> EffectContext:
	var ctx := EffectContext.new()
	ctx.target_index = target
	ctx.primary_index = primary
	ctx.hit_kind = kind
	return ctx


func _effect() -> FocusCombo:
	return FocusCombo.new(&"t", {"pct": 6.0, "max": 5})


func _strike(fx: FocusCombo, target: int) -> float:
	var mult: float = fx.hit_mult(_ctx(target, target))
	fx.on_hit(_ctx(target, target), 5)
	return mult


func test_example_sequence() -> void:
	var fx: FocusCombo = _effect()
	var expected: Array[float] = [1.00, 1.06, 1.12, 1.18, 1.24, 1.30, 1.30]
	for step: int in expected.size():
		assert_almost_eq(_strike(fx, 0), expected[step], 0.0000001, "hit %d" % step)


func test_another_main_target_restarts() -> void:
	var fx: FocusCombo = _effect()
	for i: int in 3:
		_strike(fx, 0)
	assert_eq(_strike(fx, 1), 1.0)
	assert_almost_eq(_strike(fx, 1), 1.06, 0.0000001)
	assert_eq(_strike(fx, 0), 1.0, "back to the first one: restarts too")


func test_the_extra_targets_of_an_attack_all_neither_get_it_nor_count() -> void:
	var fx: FocusCombo = _effect()
	_strike(fx, 0)
	_strike(fx, 0)
	assert_eq(fx.hit_mult(_ctx(1, 0)), 1.0, "a target that is not the main one")
	fx.on_hit(_ctx(1, 0), 9)
	assert_almost_eq(fx.hit_mult(_ctx(0, 0)), 1.12, 0.0000001, "still two hits on the main target")


func test_only_base_hits() -> void:
	var fx: FocusCombo = _effect()
	_strike(fx, 0)
	for kind: StringName in [EffectContext.HIT_ABILITY, EffectContext.HIT_COUNTER, EffectContext.HIT_EXTRA]:
		assert_eq(fx.hit_mult(_ctx(0, 0, kind)), 1.0)
		fx.on_hit(_ctx(0, 0, kind), 5)
	assert_almost_eq(fx.hit_mult(_ctx(0, 0)), 1.06, 0.0000001)


func test_a_new_encounter_resets() -> void:
	var fx: FocusCombo = _effect()
	_strike(fx, 0)
	_strike(fx, 0)
	fx.on_encounter_start(EffectContext.new())
	assert_eq(fx.hit_mult(_ctx(0, 0)), 1.0)
	assert_eq(fx.to_save(), {})


func test_state_round_trip_and_tolerance() -> void:
	var fx: FocusCombo = _effect()
	assert_true(fx.has_state())
	_strike(fx, 2)
	_strike(fx, 2)
	assert_eq(fx.to_save(), {"target": 2, "count": 2})
	var other: FocusCombo = _effect()
	other.from_save(fx.to_save())
	assert_almost_eq(other.hit_mult(_ctx(2, 2)), 1.12, 0.0000001)
	other.from_save({"target": 2, "count": 77})
	assert_eq(other.to_save(), {"target": 2, "count": 5})
	other.from_save({"target": "x"})
	assert_eq(other.to_save(), {})
