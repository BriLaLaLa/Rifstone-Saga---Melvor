extends GutTest
## F-120 `armor_pierce_pct` (hook `on_before_attack`): the reduction of the target (F-25) x (1 - pct/100): DR 20, 50% -> 10.

var _s: GameSession = null


func _attacker() -> CombatantStats:
	var attacker := CombatantStats.new()
	attacker.style = &"blade"
	attacker.accuracy = 100000
	attacker.min_hit = 100
	attacker.max_hit = 100
	return attacker


func _defender(dr: float) -> CombatantStats:
	var defender := CombatantStats.new()
	defender.style = &"blade"
	defender.evasion = 1
	defender.damage_reduction = dr
	return defender


func test_the_effect_halves_the_factor_and_pierces_stack_by_product() -> void:
	var ctx := EffectContext.new()
	ArmorPiercePct.new(&"t", {"pct": 50.0}).on_before_attack(ctx)
	assert_eq(ctx.dr_mult, 0.5)
	assert_eq(ctx.triggered, [&"t"] as Array[StringName])
	ArmorPiercePct.new(&"u", {"pct": 50.0}).on_before_attack(ctx)
	assert_eq(ctx.dr_mult, 0.25)


func test_roll_attack_dr_20_pierced_by_50_is_dr_10() -> void:
	var data: GameData = LegendaryKit.session(1).data
	var rng := RngService.new(5)
	# 100 damage: DR 20 -> 80; DR 20 x 0.5 = 10 -> 90; no reduction left -> 100.
	for case: Array in [[1.0, 80], [0.5, 90], [0.0, 100]]:
		var damage: int = -1
		for i: int in 50:
			var result: Dictionary = Encounter.roll_attack(_attacker(), _defender(20.0), 0.0, rng, data, 1.0, case[0])
			if result["hit"]:
				damage = result["damage"]
				break
		assert_eq(damage, case[1], "dr_mult %s" % case[0])


func test_engine_the_base_attack_uses_the_pierced_reduction() -> void:
	for seed_value: int in range(1, 40):
		_s = autofree(LegendaryKit.session(seed_value))
		LegendaryKit.wear(_s, &"fx_leg_pierce")
		LegendaryKit.sturdy(_s)
		var expected: Dictionary = LegendaryKit.replay_first_attack(_s, seed_value, &"test_monster_b", 1.0, 0.5)
		if not expected["hit"]:
			continue
		var log := LegendaryKit.HitLog.new(_s.events)
		_s.combat.from_save(EffectKit.fight([EffectKit.enemy("test_monster_b", 60000, 999999)], 100))
		_s.combat.advance(100)
		assert_eq(log.player[0], [0, true, expected["damage"]], "monster B has 10% reduction, pierced to 5%")
		var plain: Dictionary = LegendaryKit.replay_first_attack(_s, seed_value, &"test_monster_b", 1.0, 1.0)
		assert_gte(expected["damage"], plain["damage"])
		return
	fail_test("no seed hits")
