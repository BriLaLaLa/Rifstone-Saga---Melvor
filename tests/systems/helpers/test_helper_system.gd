extends GutTest
## HelperSystem (05 §5.21, 01 §4.1): hire, set_action, stop, advance (F-101, F-102), waiting for the Deposit, save.
## Fixture: test_gather (gather_twig 3000 ms level 1 xp 10 mastery; gather_log 4000 ms level 5), contracts of every grade.

const ROOT: String = "res://tests/fixtures/data"
const SKILL: StringName = &"test_gather"
const TWIG: StringName = &"gather_twig"
const LOG_ACTION: StringName = &"gather_log"
const TWIG_ITEM: StringName = &"test_twig"
const LOG_ITEM: StringName = &"test_log"
const APPRENTICE: StringName = &"contract_test_gather_apprentice"
const JOURNEYMAN: StringName = &"contract_test_gather_journeyman"
const EXPERT: StringName = &"contract_test_gather_expert"

var _session: GameSession
var _done: Array[Array] = []


func before_each() -> void:
	_session = autofree(TestFactory.session(11))
	_track(_session)


func _track(session: GameSession) -> void:
	_done = []
	session.events.helper_completed.connect(func(s: StringName, a: StringName, o: Dictionary) -> void: _done.append([s, a, o]))


func _hired(contract: StringName = APPRENTICE, action: StringName = TWIG) -> void:
	TestFactory.give(_session, contract, 1)
	assert_true(_session.helpers.hire(contract).ok)
	if action != &"":
		assert_true(_session.helpers.set_action(SKILL, action).ok)


# --- hire ----------------------------------------------------------------------------------------------------------

func test_hire_failures_in_order() -> void:
	assert_eq(_session.helpers.hire(&"nothing").reason, Reasons.UNKNOWN_ID)
	assert_eq(_session.helpers.hire(TWIG_ITEM).reason, Reasons.NOT_A_CONTRACT)
	assert_eq(_session.helpers.hire(APPRENTICE).reason, Reasons.NOT_ENOUGH_ITEMS)
	assert_eq(_session.helpers.get_grade(SKILL), &"")


func test_hire_consumes_the_contract_and_signals() -> void:
	TestFactory.give(_session, APPRENTICE, 2)
	watch_signals(_session.events)
	assert_true(_session.helpers.hire(APPRENTICE).ok)
	assert_eq(_session.bank.get_count(APPRENTICE), 1)
	assert_eq(_session.helpers.get_grade(SKILL), &"apprentice")
	assert_eq(_session.helpers.grade_rank(SKILL), 1)
	assert_signal_emitted_with_parameters(_session.events, "helper_changed", [SKILL, &"apprentice", &""])


func test_a_contract_not_above_the_current_grade_is_refused_and_kept() -> void:
	_hired(JOURNEYMAN, &"")
	TestFactory.give(_session, APPRENTICE, 1)
	TestFactory.give(_session, JOURNEYMAN, 1)
	assert_eq(_session.helpers.hire(APPRENTICE).reason, Reasons.HELPER_NOT_BETTER)
	assert_eq(_session.helpers.hire(JOURNEYMAN).reason, Reasons.HELPER_NOT_BETTER)
	assert_eq(_session.bank.get_count(APPRENTICE), 1)
	assert_eq(_session.bank.get_count(JOURNEYMAN), 1)
	assert_eq(_session.helpers.get_grade(SKILL), &"journeyman")


func test_a_better_contract_replaces_the_helper_and_keeps_the_action() -> void:
	_hired(APPRENTICE, TWIG)
	_session.helpers.advance(1000)
	TestFactory.give(_session, EXPERT, 1)
	assert_true(_session.helpers.hire(EXPERT).ok)
	assert_eq(_session.helpers.get_grade(SKILL), &"expert")
	assert_eq(_session.helpers.grade_rank(SKILL), 3)
	assert_eq(_session.helpers.get_action(SKILL), TWIG)
	assert_eq(_session.helpers.get_progress(SKILL), 0.0)
	assert_eq(_session.helpers.interval_ms(SKILL), 6000)


# --- set_action / stop ---------------------------------------------------------------------------------------------

func test_set_action_failures() -> void:
	assert_eq(_session.helpers.set_action(&"test_craft", TWIG).reason, Reasons.UNKNOWN_ID)
	assert_eq(_session.helpers.set_action(SKILL, &"nothing").reason, Reasons.UNKNOWN_ID)
	assert_eq(_session.helpers.set_action(SKILL, TWIG).reason, Reasons.NO_HELPER)
	_hired(APPRENTICE, &"")
	assert_eq(_session.helpers.set_action(SKILL, LOG_ACTION).reason, Reasons.LEVEL_TOO_LOW)
	assert_eq(_session.helpers.set_action(&"test_gather_b", TWIG).reason, Reasons.UNKNOWN_ID)


func test_available_actions_follow_the_level() -> void:
	assert_false(_session.helpers.available_actions(SKILL).has(LOG_ACTION))
	TestFactory.set_level(_session, SKILL, 5)
	assert_true(_session.helpers.available_actions(SKILL).has(LOG_ACTION))
	assert_eq(_session.helpers.available_actions(&"test_craft").size(), 0)
	assert_true(_session.helpers.is_helper_skill(SKILL))
	assert_false(_session.helpers.is_helper_skill(&"test_craft"))


func test_same_action_is_a_noop_another_one_resets_the_progress() -> void:
	_hired()
	_session.helpers.advance(4500)
	assert_almost_eq(_session.helpers.get_progress(SKILL), 0.5, 0.0001)
	watch_signals(_session.events)
	assert_true(_session.helpers.set_action(SKILL, TWIG).ok)
	assert_signal_not_emitted(_session.events, "helper_changed")
	assert_almost_eq(_session.helpers.get_progress(SKILL), 0.5, 0.0001)
	TestFactory.set_level(_session, SKILL, 5)
	assert_true(_session.helpers.set_action(SKILL, LOG_ACTION).ok)
	assert_signal_emitted_with_parameters(_session.events, "helper_changed", [SKILL, &"apprentice", LOG_ACTION])
	assert_eq(_session.helpers.get_progress(SKILL), 0.0)
	assert_eq(_session.helpers.interval_ms(SKILL), 12000)


func test_stop_removes_the_action_and_keeps_the_helper() -> void:
	_session.helpers.stop(SKILL)  # no helper: no-op
	_hired()
	watch_signals(_session.events)
	_session.helpers.stop(SKILL)
	assert_signal_emitted_with_parameters(_session.events, "helper_changed", [SKILL, &"apprentice", &""])
	assert_eq(_session.helpers.get_action(SKILL), &"")
	assert_eq(_session.helpers.get_grade(SKILL), &"apprentice")
	_session.helpers.stop(SKILL)
	assert_signal_emit_count(_session.events, "helper_changed", 1)


# --- advance -------------------------------------------------------------------------------------------------------

func test_one_cycle_gives_products_and_the_f102_share() -> void:
	_hired()
	watch_signals(_session.events)
	_session.helpers.advance(8999)
	assert_eq(_done.size(), 0)
	assert_eq(_session.bank.get_count(TWIG_ITEM), 0)
	_session.helpers.advance(1)
	assert_eq(_done.size(), 1)
	assert_eq(_done[0][0], SKILL)
	assert_eq(_done[0][1], TWIG)
	assert_eq((_done[0][2] as Dictionary)[TWIG_ITEM], 1)
	assert_eq(_session.bank.get_count(TWIG_ITEM), 1)
	assert_eq(_session.skills.get_xp(SKILL), 2)  # 10 x 25%
	assert_eq(_session.mastery.get_mastery_xp(TWIG), 1)  # round(3 x 25%)
	assert_signal_emitted_with_parameters(_session.events, "xp_gained", [SKILL, 2])
	assert_eq(_session.helpers.get_progress(SKILL), 0.0)


func test_many_cycles_in_one_step_and_in_small_steps_are_equal() -> void:
	_hired()
	_session.helpers.advance(9000 * 5 + 100)
	var big: int = _done.size()
	var xp_big: int = _session.skills.get_xp(SKILL)
	var other: GameSession = autofree(TestFactory.session(11))
	TestFactory.give(other, APPRENTICE, 1)
	other.helpers.hire(APPRENTICE)
	other.helpers.set_action(SKILL, TWIG)
	var count: Array[int] = [0]
	other.events.helper_completed.connect(func(_s: StringName, _a: StringName, _o: Dictionary) -> void: count[0] += 1)
	for i: int in 9000 * 5 / 100 + 1:
		other.helpers.advance(100)
	assert_eq(big, 5)
	assert_eq(count[0], 5)
	assert_eq(other.skills.get_xp(SKILL), xp_big)


func test_interval_is_fixed_when_the_cycle_starts() -> void:
	_hired()
	_session.helpers.advance(100)
	_session.modifiers.set_source(&"test:fast", [Modifier.make(&"skill_interval_pct", -50.0)] as Array[Modifier])
	_session.helpers.advance(8900)
	assert_eq(_done.size(), 1)  # the running cycle kept 9000 ms ...
	assert_eq(_session.helpers.interval_ms(SKILL), 4500)  # ... the next one gets the new F-101 value


func test_it_works_in_parallel_with_the_player_action() -> void:
	_hired()
	assert_true(_session.actions.start(SKILL, TWIG).ok)
	_session.advance(9000)
	assert_eq(_done.size(), 1)
	assert_eq(_session.bank.get_count(TWIG_ITEM), 4)  # 3 player cycles + 1 helper cycle
	assert_true(_session.actions.is_running())


func test_the_session_advance_runs_the_helpers_phase() -> void:
	_hired()
	_session.advance(9000)
	assert_eq(_done.size(), 1)


func test_player_tool_does_not_change_the_helper() -> void:
	_hired()
	var before: int = _session.helpers.interval_ms(SKILL)
	_session.modifiers.set_source(&"equipment:tool_test_gather", [Modifier.make(&"skill_interval_pct", -23.0)] as Array[Modifier])
	assert_eq(_session.helpers.interval_ms(SKILL), before)
	assert_eq(before, 9000)
	assert_lt(_session.actions.current_interval_ms(TWIG), 3000)


# --- Deposit full --------------------------------------------------------------------------------------------------

func test_full_deposit_makes_it_wait_and_resume_without_losing_the_cycle() -> void:
	_session = autofree(TestFactory.session(11, TestFactory.data_with_deposit(ROOT, 1)))
	_track(_session)
	_hired()
	TestFactory.give(_session, LOG_ITEM, 1)  # the only box (the contract freed its box when hired)
	var blocks: Array[bool] = []
	_session.events.helper_blocked.connect(func(_s: StringName, b: bool) -> void: blocks.append(b))
	var notes: Array[String] = []
	_session.events.notification_requested.connect(func(t: String, _k: StringName) -> void: notes.append(t))
	_session.helpers.advance(9000)
	assert_true(_session.helpers.is_blocked(SKILL))
	assert_eq(_done.size(), 0)
	assert_eq(_session.skills.get_xp(SKILL), 0)
	_session.helpers.advance(5000)
	_session.helpers.advance(5000)
	assert_eq(blocks, [true] as Array[bool])
	assert_eq(notes.size(), 1)
	assert_eq(_session.helpers.get_progress(SKILL), 1.0)
	assert_true(_session.bank.remove(LOG_ITEM, 1).ok)
	_session.helpers.advance(1)
	assert_false(_session.helpers.is_blocked(SKILL))
	assert_eq(blocks, [true, false] as Array[bool])
	assert_eq(_done.size(), 1)
	assert_eq(_session.skills.get_xp(SKILL), 2)
	assert_eq(_session.bank.get_count(TWIG_ITEM), 1)


func test_changing_the_action_while_waiting_clears_the_wait() -> void:
	_session = autofree(TestFactory.session(11, TestFactory.data_with_deposit(ROOT, 1)))
	_hired()
	TestFactory.give(_session, LOG_ITEM, 1)
	_session.helpers.advance(9000)
	assert_true(_session.helpers.is_blocked(SKILL))
	_session.helpers.stop(SKILL)
	assert_false(_session.helpers.is_blocked(SKILL))


# --- save ----------------------------------------------------------------------------------------------------------

func test_save_round_trip() -> void:
	_hired(JOURNEYMAN, TWIG)
	_session.helpers.advance(3000)
	var saved: Dictionary = _session.helpers.to_save()
	assert_eq(saved, {"test_gather": {"grade": "journeyman", "action": "gather_twig", "elapsed_ms": 3000}})
	var other: GameSession = autofree(TestFactory.session(11))
	other.helpers.from_save(JSON.parse_string(JSON.stringify(saved)))
	assert_eq(other.helpers.to_save(), saved)
	assert_eq(other.helpers.get_grade(SKILL), &"journeyman")
	assert_almost_eq(other.helpers.get_progress(SKILL), 3000.0 / 7500.0, 0.0001)


func test_new_game_removes_the_helpers() -> void:
	_hired()
	_session.helpers.new_game()
	assert_eq(_session.helpers.to_save(), {})


func test_from_save_is_tolerant() -> void:
	var d: Dictionary = {
		"test_craft": {"grade": "master", "action": "", "elapsed_ms": 0},
		"test_gather": {"grade": "wizard", "action": "gather_twig", "elapsed_ms": 5},
		"test_gather_b": {"grade": "master", "action": "gather_twig", "elapsed_ms": -4},
	}
	_session.helpers.from_save(d)
	assert_eq(_session.helpers.get_grade(&"test_craft"), &"")
	assert_eq(_session.helpers.get_grade(SKILL), &"")
	assert_eq(_session.helpers.get_grade(&"test_gather_b"), &"master")
	assert_eq(_session.helpers.get_action(&"test_gather_b"), &"")  # an action of another skill
	_session.helpers.from_save({"test_gather": {"grade": "master", "action": "gather_log", "elapsed_ms": 1.5}})
	assert_eq(_session.helpers.get_action(SKILL), &"")  # above the level
	_session.helpers.from_save({"test_gather": {"grade": "master", "action": "gather_twig", "elapsed_ms": -4}})
	assert_eq(_session.helpers.get_action(SKILL), TWIG)
	assert_eq(_session.helpers.get_progress(SKILL), 0.0)


func test_session_save_has_the_helpers_module() -> void:
	_hired()
	var save: Dictionary = _session.to_save(1)
	assert_true((save[GameSession.MODULES_KEY] as Dictionary).has("helpers"))
