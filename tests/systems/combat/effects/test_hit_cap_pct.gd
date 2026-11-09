extends GutTest
## F-120 `hit_cap_pct` (hook `on_damaged`, before the damage is taken): a hit never exceeds max(1, floor(max_hp x pct/100)):
## max 400, 25% -> cap 100; a hit of 180 -> 100.

var _s: GameSession = null


func _ctx(max_hp: int) -> EffectContext:
	var ctx := EffectContext.new()
	ctx.player_max_hp = max_hp
	return ctx


func test_example() -> void:
	var ctx: EffectContext = _ctx(400)
	assert_eq(HitCapPct.new(&"t", {"pct": 25.0}).cap_damage(ctx, 180), 100)
	assert_eq(ctx.triggered, [&"t"] as Array[StringName])


func test_a_hit_under_the_cap_is_untouched() -> void:
	var ctx: EffectContext = _ctx(400)
	assert_eq(HitCapPct.new(&"t", {"pct": 25.0}).cap_damage(ctx, 100), 100)
	assert_eq(HitCapPct.new(&"t", {"pct": 25.0}).cap_damage(ctx, 7), 7)
	assert_true(ctx.triggered.is_empty())


func test_the_cap_is_at_least_one() -> void:
	assert_eq(HitCapPct.new(&"t", {"pct": 25.0}).cap_damage(_ctx(3), 50), 1, "floor(0.75) = 0 -> 1")
	assert_eq(HitCapPct.new(&"t", {"pct": 100.0}).cap_damage(_ctx(400), 900), 400, "100%: the maximum hp")


func test_engine_a_big_hit_loses_at_most_the_cap() -> void:
	var found: bool = false
	for seed_value: int in range(1, 40):
		_s = autofree(LegendaryKit.session(seed_value))
		LegendaryKit.wear(_s, &"fx_leg_cap")
		var max_hp: int = _s.combat.player_stats().max_hp
		var cap: int = maxi(1, int(floor(max_hp * 25.0 / 100.0)))
		var log := LegendaryKit.HitLog.new(_s.events)
		_s.combat.from_save(EffectKit.fight([EffectKit.enemy("fx_brute", 100000, 1000)], 999999, max_hp))
		_s.combat.advance(1000)
		if log.enemies.is_empty() or not log.enemies[0][1]:
			continue
		assert_gt(log.enemies[0][2], cap, "the brute hits harder than the cap")
		assert_eq(max_hp - int(_s.combat.get_state()["player_hp"]), cap, "the hit takes exactly the cap")
		found = true
		break
	assert_true(found, "some seed is hit")
