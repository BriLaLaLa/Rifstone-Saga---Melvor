extends GutTest
## F-25 with the Armour and Barrier of the player (F-117): the defender uses the stat that matches the style of the
## attacker, the monster defender keeps its flat `damage_reduction`.

var _d: GameData = null
var _rng: RngService = null


func before_all() -> void:
	_d = TestFactory.real_data()


func before_each() -> void:
	_rng = RngService.new(5)


func _monster(style: StringName, level: int, hit: int) -> CombatantStats:
	var s := CombatantStats.new()
	s.style = style
	s.level = level
	s.accuracy = 10000000
	s.min_hit = hit
	s.max_hit = hit
	return s


func _player(armor: int, barrier: int, style: StringName = &"blade") -> CombatantStats:
	var s := CombatantStats.new()
	s.is_player = true
	s.style = style
	s.level = 10
	s.evasion = 1
	s.armor = armor
	s.barrier = barrier
	return s


func test_physical_hit_uses_armor_example() -> void:
	# F-25: roll 40, monster `blade` level 20, Armour 100 (35.71%), neutral -> floor(40 x 0.6429) = 25
	var r: Dictionary = Encounter.roll_attack(_monster(&"blade", 20, 40), _player(100, 0), 0.0, _rng, _d)
	assert_true(r["hit"])
	assert_eq(r["damage"], 25)


func test_disadvantage_multiplies_the_reduction_by_075() -> void:
	var dr: float = ArmorMath.reduction_pct(100, 20, _d)
	var eff: float = CombatMath.effective_dr(dr, CombatMath.ADVANTAGE, _d)
	assert_almost_eq(eff, 26.7857, 0.0001)
	assert_eq(CombatMath.damage_after_dr(40, eff), 29, "F-25: floor(40 x 0.7321)")
	# in the fight the same relation also raises the damage (F-24): floor(40 x 1.15) = 46 -> floor(46 x 0.7321) = 33
	var r: Dictionary = Encounter.roll_attack(_monster(&"marksmanship", 20, 40), _player(100, 0), 0.0, _rng, _d)
	assert_eq(r["damage"], 33)


func test_arcane_hit_uses_barrier_not_armor() -> void:
	# roll 40, monster `arcana` level 30, Barrier 121 and Armour 500 (Armour does not count): 33.52% -> 26. The player
	# defends as `arcana` here so that the triangle stays neutral.
	var r: Dictionary = Encounter.roll_attack(_monster(&"arcana", 30, 40), _player(500, 121, &"arcana"), 0.0, _rng, _d)
	assert_eq(r["damage"], 26)


func test_armor_does_not_help_against_arcane_and_barrier_not_against_physical() -> void:
	var only_armor: CombatantStats = _player(500, 0, &"arcana")
	assert_eq(only_armor.reduction_against(&"arcana", 30, _d), 0.0)
	assert_gt(only_armor.reduction_against(&"blade", 30, _d), 0.0)
	var only_barrier: CombatantStats = _player(0, 500, &"arcana")
	assert_eq(only_barrier.reduction_against(&"blade", 30, _d), 0.0)
	assert_gt(only_barrier.reduction_against(&"arcana", 30, _d), 0.0)
	assert_gt(only_armor.reduction_against(&"marksmanship", 30, _d), 0.0, "marksmanship is physical")


func test_cap_is_75_percent() -> void:
	assert_eq(_player(100000, 0).reduction_against(&"blade", 1, _d), 75.0)


func test_monster_defender_keeps_the_flat_percentage() -> void:
	var defender := CombatantStats.new()
	defender.damage_reduction = 25.0
	defender.evasion = 1
	var r: Dictionary = Encounter.roll_attack(_monster(&"blade", 20, 20), defender, 0.0, _rng, _d)
	assert_eq(r["damage"], 15, "F-25: monster DR 25 on 20 -> 15")


func test_pulse_counts_as_armor_with_the_given_level() -> void:
	var me: CombatantStats = _player(100, 5000)
	var r: Dictionary = Encounter.roll_pulse(40, me, 0.0, _rng, _d, 20)
	assert_eq(r["damage"], 25, "no style: Armour (the Barrier does not count)")
	var default_level: Dictionary = Encounter.roll_pulse(40, me, 0.0, _rng, _d)
	assert_eq(default_level["damage"], CombatMath.damage_after_dr(40, ArmorMath.reduction_pct(100, 10, _d)),
			"default level = the defender level")


func test_parry_block_is_unchanged() -> void:
	var r: Dictionary = Encounter.roll_attack(_monster(&"blade", 20, 40), _player(100, 0), 100.0, _rng, _d)
	assert_eq([r["hit"], r["blocked"], r["damage"]], [true, true, 0], "F-75: a block does no damage")


func test_player_stats_come_from_the_modifiers() -> void:
	var s: GameSession = autofree(TestFactory.session())
	s.modifiers.set_source(&"test:armor", [Modifier.make(&"armor", 100.0), Modifier.make(&"barrier", 7.0)])
	var stats: CombatantStats = CombatantStats.for_player(s)
	assert_eq([stats.armor, stats.barrier, stats.is_player], [100, 7, true])
	s.modifiers.set_source(&"test:armor", [Modifier.make(&"armor", 900000.0)])
	assert_eq(CombatantStats.for_player(s).armor, 100000, "limited by stats.json")


func test_worn_armour_feeds_the_stat() -> void:
	var s: GameSession = autofree(TestFactory.session())
	s.equipment.equip(TestFactory.give_piece(s, &"test_plate_body_11"))
	assert_eq(CombatantStats.for_player(s).armor, 121)
