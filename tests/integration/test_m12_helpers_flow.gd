extends GutTest
## Integration, helpers (M12-08; F-101, F-102, 05 §5.21) on the real data: the four grades, work in parallel with combat,
## offline (and its equivalence with the online ticks), Deposit full -> wait -> resume, save in the middle of a cycle,
## hiring never creates or loses a contract. Fixed seeds, sessions freed, no real slot.

const SEED: int = 120802
const NOW_MS: int = 1793603600000
const FORESTRY: StringName = &"forestry"
const BIRCH: StringName = &"cut_redbirch"
const LOG: StringName = &"redbirch_log"
const AREA: StringName = &"redrock_plains"
const HERO: StringName = &"test:hero"
const TICK_MS: int = 100
const MINUTE_MS: int = 60000
const GRADE_INTERVALS: Dictionary = {
	&"apprentice": 9000, &"journeyman": 7500, &"expert": 6000, &"master": 4500,
}

var _s: GameSession = null


func after_each() -> void:
	if _s != null:
		_s.free()
	_s = null


func _new(data: GameData = null) -> GameSession:
	if _s != null:
		_s.free()
	_s = TestFactory.session_no_kit(SEED, data if data != null else TestFactory.real_data())
	return _s


func _hire(grade: StringName, skill: StringName = FORESTRY) -> void:
	var contract: StringName = StringName("contract_%s_%s" % [skill, grade])
	TestFactory.give(_s, contract, 1)
	var hired: CommandResult = _s.helpers.hire(contract)
	assert_true(hired.ok, "hire %s: %s" % [contract, hired.reason])


func _hire_and_assign(grade: StringName = &"apprentice") -> void:
	_hire(grade)
	assert_true(_s.helpers.set_action(FORESTRY, BIRCH).ok)


func _run(ms: int, step: int = TICK_MS) -> void:
	for i: int in ms / step:
		_s.advance(step)


func test_each_grade_has_the_f101_interval_for_birch() -> void:
	_new()
	var expected_min: int = 0
	for grade: StringName in [&"apprentice", &"journeyman", &"expert", &"master"]:
		_hire(grade)
		assert_true(_s.helpers.set_action(FORESTRY, BIRCH).ok)
		assert_eq(_s.helpers.get_grade(FORESTRY), grade)
		assert_eq(_s.helpers.interval_ms(FORESTRY), GRADE_INTERVALS[grade], "F-101: Birch 3000 ms, grade %s" % grade)
		assert_gt(_s.helpers.interval_ms(FORESTRY), expected_min - 1)
		assert_gte(_s.helpers.interval_ms(FORESTRY), int(_s.actions.current_interval_ms(BIRCH)), "never faster than the player")
	assert_eq(_s.helpers.grade_rank(FORESTRY), 4)


func test_the_players_tool_does_not_speed_the_helper_but_a_node_does() -> void:
	_new()
	_hire_and_assign(&"master")
	assert_eq(_s.helpers.interval_ms(FORESTRY), 4500)
	_s.modifiers.set_source(&"equipment:tool_forestry", [Modifier.make(&"skill_interval_pct", -50.0)])
	assert_eq(_s.helpers.interval_ms(FORESTRY), 4500, "the helper does not use the tool (F-101)")
	_s.modifiers.set_source(&"mastery_node:test", [Modifier.make(&"skill_interval_pct", -10.0)])
	assert_eq(_s.helpers.interval_ms(FORESTRY), 4050, "F-101 example: p_h -10 -> base 2700, Master 4050")


func test_a_cycle_gives_the_log_and_the_f102_share_of_xp_and_nothing_to_the_tool() -> void:
	_new()
	_hire_and_assign()
	var done: Array[Dictionary] = []
	_s.events.helper_completed.connect(func(s: StringName, a: StringName, o: Dictionary) -> void:
		done.append({"s": s, "a": a, "o": o}))
	_run(8900)
	assert_eq(done.size(), 0, "not before 9000 ms")
	_run(100)
	assert_eq(done.size(), 1)
	assert_eq(done[0]["a"], BIRCH)
	assert_gte(_s.bank.get_count(LOG), 1)
	assert_eq(_s.skills.get_xp(FORESTRY), 2, "F-102: floor(10 x 25 / 100)")
	assert_gt(_s.mastery.get_mastery_xp(BIRCH), 0, "mastery share of the helper")
	assert_lt(_s.mastery.get_mastery_xp(BIRCH), 5, "a fraction of the player's cycle (F-102: 25%)")
	assert_eq(_s.helpers.get_progress(FORESTRY), 0.0, "the next cycle starts at once")


func test_the_helper_works_while_the_hero_fights() -> void:
	_new()
	TestFactory.make_roomy(_s)
	_s.modifiers.set_source(HERO, [Modifier.make(&"power_bonus", 5000.0), Modifier.make(&"max_hp_flat", 100000.0)])
	_hire_and_assign()
	var kills: Array[int] = [0]
	var cycles: Array[int] = [0]
	_s.events.monster_killed.connect(func(_i: int, _m: StringName) -> void: kills[0] += 1)
	_s.events.helper_completed.connect(func(_s2: StringName, _a: StringName, _o: Dictionary) -> void: cycles[0] += 1)
	assert_true(_s.combat.start(AREA).ok)
	_run(2 * MINUTE_MS)
	assert_gt(kills[0], 5, "the fight went on")
	assert_true(_s.combat.is_active())
	assert_eq(cycles[0], 2 * MINUTE_MS / 9000, "13 helper cycles in 120 s, as if the hero were idle")
	assert_eq(_s.skills.get_xp(FORESTRY), cycles[0] * 2)
	assert_gte(_s.bank.get_count(LOG), cycles[0])


func test_the_helper_and_the_players_own_action_run_together() -> void:
	_new()
	_hire_and_assign()
	assert_true(_s.actions.start(FORESTRY, BIRCH).ok)
	_run(MINUTE_MS)
	var player_cycles: int = MINUTE_MS / 3000
	var helper_cycles: int = MINUTE_MS / 9000
	assert_gte(_s.bank.get_count(LOG), player_cycles + helper_cycles, "both produce (double chance only adds)")
	assert_eq(_s.skills.get_xp(FORESTRY), player_cycles * 10 + helper_cycles * 2, "player 10 per cycle, helper 2")


func test_offline_the_helper_keeps_working_and_matches_the_online_ticks() -> void:
	var online: GameSession = autofree(TestFactory.session_no_kit(SEED, TestFactory.real_data()))
	var away: GameSession = autofree(TestFactory.session_no_kit(SEED, TestFactory.real_data()))
	for s: GameSession in [online, away]:
		TestFactory.give(s, &"contract_forestry_journeyman", 1)
		assert_true(s.helpers.hire(&"contract_forestry_journeyman").ok)
		assert_true(s.helpers.set_action(FORESTRY, BIRCH).ok)
		assert_true(s.actions.start(&"angling", &"catch_brookfin").ok)
	var ms: int = 20 * MINUTE_MS
	for i: int in ms / TICK_MS:
		online.advance(TICK_MS)
	await OfflineSimulator.new().run(away, ms, false, false)
	online.play_time_ms = 0
	away.play_time_ms = 0
	assert_eq(SaveCodec.encode(away.to_save(NOW_MS)), SaveCodec.encode(online.to_save(NOW_MS)), "same state online and offline")
	assert_eq(away.skills.get_xp(FORESTRY), (ms / 7500) * 2, "the helper worked 160 cycles away")
	assert_gte(away.bank.get_count(LOG), ms / 7500)


func test_deposit_full_makes_the_helper_wait_and_it_resumes_without_losing_the_cycle() -> void:
	_new(TestFactory.data_with_deposit(TestFactory.REAL_CONTENT_ROOT, 3))
	_hire_and_assign()
	var fillers: Array[StringName] = []
	for def: ItemDef in _s.data.items():
		if def.category == &"material" and def.id != LOG and fillers.size() < 3:
			fillers.append(def.id)
	for id: StringName in fillers:
		TestFactory.give(_s, id, 1)
	assert_eq(_s.deposit.free_slots(), 0)
	var blocks: Array[bool] = []
	_s.events.helper_blocked.connect(func(_k: StringName, b: bool) -> void: blocks.append(b))
	var notes: Array[String] = []
	_s.events.notification_requested.connect(func(t: String, _k: StringName) -> void: notes.append(t))
	_run(30000)
	assert_true(_s.helpers.is_blocked(FORESTRY))
	assert_eq(blocks, [true] as Array[bool], "one signal, not one per tick")
	assert_eq(notes.size(), 1, "one warning")
	assert_eq(_s.skills.get_xp(FORESTRY), 0, "the waiting cycle does not count")
	assert_eq(_s.bank.get_count(LOG), 0)
	assert_true(_s.bank.remove(fillers[0], 1).ok)
	_run(TICK_MS)
	assert_false(_s.helpers.is_blocked(FORESTRY))
	assert_eq(blocks, [true, false] as Array[bool])
	assert_eq(_s.skills.get_xp(FORESTRY), 2, "the cycle that was waiting is paid, once")
	assert_gte(_s.bank.get_count(LOG), 1)


func test_save_in_the_middle_of_a_cycle_resumes_exactly() -> void:
	_new()
	_hire_and_assign(&"expert")
	_run(4000)
	var saved: Dictionary = _s.to_save(NOW_MS)
	var entry: Dictionary = (saved["modules"] as Dictionary)["helpers"][String(FORESTRY)]
	assert_eq(entry["grade"], "expert")
	assert_eq(entry["action"], String(BIRCH))
	assert_eq(entry["elapsed_ms"], 4000)
	var other: GameSession = autofree(TestFactory.session_no_kit(SEED + 5, TestFactory.real_data()))
	assert_true(other.from_save(SaveCodec.decode(SaveCodec.encode(saved))).ok)
	assert_eq(other.helpers.get_progress(FORESTRY), _s.helpers.get_progress(FORESTRY))
	_run(2000)
	other.advance(2000)
	assert_eq(other.skills.get_xp(FORESTRY), 2, "completes at 6000 ms of the interval")
	assert_eq(other.bank.get_count(LOG), _s.bank.get_count(LOG))


func test_hiring_consumes_one_contract_and_a_worse_one_is_refused_and_kept() -> void:
	_new()
	TestFactory.give(_s, &"contract_forestry_expert", 2)
	TestFactory.give(_s, &"contract_forestry_apprentice", 1)
	assert_true(_s.helpers.hire(&"contract_forestry_expert").ok)
	assert_eq(_s.bank.get_count(&"contract_forestry_expert"), 1)
	assert_eq(_s.helpers.hire(&"contract_forestry_apprentice").reason, Reasons.HELPER_NOT_BETTER)
	assert_eq(_s.bank.get_count(&"contract_forestry_apprentice"), 1, "the contract is not consumed")
	assert_eq(_s.helpers.hire(&"contract_forestry_expert").reason, Reasons.HELPER_NOT_BETTER, "same grade: refused too")
	assert_eq(_s.bank.get_count(&"contract_forestry_expert"), 1)
	assert_eq(_s.helpers.get_grade(FORESTRY), &"expert")


func test_the_three_gathering_trades_have_their_own_helper() -> void:
	_new()
	for skill: StringName in [&"forestry", &"quarrying", &"angling"]:
		assert_true(_s.helpers.is_helper_skill(skill))
		_hire(&"apprentice", skill)
		var first: StringName = _s.helpers.available_actions(skill)[0]
		assert_true(_s.helpers.set_action(skill, first).ok)
	assert_false(_s.helpers.is_helper_skill(&"forging"), "crafting skills have no helper")
	_run(MINUTE_MS)
	for skill: StringName in [&"forestry", &"quarrying", &"angling"]:
		assert_gt(_s.skills.get_xp(skill), 0, "%s worked" % skill)
