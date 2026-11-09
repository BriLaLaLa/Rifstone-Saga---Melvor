extends GutTest
## F-120 `execute_mult` (hook `on_before_attack`, asked for each target): the damage after F-24 x `mult` (floor) when the
## target has hp <= hp_pct% of its maximum: 30%, x2, roll 40 -> 80.

var _s: GameSession = null


func test_threshold_is_floor_of_the_maximum() -> void:
	var effect := ExecuteMult.new(&"t", {"hp_pct": 30.0, "mult": 2.0})
	for row: Array in [[18, 2.0], [19, 1.0], [0, 2.0], [60, 1.0]]:
		var ctx := EffectContext.new()
		assert_eq(effect.damage_mult_against(ctx, row[0], 60), row[1], "hp %d of 60" % row[0])
		assert_eq(ctx.triggered.is_empty(), row[1] == 1.0)


func test_roll_40_doubled_is_80() -> void:
	var data: GameData = LegendaryKit.session(1).data
	var attacker := CombatantStats.new()
	attacker.style = &"blade"
	attacker.accuracy = 100000
	attacker.min_hit = 40
	attacker.max_hit = 40
	var defender := CombatantStats.new()
	defender.style = &"blade"
	defender.evasion = 1
	var rng := RngService.new(5)
	var mult: float = ExecuteMult.new(&"t", {"hp_pct": 30.0, "mult": 2.0}).damage_mult_against(EffectContext.new(), 10, 60)
	for i: int in 50:
		var result: Dictionary = Encounter.roll_attack(attacker, defender, 0.0, rng, data, mult)
		if result["hit"]:
			assert_eq(result["damage"], 80)
			return
	fail_test("no hit")


# Monster B has 60 hp at most: with 10 hp (<= 18) the damage is doubled, at full health it is the plain one.
func test_engine_the_weak_target_takes_double_and_the_healthy_one_does_not() -> void:
	for hp: int in [10, 60]:
		var checked: bool = false
		for seed_value: int in range(1, 60):
			_s = autofree(LegendaryKit.session(seed_value))
			LegendaryKit.sturdy(_s)
			LegendaryKit.wear(_s, &"fx_leg_execute")
			var expected: Dictionary = LegendaryKit.replay_first_attack(_s, seed_value, &"test_monster_b", 2.0 if hp <= 18 else 1.0)
			if not expected["hit"]:
				continue
			var log := LegendaryKit.HitLog.new(_s.events)
			_s.combat.from_save(EffectKit.fight([EffectKit.enemy("test_monster_b", hp, 999999)], 100))
			_s.combat.advance(100)
			assert_eq(log.player[0][2], expected["damage"], "hp %d" % hp)
			checked = true
			break
		assert_true(checked, "a seed hits for hp %d" % hp)
