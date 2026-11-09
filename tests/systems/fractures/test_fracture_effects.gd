extends GutTest
## F-111: one test per risk and reward type, with the examples of docs/02_FORMULAS.md. Fixtures with three groups; the
## modifiers of the Card are `sturdy`, `assault`, `famine`, `brutal`, `hordes`, `pulses`, `shrouded`, ... of the fixtures.

var _s: GameSession = null
var _none: Array[Dictionary] = []


func before_each() -> void:
	_s = autofree(FractureUtil.session(21))


func _effects(mods: Array, grade: int = 6) -> Array[Dictionary]:
	var card := MapCard.new()
	card.base_id = StringName("fracture_card_%d" % grade)
	card.grade = grade
	for pair: Array in mods:
		card.mods.append(MapModRoll.make(StringName(pair[0]), int(pair[1])))
	return MapCardRoller.effects(card, _s.data)


func _monster(id: StringName, grade: int, effects: Array[Dictionary]) -> ScaledMonsterDef:
	return FractureScaler.scale_monster(_s.data.monster(id), grade, effects, _s.data) as ScaledMonsterDef


func _run(mods: Array, grade: int = 1) -> FractureRun:
	var card := MapCard.new()
	card.base_id = StringName("fracture_card_%d" % grade)
	card.grade = grade
	for pair: Array in mods:
		card.mods.append(MapModRoll.make(StringName(pair[0]), int(pair[1])))
	return FractureRun.create(card, &"", _s.data)


# --- risks --------------------------------------------------------------------------------------------------------

func test_monster_hp_pct_is_applied_after_f110_with_round() -> void:
	# sturdy: risk 20-60, step 5 -> +40: the hp of F-110 (round) times 1.40 (round), real data golem at grade 3
	var real: GameData = TestFactory.real_data()
	var effects: Array[Dictionary] = _effects([["sturdy", 5]])
	assert_eq(FractureScaler.total(effects, &"monster_hp_pct"), 40.0)
	var golem: ScaledMonsterDef = FractureScaler.scale_monster(real.monster(&"crack_golem"), 3, effects, real) as ScaledMonsterDef
	var grade_hp: int = int(round(float(real.monster(&"crack_golem").hp) * real.fracture_grade(3).hp_mult))
	assert_eq(golem.hp, int(round(float(grade_hp) * 1.4)))


func test_monster_damage_pct_floors_with_a_minimum_of_one() -> void:
	var effects: Array[Dictionary] = _effects([["brutal", 5]])  # 15-45 -> +30
	assert_eq(FractureScaler.total(effects, &"monster_damage_pct"), 30.0)
	var base: CombatantStats = CombatantStats.for_monster(_monster(&"test_monster_b", 1, _none), _s.data)
	var hurt: CombatantStats = CombatantStats.for_monster(_monster(&"test_monster_b", 1, effects), _s.data)
	assert_eq(hurt.max_hit, maxi(1, floori(base.max_hit * 1.3 + 1e-9)))
	assert_eq(hurt.min_hit, maxi(1, floori(base.min_hit * 1.3 + 1e-9)))


func test_monster_speed_pct_uses_f26_with_a_negative_pct() -> void:
	# assault: 10-35, step 4 -> 10 + round(25 x 0.4) = 20: 2800 ms -> 2240 ms
	var effects: Array[Dictionary] = _effects([["assault", 4]])
	assert_eq(FractureScaler.total(effects, &"monster_speed_pct"), 20.0)
	assert_eq(CombatantStats.for_monster(_monster(&"test_monster_a", 1, effects), _s.data).attack_interval_ms, 2240)
	var fast: Array[Dictionary] = _effects([["frenzy", 10]])  # 60: 2800 x 0.4 = 1120, above the minimum
	assert_eq(CombatantStats.for_monster(_monster(&"test_monster_a", 1, fast), _s.data).attack_interval_ms,
		CombatMath.attack_interval_ms(2800, -60.0, _s.data))


func test_monster_defence_pct_multiplies_the_evasion_with_round() -> void:
	var effects: Array[Dictionary] = _effects([["shrouded", 5]])  # 20-60 -> +40
	var base: CombatantStats = CombatantStats.for_monster(_monster(&"test_monster_b", 1, _none), _s.data)
	var hard: CombatantStats = CombatantStats.for_monster(_monster(&"test_monster_b", 1, effects), _s.data)
	assert_eq(hard.evasion, int(round(base.evasion * 1.4)))


func test_pack_bonus_adds_monsters_repeating_the_pack_in_order() -> void:
	var run: FractureRun = _run([["hordes", 0]], 2)  # step 0 -> +1
	var seen_sizes: Dictionary = {}
	for _i: int in 30:
		var pack: Array[MonsterDef] = run.next_pack(_s.rng, _s.data)
		seen_sizes[pack.size()] = true
		if pack.size() == 3:  # the pack [a, b] widened by one: a, b, a
			assert_eq([pack[0].id, pack[1].id, pack[2].id], [&"test_monster_a", &"test_monster_b", &"test_monster_a"])
		else:
			assert_eq(pack.size(), 2, "the pack [a] widened by one: a, a")
	assert_true(seen_sizes.has(2) and seen_sizes.has(3))


func test_food_heal_pct_cuts_the_heal_of_the_food() -> void:
	# a food worth 100 with Fame +40 heals 60 (the fixture ration heals 20: +400% food healing gives 100)
	_s.modifiers.set_source(&"test:food", [Modifier.make(&"food_healing_pct", 400.0), Modifier.make(&"max_hp_flat", 1000.0)])
	TestFactory.give(_s, &"test_ration", 10)
	_s.equipment.set_food(&"test_ration")
	var healed: Array[int] = []
	_s.events.food_eaten.connect(func(_i: StringName, h: int) -> void: healed.append(h))
	var max_hp: int = _s.combat.player_stats().max_hp
	AutoEat.eat_one(_s, 1, max_hp)
	assert_eq(healed, [100] as Array[int])
	assert_true(_s.fractures.open(FractureUtil.card(_s, 1, [["famine", 5]])).ok)  # 20-60 -> +40
	AutoEat.eat_one(_s, 1, max_hp)
	assert_eq(healed, [100, 60] as Array[int])


func test_pulse_hits_every_pulse_ms_during_an_encounter() -> void:
	# pulses: 2-5, step 6 -> 2 + round(3 x 0.6) = 4 (% of the maximum hp, before F-25)
	_s.modifiers.set_source(FractureUtil.SOURCE, [Modifier.make(&"power_bonus", -1000.0), Modifier.make(&"max_hp_flat", 100000.0)])
	var hits: Array = []
	_s.events.combat_hit.connect(func(a: int, t: int, hit: bool, d: int, b: bool) -> void:
		if a == FractureCombat.PULSE_SOURCE:
			hits.append([t, hit, d, b, _s.combat.get_state()["fracture"]["group"]]))
	assert_true(_s.fractures.open(FractureUtil.card(_s, 1, [["pulses", 6]])).ok)
	var stats: CombatantStats = _s.combat.player_stats()
	var expected: int = CombatMath.damage_after_dr(maxi(1, floori(stats.max_hp * 4.0 / 100.0)), stats.damage_reduction)
	_s.advance(3999)
	assert_eq(hits.size(), 0)
	_s.advance(1)
	assert_eq(hits.size(), 1, "the first pulse after fracture.pulse_ms (4000)")
	assert_eq(hits[0], [CombatEngine.PLAYER, true, expected, false, 1])
	_s.advance(8000)
	assert_eq(hits.size(), 3)


func test_pulse_timer_does_not_run_between_groups() -> void:
	FractureUtil.hero(_s)
	assert_true(_s.fractures.open(FractureUtil.card(_s, 1, [["pulses", 6]])).ok)
	assert_eq((_s.combat.to_save()["fracture"] as Dictionary)["pulse_ms"], 4000)
	FractureUtil.run_until(_s, func() -> bool: return _s.combat.state() == CombatEngine.STATE_BETWEEN)
	var at_clear: int = (_s.combat.to_save()["fracture"] as Dictionary)["pulse_ms"]
	_s.advance(int(_s.combat.get_state()["between_ms"]) - 1)
	assert_eq(_s.combat.state(), CombatEngine.STATE_BETWEEN)
	assert_eq((_s.combat.to_save()["fracture"] as Dictionary)["pulse_ms"], at_clear, "BETWEEN does not tick the pulse")


# --- rewards ------------------------------------------------------------------------------------------------------

func test_loot_qty_pct_never_goes_below_the_rolled_quantity() -> void:
	var run: FractureRun = _run([["sturdy", 5]])  # reward 5-15, step 5 -> +10
	var sink := FractureSink.new(_s, run)
	var item: ItemDef = _s.data.item(&"test_log")
	assert_eq(sink.drop_qty(item, 10), 11)
	assert_eq(sink.drop_qty(item, 1), 1, "round(1.1) = 1")
	assert_eq(sink.drop_qty(item, 5), 6, "round(5.5) = 6")
	assert_eq(FractureSink.new(_s, _run([])).drop_qty(item, 7), 7, "no reward: unchanged")


func test_dust_pct_multiplies_only_the_rift_dust() -> void:
	var run: FractureRun = _run([["pulses", 10]])  # reward dust_pct 20-60 -> 60
	var sink := FractureSink.new(_s, run)
	assert_eq(sink.drop_qty(_s.data.item(&"rift_dust"), 5), 8, "round(5 x 1.6)")
	assert_eq(sink.drop_qty(_s.data.item(&"test_log"), 5), 5)


func test_blueprint_pct_raises_the_chance_up_to_100() -> void:
	var real: GameData = TestFactory.real_data()
	var blueprint: ItemDef = real.item(&"bp_mw_sword_5")
	var sink := FractureSink.new(_s, _run([["famine", 5]]))  # reward blueprint 25-75, step 5 -> 50
	assert_eq(sink.drop_chance(blueprint, 0.12), 0.12 * 1.5)
	assert_eq(sink.drop_chance(blueprint, 90.0), 100.0)
	assert_eq(sink.drop_chance(_s.data.item(&"test_log"), 10.0), 10.0, "only blueprints")


func test_stat_rewards_are_a_modifier_source_only_while_the_fracture_runs() -> void:
	var rarity: float = _s.modifiers.total(&"item_rarity_pct")
	var gold: float = _s.modifiers.total(&"gold_drop_pct")
	var xp: float = _s.modifiers.total(&"skill_xp_pct")
	var uid: int = FractureUtil.card(_s, 3, [["assault", 10], ["hordes", 10]])  # rarity 35, xp 30
	assert_true(_s.fractures.open(uid).ok)
	assert_true(_s.modifiers.has_source(StringName("fracture:%d" % uid)))
	assert_eq(_s.modifiers.total(&"item_rarity_pct"), rarity + 35.0)
	assert_eq(_s.modifiers.total(&"skill_xp_pct"), xp + 30.0)
	assert_eq(_s.modifiers.total(&"gold_drop_pct"), gold)
	_s.fractures.abandon()
	assert_false(_s.modifiers.has_source(StringName("fracture:%d" % uid)))
	assert_eq(_s.modifiers.total(&"item_rarity_pct"), rarity)
	assert_eq(_s.modifiers.total(&"skill_xp_pct"), xp)


func test_gold_drop_pct_reward_changes_the_gold_of_a_kill() -> void:
	FractureUtil.hero(_s)
	assert_true(_s.fractures.open(FractureUtil.card(_s, 1, [["brutal", 10]])).ok)  # gold 20-60 -> 60%
	assert_eq(_s.modifiers.total(&"gold_drop_pct"), 60.0)
