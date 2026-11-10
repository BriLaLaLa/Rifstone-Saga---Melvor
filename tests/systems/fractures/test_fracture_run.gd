extends GutTest
## FractureRun (F-50): the pack of each group (F-77 on the packs of the areas of the grade, scaled with F-110 / F-111), the
## counters, the boss of the grade and the save form.

var _s: GameSession = null


func before_each() -> void:
	_s = autofree(FractureUtil.session(4))


func _run(grade: int = 1, mods: Array = []) -> FractureRun:
	var card := MapCard.new()
	card.base_id = StringName("fracture_card_%d" % grade)
	card.grade = grade
	for pair: Array in mods:
		card.mods.append(MapModRoll.make(StringName(pair[0]), int(pair[1])))
	return FractureRun.create(card, &"test_area", _s.data)


func test_create_reads_the_total_from_the_balance() -> void:
	var run: FractureRun = _run(2)
	assert_eq(run.groups_total, 3)
	assert_eq(run.grade, 2)
	assert_eq(run.group, 0)
	assert_eq(run.groups_cleared, 0)
	assert_false(run.boss_started)
	assert_eq(run.return_area, &"test_area")
	assert_true(run.bag.is_empty())
	var real_total: int = int(TestFactory.fixture_data().balance_value("fracture.groups"))
	assert_eq(real_total, 16, "the shared balance has 16 groups")


func test_next_pack_counts_the_groups_and_draws_with_pick_weighted() -> void:
	var run: FractureRun = _run(1)
	var shadow := RngService.new(4)
	var ids: Array = []
	for i: int in 3:
		var pack: Array[MonsterDef] = run.next_pack(_s.rng, _s.data)
		assert_eq(run.group, i + 1)
		var weights: Array[int] = [3, 1]  # cracked_mines of the fixtures: [a] weight 3, [a, b] weight 1
		ids.append(shadow.pick_weighted(weights))
		assert_eq(pack.size(), 1 if ids[i] == 0 else 2)


func test_the_pack_is_scaled_by_the_grade_row() -> void:
	var row: FractureGradeDef = _s.data.fracture_grade(3)  # level_bonus 8, hp and reward from the row
	var run: FractureRun = _run(3)
	var pack: Array[MonsterDef] = run.next_pack(_s.rng, _s.data)
	var first: ScaledMonsterDef = pack[0] as ScaledMonsterDef
	assert_eq(first.id, &"test_monster_a")
	assert_eq(first.attack_level, 9)
	assert_eq(first.hp, int(round(20.0 * row.hp_mult)), "round(20 x hp_mult)")
	assert_eq(first.xp, int(round(80.0 * row.reward_mult)))
	assert_false(first.is_boss)


func test_the_grade_picks_its_area() -> void:
	var run: FractureRun = _run(4)  # rift_threshold: only [test_monster_b]
	for _i: int in 3:
		var pack: Array[MonsterDef] = run.next_pack(_s.rng, _s.data)
		assert_eq(pack.size(), 1)
		assert_eq(pack[0].id, &"test_monster_b")


func test_the_boss_is_the_one_of_the_grade() -> void:
	assert_eq(_run(1).boss_def(_s.data).id, &"boss_grade_1")
	assert_eq(_run(3).boss_def(_s.data).id, &"boss_grade_3")


func test_the_effects_come_from_the_card() -> void:
	var run: FractureRun = _run(1, [["sturdy", 5]])
	assert_eq(run.effects.size(), 1)
	assert_eq(run.effects[0]["risk_type"], &"monster_hp_pct")
	assert_eq(run.effects[0]["risk"], 40.0)


func test_save_round_trip() -> void:
	var run: FractureRun = _run(2, [["sturdy", 5], ["assault", 2]])
	run.group = 2
	run.groups_cleared = 1
	run.bag.add_stack(&"test_log", 5)
	var loaded: FractureRun = FractureRun.from_save(run.to_save(), _s.data)
	assert_not_null(loaded)
	assert_eq(loaded.to_save(), run.to_save())
	assert_eq(loaded.effects, run.effects)
	assert_eq(loaded.return_area, &"test_area")
	assert_false(loaded.boss_started)


func test_save_rejections() -> void:
	var good: Dictionary = _run(1).to_save()
	var bad_card: Dictionary = good.duplicate(true)
	bad_card["card"]["base"] = "nope"
	assert_null(FractureRun.from_save(bad_card, _s.data))
	var bad_mod: Dictionary = good.duplicate(true)
	bad_mod["card"]["mods"] = [{"mod": "no_such_mod", "step": 1}]
	assert_null(FractureRun.from_save(bad_mod, _s.data))
	var bad_group: Dictionary = good.duplicate(true)
	bad_group["group"] = 4
	assert_null(FractureRun.from_save(bad_group, _s.data))
	var bad_cleared: Dictionary = good.duplicate(true)
	bad_cleared["group"] = 1
	bad_cleared["groups_cleared"] = 2
	assert_null(FractureRun.from_save(bad_cleared, _s.data))
	var unknown_area: Dictionary = good.duplicate(true)
	unknown_area["return_area"] = "nowhere"
	assert_eq(FractureRun.from_save(unknown_area, _s.data).return_area, &"", "an unknown area is dropped, the run stays")
