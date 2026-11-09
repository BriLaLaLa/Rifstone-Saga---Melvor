extends GutTest
## WeaponMath and the weapon part of CombatantStats (F-22, F-118 weapons; docs/02_FORMULAS.md §5, §8.4).

var _d: GameData = null
var _session: GameSession = null


func before_all() -> void:
	_d = TestFactory.fixture_data()


func before_each() -> void:
	_session = autofree(TestFactory.session())


func _inst(base_id: StringName, rarity: StringName = &"common", upgrade: int = 0) -> ItemInstance:
	var inst := ItemInstance.new()
	inst.base_id = base_id
	inst.rarity = rarity
	inst.upgrade = upgrade
	return inst


func test_damage_range_of_the_model() -> void:
	assert_eq(WeaponMath.damage_range(_inst(&"test_sword_g1"), _d), Vector2(4, 6))
	assert_eq(WeaponMath.damage_range(_inst(&"test_sword_g8"), _d), Vector2(20, 34))
	assert_eq(WeaponMath.damage_range(_inst(&"test_sword_g15"), _d), Vector2(37, 62))
	assert_eq(WeaponMath.damage_range(_inst(&"test_greatsword_g15"), _d), Vector2(62, 124))


func test_damage_range_follows_the_refinement_without_rounding() -> void:
	var per_level: float = float(_d.balance_value("upgrade.mod_pct_per_level"))
	var factor: float = 1.0 + per_level * 5.0 / 100.0
	var span: Vector2 = WeaponMath.damage_range(_inst(&"test_sword_g8", &"common", 5), _d)
	assert_almost_eq(span.x, 20.0 * factor, 0.0001)
	assert_almost_eq(span.y, 34.0 * factor, 0.0001)


func test_not_a_weapon_has_no_damage() -> void:
	assert_eq(WeaponMath.damage_range(_inst(&"test_helm"), _d), Vector2.ZERO)
	assert_eq(WeaponMath.damage_range(null, _d), Vector2.ZERO)
	assert_eq(WeaponMath.dps(_inst(&"test_helm"), 0.0, _d), 0.0)


func test_weapon_dps() -> void:
	assert_almost_eq(WeaponMath.dps(_inst(&"test_sword_g1"), 0.0, _d), 2.5, 0.0001)
	assert_almost_eq(WeaponMath.dps(_inst(&"test_greatsword_g1"), 0.0, _d), 2.8125, 0.0001)
	assert_almost_eq(WeaponMath.dps(_inst(&"test_sword_g15"), 0.0, _d), 24.75, 0.0001)
	assert_almost_eq(WeaponMath.dps(_inst(&"test_greatsword_g15"), 0.0, _d), 29.0625, 0.0001)
	# F-26 over the total attack_interval_pct: 2000 ms -10% = 1800 ms -> 49.5 / 1.8
	assert_almost_eq(WeaponMath.dps(_inst(&"test_sword_g15"), -10.0, _d), 27.5, 0.0001)


func test_player_hits_with_the_worn_weapon() -> void:
	_session.equipment.equip(TestFactory.give_piece(_session, &"test_sword_g1"))
	var s: CombatantStats = CombatantStats.for_player(_session)
	assert_eq([s.max_hit, s.min_hit], [12, 8], "F-22: spada grado 1 a livello 1")
	assert_eq([s.weapon_min, s.weapon_max], [4.0, 6.0])


func test_player_example_grade_15_sword_at_level_90() -> void:
	TestFactory.set_character_level(_session, 90)
	_session.equipment.equip(TestFactory.give_piece(_session, &"test_sword_g15"))
	var s: CombatantStats = CombatantStats.for_player(_session)
	assert_eq([s.max_hit, s.min_hit], [255, 152])


func test_player_example_greatsword_grade_8_at_level_50() -> void:
	TestFactory.set_character_level(_session, 50)
	_session.equipment.equip(TestFactory.give_piece(_session, &"test_greatsword_g8"))
	var s: CombatantStats = CombatantStats.for_player(_session)
	assert_eq([s.max_hit, s.min_hit], [162, 81])


func test_power_bonus_and_pct_add_to_the_weapon() -> void:
	TestFactory.set_character_level(_session, 50)
	_session.equipment.equip(TestFactory.give_piece(_session, &"test_sword_g8"))
	_session.modifiers.set_source(&"test:affix", [Modifier.make(&"power_bonus", 10.0), Modifier.make(&"power_pct", 10.0)])
	assert_eq(CombatantStats.for_player(_session).max_hit, 138, "F-22: floor(60 x 84/40 x 1.1)")


func test_bare_hands_use_min_hit_ratio() -> void:
	var s: CombatantStats = CombatantStats.for_player(_session)
	assert_eq([s.max_hit, s.min_hit, s.weapon_max], [11, 1, 0.0])
	TestFactory.set_character_level(_session, 50)
	s = CombatantStats.for_player(_session)
	assert_eq([s.max_hit, s.min_hit], [60, 6], "min_hit_ratio 0.1")


func test_monsters_keep_their_numbers() -> void:
	var data: GameData = TestFactory.real_data()
	var boar: CombatantStats = CombatantStats.for_monster(data.monster(&"plains_boar"), data)
	assert_eq([boar.max_hit, boar.min_hit, boar.weapon_max], [11, 1, 0.0])



func test_advance_one_step_equals_ten_steps_with_a_weapon() -> void:
	var saves: Array = []
	for step: int in [1000, 100]:
		var s: GameSession = autofree(TestFactory.session(777))
		s.equipment.equip(TestFactory.give_piece(s, &"test_sword_g1"))
		assert_true(s.combat.start(&"test_area").ok)
		for i: int in 40:
			for j: int in 1000 / step:
				s.combat.advance(step)
		saves.append(s.combat.to_save())
	assert_eq(saves[0], saves[1], "advance(1000) = 10 x advance(100)")
