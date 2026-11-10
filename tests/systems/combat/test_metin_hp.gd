extends GutTest
## F-125 (docs/02_FORMULAS.md §5f): the hp of a Rift Stone by level and its fixed pulse. Real balance, no fixtures needed.

const SOURCE: StringName = &"test:armour"


func test_hp_by_level_examples() -> void:
	var data: GameData = TestFactory.real_data()
	assert_eq(StoneFight.max_hp(5, data), 450, "200 x (1 + 0.25 x 5)")
	assert_eq(StoneFight.max_hp(10, data), 700)
	assert_eq(StoneFight.max_hp(15, data), 950)
	assert_eq(StoneFight.max_hp(65, data), 3450)
	assert_eq(StoneFight.max_hp(95, data), 4950)


func test_pulse_damage_is_the_balance_value() -> void:
	assert_eq(StoneFight.pulse_damage(TestFactory.real_data()), 1)


func test_the_stone_enemy_has_the_formula_hp_and_the_pulse() -> void:
	var data: GameData = TestFactory.real_data()
	var def: RiftStoneDef = data.rift_stone(&"redrock_plains_stone_10")
	var enemy: Encounter.Enemy = RiftStone.enemy(def, data)
	assert_eq(enemy.stats.max_hp, 700)
	assert_eq(enemy.hp, 700)
	assert_eq(enemy.pulse_damage, 1)
	assert_true(enemy.is_stone())
	assert_eq(enemy.stats.attack_interval_ms, def.pulse_ms)


func test_the_pulse_ignores_armour_and_barrier_and_cannot_be_blocked() -> void:
	var data: GameData = TestFactory.real_data()
	var me := CombatantStats.new()
	me.damage_reduction = 90.0
	me.block_chance = 100.0
	var rng := RngService.new(3)
	var stone: Encounter.Enemy = RiftStone.enemy(data.rift_stone(&"redrock_plains_stone_5"), data)
	for _i: int in 20:
		assert_eq(Encounter.roll_enemy_attack(stone, me, rng, data), {"hit": true, "blocked": false, "damage": 1})


func test_in_a_fight_the_pulse_takes_one_hp_with_heavy_armour_and_a_shield() -> void:
	var data: GameData = TestFactory.real_data()
	var s: GameSession = autofree(TestFactory.session_no_kit(11, data))
	s.modifiers.set_source(SOURCE, [Modifier.make(&"armor", 5000.0), Modifier.make(&"barrier", 5000.0),
			Modifier.make(&"block_chance", 90.0)])
	var enemies: Array = [{"monster": "redrock_plains_stone_5", "hp": 450, "timer_ms": 3000}]
	s.combat.from_save({"state": "riftstone", "area": "redrock_plains", "player_hp": 50, "player_timer_ms": 999999,
		"hand": 0, "between_ms": 0, "loot": {}, "kills": {}, "deaths": 0, "food_eaten": 0, "enemies": enemies,
		"stone": {"since": 0, "pending": false, "stone_id": ""}})
	assert_eq(s.combat.state(), CombatEngine.STATE_RIFTSTONE)
	s.combat.advance(3000)
	assert_eq(s.combat.get_state()["player_hp"], 49)
	s.combat.advance(9000)
	assert_eq(s.combat.get_state()["player_hp"], 46, "one hp per pulse, every time")
