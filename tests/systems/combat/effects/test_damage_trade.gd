extends GutTest
## F-192 `damage_trade` (`dealt_pct`, `taken_pct`): factor `1 + dealt_pct/100` in `M` (B, A, C), `1 + taken_pct/100` on the damage taken.
## F-190 example: Slancio x1.15 (3 stacks), `damage_trade` 25, Breccia 15 -> M = 1.653125 -> roll 40 -> 66. F-193: d0 25, taken 20 -> 30.


func _hit(kind: StringName) -> EffectContext:
	var ctx := EffectContext.new()
	ctx.hit_kind = kind
	return ctx


func test_dealt_factor_in_the_f190_example() -> void:
	var trade := DamageTrade.new(&"t", {"dealt_pct": 25.0, "taken_pct": 20.0})
	var m: float = 1.15 * trade.hit_mult(_hit(EffectContext.HIT_BASE)) * 1.15
	assert_almost_eq(m, 1.653125, 0.0000001)
	assert_eq(int(floor(40.0 * m + CombatMath.EPSILON)), 66)


func test_dealt_for_b_a_and_c_only() -> void:
	var trade := DamageTrade.new(&"t", {"dealt_pct": 25.0, "taken_pct": 20.0})
	for kind: StringName in [EffectContext.HIT_BASE, EffectContext.HIT_ABILITY, EffectContext.HIT_COUNTER]:
		assert_eq(trade.hit_mult(_hit(kind)), 1.25, String(kind))
	assert_eq(trade.hit_mult(_hit(EffectContext.HIT_EXTRA)), 1.0)


func test_taken_factor_in_the_f193_examples() -> void:
	var trade := DamageTrade.new(&"t", {"dealt_pct": 25.0, "taken_pct": 20.0})
	var taken: float = trade.incoming_mult(EffectContext.new())
	assert_eq(taken, 1.2)
	assert_eq(int(floor(25.0 * (1.0 - 25.0 / 100.0) * taken + CombatMath.EPSILON)), 22, "with Weaken 25")
	assert_eq(int(floor(25.0 * taken + CombatMath.EPSILON)), 30, "alone")


func test_two_trades_multiply() -> void:
	var a := DamageTrade.new(&"a", {"dealt_pct": 10.0, "taken_pct": 10.0})
	var b := DamageTrade.new(&"b", {"dealt_pct": 10.0, "taken_pct": 10.0})
	var set_mult: float = a.incoming_mult(EffectContext.new()) * b.incoming_mult(EffectContext.new())
	assert_almost_eq(set_mult, 1.21, 0.0000001)
