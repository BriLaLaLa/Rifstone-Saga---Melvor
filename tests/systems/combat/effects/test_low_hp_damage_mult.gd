extends GutTest
## F-81 `low_hp_damage_mult`: max 170, 30% -> threshold 51; hp 50, roll 20, x2 -> 40; `no_auto_eat` blocks F-30 when low.

var _session: GameSession


func before_each() -> void:
	_session = autofree(TestFactory.session(3))


func _effect(no_auto_eat: bool) -> LowHpDamageMult:
	return LowHpDamageMult.new(&"t", {"hp_pct": 30.0, "mult": 2.0, "no_auto_eat": no_auto_eat})


func _ctx(hp: int) -> EffectContext:
	var ctx := EffectContext.new()
	ctx.player_hp = hp
	ctx.player_max_hp = 170
	return ctx


func test_threshold_is_floor_of_max_hp_pct() -> void:
	for row: Array in [[50, 2.0], [51, 2.0], [52, 1.0]]:
		var ctx: EffectContext = _ctx(row[0])
		_effect(false).on_before_attack(ctx)
		assert_eq(ctx.damage_mult, row[1], "hp %d" % row[0])
		assert_eq(ctx.triggered.is_empty(), row[1] == 1.0)


func test_multiplier_applies_after_the_triangle_and_before_the_reduction() -> void:
	# roll 20 (min = max), neutral, DR 0: 20 x 2 = 40. With DR 10: floor(40 x 0.9) = 36.
	var attacker := CombatantStats.new()
	attacker.style = &"blade"
	attacker.accuracy = 100000
	attacker.min_hit = 20
	attacker.max_hit = 20
	var defender := CombatantStats.new()
	defender.style = &"blade"
	defender.evasion = 1
	var data: GameData = _session.data
	for dr: float in [0.0, 10.0]:
		defender.damage_reduction = dr
		var expected: int = 40 if dr == 0.0 else 36
		var got: int = 0
		for i: int in 50:
			var result: Dictionary = Encounter.roll_attack(attacker, defender, 0.0, _session.rng, data, 2.0)
			if result["hit"]:
				got = result["damage"]
				break
		assert_eq(got, expected, "DR %s" % dr)


func test_no_auto_eat_only_when_low_and_flagged() -> void:
	assert_true(_effect(true).blocks_auto_eat(_ctx(50)))
	assert_false(_effect(true).blocks_auto_eat(_ctx(52)))
	assert_false(_effect(false).blocks_auto_eat(_ctx(50)))


func test_engine_no_auto_eat_keeps_the_food() -> void:
	# Level-1 auto-eat would eat below 30% hp; the trait forbids it while low.
	_session.modifiers.set_source(&"test:eat", [Modifier.make(&"auto_eat_tier", 1.0)] as Array[Modifier])
	TestFactory.give(_session, &"test_ration", 5)
	_session.equipment.set_food(&"test_ration")
	EffectKit.equip_trait(_session, &"t_rage", [{"type": "low_hp_damage_mult", "params": {
		"hp_pct": 30, "mult": 2.0, "no_auto_eat": true}}])
	_session.combat.from_save(EffectKit.fight([EffectKit.enemy("test_monster_b", 60, 100)], 5000, 12))
	var guard: int = 0
	while _session.combat.food_eaten() == 0 and _session.combat.deaths() == 0 and guard < 200:
		_session.combat.advance(100)
		guard += 1
	assert_eq(_session.combat.food_eaten(), 0, "no meal while low")
	EffectKit.cleanup()
