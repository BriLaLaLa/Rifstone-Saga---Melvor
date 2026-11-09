extends GutTest
## Save and resume in the middle of a Fracture (docs/05_INTERFACES.md §5.23, §6): through JSON text, at several points
## (a group, BETWEEN, the boss), the loaded game continues exactly as the saved one; the keys are additive (`format_version` 4).

const SEED: int = 91


func _session() -> GameSession:
	var s: GameSession = autofree(FractureUtil.session(SEED))
	TestFactory.set_character_level(s, 90)  # strong through saved state (a test modifier would not survive the load)
	s.combat.start(&"test_area")
	assert_true(s.fractures.open(FractureUtil.card(s, 1, [["hordes", 1], ["pulses", 5]])).ok)
	return s


func _roundtrip(s: GameSession) -> GameSession:
	var text: String = JSON.stringify(s.to_save(1234))
	var parsed: Variant = JSON.parse_string(text)
	assert_true(parsed is Dictionary)
	var loaded: GameSession = autofree(FractureUtil.session(999))
	assert_true(loaded.from_save(parsed as Dictionary).ok)
	return loaded


func _same_state(a: GameSession, b: GameSession) -> void:
	assert_eq(a.combat.to_save(), b.combat.to_save())
	assert_eq(a.fractures.to_save(), b.fractures.to_save())
	assert_eq(a.combat.get_state(), b.combat.get_state())
	assert_eq(a.bank.to_save(), b.bank.to_save())
	assert_eq(a.rng.to_save(), b.rng.to_save())


func _check_from(a: GameSession) -> void:
	var b: GameSession = _roundtrip(a)
	_same_state(a, b)
	assert_true(b.combat.in_fracture())
	for _i: int in 200:
		a.advance(250)
		b.advance(250)
		if not a.combat.in_fracture():
			break
	_same_state(a, b)


func test_the_save_has_the_fracture_keys() -> void:
	var s: GameSession = _session()
	s.advance(2000)
	var saved: Dictionary = s.to_save(1)
	assert_eq(saved["format_version"], SaveMigrator.CURRENT_VERSION)
	var combat: Dictionary = (saved["modules"] as Dictionary)["combat"]
	assert_true((combat["fracture"] as Dictionary).has("pulse_ms"))
	assert_eq(combat["area"], "")
	var run: Dictionary = ((saved["modules"] as Dictionary)["fractures"] as Dictionary)["run"]
	for key: String in ["card", "group", "groups_cleared", "boss_started", "return_area", "bag"]:
		assert_true(run.has(key), key)
	assert_eq(run["return_area"], "test_area")


func test_outside_a_fracture_the_combat_save_has_no_fracture_key() -> void:
	var s: GameSession = autofree(FractureUtil.session(3))
	s.combat.start(&"test_area")
	s.advance(3000)
	assert_false((s.to_save(1)["modules"]["combat"] as Dictionary).has("fracture"))
	assert_eq(s.to_save(1)["modules"]["fractures"], {"run": {}, "pending": {}})


func test_resume_in_the_middle_of_a_group() -> void:
	var a: GameSession = _session()
	a.advance(900)
	assert_eq(a.combat.state(), CombatEngine.STATE_ENCOUNTER)
	_check_from(a)


func test_resume_between_two_groups() -> void:
	var a: GameSession = _session()
	FractureUtil.run_until(a, func() -> bool: return a.combat.state() == CombatEngine.STATE_BETWEEN, 50)
	a.advance(300)
	assert_eq(a.combat.state(), CombatEngine.STATE_BETWEEN)
	_check_from(a)


func test_resume_during_the_boss() -> void:
	var a: GameSession = _session()
	FractureUtil.run_until(a, func() -> bool: return a.fractures.run() == null or a.fractures.run().boss_started, 50, 600_000)
	var b: GameSession = _roundtrip(a)
	_same_state(a, b)
	assert_true(b.fractures.run().boss_started)
	assert_eq(b.combat.get_state()["fracture"]["boss_id"], &"boss_grade_1")
	for _i: int in 100:
		a.advance(250)
		b.advance(250)
	_same_state(a, b)


func test_the_bag_of_the_fracture_survives_the_save() -> void:
	var a: GameSession = _session()
	FractureUtil.run_until(a, func() -> bool: return a.fractures.run() == null or a.fractures.run().bag.stacks().size() > 0, 50, 600_000)
	var b: GameSession = _roundtrip(a)
	assert_eq(b.fractures.run().bag.to_save(), a.fractures.run().bag.to_save())
	assert_gt(b.fractures.run().bag.stacks().size(), 0)
	assert_true(b.combat.loot.items().is_empty())


func test_summoned_enemies_are_saved_and_come_back() -> void:
	var a: GameSession = _session()
	var run: FractureRun = a.fractures.run()
	var scaled: MonsterDef = FractureScaler.scale_monster(a.data.monster(&"test_monster_a"), 1, run.effects, a.data)
	var snapshot: Encounter = Encounter.of_defs([scaled] as Array[MonsterDef], a.data)
	snapshot.enemies[0].summoned = true
	var saved: Array = snapshot.to_save()
	assert_eq(saved[0]["summoned"], true)
	var back: Encounter = Encounter.from_save(saved, a.data, run)
	assert_not_null(back)
	assert_true(back.enemies[0].summoned)
	assert_eq(back.enemies[0].stats.max_hp, snapshot.enemies[0].stats.max_hp, "scaled like the pack")
	var plain: Array = Encounter.of_defs([a.data.monster(&"test_monster_a")] as Array[MonsterDef], a.data).to_save()
	assert_false((plain[0] as Dictionary).has("summoned"), "absent means false")


func test_a_loaded_boss_is_resolved_on_the_run() -> void:
	var a: GameSession = _session()
	var run: FractureRun = a.fractures.run()
	var boss: MonsterDef = FractureScaler.scale_monster(run.boss_def(a.data), 1, run.effects, a.data)
	var saved: Array = Encounter.of_defs([boss] as Array[MonsterDef], a.data).to_save()
	assert_not_null(Encounter.from_save(saved, a.data, run))
	assert_null(Encounter.from_save(saved, a.data), "outside a Fracture a boss is an unknown monster")
