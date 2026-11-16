extends GutTest
## ActionRunner on the production queue (M24-03, docs/05_INTERFACES_M24.md §5.32): a recipe job runs its cycles, the interval is fixed
## per cycle (F-03), progress (F-04), 1x1000 ms = 10x100 ms, a full Bank makes the head wait, the stop reasons log, the save of the
## head and the tolerant loading. The queue itself (refusals, order, cancel/move, F-157) is in test_production_queue.gd.
##
## Fixture: craft_plank (test_craft, 2000 ms, 2 test_log -> 1 test_plank, 8 xp), craft_secret (test_craft_b, discover, 1 test_sap -> test_plank).
## `small` = config with `bank.base_slots` 1 and one test_log at start (a full Bank).

const FIXTURE_ROOT: String = "res://tests/fixtures/data"
const CONFIG_ROOT: String = "res://data/config"
const PreRun := preload("res://tests/helpers/gut_pre_run.gd")
const NOW_MS: int = 1793603600000
const QUEUE: StringName = &"queue"
const INTERVAL_STAT: StringName = &"skill_interval_pct"
const CRAFT_SKILL: StringName = &"test_craft"
const PLANK: StringName = &"craft_plank"

var _tmp_root: String = PreRun.test_dir("test_action_runner")
var _small_data: GameData = null
var _session: GameSession = null
var _runner: ActionRunner = null


func before_all() -> void:
	var config: String = _tmp_root.path_join("config")
	DirAccess.make_dir_recursive_absolute(config)
	var balance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_ROOT.path_join("balance.json")))
	(balance["deposit"] as Dictionary)["base_slots"] = 1
	(balance["start"] as Dictionary)["items"] = [{"item": "test_log", "qty": 1}, {"item": "seared_brookfin", "qty": 1}]
	_write(config.path_join("balance.json"), JSON.stringify(balance))
	_write(config.path_join("stats.json"), FileAccess.get_file_as_string(CONFIG_ROOT.path_join("stats.json")))
	_small_data = GameData.load_from_dirs(FIXTURE_ROOT, config)


func after_all() -> void:
	_remove_tree(_tmp_root)


func before_each() -> void:
	_session = autofree(TestFactory.session())
	_runner = _session.actions


func test_new_game_is_idle() -> void:
	assert_false(_runner.is_running())
	assert_eq(_runner.current(), {})
	assert_eq(_runner.jobs(), [] as Array[Dictionary])
	assert_eq(_runner.get_progress(), 0.0)
	assert_eq(_runner.capacity(), 5)
	assert_eq(_runner.to_save(), {"jobs": [], "elapsed_ms": 0, "rng": ProductionQueueLoader.derive_rng(_session).to_save()})
	assert_eq(_runner.stop_reasons_log(), [] as Array[StringName])


func test_enqueue_starts_the_head() -> void:
	TestFactory.give(_session, &"test_log", 4)
	watch_signals(_session.events)
	assert_true(_runner.enqueue(CRAFT_SKILL, PLANK, 2).ok)
	assert_true(_runner.is_running())
	assert_eq(_runner.current(), {"skill": "test_craft", "action": "craft_plank", "remaining": 2, "repeat": false,
			"elapsed_ms": 0, "interval_ms": 2000, "waiting": false})
	assert_signal_emitted(_session.events, "production_queue_changed")
	assert_signal_emitted_with_parameters(_session.events, "action_started", [QUEUE, CRAFT_SKILL, PLANK])


func test_a_job_ends_with_job_done_after_its_cycles() -> void:
	TestFactory.give(_session, &"test_log", 6)
	_runner.enqueue(CRAFT_SKILL, PLANK, 2)
	watch_signals(_session.events)
	_session.advance(4000)
	assert_signal_emit_count(_session.events, "action_completed", 2)
	assert_signal_emitted_with_parameters(_session.events, "action_stopped", [QUEUE, CRAFT_SKILL, Reasons.JOB_DONE])
	assert_false(_runner.is_running())
	assert_eq(_session.bank.get_count(&"test_plank"), 2)
	assert_eq(_session.bank.get_count(&"test_log"), 2)
	assert_eq(_runner.stop_reasons_log(), [Reasons.JOB_DONE] as Array[StringName])
	assert_eq(_runner.stop_reasons_log(), [] as Array[StringName])


func test_repeat_runs_until_the_inputs_run_out() -> void:
	TestFactory.give(_session, &"test_log", 5)
	_runner.enqueue(CRAFT_SKILL, PLANK, 1, true)
	watch_signals(_session.events)
	_session.advance(10000)
	assert_signal_emit_count(_session.events, "action_completed", 2)
	assert_eq(_session.bank.get_count(&"test_plank"), 2)
	assert_eq(_session.bank.get_count(&"test_log"), 1)
	assert_eq(_session.skills.get_xp(CRAFT_SKILL), 16)
	assert_false(_runner.is_running())
	assert_signal_emitted_with_parameters(_session.events, "action_stopped", [QUEUE, CRAFT_SKILL, Reasons.MISSING_INPUTS])
	assert_eq(_runner.stop_reasons_log(), [Reasons.MISSING_INPUTS] as Array[StringName])


func test_inputs_sold_mid_cycle_end_the_job_without_xp() -> void:
	TestFactory.give(_session, &"test_log", 2)
	_runner.enqueue(CRAFT_SKILL, PLANK, 3)
	_session.advance(1000)
	_session.bank.remove(&"test_log", 2)
	_session.advance(1000)
	assert_false(_runner.is_running())
	assert_eq(_session.skills.get_xp(CRAFT_SKILL), 0)
	assert_eq(_session.bank.get_count(&"test_plank"), 0)
	assert_eq(_runner.stop_reasons_log(), [Reasons.MISSING_INPUTS] as Array[StringName])


func test_one_advance_runs_several_cycles() -> void:
	TestFactory.give(_session, &"test_log", 20)
	_session.modifiers.set_source(&"test", [Modifier.make(INTERVAL_STAT, -50.0)] as Array[Modifier])
	_runner.enqueue(CRAFT_SKILL, PLANK, 1, true)
	assert_eq(_runner.current()["interval_ms"], 1000)
	watch_signals(_session.events)
	_session.advance(2500)
	assert_signal_emit_count(_session.events, "action_completed", 2)
	assert_eq(_runner.current()["elapsed_ms"], 500)


func test_action_completed_after_bank_xp_and_mastery() -> void:
	TestFactory.give(_session, &"test_log", 2)
	var order: Array[String] = []
	_session.events.bank_changed.connect(func(_i: StringName, _n: int, _d: int) -> void: order.append("bank"))
	_session.events.xp_gained.connect(func(_s: StringName, _a: int) -> void: order.append("xp"))
	_session.events.mastery_xp_gained.connect(func(_s: StringName, _a: StringName, _m: int) -> void: order.append("mastery"))
	_session.events.action_completed.connect(func(l: StringName, _s: StringName, _a: StringName, out: Dictionary) -> void:
		order.append("completed:%s:%d" % [l, out[&"test_plank"]]))
	_runner.enqueue(CRAFT_SKILL, PLANK, 1)
	_session.advance(2000)
	assert_eq(order.slice(order.size() - 3), ["xp", "mastery", "completed:queue:1"])
	assert_eq(order[0], "bank")


## 01_GDD §4: the interval is fixed when a cycle starts; a modifier change counts from the next cycle.
func test_interval_recomputed_at_each_cycle() -> void:
	TestFactory.give(_session, &"test_log", 20)
	_runner.enqueue(CRAFT_SKILL, PLANK, 1, true)
	_session.advance(500)
	_session.modifiers.set_source(&"tool", [Modifier.make(INTERVAL_STAT, -50.0)] as Array[Modifier])
	assert_eq(_runner.current()["interval_ms"], 2000)
	assert_eq(_runner.current_interval_ms(PLANK), 1000)
	_session.advance(1500)
	assert_eq(_session.skills.get_xp(CRAFT_SKILL), 8)
	assert_eq(_runner.current()["interval_ms"], 1000)
	_session.advance(1000)
	assert_eq(_session.skills.get_xp(CRAFT_SKILL), 16)


## F-04: 600 / 2000 -> 0.3.
func test_progress_f04() -> void:
	TestFactory.give(_session, &"test_log", 2)
	_runner.enqueue(CRAFT_SKILL, PLANK, 1)
	_session.advance(600)
	assert_almost_eq(_runner.get_progress(), 0.3, 1e-9)


## Acceptance: one 1000 ms step = ten 100 ms steps (same seed, same state), with random rolls in play.
func test_one_big_step_equals_many_small_steps() -> void:
	var big: GameSession = _equivalence_session()
	var small: GameSession = _equivalence_session()
	for i: int in 30:
		big.advance(1000)
	for i: int in 300:
		small.advance(100)
	assert_gt(big.skills.get_xp(CRAFT_SKILL), 0)
	assert_eq(SaveCodec.encode(small.to_save(NOW_MS)), SaveCodec.encode(big.to_save(NOW_MS)))
	assert_eq(small.actions.current(), big.actions.current())


## A full Bank: the head waits at 100% without losing progress; with room again the cycle completes.
func test_a_full_bank_makes_the_head_wait() -> void:
	var session: GameSession = autofree(TestFactory.session(1234, _small_data))
	session.bank.remove(&"test_log", 1)
	TestFactory.give(session, &"test_sap", 2)
	session.disciplines.from_save({"learned": {"test_craft_b": 3}, "recipes": ["craft_secret"]})
	assert_true(session.actions.enqueue(&"test_craft_b", &"craft_secret", 3).ok)
	watch_signals(session.events)
	session.advance(2500)
	assert_true(session.actions.current()["waiting"])
	assert_eq(session.actions.get_progress(), 1.0)
	assert_signal_emit_count(session.events, "notification_requested", 1)
	session.advance(500)
	assert_signal_emit_count(session.events, "notification_requested", 1, "one notification only")
	assert_signal_not_emitted(session.events, "action_completed")
	assert_eq(session.skills.get_xp(&"test_craft_b"), 0)
	session.bank.remove(&"test_sap", 2)  # the ingredients are gone: the waiting cycle fails, the job ends
	session.advance(100)
	assert_false(session.actions.is_running())
	assert_eq(session.actions.stop_reasons_log(), [Reasons.MISSING_INPUTS] as Array[StringName])


func test_save_writes_the_jobs_and_the_head_elapsed() -> void:
	TestFactory.give(_session, &"test_log", 4)
	_runner.enqueue(CRAFT_SKILL, PLANK, 2)
	_runner.enqueue(CRAFT_SKILL, PLANK, 1, true)
	_session.advance(1200)
	assert_eq(_runner.to_save(), {"jobs": [
			{"skill": "test_craft", "action": "craft_plank", "remaining": 2, "repeat": false},
			{"skill": "test_craft", "action": "craft_plank", "remaining": 0, "repeat": true}], "elapsed_ms": 1200,
			"rng": _runner.to_save()["rng"]})


## elapsed_ms is saved: after loading the bar continues and the cycle ends after the missing 800 ms.
func test_round_trip_resumes_the_cycle() -> void:
	TestFactory.give(_session, &"test_log", 4)
	_runner.enqueue(CRAFT_SKILL, PLANK, 2)
	_session.advance(1200)
	var text: String = SaveCodec.encode(_session.to_save(NOW_MS))
	var loaded: GameSession = autofree(TestFactory.session(1))
	watch_signals(loaded.events)
	assert_true(loaded.from_save(SaveCodec.decode(text)).ok)
	assert_signal_not_emitted(loaded.events, "action_started")
	assert_eq(loaded.actions.current()["elapsed_ms"], 1200)
	assert_eq(loaded.actions.current()["interval_ms"], 2000)
	assert_almost_eq(loaded.actions.get_progress(), 0.6, 1e-9)
	loaded.advance(700)
	assert_eq(loaded.skills.get_xp(CRAFT_SKILL), 0)
	loaded.advance(100)
	assert_eq(loaded.skills.get_xp(CRAFT_SKILL), 8)
	assert_eq(SaveCodec.encode(loaded.to_save(NOW_MS)), SaveCodec.encode(_advanced_copy(800)))


func test_from_save_drops_unusable_jobs() -> void:
	var good: Dictionary = {"skill": "test_craft", "action": "craft_plank", "remaining": 3, "repeat": false}
	var cases: Array = [
		"oops", [5], [{"skill": "test_craft", "action": "no_action", "remaining": 1, "repeat": false}],
		[{"skill": "test_gather", "action": "gather_twig", "remaining": 1, "repeat": false}],
		[{"skill": "test_craft", "action": "craft_plank", "remaining": 0, "repeat": false}],
		[{"skill": "test_craft", "action": "craft_plank", "remaining": "x", "repeat": false}],
		[{"skill": "test_craft_b", "action": "craft_secret", "remaining": 1, "repeat": false}],
	]
	for jobs: Variant in cases:
		_runner.from_save({"jobs": jobs})
		assert_false(_runner.is_running(), str(jobs))
	_runner.from_save({"jobs": [{"skill": "no", "action": "x"}, good], "elapsed_ms": 10})
	assert_eq(_runner.jobs().size(), 1, "the unusable job is dropped, the good one kept")
	_runner.from_save({})
	assert_false(_runner.is_running())


func test_from_save_drops_the_jobs_of_a_discipline_not_learned() -> void:
	_session.disciplines.new_game()
	_runner.from_save({"jobs": [{"skill": "test_craft", "action": "craft_plank", "remaining": 1, "repeat": false}]})
	assert_false(_runner.is_running())


func test_from_save_cuts_the_queue_to_its_capacity() -> void:
	var job: Dictionary = {"skill": "test_craft", "action": "craft_plank", "remaining": 1, "repeat": false}
	_runner.from_save({"jobs": [job, job, job, job, job, job, job]})
	assert_eq(_runner.jobs().size(), 5)


func test_from_save_bad_elapsed_restarts_the_cycle() -> void:
	var job: Dictionary = {"skill": "test_craft", "action": "craft_plank", "remaining": 1, "repeat": false}
	for elapsed: Variant in [-5, "x", 2.5]:
		_runner.from_save({"jobs": [job], "elapsed_ms": elapsed})
		assert_true(_runner.is_running())
		assert_eq(_runner.current()["elapsed_ms"], 0)
	_runner.from_save({"jobs": [job], "elapsed_ms": 700.0})
	assert_eq(_runner.current()["elapsed_ms"], 700)


func test_new_game_empties_the_queue_without_signals() -> void:
	TestFactory.give(_session, &"test_log", 2)
	_runner.enqueue(CRAFT_SKILL, PLANK, 1)
	watch_signals(_session.events)
	_session.new_game()
	assert_false(_runner.is_running())
	assert_signal_not_emitted(_session.events, "action_stopped")
	assert_signal_not_emitted(_session.events, "production_queue_changed")


# The state _session would have after another `ms` of play, from its own save (for the round trip comparison).
func _advanced_copy(ms: int) -> Dictionary:
	_session.advance(ms)
	return _session.to_save(NOW_MS)


func _equivalence_session() -> GameSession:
	var session: GameSession = autofree(TestFactory.session(99))
	TestFactory.give(session, &"test_log", 1000)
	session.modifiers.set_source(&"test", [Modifier.make(INTERVAL_STAT, -50.0), Modifier.make(&"double_item_chance", 40.0),
			Modifier.make(&"preservation_chance", 30.0)] as Array[Modifier])
	assert_true(session.actions.enqueue(CRAFT_SKILL, PLANK, 1, true).ok)
	return session


func _remove_tree(dir: String) -> void:
	for file: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(file))
	for sub: String in DirAccess.get_directories_at(dir):
		_remove_tree(dir.path_join(sub))
	DirAccess.remove_absolute(dir)


func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
