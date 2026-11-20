extends GutTest
## F-192 `ward_on` (`on`, `pct`, `ms`): a Ward of floor(max_hp x pct/100) for `ms` at the event; the largest wins (F-189).
## Example: a kill, max 500, 8% -> 40 for 6000 ms.


func test_example_a_kill_asks_8_percent_for_6000_ms() -> void:
	var fx := WardOn.new(&"t", {"on": "kill", "pct": 8.0, "ms": 6000})
	var ctx := EffectContext.new()
	ctx.player_max_hp = 500
	fx.on_kill(ctx)
	assert_eq([ctx.ward_pct, ctx.ward_ms], [8.0, 6000])
	assert_eq(int(floor(float(ctx.player_max_hp) * ctx.ward_pct / 100.0 + CombatMath.EPSILON)), 40)
	assert_eq(ctx.triggered, [&"t"] as Array[StringName])


func test_only_the_chosen_event() -> void:
	for event: String in ["kill", "block", "encounter_start"]:
		var fx := WardOn.new(&"t", {"on": event, "pct": 5.0, "ms": 3000})
		var ctx := EffectContext.new()
		fx.on_kill(ctx)
		assert_eq(ctx.ward_pct > 0.0, event == "kill", "kill with on=%s" % event)
		ctx = EffectContext.new()
		fx.on_block(ctx)
		assert_eq(ctx.ward_pct > 0.0, event == "block", "block with on=%s" % event)
		ctx = EffectContext.new()
		fx.on_encounter_start(ctx)
		assert_eq(ctx.ward_pct > 0.0, event == "encounter_start", "start with on=%s" % event)


func test_the_largest_ward_wins_whatever_the_order() -> void:
	var small := WardOn.new(&"small", {"on": "kill", "pct": 5.0, "ms": 9000})
	var big := WardOn.new(&"big", {"on": "kill", "pct": 12.0, "ms": 2000})
	var first := EffectContext.new()
	small.on_kill(first)
	big.on_kill(first)
	assert_eq([first.ward_pct, first.ward_ms], [12.0, 2000])
	var second := EffectContext.new()
	big.on_kill(second)
	small.on_kill(second)
	assert_eq([second.ward_pct, second.ward_ms], [12.0, 2000])


func test_no_state() -> void:
	assert_false(WardOn.new(&"t", {"on": "kill", "pct": 5.0, "ms": 1000}).has_state())
