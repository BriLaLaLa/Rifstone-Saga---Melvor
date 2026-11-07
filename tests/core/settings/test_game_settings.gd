extends GutTest
## GameSettings (M9-03): defaults, validation, save/load round trip in a scratch file, log level, UI scale.

const PreRun := preload("res://tests/helpers/gut_pre_run.gd")

var _dir: String = PreRun.test_dir("test_game_settings")
var _file: String = _dir.path_join("settings.cfg")
var _old_level: Log.Level


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(_dir)
	DirAccess.remove_absolute(_file)
	_old_level = Log.level
	GameSettings.file_path = _file
	GameSettings.reset()


func after_each() -> void:
	DirAccess.remove_absolute(_file)
	GameSettings.file_path = GameSettings.FILE
	GameSettings.reset()
	Log.level = _old_level


func test_defaults_without_file() -> void:
	for key: String in GameSettings.DEFAULTS:
		assert_eq(GameSettings.get_value(key), GameSettings.DEFAULTS[key], key)


func test_keys_are_the_contract_ones() -> void:
	var keys: Array = GameSettings.DEFAULTS.keys()
	keys.sort()
	assert_eq(keys, ["fps_limit", "log_level", "ui_scale", "volume", "vsync", "window_mode", "window_size"])


func test_save_and_reload_round_trip() -> void:
	GameSettings.set_value("volume", 0.35)
	GameSettings.set_value("vsync", false)
	GameSettings.set_value("fps_limit", 60)
	GameSettings.set_value("ui_scale", 1.25)
	GameSettings.set_value("log_level", 3)
	GameSettings.save()
	assert_true(FileAccess.file_exists(_file))
	GameSettings.reset()
	assert_almost_eq(float(GameSettings.get_value("volume")), 0.35, 0.0001)
	assert_false(bool(GameSettings.get_value("vsync")))
	assert_eq(GameSettings.get_value("fps_limit"), 60)
	assert_eq(GameSettings.get_value("ui_scale"), 1.25)
	assert_eq(GameSettings.get_value("log_level"), 3)


func test_unknown_key_is_an_error_and_not_stored() -> void:
	assert_null(GameSettings.get_value("quality"))
	GameSettings.set_value("quality", "Alta")
	assert_push_error(2)


func test_invalid_value_is_rejected() -> void:
	GameSettings.set_value("volume", 1.5)
	GameSettings.set_value("fps_limit", 75)
	GameSettings.set_value("vsync", "yes")
	GameSettings.set_value("log_level", 9)
	assert_push_error(4)
	assert_eq(GameSettings.get_value("volume"), GameSettings.DEFAULTS["volume"])
	assert_eq(GameSettings.get_value("fps_limit"), 0)
	assert_eq(GameSettings.get_value("log_level"), 1)


func test_invalid_stored_value_falls_back_to_default() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("settings", "window_size", 99)
	cfg.set_value("settings", "volume", 0.5)
	cfg.save(_file)
	assert_eq(GameSettings.get_value("window_size"), GameSettings.DEFAULTS["window_size"])
	assert_eq(GameSettings.get_value("volume"), 0.5)


func test_apply_log_level_sets_the_logger() -> void:
	GameSettings.set_value("log_level", int(Log.Level.WARN))
	GameSettings.apply_log_level()
	assert_eq(Log.level, Log.Level.WARN)
	assert_eq(GameSettings.LOG_LEVELS.size(), Log.Level.size())


func test_ui_scale_explicit_and_automatic() -> void:
	var win := Window.new()
	add_child_autofree(win)
	GameSettings.set_value("ui_scale", 1.5)
	assert_eq(GameSettings.ui_scale(win), 1.5)
	GameSettings.set_value("ui_scale", 0.0)
	var auto: float = GameSettings.ui_scale(win)
	assert_between(auto, GameSettings.AUTO_SCALE_MIN, GameSettings.AUTO_SCALE_MAX)


func test_save_writes_only_the_settings_file() -> void:
	GameSettings.save()
	var files: PackedStringArray = DirAccess.get_files_at(_dir)
	assert_eq(files, PackedStringArray(["settings.cfg"]))
