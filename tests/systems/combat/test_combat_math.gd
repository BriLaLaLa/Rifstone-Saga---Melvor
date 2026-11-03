extends GutTest
## CombatMath: every numeric example of F-20..F-27, F-73 and F-75 (docs/02_FORMULAS.md) on the real balance data.

var _d: GameData = null


func before_all() -> void:
	_d = GameData.load_from_dirs()


func test_data_valid() -> void:
	assert_true(_d.is_valid())


func test_f20_accuracy() -> void:
	assert_eq(CombatMath.accuracy_rating(1, 0, 0, _d), 450)
	assert_eq(CombatMath.accuracy_rating(10, 20, 0, _d), 1260)
	assert_eq(CombatMath.accuracy_rating(10, 20, 10, _d), 1386)
	assert_eq(CombatMath.accuracy_rating(50, 60, 0, _d), 6380)
	assert_eq(CombatMath.accuracy_rating(99, 150, 0, _d), 21400)
	assert_eq(CombatMath.accuracy_rating(10, 20, -10, _d), 1134)


func test_f21_evasion() -> void:
	assert_eq(CombatMath.evasion_rating(1, 0, 0, _d), 450)
	assert_eq(CombatMath.evasion_rating(16, 18, 0, _d), 1632)
	assert_eq(CombatMath.evasion_rating(24, 30, 0, _d), 2560)


func test_f22_max_and_min_hit() -> void:
	var cases: Array = [[1, 0, 0, 11, 1], [10, 20, 0, 30, 3], [50, 60, 0, 150, 15], [99, 150, 0, 517, 51],
		[10, 20, 10, 33, 3]]
	for c: Array in cases:
		var mx: int = CombatMath.max_hit(c[0], c[1], c[2], _d)
		assert_eq(mx, c[3], "max %s" % [c])
		assert_eq(CombatMath.min_hit(mx, _d), c[4], "min %s" % [c])


func test_f23_hit_chance() -> void:
	assert_almost_eq(CombatMath.hit_chance(450, 450, _d), 0.5, 0.0001)
	assert_almost_eq(CombatMath.hit_chance(1080, 450, _d), 0.7059, 0.0001)
	assert_almost_eq(CombatMath.hit_chance(450, 1800, _d), 0.20, 0.0001)
	assert_almost_eq(CombatMath.hit_chance(100, 10000, _d), 0.05, 0.0001)
	assert_almost_eq(CombatMath.hit_chance(10000, 100, _d), 0.95, 0.0001)
	assert_almost_eq(CombatMath.hit_chance(1000, 0, _d), 0.95, 0.0001)


func test_f24_triangle() -> void:
	assert_eq(CombatMath.triangle(&"blade", &"arcana", _d), CombatMath.ADVANTAGE)
	assert_eq(CombatMath.triangle(&"blade", &"marksmanship", _d), CombatMath.DISADVANTAGE)
	assert_eq(CombatMath.triangle(&"arcana", &"arcana", _d), CombatMath.NEUTRAL)
	assert_eq(CombatMath.triangle(&"arcana", &"marksmanship", _d), CombatMath.ADVANTAGE)
	assert_eq(CombatMath.triangle(&"marksmanship", &"blade", _d), CombatMath.ADVANTAGE)


func test_f24_triangle_damage() -> void:
	assert_eq(CombatMath.triangle_damage(20, CombatMath.ADVANTAGE, _d), 23)
	assert_eq(CombatMath.triangle_damage(20, CombatMath.DISADVANTAGE, _d), 17)
	assert_eq(CombatMath.triangle_damage(20, CombatMath.NEUTRAL, _d), 20)


func test_f25_damage_reduction() -> void:
	assert_eq(CombatMath.damage_after_dr(20, 25.0), 15)
	assert_eq(CombatMath.damage_after_dr(3, 80.0), 1)


func test_f25_with_triangle() -> void:
	var adv: int = CombatMath.triangle_damage(20, CombatMath.ADVANTAGE, _d)
	var dr_adv: float = CombatMath.effective_dr(10.0, CombatMath.ADVANTAGE, _d)
	assert_almost_eq(dr_adv, 7.5, 0.0001)
	assert_eq(CombatMath.damage_after_dr(adv, dr_adv), 21)
	var dis: int = CombatMath.triangle_damage(20, CombatMath.DISADVANTAGE, _d)
	var dr_dis: float = CombatMath.effective_dr(10.0, CombatMath.DISADVANTAGE, _d)
	assert_almost_eq(dr_dis, 10.0, 0.0001)
	assert_eq(CombatMath.damage_after_dr(dis, dr_dis), 15)


func test_f26_attack_interval() -> void:
	assert_eq(CombatMath.attack_interval_ms(2400, -10.0, _d), 2160)
	assert_eq(CombatMath.attack_interval_ms(1000, -50.0, _d), 800)
	assert_eq(CombatMath.attack_interval_ms(1800, -10.0, _d), 1620)


func test_f27_max_hp() -> void:
	assert_eq(CombatMath.max_hp(1, 0.0, _d), 60)
	assert_eq(CombatMath.max_hp(10, 20.0, _d), 170)
	assert_eq(CombatMath.max_hp(99, 0.0, _d), 1040)


func test_dual_wield_interval() -> void:
	assert_eq(CombatMath.dual_wield_base_ms(2400, 2400, _d), 1800)
	assert_eq(CombatMath.dual_wield_base_ms(2400, 2000, _d), 1650)
	assert_eq(CombatMath.attack_interval_ms(1650, -10.0, _d), 1485)


func test_f70_base_values() -> void:
	assert_eq(CombatMath.accuracy_rating(10, 0, 0, _d), 900)
	assert_eq(CombatMath.evasion_rating(10, 0, 0, _d), 900)
	assert_eq(CombatMath.max_hit(10, 0, 0, _d), 20)
	assert_eq(CombatMath.min_hit(20, _d), 2)
	assert_eq(CombatMath.max_hp(10, 0.0, _d), 150)
	assert_eq(CombatMath.accuracy_rating(50, 0, 0, _d), 2900)
	assert_eq(CombatMath.max_hit(50, 0, 0, _d), 60)
	assert_eq(CombatMath.min_hit(60, _d), 6)
	assert_eq(CombatMath.max_hp(50, 0.0, _d), 550)


func test_f75_block_chance_clamp() -> void:
	assert_almost_eq(CombatMath.block_chance(5.0, _d), 5.0, 0.0001)
	assert_almost_eq(CombatMath.block_chance(9.0, _d), 9.0, 0.0001)
	assert_almost_eq(CombatMath.block_chance(15.0, _d), 15.0, 0.0001)
	assert_almost_eq(CombatMath.block_chance(55.0, _d), 50.0, 0.0001)
	assert_almost_eq(CombatMath.block_chance(-3.0, _d), 0.0, 0.0001)
