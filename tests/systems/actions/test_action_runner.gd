extends GutTest
## ActionRunner: start/stop with reasons, several cycles in one advance, interval fixed per cycle (F-03), progress
## (F-04), 1×1000 ms = 10×100 ms, bank full stop, stop reasons log, save of the lane and tolerant loading.
##
## Fixture: gather_twig (test_gather, level 1, 3000 ms), gather_log (level 5), gather_bundle (no mastery),
## craft_plank (test_craft, with inputs). Two data copies under user://: `fast` = fixture content with
## gather_bundle at 1000 ms (so -80% reaches the 250 ms minimum); `small` = config with `bank.base_slots` 1 and one
## test_log at start (a full bank).

const FIXTURE_ROOT: String = "res://tests/fixtures/data"
const CONFIG_ROOT: String = "res://data/config"
const PreRun := preload("res://tests/helpers/gut_pre_run.gd")
const NOW_MS: int = 1793603600000
const MAIN: StringName = &"main"
const SKILL: StringName = &"test_gather"
const TWIG: StringName = &"gather_twig"
const BUNDLE: StringName = &"gather_bundle"
const INTERVAL_STAT: StringName = &"skill_interval_pct"
const CRAFT_SKILL: StringName = &"test_craft"
const PLANK: StringName = &"craft_plank"

var _tmp_root: String = PreRun.test_dir("test_action_runner")
var _fast_data: GameData = null
var _small_data: GameData = null
var _session: GameSession = null
var _runner: ActionRunner = null


func before_all() -> void:
	var content: String = _tmp_root.path_join("content")
	_copy_json_tree(FIXTURE_ROOT, content)
	var path: String = content.path_join("actions/test_gather.json")
	var gather: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	for entry: Dictionary in gather["actions"]:
		if entry["id"] == String(BUNDLE):
			entry["interval_ms"] = 1000
	_write(path, JSON.stringify(gather))
	_fast_data = GameData.load_from_dirs(content, CONFIG_ROOT)
	var config: String = _tmp_root.path_join("config")
	DirAccess.make_dir_recursive_absolute(config)
	var balance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_ROOT.path_join("balance.json")))
	(balance["bank"] as Dictionary)["base_slots"] = 1
	(balance["start"] as Dictionary)["items"] = [{"item": "test_log", "qty": 1}]
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
	assert_eq(_runner.get_lane(), {})
	assert_eq(_runner.get_progress(), 0.0)
	assert_eq(_runner.lanes_available(), 1)
	assert_eq(_runner.to_save(), {"lanes": {}})
	assert_eq(_runner.stop_reasons_log(), [] as Array[StringName])


func test_start_runs_the_action() -> void:
	watch_signals(_session.events)
	assert_true(_runner.start(SKILL, TWIG).ok)
	assert_true(_runner.is_running(MAIN))
	assert_eq(_runner.get_lane(), {"skill": SKILL, "action": TWIG, "elapsed_ms": 0, "interval_ms": 3000})
	assert_signal_emitted_with_parameters(_session.events, "action_started", [MAIN, SKILL, TWIG])


func test_start_failures_change_nothing() -> void:
	_runner.start(SKILL, TWIG)
	_session.advance(500)
	watch_signals(_session.events)
	assert_eq(_runner.start(&"no_skill", TWIG).reason, Reasons.UNKNOWN_ID)
	assert_eq(_runner.start(SKILL, &"no_action").reason, Reasons.UNKNOWN_ID)
	assert_eq(_runner.start(&"test_gather_b", TWIG).reason, Reasons.UNKNOWN_ID)
	assert_eq(_runner.start(&"test_craft", &"craft_plank").reason, Reasons.MISSING_INPUTS)
	assert_eq(_runner.start(SKILL, &"gather_log").reason, Reasons.LEVEL_TOO_LOW)
	assert_eq(_runner.start(SKILL, BUNDLE, &"secondary").reason, Reasons.LANE_UNAVAILABLE)
	assert_eq(_runner.get_lane()["action"], TWIG)
	assert_eq(_runner.get_lane()["elapsed_ms"], 500)
	assert_signal_not_emitted(_session.events, "action_started")
	assert_signal_not_emitted(_session.events, "action_stopped")


func test_start_after_level_up() -> void:
	TestFactory.set_level(_session, SKILL, 5)
	assert_true(_runner.start(SKILL, &"gather_log").ok)


func test_start_other_action_replaces_the_running_one() -> void:
	_runner.start(SKILL, TWIG)
	_session.advance(1000)
	watch_signals(_session.events)
	assert_true(_runner.start(SKILL, BUNDLE).ok)
	assert_signal_emitted_with_parameters(_session.events, "action_stopped", [MAIN, SKILL, Reasons.REPLACED])
	assert_signal_emitted_with_parameters(_session.events, "action_started", [MAIN, SKILL, BUNDLE])
	assert_eq(_runner.get_lane()["elapsed_ms"], 0)
	assert_eq(_runner.stop_reasons_log(), [Reasons.REPLACED] as Array[StringName])


func test_start_same_action_keeps_the_cycle() -> void:
	_runner.start(SKILL, TWIG)
	_session.advance(1000)
	watch_signals(_session.events)
	assert_true(_runner.start(SKILL, TWIG).ok)
	assert_eq(_runner.get_lane()["elapsed_ms"], 1000)
	assert_signal_not_emitted(_session.events, "action_started")
	assert_signal_not_emitted(_session.events, "action_stopped")


func test_stop_by_user() -> void:
	_runner.start(SKILL, TWIG)
	watch_signals(_session.events)
	_runner.stop()
	assert_false(_runner.is_running())
	assert_eq(_runner.get_progress(), 0.0)
	assert_signal_emitted_with_parameters(_session.events, "action_stopped", [MAIN, SKILL, Reasons.STOPPED_BY_USER])
	assert_eq(_runner.stop_reasons_log(), [Reasons.STOPPED_BY_USER] as Array[StringName])
	assert_eq(_runner.stop_reasons_log(), [] as Array[StringName])


func test_stop_idle_lane_does_nothing() -> void:
	watch_signals(_session.events)
	_runner.stop()
	assert_signal_not_emitted(_session.events, "action_stopped")
	assert_eq(_runner.stop_reasons_log(), [] as Array[StringName])


## F-04: 1200 / 3000 -> 0.4.
func test_progress_f04() -> void:
	_runner.start(SKILL, TWIG)
	_session.advance(1200)
	assert_almost_eq(_runner.get_progress(), 0.4, 1e-9)
	assert_eq(_runner.get_lane()["elapsed_ms"], 1200)


## Acceptance: 600 ms with a 250 ms interval -> 2 cycles and 100 ms left.
func test_one_advance_runs_several_cycles() -> void:
	var session: GameSession = _data_session(_fast_data)
	session.modifiers.set_source(&"test", [Modifier.make(INTERVAL_STAT, -80.0)] as Array[Modifier])
	assert_true(session.actions.start(SKILL, BUNDLE).ok)
	assert_eq(session.actions.get_lane()["interval_ms"], 250)
	watch_signals(session.events)
	session.advance(600)
	assert_signal_emit_count(session.events, "action_completed", 2)
	assert_eq(session.actions.get_lane()["elapsed_ms"], 100)
	assert_eq(session.skills.get_xp(SKILL), 20)
	assert_eq(session.bank.get_count(&"test_twig"), 4)


func test_action_completed_after_bank_xp_and_mastery() -> void:
	var order: Array[String] = []
	var on_bank: Callable = func(_i: StringName, _n: int, _d: int) -> void: order.append("bank")
	var on_xp: Callable = func(_s: StringName, _a: int) -> void: order.append("xp")
	var on_mastery: Callable = func(_s: StringName, _a: StringName, _m: int) -> void: order.append("mastery")
	var on_done: Callable = func(_l: StringName, _s: StringName, _a: StringName, out: Dictionary) -> void:
		order.append("completed:%d" % out[&"test_twig"])
	_session.events.bank_changed.connect(on_bank)
	_session.events.xp_gained.connect(on_xp)
	_session.events.mastery_xp_gained.connect(on_mastery)
	_session.events.action_completed.connect(on_done)
	_runner.start(SKILL, TWIG)
	_session.advance(3000)
	assert_eq(order, ["bank", "xp", "mastery", "completed:1"])
	assert_eq(_runner.get_lane()["elapsed_ms"], 0)


## 01_GDD §4: the interval is fixed when a cycle starts; a modifier change counts from the next cycle.
func test_interval_recomputed_at_each_cycle() -> void:
	_runner.start(SKILL, TWIG)
	_session.advance(1000)
	_session.modifiers.set_source(&"tool", [Modifier.make(INTERVAL_STAT, -50.0)] as Array[Modifier])
	assert_eq(_runner.get_lane()["interval_ms"], 3000)
	assert_eq(_runner.current_interval_ms(TWIG), 1500)
	_session.advance(2000)
	assert_eq(_session.skills.get_xp(SKILL), 10)
	assert_eq(_runner.get_lane()["interval_ms"], 1500)
	_session.advance(1500)
	assert_eq(_session.skills.get_xp(SKILL), 20)


## Acceptance: one 1000 ms step = ten 100 ms steps (same seed, same state), with random rolls in play.
func test_one_big_step_equals_many_small_steps() -> void:
	var big: GameSession = _equivalence_session()
	var small: GameSession = _equivalence_session()
	for i: int in 30:
		big.advance(1000)
	for i: int in 300:
		small.advance(100)
	assert_gt(big.skills.get_xp(SKILL), 0)
	assert_eq(SaveCodec.encode(small.to_save(NOW_MS)), SaveCodec.encode(big.to_save(NOW_MS)))
	assert_eq(small.actions.get_lane(), big.actions.get_lane())


## Acceptance: bank full -> no xp, stop with bank_full.
func test_bank_full_stops_without_xp() -> void:
	var session: GameSession = _data_session(_small_data)
	session.actions.start(SKILL, TWIG)
	watch_signals(session.events)
	session.advance(5000)
	assert_false(session.actions.is_running())
	assert_signal_emitted_with_parameters(session.events, "action_stopped", [MAIN, SKILL, Reasons.BANK_FULL])
	assert_signal_not_emitted(session.events, "action_completed")
	assert_eq(session.skills.get_xp(SKILL), 0)
	assert_eq(session.mastery.get_mastery_xp(TWIG), 0)
	assert_eq(session.bank.get_count(&"test_twig"), 0)
	assert_eq(session.actions.stop_reasons_log(), [Reasons.BANK_FULL] as Array[StringName])


func test_save_writes_the_lane() -> void:
	_runner.start(SKILL, TWIG)
	_session.advance(1200)
	assert_eq(_runner.to_save(), {"lanes": {"main": {"skill": "test_gather", "action": "gather_twig",
			"elapsed_ms": 1200}}})


## elapsed_ms is saved: after loading the bar continues and the cycle ends after the missing 1800 ms.
func test_round_trip_resumes_the_cycle() -> void:
	_runner.start(SKILL, TWIG)
	_session.advance(1200)
	var text: String = SaveCodec.encode(_session.to_save(NOW_MS))
	var loaded: GameSession = autofree(TestFactory.session(1))
	watch_signals(loaded.events)
	assert_true(loaded.from_save(SaveCodec.decode(text)).ok)
	assert_signal_not_emitted(loaded.events, "action_started")
	assert_eq(loaded.actions.get_lane(), {"skill": SKILL, "action": TWIG, "elapsed_ms": 1200, "interval_ms": 3000})
	assert_almost_eq(loaded.actions.get_progress(), 0.4, 1e-9)
	loaded.advance(1700)
	assert_eq(loaded.skills.get_xp(SKILL), 0)
	loaded.advance(100)
	assert_eq(loaded.skills.get_xp(SKILL), 10)
	assert_eq(SaveCodec.encode(loaded.to_save(NOW_MS)), SaveCodec.encode(_advanced_copy(1800)))


func test_from_save_drops_invalid_lanes() -> void:
	var cases: Array = [
		"oops",
		{"secondary": {"skill": "test_gather", "action": "gather_twig", "elapsed_ms": 0}},
		{"main": "oops"},
		{"main": {"skill": "test_gather", "action": "no_action", "elapsed_ms": 0}},
		{"main": {"skill": "test_gather_b", "action": "gather_twig", "elapsed_ms": 0}},
		{"main": {"skill": "test_craft", "action": "craft_plank", "elapsed_ms": 0}},
		{"main": {"skill": "test_gather", "action": "gather_log", "elapsed_ms": 0}},
	]
	for lanes: Variant in cases:
		_runner.from_save({"lanes": lanes})
		assert_false(_runner.is_running(), str(lanes))
	_runner.from_save({})
	assert_false(_runner.is_running())


func test_from_save_bad_elapsed_restarts_the_cycle() -> void:
	for elapsed: Variant in [-5, "x", 2.5]:
		_runner.from_save({"lanes": {"main": {"skill": "test_gather", "action": "gather_twig", "elapsed_ms": elapsed}}})
		assert_true(_runner.is_running())
		assert_eq(_runner.get_lane()["elapsed_ms"], 0)
	_runner.from_save({"lanes": {"main": {"skill": "test_gather", "action": "gather_twig", "elapsed_ms": 700.0}}})
	assert_eq(_runner.get_lane()["elapsed_ms"], 700)


func test_new_game_stops_without_signals() -> void:
	_runner.start(SKILL, TWIG)
	watch_signals(_session.events)
	_session.new_game()
	assert_false(_runner.is_running())
	assert_signal_not_emitted(_session.events, "action_stopped")


# The state _session would have after another `ms` of play, from its own save (for the round trip comparison).
func _advanced_copy(ms: int) -> Dictionary:
	_session.advance(ms)
	return _session.to_save(NOW_MS)


func _equivalence_session() -> GameSession:
	var session: GameSession = autofree(TestFactory.session(99))
	session.modifiers.set_source(&"test", [Modifier.make(INTERVAL_STAT, -50.0), Modifier.make(&"double_item_chance",
			40.0), Modifier.make(&"rift_shard_chance", 30.0)] as Array[Modifier])
	assert_true(session.actions.start(SKILL, TWIG).ok)
	return session


func _data_session(data: GameData) -> GameSession:
	assert_true(data.is_valid(), "\n".join(data.errors))
	return autofree(TestFactory.session(1234, data))


func _copy_json_tree(from_dir: String, to_dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(to_dir)
	for file: String in DirAccess.get_files_at(from_dir):
		if file.get_extension() == "json":
			_write(to_dir.path_join(file), FileAccess.get_file_as_string(from_dir.path_join(file)))
	for sub: String in DirAccess.get_directories_at(from_dir):
		_copy_json_tree(from_dir.path_join(sub), to_dir.path_join(sub))


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


## M3-01: artisan actions start with the inputs in the bank and stop with the outcome's reason.
func test_artisan_start_needs_the_inputs() -> void:
	assert_eq(_runner.start(CRAFT_SKILL, PLANK).reason, Reasons.MISSING_INPUTS)
	assert_false(_runner.is_running())
	TestFactory.give(_session, &"test_log", 1)
	assert_eq(_runner.start(CRAFT_SKILL, PLANK).reason, Reasons.MISSING_INPUTS)
	TestFactory.give(_session, &"test_log", 1)
	assert_true(_runner.start(CRAFT_SKILL, PLANK).ok)
	assert_eq(_runner.get_lane()["interval_ms"], 2000)


func test_artisan_cycles_consume_until_the_inputs_run_out() -> void:
	TestFactory.give(_session, &"test_log", 5)
	_runner.start(CRAFT_SKILL, PLANK)
	watch_signals(_session.events)
	_session.advance(10000)
	assert_signal_emit_count(_session.events, "action_completed", 2)
	assert_eq(_session.bank.get_count(&"test_plank"), 2)
	assert_eq(_session.bank.get_count(&"test_log"), 1)
	assert_eq(_session.skills.get_xp(CRAFT_SKILL), 16)
	assert_false(_runner.is_running())
	assert_signal_emitted_with_parameters(_session.events, "action_stopped", [MAIN, CRAFT_SKILL, Reasons.MISSING_INPUTS])
	assert_eq(_runner.stop_reasons_log(), [Reasons.MISSING_INPUTS] as Array[StringName])


func test_artisan_inputs_sold_mid_cycle_fail_without_xp() -> void:
	TestFactory.give(_session, &"test_log", 2)
	_runner.start(CRAFT_SKILL, PLANK)
	_session.advance(1000)
	_session.bank.remove(&"test_log", 2)
	_session.advance(1000)
	assert_false(_runner.is_running())
	assert_eq(_session.skills.get_xp(CRAFT_SKILL), 0)
	assert_eq(_session.bank.get_count(&"test_plank"), 0)
	assert_eq(_runner.stop_reasons_log(), [Reasons.MISSING_INPUTS] as Array[StringName])


func test_artisan_lane_is_not_restored_without_inputs() -> void:
	var lanes: Dictionary = {"main": {"skill": "test_craft", "action": "craft_plank", "elapsed_ms": 500}}
	_runner.from_save({"lanes": lanes})
	assert_false(_runner.is_running())
	TestFactory.give(_session, &"test_log", 2)
	_runner.from_save({"lanes": lanes})
	assert_true(_runner.is_running())
	assert_eq(_runner.get_lane()["elapsed_ms"], 500)
