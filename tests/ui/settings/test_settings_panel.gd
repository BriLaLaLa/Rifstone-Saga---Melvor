extends GutTest
## SettingsPanel (M9-03): builds, Apply writes the settings file, Close frees it, "Salva ed esci" only in game and
## through Game.end_session(true) (fake coordinator), no "rivedi suggerimenti".

const PreRun := preload("res://tests/helpers/gut_pre_run.gd")


class FakeGame:
	extends "res://core/autoload/game.gd"
	var calls: Array[String] = []

	func end_session(save: bool = true) -> void:
		calls.append("end_session:%s" % save)


var _dir: String = PreRun.test_dir("test_settings_panel")
var _file: String = _dir.path_join("settings.cfg")
var _old_level: Log.Level
var _fake: FakeGame = null
var _scenes: Array[String] = []
var _window: Window = null


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(_dir)
	DirAccess.remove_absolute(_file)
	_old_level = Log.level
	GameSettings.file_path = _file
	GameSettings.reset()
	_fake = FakeGame.new()
	_scenes = []
	_window = Window.new()
	add_child_autofree(_window)


func after_each() -> void:
	_fake.free()
	DirAccess.remove_absolute(_file)
	GameSettings.file_path = GameSettings.FILE
	GameSettings.reset()
	Log.level = _old_level
	Engine.max_fps = 0


func _panel(in_game: bool) -> SettingsPanel:
	var p := SettingsPanel.new()
	p.in_game = in_game
	p.game = _fake
	p.scene_changer = func(path: String) -> Error:
		_scenes.append(path)
		return OK
	p.apply_window = func() -> Window: return _window
	add_child_autoqfree(p)
	return p


func _buttons(root: Node) -> Dictionary:
	var found: Dictionary = {}
	for n: Node in root.find_children("*", "Button", true, false):
		found[(n as Button).text] = n
	return found


func test_menu_panel_has_no_quit_button_and_no_hints() -> void:
	var buttons: Dictionary = _buttons(_panel(false))
	assert_true(buttons.has("Applica"))
	assert_true(buttons.has("Chiudi"))
	assert_false(buttons.has("Salva ed esci"))
	assert_false(buttons.has("Rivedi i suggerimenti"))


func test_in_game_panel_has_quit_button() -> void:
	assert_true(_buttons(_panel(true)).has("Salva ed esci"))


func test_save_and_quit_saves_and_returns_to_menu() -> void:
	var panel: SettingsPanel = _panel(true)
	(_buttons(panel)["Salva ed esci"] as Button).pressed.emit()
	assert_eq(_fake.calls, ["end_session:true"] as Array[String])
	assert_eq(_scenes, [str(ProjectSettings.get_setting("application/run/main_scene"))] as Array[String])


func test_apply_writes_file_with_chosen_values() -> void:
	var panel: SettingsPanel = _panel(false)
	var options: Array[Node] = panel.find_children("*", "OptionButton", true, false)
	var fps: OptionButton = options[3] as OptionButton
	fps.select(GameSettings.FPS_LIMITS.find(60))
	var log_level: OptionButton = options[4] as OptionButton
	log_level.select(2)
	(panel.find_children("*", "CheckBox", true, false)[0] as CheckBox).button_pressed = false
	(_buttons(panel)["Applica"] as Button).pressed.emit()
	GameSettings.reset()
	assert_eq(GameSettings.get_value("fps_limit"), 60)
	assert_eq(GameSettings.get_value("log_level"), 2)
	assert_false(bool(GameSettings.get_value("vsync")))
	assert_eq(Log.level, Log.Level.WARN)


func test_close_emits_and_frees() -> void:
	var panel: SettingsPanel = _panel(false)
	watch_signals(panel)
	(_buttons(panel)["Chiudi"] as Button).pressed.emit()
	assert_signal_emitted(panel, "closed")
	await wait_process_frames(2)
	assert_false(is_instance_valid(panel))


func test_main_menu_settings_button_opens_panel() -> void:
	var menu: Control = (load("res://ui/screens/main_menu/main_menu.tscn") as PackedScene).instantiate() as Control
	add_child_autofree(menu)
	(menu.get_node("%SettingsButton") as Button).pressed.emit()
	var found: Array[Node] = menu.get_children().filter(func(n: Node) -> bool: return n is SettingsPanel)
	assert_eq(found.size(), 1)
