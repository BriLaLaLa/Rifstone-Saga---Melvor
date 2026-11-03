extends GutTest
## Lesson "no save before a slot": until new_game no file appears in the saves folder, whatever the menu does.
##
## Uses a private instance of game.gd (never the Game autoload with real slots). SaveService points at
## user://test_saves (gut_pre_run.gd); the folder is emptied before each test.

const GameScript := preload("res://core/autoload/game.gd")
const TEST_DIR: String = "user://test_saves"
const FRAME_S: float = 0.5

var _game: GameScript


func before_each() -> void:
	_clear_dir(TEST_DIR)
	_game = GameScript.new()
	add_child_autofree(_game)


func after_each() -> void:
	_game.end_session(false)
	_clear_dir(TEST_DIR)


func test_saves_point_at_test_folder() -> void:
	assert_eq(SaveService.base_dir, TEST_DIR)


func test_menu_commands_write_nothing() -> void:
	assert_eq(_game.state, &"menu")
	assert_eq(_game.list_slots().size(), _slot_count())
	var saved: CommandResult = _game.save_now()
	assert_false(saved.ok)
	assert_eq(saved.reason, Reasons.SLOT_NOT_SELECTED)
	var loaded: CommandResult = _game.continue_game(1)
	assert_false(loaded.ok)
	assert_eq(_game.state, &"menu")
	_game.delete_slot(1)
	_game.end_session(true)
	_game.notification(NOTIFICATION_WM_CLOSE_REQUEST)
	assert_null(_game.session)
	assert_eq(_files_in(TEST_DIR), [] as Array[String])


func test_clock_running_in_menu_writes_nothing() -> void:
	var interval_s: float = float(DataRegistry.data.balance_value("autosave_interval_ms")) / 1000.0
	GameClock.set_paused(false)
	var frames: int = int(ceilf(interval_s * 3.0 / FRAME_S))
	for i: int in frames:
		GameClock._process(FRAME_S)
	GameClock.set_paused(true)
	assert_eq(_files_in(TEST_DIR), [] as Array[String])


func test_invalid_name_writes_nothing() -> void:
	for player_name: String in ["", "   ", "x".repeat(25)]:
		var result: CommandResult = _game.new_game(1, player_name)
		assert_eq(result.reason, Reasons.INVALID_NAME, "'%s'" % player_name)
	assert_null(_game.session)
	assert_eq(_files_in(TEST_DIR), [] as Array[String])


func test_new_game_is_the_first_write() -> void:
	assert_eq(_files_in(TEST_DIR), [] as Array[String])
	var result: CommandResult = _game.new_game(1, "Davide")
	assert_true(result.ok)
	assert_eq(_files_in(TEST_DIR), ["slot_1.json"] as Array[String])


func _slot_count() -> int:
	return int(DataRegistry.data.balance_value("slots.count"))


func _files_in(path: String) -> Array[String]:
	var files: Array[String] = []
	if not DirAccess.dir_exists_absolute(path):
		return files
	for sub_dir: String in DirAccess.get_directories_at(path):
		for file_name: String in _files_in(path.path_join(sub_dir)):
			files.append(sub_dir.path_join(file_name))
	for file_name: String in DirAccess.get_files_at(path):
		files.append(file_name)
	return files


func _clear_dir(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for sub_dir: String in DirAccess.get_directories_at(path):
		_clear_dir(path.path_join(sub_dir))
		DirAccess.remove_absolute(path.path_join(sub_dir))
	for file_name: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file_name))
