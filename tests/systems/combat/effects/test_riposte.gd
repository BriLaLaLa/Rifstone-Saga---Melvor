extends GutTest
## F-192 `riposte` (`on`, `mult`): the counter-attack C after a block or an evade; the strongest `mult` wins. Example: a block, roll 30, x0.8,
## neutral, DR 10 -> floor(30 x 0.8) = 24 -> 24 after F-24 and M -> F-25 -> 21.


func test_example_damage_of_the_counter() -> void:
	var scaled: int = int(floor(30.0 * 0.8 + CombatMath.EPSILON))
	assert_eq(scaled, 24)
	assert_eq(CombatMath.damage_after_dr(scaled, 10.0), 21)


func test_a_block_asks_for_the_counter_only_when_set_on_block() -> void:
	var fx := Riposte.new(&"t", {"on": "block", "mult": 0.8})
	var ctx := EffectContext.new()
	fx.on_evade(ctx)
	assert_eq(ctx.counter_mult, 0.0)
	assert_true(ctx.triggered.is_empty())
	fx.on_block(ctx)
	assert_eq(ctx.counter_mult, 0.8)
	assert_eq(ctx.triggered, [&"t"] as Array[StringName])


func test_an_evade_asks_for_the_counter_only_when_set_on_evade() -> void:
	var fx := Riposte.new(&"t", {"on": "evade", "mult": 1.5})
	var ctx := EffectContext.new()
	fx.on_block(ctx)
	assert_eq(ctx.counter_mult, 0.0)
	fx.on_evade(ctx)
	assert_eq(ctx.counter_mult, 1.5)


func test_the_strongest_mult_wins_in_any_order() -> void:
	var low := Riposte.new(&"low", {"on": "block", "mult": 0.8})
	var high := Riposte.new(&"high", {"on": "block", "mult": 1.5})
	var ctx := EffectContext.new()
	high.on_block(ctx)
	low.on_block(ctx)
	assert_eq(ctx.counter_mult, 1.5)
	var other := EffectContext.new()
	low.on_block(other)
	high.on_block(other)
	assert_eq(other.counter_mult, 1.5)


func test_no_state() -> void:
	var fx := Riposte.new(&"t", {"on": "block", "mult": 0.8})
	assert_false(fx.has_state())
	assert_eq(fx.to_save(), {})
