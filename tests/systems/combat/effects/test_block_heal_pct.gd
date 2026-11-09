extends GutTest
## F-120 `block_heal_pct` (legendary shield, hook `on_block`): a block heals floor(max_hp x pct/100): max 200, 10% -> +20.

var _s: GameSession = null


func test_example() -> void:
	var ctx := EffectContext.new()
	ctx.player_max_hp = 200
	BlockHealPct.new(&"equipment:offhand", {"pct": 10.0}).on_block(ctx)
	assert_eq(ctx.heal, 20)
	assert_eq(ctx.triggered, [&"equipment:offhand"] as Array[StringName])


func test_a_heal_of_zero_does_nothing() -> void:
	var ctx := EffectContext.new()
	ctx.player_max_hp = 5
	BlockHealPct.new(&"t", {"pct": 10.0}).on_block(ctx)
	assert_eq(ctx.heal, 0)
	assert_true(ctx.triggered.is_empty())


func test_engine_a_block_heals_the_player() -> void:
	var found: bool = false
	for seed_value: int in range(1, 80):
		_s = autofree(LegendaryKit.session(seed_value))
		LegendaryKit.sturdy(_s)
		LegendaryKit.wear(_s, &"fx_leg_blockheal")
		_s.modifiers.set_source(&"test:block", [Modifier.make(&"block_chance", 50.0)] as Array[Modifier])
		var log := LegendaryKit.HitLog.new(_s.events)
		_s.combat.from_save(EffectKit.fight([EffectKit.enemy("test_monster_b", 60, 100)], 999999, 50000))
		_s.combat.advance(100)
		if log.enemies.is_empty() or not log.enemies[0][3]:
			continue
		var max_hp: int = _s.combat.player_stats().max_hp
		assert_eq(_s.combat.get_state()["player_hp"], 50000 + int(floor(max_hp * 10.0 / 100.0)), "10% of the maximum")
		found = true
		break
	assert_true(found, "some seed blocks the first attack")


func test_engine_without_a_block_nothing_is_healed() -> void:
	_s = autofree(LegendaryKit.session(3))
	LegendaryKit.sturdy(_s)
	LegendaryKit.wear(_s, &"fx_leg_blockheal")  # block_chance 0: never blocks
	_s.combat.from_save(EffectKit.fight([EffectKit.enemy("test_monster_b", 60, 100)], 999999, 50000))
	_s.combat.advance(100)
	assert_lte(_s.combat.get_state()["player_hp"], 50000)
