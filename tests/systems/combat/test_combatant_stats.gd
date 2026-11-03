extends GutTest
## CombatantStats: F-70 (player base values), F-74 (stats of the striking hand) and monsters (D5).

const BLADE: StringName = &"test_blade"
const SHIELD: StringName = &"test_shield"

var _session: GameSession = null


func before_each() -> void:
	_session = autofree(TestFactory.session())


func _mods(source: StringName, list: Array[Modifier]) -> void:
	_session.modifiers.set_source(source, list)


func test_player_base_from_character_level() -> void:
	var s: CombatantStats = CombatantStats.for_player(_session)
	assert_eq([s.accuracy, s.evasion, s.max_hit, s.min_hit, s.max_hp], [450, 450, 11, 1, 60], "level 1")
	assert_eq(s.attack_interval_ms, 2400, "bare hands")
	assert_eq(s.style, &"blade")
	assert_eq(s.block_chance, 0.0)
	TestFactory.set_character_level(_session, 10)
	s = CombatantStats.for_player(_session)
	assert_eq([s.accuracy, s.evasion, s.max_hit, s.min_hit, s.max_hp], [900, 900, 20, 2, 150], "level 10")
	TestFactory.set_character_level(_session, 50)
	s = CombatantStats.for_player(_session)
	assert_eq([s.accuracy, s.max_hit, s.min_hit, s.max_hp], [2900, 60, 6, 550], "level 50")


func test_stats_follow_the_modifiers_without_a_saved_copy() -> void:
	var before: CombatantStats = CombatantStats.for_player(_session)
	_mods(&"test:ring", [Modifier.make(&"max_hp_flat", 20.0), Modifier.make(&"damage_reduction", 10.0)])
	var after: CombatantStats = CombatantStats.for_player(_session)
	assert_eq(after.max_hp, before.max_hp + 20)
	assert_eq(after.damage_reduction, 10.0)


func test_weapon_interval_and_pct() -> void:
	_session.equipment.equip(TestFactory.give_piece(_session, BLADE))
	_mods(&"test:ring", [Modifier.make(&"attack_interval_pct", -10.0)])
	assert_eq(CombatantStats.for_player(_session).attack_interval_ms, 2160)


func test_dual_wield_hand_stats() -> void:
	_session.equipment.equip(TestFactory.give_piece(_session, BLADE))
	_session.equipment.equip(TestFactory.give_piece(_session, BLADE), &"offhand")
	assert_eq(_session.equipment.setup(), &"dual_swords")
	# F-74 example: T3 sword in the main hand, T1 sword in the offhand, ring accuracy +5.
	_mods(&"equipment:weapon", [Modifier.make(&"accuracy_bonus", 24.0), Modifier.make(&"power_bonus", 18.0)])
	_mods(&"equipment:offhand", [Modifier.make(&"accuracy_bonus", 8.0), Modifier.make(&"power_bonus", 6.0)])
	_mods(&"test:ring", [Modifier.make(&"accuracy_bonus", 5.0)])
	# The exact numbers of the F-74 example: main hand acc 29, pot 18; offhand acc 13, pot 6.
	var without_off: Array[StringName] = [&"equipment:offhand"]
	var without_main: Array[StringName] = [&"equipment:weapon"]
	assert_eq(_session.modifiers.total_without(&"accuracy_bonus", null, without_off), 29.0)
	assert_eq(_session.modifiers.total_without(&"power_bonus", null, without_off), 18.0)
	assert_eq(_session.modifiers.total_without(&"accuracy_bonus", null, without_main), 13.0)
	assert_eq(_session.modifiers.total_without(&"power_bonus", null, without_main), 6.0)
	var main: CombatantStats = CombatantStats.for_player(_session, 0)
	var off: CombatantStats = CombatantStats.for_player(_session, 1)
	# accuracy bonus 29 / 13, power bonus 18 / 6 at level 1 (F-20, F-22); the dual_swords setup adds accuracy_pct -10
	assert_eq(main.accuracy, CombatMath.accuracy_rating(1, 29, -10, _session.data))
	assert_eq(main.max_hit, CombatMath.max_hit(1, 18, 0, _session.data))
	assert_eq(off.accuracy, CombatMath.accuracy_rating(1, 13, -10, _session.data))
	assert_eq(off.max_hit, CombatMath.max_hit(1, 6, 0, _session.data))
	assert_eq([main.accuracy, main.max_hit, off.accuracy, off.max_hit], [639, 15, 510, 12])
	assert_eq(main.attack_interval_ms, 1800, "F-73: both hands share the interval")
	assert_eq(off.attack_interval_ms, 1800)


func test_single_weapon_ignores_hand() -> void:
	_session.equipment.equip(TestFactory.give_piece(_session, BLADE))
	var main: CombatantStats = CombatantStats.for_player(_session, 0)
	var off: CombatantStats = CombatantStats.for_player(_session, 1)
	assert_eq([off.accuracy, off.max_hit], [main.accuracy, main.max_hit])


func test_block_chance_only_with_a_shield() -> void:
	_mods(&"test:ring", [Modifier.make(&"block_chance", 40.0)])
	assert_eq(CombatantStats.for_player(_session).block_chance, 0.0, "no shield, no roll")
	_session.equipment.equip(TestFactory.give_piece(_session, BLADE))
	_session.equipment.equip(TestFactory.give_piece(_session, SHIELD))
	assert_eq(CombatantStats.for_player(_session).block_chance, 40.0)
	_mods(&"test:ring", [Modifier.make(&"block_chance", 90.0)])
	assert_eq(CombatantStats.for_player(_session).block_chance, 50.0, "limited by stats.json")


func test_monster_stats() -> void:
	var data: GameData = TestFactory.real_data()
	var boar: CombatantStats = CombatantStats.for_monster(data.monster(&"plains_boar"), data)
	assert_eq([boar.accuracy, boar.evasion, boar.max_hit, boar.min_hit], [450, 450, 11, 1])
	assert_eq([boar.max_hp, boar.attack_interval_ms, boar.style, boar.block_chance], [20, 2800, &"blade", 0.0])
	var raider: CombatantStats = CombatantStats.for_monster(data.monster(&"redrock_raider"), data)
	assert_eq(raider.damage_reduction, 2.0)
	assert_eq(raider.style, &"marksmanship")
