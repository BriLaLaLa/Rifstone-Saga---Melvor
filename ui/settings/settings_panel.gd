class_name SettingsPanel
extends Control
## Settings panel, opened from the main menu and in game: video, audio and log level. "Applica" writes
## user://settings.cfg and applies at once (GameSettings). Settings are not per slot. With `in_game` = true there is
## also "Salva ed esci": it closes the session with a save (Game.end_session(true)) and goes back to the main menu.
##
## Injection points (set them before adding the node to the tree), for tests:
## - `game`: the coordinator; null means the `Game` autoload.
## - `scene_changer`: `(path: String) -> Error`; invalid means `get_tree().change_scene_to_file`.
## - `apply_window`: `() -> Window` used by "Applica"; invalid means `get_window()` (tests pass a scratch Window).

signal closed

const GameScript := preload("res://core/autoload/game.gd")
const MAIN_SCENE_SETTING: String = "application/run/main_scene"
const LOG_CATEGORY: String = "ui"
const TITLE_TEXT := "Impostazioni"
const VIDEO_HEADER_TEXT := "Video e audio"
const DIAGNOSTICS_HEADER_TEXT := "Diagnostica"
const MODE_TEXT := "Modalità finestra"
const SIZE_TEXT := "Dimensione finestra"
const SCALE_TEXT := "Scala interfaccia"
const FPS_TEXT := "Limite FPS"
const VSYNC_TEXT := "VSync"
const VOLUME_TEXT := "Volume"
const REDUCED_FX_TEXT := "Effetti visivi ridotti"
const LOG_LEVEL_TEXT := "Livello dei log"
const AUTO_SCALE_TEXT := "Automatica"
const NO_LIMIT_TEXT := "Nessun limite"
const CLOSE_TOOLTIP := "Chiudi"
const CLOSE_TEXT := "Chiudi"
const APPLY_TEXT := "Applica"
const SAVE_QUIT_TEXT := "Salva ed esci"
const QUIT_ICON: String = "door-exit"
const CLOSE_ICON: String = "x"
const CLOSE_BUTTON_SIDE: int = 32
const VOLUME_STEP: float = 0.05

## Set to true before adding the node to the tree when the panel is opened inside a session.
var in_game: bool = false
var game: GameScript = null
var scene_changer: Callable = Callable()
var apply_window: Callable = Callable()

var _mode: OptionButton
var _size: OptionButton
var _scale: OptionButton
var _fps: OptionButton
var _vsync: CheckBox
var _reduced_fx: CheckBox
var _volume: HSlider
var _log_level: OptionButton
var _apply_button: Button
var _close_button: Button
var _quit_button: Button = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = UiStyle.SETTINGS_DIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"WindowPanel"
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", UiStyle.SETTINGS_BLOCK_SEPARATION)
	panel.add_child(content)
	_build_title(content)
	content.add_child(_separator())
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", UiStyle.SETTINGS_SECTION_SEPARATION)
	content.add_child(column)
	_build_video(column)
	_build_diagnostics(column)
	content.add_child(_separator())
	_build_buttons(content)


func _build_title(parent: VBoxContainer) -> void:
	var top := HBoxContainer.new()
	parent.add_child(top)
	var title := Label.new()
	title.text = TITLE_TEXT
	title.theme_type_variation = &"TitleLabel"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var x: Button = UiStyle.icon_button(CLOSE_ICON, CLOSE_TOOLTIP, CLOSE_BUTTON_SIDE)
	x.pressed.connect(_close)
	top.add_child(x)


func _build_video(column: VBoxContainer) -> void:
	column.add_child(_header(VIDEO_HEADER_TEXT))
	var grid: GridContainer = _grid(column)
	_mode = _option(grid, MODE_TEXT, GameSettings.WINDOW_MODES, int(GameSettings.get_value(GameSettings.KEY_WINDOW_MODE)))
	var sizes: Array[String] = []
	for v: Vector2i in GameSettings.WINDOW_SIZES:
		sizes.append("%d × %d" % [v.x, v.y])
	_size = _option(grid, SIZE_TEXT, sizes, int(GameSettings.get_value(GameSettings.KEY_WINDOW_SIZE)))
	var scales: Array[String] = []
	for s: float in GameSettings.UI_SCALES:
		scales.append(AUTO_SCALE_TEXT if s == 0.0 else "%d%%" % int(round(s * 100.0)))
	var scale_index: int = GameSettings.UI_SCALES.find(float(GameSettings.get_value(GameSettings.KEY_UI_SCALE)))
	_scale = _option(grid, SCALE_TEXT, scales, scale_index)
	var limits: Array[String] = []
	for f: int in GameSettings.FPS_LIMITS:
		limits.append(NO_LIMIT_TEXT if f == 0 else str(f))
	var fps_index: int = GameSettings.FPS_LIMITS.find(int(GameSettings.get_value(GameSettings.KEY_FPS_LIMIT)))
	_fps = _option(grid, FPS_TEXT, limits, fps_index)
	_vsync = _check(grid, VSYNC_TEXT, bool(GameSettings.get_value(GameSettings.KEY_VSYNC)))
	_reduced_fx = _check(grid, REDUCED_FX_TEXT, bool(GameSettings.get_value(GameSettings.KEY_REDUCED_FX)))
	_label(grid, VOLUME_TEXT)
	_volume = HSlider.new()
	_volume.min_value = 0.0
	_volume.max_value = 1.0
	_volume.step = VOLUME_STEP
	_volume.value = float(GameSettings.get_value(GameSettings.KEY_VOLUME))
	_volume.custom_minimum_size = Vector2(UiStyle.SETTINGS_OPTION_WIDTH, 0)
	_volume.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grid.add_child(_volume)
	_mode.item_selected.connect(func(i: int) -> void: _size.disabled = i != 0)
	_size.disabled = _mode.selected != 0


func _build_diagnostics(column: VBoxContainer) -> void:
	column.add_child(_header(DIAGNOSTICS_HEADER_TEXT))
	var grid: GridContainer = _grid(column)
	_log_level = _option(grid, LOG_LEVEL_TEXT, GameSettings.LOG_LEVELS, int(GameSettings.get_value(GameSettings.KEY_LOG_LEVEL)))


func _build_buttons(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiStyle.SETTINGS_BUTTON_ROW_SEPARATION)
	parent.add_child(row)
	if in_game:
		_quit_button = Button.new()
		_quit_button.text = SAVE_QUIT_TEXT
		_quit_button.icon = UiStyle.icon(QUIT_ICON)
		_quit_button.add_theme_constant_override("icon_max_width", UiStyle.SETTINGS_BUTTON_ICON_SIDE)
		_quit_button.pressed.connect(_save_and_quit)
		row.add_child(_quit_button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_close_button = Button.new()
	_close_button.text = CLOSE_TEXT
	_close_button.pressed.connect(_close)
	row.add_child(_close_button)
	_apply_button = Button.new()
	_apply_button.text = APPLY_TEXT
	_apply_button.theme_type_variation = &"AccentButton"
	_apply_button.pressed.connect(_apply)
	row.add_child(_apply_button)


# ==================== ACTIONS ====================

func _apply() -> void:
	GameSettings.set_value(GameSettings.KEY_WINDOW_MODE, _mode.selected)
	GameSettings.set_value(GameSettings.KEY_WINDOW_SIZE, _size.selected)
	GameSettings.set_value(GameSettings.KEY_UI_SCALE, GameSettings.UI_SCALES[_scale.selected])
	GameSettings.set_value(GameSettings.KEY_FPS_LIMIT, GameSettings.FPS_LIMITS[_fps.selected])
	GameSettings.set_value(GameSettings.KEY_VSYNC, _vsync.button_pressed)
	GameSettings.set_value(GameSettings.KEY_REDUCED_FX, _reduced_fx.button_pressed)
	GameSettings.set_value(GameSettings.KEY_VOLUME, _volume.value)
	GameSettings.set_value(GameSettings.KEY_LOG_LEVEL, _log_level.selected)
	GameSettings.save()
	var window: Window = apply_window.call() as Window if apply_window.is_valid() else get_window()
	GameSettings.apply(window)


func _close() -> void:
	closed.emit()
	queue_free()


# Closes the session with a save and goes back to the main menu.
func _save_and_quit() -> void:
	var coordinator: GameScript = game if game != null else Game
	coordinator.end_session(true)
	var path: String = str(ProjectSettings.get_setting(MAIN_SCENE_SETTING))
	var err: int = OK
	if scene_changer.is_valid():
		err = int(scene_changer.call(path))
	else:
		err = get_tree().change_scene_to_file(path)
	if err != OK:
		Log.error(LOG_CATEGORY, "cannot open %s (error %d)" % [path, err])


# ==================== PIECES ====================

func _header(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = &"HeaderLabel"
	return l


func _separator() -> HSeparator:
	var s := HSeparator.new()
	s.add_theme_stylebox_override("separator", UiStyle.line(UiStyle.GOLD_DIM))
	return s


func _grid(column: VBoxContainer) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", UiStyle.SETTINGS_GRID_H_SEPARATION)
	grid.add_theme_constant_override("v_separation", UiStyle.SETTINGS_SECTION_SEPARATION)
	column.add_child(grid)
	return grid


func _label(grid: GridContainer, text: String) -> void:
	var l := Label.new()
	l.text = text
	grid.add_child(l)


func _check(grid: GridContainer, text: String, on: bool) -> CheckBox:
	_label(grid, text)
	var c := CheckBox.new()
	c.button_pressed = on
	grid.add_child(c)
	return c


func _option(grid: GridContainer, text: String, items: Array[String], selected: int) -> OptionButton:
	_label(grid, text)
	var o := OptionButton.new()
	for item: String in items:
		o.add_item(item)
	o.select(clampi(selected, 0, items.size() - 1))
	o.custom_minimum_size = Vector2(UiStyle.SETTINGS_OPTION_WIDTH, 0)
	grid.add_child(o)
	return o
