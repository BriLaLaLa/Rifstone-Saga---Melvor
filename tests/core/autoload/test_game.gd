extends GutTest
## Game: new game, continue, autosave driven by GameClock, end_session, delete, lifecycle signals.
##
## Uses a private instance of game.gd on the real data and the EventBus, never the Game autoload. SaveService points
## at user://test_saves (gut_pre_run.gd), emptied before each test. GameClock time is simulated by calling its
## _process with exact binary fractions of a second; its time source is replaced and restored.

const GameScript := preload("res://core/autoload/game.gd")
const TEST_DIR: String = "user://test_saves"
const FRAME_S: float = 0.5
const FRAME_MS: int = 500
const NOW_MS: int = 1793600000000
const MAX_EXACT_JSON_INT: int = 9007199254740992

var _game: GameScript
var _saved_time_source: Callable
var _saves: Array[int] = []
var _failures: Array[StringName] = []
var _started: Array = []
var _ended: Array[int] = []


func before_each() -> void:
	_clear_dir(TEST_DIR)
	_saved_time_source = GameClock.time_source
	GameClock.time_source = func() -> int: return NOW_MS
	_saves.clear()
	_failures.clear()
	_started.clear()
	_ended.clear()
	EventBus.save_completed.connect(_on_event_bus_save_completed)
	EventBus.save_failed.connect(_on_event_bus_save_failed)
	EventBus.session_started.connect(_on_event_bus_session_started)
	EventBus.session_ended.connect(_on_event_bus_session_ended)
	_game = GameScript.new()
	add_child_autofree(_game)


func after_each() -> void:
	_game.end_session(false)
	EventBus.save_completed.disconnect(_on_event_bus_save_completed)
	EventBus.save_failed.disconnect(_on_event_bus_save_failed)
	EventBus.session_started.disconnect(_on_event_bus_session_started)
	EventBus.session_ended.disconnect(_on_event_bus_session_ended)
	GameClock.time_source = _saved_time_source
	_clear_dir(TEST_DIR)


func test_ready_configures_slots_from_balance() -> void:
	var infos: Array[SlotInfo] = _game.list_slots()
	assert_eq(infos.size(), int(DataRegistry.data.balance_value("slots.count")))
	assert_eq(infos[0].slot, 1)
	assert_eq(infos[0].state, &"empty")
	assert_true(GameClock.is_paused(), "the clock is paused in the menu")


func test_new_game_creates_saves_and_plays() -> void:
	var result: CommandResult = _game.new_game(2, "  Davide  ")
	assert_true(result.ok)
	assert_eq(_game.state, &"playing")
	assert_eq(_game.active_slot, 2)
	assert_not_null(_game.session)
	assert_eq(_game.session.get_parent(), _game, "the session is a child of Game")
	assert_eq(_game.session.events, EventBus)
	assert_eq(_game.session.player_name, "Davide", "edges stripped")
	assert_eq(_game.session.slot, 2)
	assert_eq(_game.session.created_at_unix_ms, NOW_MS)
	assert_eq(_game.session.wallet.get_gold(), int(DataRegistry.data.balance_value("start.gold")))
	assert_false(GameClock.is_paused())
	assert_eq(_saves, [2] as Array[int], "saved right away")
	assert_eq(_started, [[2, true]])
	var info: SlotInfo = SaveService.read_slot_info(2)
	assert_eq(info.state, &"ok")
	assert_eq(info.player_name, "Davide")
	assert_eq(info.saved_at_unix_ms, NOW_MS)


func test_new_seed_fits_in_53_bits() -> void:
	for slot: int in [1, 4]:
		_game.new_game(slot, "Seed")
		var seed_value: int = int(_game.session.rng.to_save()["seed"])
		assert_between(seed_value, 0, MAX_EXACT_JSON_INT - 1)
		_game.end_session(false)


func test_name_at_the_limits_of_balance_is_accepted() -> void:
	var min_length: int = int(DataRegistry.data.balance_value("player_name.min_length"))
	var max_length: int = int(DataRegistry.data.balance_value("player_name.max_length"))
	assert_eq([min_length, max_length], [1, 24], "values of 01_GDD.md §1")
	assert_true(_game.new_game(1, "x".repeat(min_length)).ok)
	_game.end_session(false)
	assert_true(_game.new_game(2, " %s " % "x".repeat(max_length)).ok, "edges do not count")


func test_name_outside_the_limits_of_balance_is_invalid() -> void:
	var min_length: int = int(DataRegistry.data.balance_value("player_name.min_length"))
	var max_length: int = int(DataRegistry.data.balance_value("player_name.max_length"))
	for player_name: String in ["x".repeat(min_length - 1), "   ", "x".repeat(max_length + 1)]:
		assert_eq(_game.new_game(1, player_name).reason, Reasons.INVALID_NAME, "'%s'" % player_name)
	assert_null(_game.session)
	assert_eq(_game.state, &"menu")


func test_invalid_slot_fails_without_session() -> void:
	for slot: int in [0, int(DataRegistry.data.balance_value("slots.count")) + 1]:
		var result: CommandResult = _game.new_game(slot, "Davide")
		assert_eq(result.reason, Reasons.IO_ERROR)
	assert_null(_game.session)
	assert_eq(_game.state, &"menu")


func test_new_game_while_playing_fails_with_slot_active() -> void:
	_game.new_game(1, "First")
	var first: GameSession = _game.session
	assert_eq(_game.new_game(2, "Second").reason, Reasons.SLOT_ACTIVE)
	assert_eq(_game.continue_game(1).reason, Reasons.SLOT_ACTIVE)
	assert_eq(_game.session, first)
	assert_false(SaveService.slot_exists(2))


func test_first_save_failure_discards_the_session() -> void:
	var saved_dir: String = SaveService.base_dir
	# A file where the folder should be: the store cannot create it.
	var blocker: String = TEST_DIR.path_join("blocker")
	FileAccess.open(blocker, FileAccess.WRITE).close()
	SaveService.base_dir = blocker
	var result: CommandResult = _game.new_game(1, "Davide")
	SaveService.base_dir = saved_dir
	assert_eq(result.reason, Reasons.IO_ERROR)
	assert_null(_game.session)
	assert_eq(_game.state, &"menu")
	assert_eq(_failures, [Reasons.IO_ERROR] as Array[StringName])
	assert_true(GameClock.is_paused())


func test_autosave_after_interval_of_clock_time() -> void:
	_game.new_game(1, "Davide")
	_saves.clear()
	_reset_clock()
	var interval_ms: int = int(DataRegistry.data.balance_value("autosave_interval_ms"))
	assert_eq(interval_ms, 10000)
	_simulate(interval_ms - FRAME_MS)
	assert_eq(_saves.size(), 0, "not before the interval")
	_simulate(FRAME_MS)
	assert_eq(_saves, [1] as Array[int], "10 s of clock: one save")
	assert_eq(_game.session.play_time_ms, interval_ms, "the clock advanced the session")
	var d: Dictionary = SaveService.read_slot(1)
	assert_eq(int(d["play_time_ms"]), interval_ms)


func test_clock_runs_the_action_lane() -> void:
	_game.new_game(1, "Davide")
	_reset_clock()
	assert_true(_game.session.actions.start(&"forestry", &"cut_redbirch").ok)
	var interval_ms: int = _game.session.actions.current_interval_ms(&"cut_redbirch")
	_simulate(interval_ms)
	assert_gt(_game.session.skills.get_xp(&"forestry"), 0)


func test_save_now_writes_and_signals() -> void:
	_game.new_game(3, "Davide")
	_saves.clear()
	_game.session.wallet.add_gold(7)
	assert_true(_game.save_now().ok)
	assert_eq(_saves, [3] as Array[int])
	var d: Dictionary = SaveService.read_slot(3)
	assert_eq(int(d["modules"]["wallet"]["gold"]), _game.session.wallet.get_gold())


func test_end_session_frees_session_and_returns_to_menu() -> void:
	_game.new_game(1, "Davide")
	var session: GameSession = _game.session
	_saves.clear()
	_game.end_session(true)
	assert_false(is_instance_valid(session))
	assert_null(_game.session)
	assert_eq(_game.active_slot, -1)
	assert_eq(_game.state, &"menu")
	assert_true(GameClock.is_paused())
	assert_eq(_saves, [1] as Array[int], "saved on the way out")
	assert_eq(_ended, [1] as Array[int])


func test_end_session_without_save_writes_nothing() -> void:
	_game.new_game(1, "Davide")
	_saves.clear()
	_game.end_session(false)
	assert_eq(_saves.size(), 0)


func test_no_autosave_after_end_session() -> void:
	_game.new_game(1, "Davide")
	_game.end_session(false)
	_saves.clear()
	GameClock.set_paused(false)
	_reset_clock()
	_simulate(int(DataRegistry.data.balance_value("autosave_interval_ms")) * 2)
	GameClock.set_paused(true)
	assert_eq(_saves.size(), 0)


func test_continue_restores_the_slot() -> void:
	_game.new_game(2, "Davide")
	_game.session.wallet.add_gold(100)
	var gold: int = _game.session.wallet.get_gold()
	var first: GameSession = _game.session
	_game.end_session(true)
	_saves.clear()
	_started.clear()
	var result: CommandResult = _game.continue_game(2)
	assert_true(result.ok)
	assert_eq(_game.state, &"playing")
	assert_ne(_game.session, first)
	assert_eq(_game.session.wallet.get_gold(), gold)
	assert_eq(_game.session.player_name, "Davide")
	assert_eq(_game.session.created_at_unix_ms, NOW_MS)
	assert_eq(_started, [[2, false]])
	assert_eq(_saves, [2] as Array[int], "saved after loading")
	assert_false(GameClock.is_paused())


func test_continue_empty_slot_fails() -> void:
	var result: CommandResult = _game.continue_game(1)
	assert_eq(result.reason, Reasons.IO_ERROR)
	assert_null(_game.session)
	assert_eq(_game.state, &"menu")


func test_continue_corrupted_slot_fails() -> void:
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	var file: FileAccess = FileAccess.open(SaveService.slot_path(1), FileAccess.WRITE)
	file.store_string("not json")
	file.close()
	var result: CommandResult = _game.continue_game(1)
	assert_eq(result.reason, Reasons.CORRUPTED)
	assert_null(_game.session)
	assert_eq(_game.state, &"menu")
	assert_eq(_started.size(), 0)


func test_delete_active_slot_fails_other_slot_ok() -> void:
	_game.new_game(1, "One")
	assert_eq(_game.delete_slot(1).reason, Reasons.SLOT_ACTIVE)
	assert_true(SaveService.slot_exists(1))
	_game.end_session(false)
	assert_true(_game.delete_slot(1).ok)
	assert_false(SaveService.slot_exists(1))


func test_close_request_saves_the_session() -> void:
	_game.new_game(1, "Davide")
	_saves.clear()
	_game.notification(NOTIFICATION_WM_CLOSE_REQUEST)
	assert_eq(_saves, [1] as Array[int])


func _reset_clock() -> void:
	var data: GameData = DataRegistry.data
	GameClock.configure(int(data.balance_value("tick_ms")), int(data.balance_value("max_catchup_ms")))


# At least `ms` of clock time, in whole frames of FRAME_MS.
func _simulate(ms: int) -> void:
	var frames: int = ceili(float(ms) / float(FRAME_MS))
	for i: int in frames:
		GameClock._process(FRAME_S)


func _on_event_bus_save_completed(slot: int) -> void:
	_saves.append(slot)


func _on_event_bus_save_failed(_slot: int, reason: StringName) -> void:
	_failures.append(reason)


func _on_event_bus_session_started(slot: int, is_new: bool) -> void:
	_started.append([slot, is_new])


func _on_event_bus_session_ended(slot: int) -> void:
	_ended.append(slot)


func _clear_dir(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for sub_dir: String in DirAccess.get_directories_at(path):
		_clear_dir(path.path_join(sub_dir))
		DirAccess.remove_absolute(path.path_join(sub_dir))
	for file_name: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file_name))
