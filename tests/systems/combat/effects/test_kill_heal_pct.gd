extends GutTest
## F-120 `kill_heal_pct` (hook `on_kill`): a kill heals floor(max_hp x pct/100): max 1000, 2% -> +20.

var _s: GameSession = null


func test_example() -> void:
	var ctx := EffectContext.new()
	ctx.player_max_hp = 1000
	KillHealPct.new(&"equipment:body", {"pct": 2.0}).on_kill(ctx)
	assert_eq(ctx.heal, 20)
	assert_eq(ctx.triggered, [&"equipment:body"] as Array[StringName])


func test_floor_and_zero() -> void:
	var ctx := EffectContext.new()
	ctx.player_max_hp = 99
	KillHealPct.new(&"t", {"pct": 2.0}).on_kill(ctx)
	assert_eq(ctx.heal, 1, "floor(1.98)")
	var none := EffectContext.new()
	none.player_max_hp = 40
	KillHealPct.new(&"t", {"pct": 2.0}).on_kill(none)
	assert_eq(none.heal, 0)
	assert_true(none.triggered.is_empty())


func test_engine_a_kill_heals_the_player_and_the_heal_is_capped() -> void:
	var found: bool = false
	for seed_value: int in range(1, 60):
		_s = autofree(LegendaryKit.session(seed_value))
		LegendaryKit.hero(_s)
		LegendaryKit.wear(_s, &"fx_leg_killheal")
		_s.combat.from_save(EffectKit.fight([EffectKit.enemy("test_monster_a", 20, 999999)], 100, 50000))
		_s.combat.advance(100)
		if _s.combat.kills(&"test_monster_a") != 1:
			continue
		var max_hp: int = _s.combat.player_stats().max_hp
		assert_eq(_s.combat.get_state()["player_hp"], 50000 + int(floor(max_hp * 2.0 / 100.0)))
		found = true
		break
	assert_true(found, "some seed kills at the first attack")


func test_engine_the_heal_never_goes_above_the_maximum() -> void:
	for seed_value: int in range(1, 60):
		_s = autofree(LegendaryKit.session(seed_value))
		LegendaryKit.hero(_s)
		LegendaryKit.wear(_s, &"fx_leg_killheal")
		var max_hp: int = _s.combat.player_stats().max_hp
		_s.combat.from_save(EffectKit.fight([EffectKit.enemy("test_monster_a", 20, 999999)], 100, max_hp))
		_s.combat.advance(100)
		if _s.combat.kills(&"test_monster_a") == 1:
			assert_eq(_s.combat.get_state()["player_hp"], max_hp)
			return
	fail_test("no seed killed at the first attack")
