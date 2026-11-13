class_name GameSettings
extends RefCounted
## Game settings (user://settings.cfg): the only file written outside the save slots (docs/05_INTERFACES.md §5.14).
##
## Static and lazy: the file is read on the first access. Applied at startup (main menu) and by the settings panel.
## The UI base size is the real window size divided by the UI scale, so there is no stretching at any resolution.
## Unknown keys are programming errors (logged, no silent default); a stored value of the wrong type or outside its
## choices is replaced by the default with a warning, because the file is user-editable.

const FILE: String = "user://settings.cfg"
const SECTION: String = "settings"
const LOG_CATEGORY: String = "settings"

const WINDOW_MODES: Array[String] = ["Finestra", "Schermo intero", "Senza bordi"]
const WINDOW_SIZES: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]
## 0.0 = automatic (from the screen height).
const UI_SCALES: Array[float] = [0.0, 0.75, 0.9, 1.0, 1.1, 1.25, 1.5, 2.0]
## 0 = no limit.
const FPS_LIMITS: Array[int] = [0, 30, 60, 120, 144]
## Index = `Log.Level` value (DEBUG, INFO, WARN, ERROR).
const LOG_LEVELS: Array[String] = ["Debug", "Info", "Avvisi", "Errori"]

const KEY_WINDOW_MODE: String = "window_mode"
const KEY_WINDOW_SIZE: String = "window_size"
const KEY_UI_SCALE: String = "ui_scale"
const KEY_VSYNC: String = "vsync"
const KEY_FPS_LIMIT: String = "fps_limit"
const KEY_VOLUME: String = "volume"
const KEY_LOG_LEVEL: String = "log_level"
## Reduced visual effects of the combat page (no breathing, pulses, shake, bar easing).
const KEY_REDUCED_FX: String = "reduced_fx"

const AUTO_SCALE_REFERENCE_HEIGHT: float = 1080.0
const AUTO_SCALE_STEP: float = 0.25
const AUTO_SCALE_MIN: float = 0.75
const AUTO_SCALE_MAX: float = 2.0
const MIN_LINEAR_VOLUME: float = 0.0001
const MASTER_BUS: String = "Master"

const DEFAULTS: Dictionary[String, Variant] = {
	KEY_WINDOW_MODE: 0,
	KEY_WINDOW_SIZE: 1,
	KEY_UI_SCALE: 0.0,
	KEY_VSYNC: true,
	KEY_FPS_LIMIT: 0,
	KEY_VOLUME: 0.8,
	KEY_LOG_LEVEL: 1,
	KEY_REDUCED_FX: false,
}

## Path of the settings file; tests point it to a scratch folder.
static var file_path: String = FILE

static var _values: Dictionary[String, Variant] = {}
static var _loaded: bool = false
static var _connected_window: Window = null


## Current value of `key`; an unknown key is logged as an error and returns null.
static func get_value(key: String) -> Variant:
	if not DEFAULTS.has(key):
		Log.error(LOG_CATEGORY, "unknown setting '%s'" % key)
		return null
	_ensure_loaded()
	return _values[key]


## Sets `key` in memory (written by `save`). Unknown keys and values of the wrong type or outside the choices are
## rejected with an error log and leave the setting unchanged.
static func set_value(key: String, value: Variant) -> void:
	if not DEFAULTS.has(key):
		Log.error(LOG_CATEGORY, "unknown setting '%s'" % key)
		return
	if not _is_valid(key, value):
		Log.error(LOG_CATEGORY, "invalid value %s for setting '%s'" % [str(value), key])
		return
	_ensure_loaded()
	_values[key] = _normalized(key, value)


## Writes all settings to `file_path`; logs an error if the write fails.
static func save() -> void:
	_ensure_loaded()
	var cfg := ConfigFile.new()
	for key: String in DEFAULTS:
		cfg.set_value(SECTION, key, _values[key])
	var err: Error = cfg.save(file_path)
	if err != OK:
		Log.error(LOG_CATEGORY, "cannot write %s (error %d)" % [file_path, err])


## Forgets the in-memory values: the next access reads the file again (tests, "restore from disk").
static func reset() -> void:
	_values = {}
	_loaded = false


## Effective UI scale: automatic = screen height / 1080 in steps of 0.25 (1080p 100%, 1440p 150%, 4K 200%).
static func ui_scale(window: Window) -> float:
	var scale: float = float(get_value(KEY_UI_SCALE))
	if scale > 0.0:
		return scale
	var screen: Vector2i = DisplayServer.screen_get_size(window.current_screen)
	var steps: float = round(screen.y / AUTO_SCALE_REFERENCE_HEIGHT / AUTO_SCALE_STEP)
	return clampf(steps * AUTO_SCALE_STEP, AUTO_SCALE_MIN, AUTO_SCALE_MAX)


## Applies everything: window, UI scale, vsync, fps limit, volume, log level. Call at startup and after "Applica".
static func apply(window: Window) -> void:
	_ensure_loaded()
	match int(get_value(KEY_WINDOW_MODE)):
		1:
			window.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
		2:
			window.mode = Window.MODE_FULLSCREEN
		_:
			_apply_windowed(window)
	var vsync: DisplayServer.VSyncMode = DisplayServer.VSYNC_ENABLED if bool(get_value(KEY_VSYNC)) else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(vsync)
	Engine.max_fps = int(get_value(KEY_FPS_LIMIT))
	apply_volume()
	apply_log_level()
	apply_ui_scale(window)


## Master bus volume from the `volume` setting (linear 0-1).
static func apply_volume() -> void:
	var bus: int = AudioServer.get_bus_index(MASTER_BUS)
	if bus < 0:
		return
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(float(get_value(KEY_VOLUME)), MIN_LINEAR_VOLUME)))


## Minimum level of the `Log` autoload from the `log_level` setting.
static func apply_log_level() -> void:
	Log.level = int(get_value(KEY_LOG_LEVEL)) as Log.Level


## Only the UI scale (no window change): the session screen can use it on entry.
static func apply_ui_scale(window: Window) -> void:
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	_fit_content(window)
	if _connected_window != window:
		_connected_window = window
		window.size_changed.connect(func() -> void: _fit_content(window))


static func _apply_windowed(window: Window) -> void:
	window.mode = Window.MODE_WINDOWED
	var size: Vector2i = WINDOW_SIZES[int(get_value(KEY_WINDOW_SIZE))]
	var screen: Rect2i = DisplayServer.screen_get_usable_rect(window.current_screen)
	size = Vector2i(mini(size.x, screen.size.x), mini(size.y, screen.size.y))
	if window.size != size:
		window.size = size
		window.position = screen.position + (screen.size - size) / 2


static func _fit_content(window: Window) -> void:
	var scale: float = ui_scale(window)
	window.content_scale_size = Vector2i(maxi(1, int(window.size.x / scale)), maxi(1, int(window.size.y / scale)))


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_values = DEFAULTS.duplicate()
	var cfg := ConfigFile.new()
	var err: Error = cfg.load(file_path)
	if err != OK:
		if err != ERR_FILE_NOT_FOUND:
			Log.warn(LOG_CATEGORY, "cannot read %s (error %d): defaults used" % [file_path, err])
		return
	for key: String in DEFAULTS:
		var stored: Variant = cfg.get_value(SECTION, key, DEFAULTS[key])
		if _is_valid(key, stored):
			_values[key] = _normalized(key, stored)
		else:
			Log.warn(LOG_CATEGORY, "invalid stored value %s for '%s': default used" % [str(stored), key])


static func _is_valid(key: String, value: Variant) -> bool:
	match key:
		KEY_WINDOW_MODE:
			return value is int and int(value) >= 0 and int(value) < WINDOW_MODES.size()
		KEY_WINDOW_SIZE:
			return value is int and int(value) >= 0 and int(value) < WINDOW_SIZES.size()
		KEY_UI_SCALE:
			return (value is float or value is int) and UI_SCALES.has(float(value))
		KEY_VSYNC, KEY_REDUCED_FX:
			return value is bool
		KEY_FPS_LIMIT:
			return value is int and FPS_LIMITS.has(int(value))
		KEY_VOLUME:
			return (value is float or value is int) and float(value) >= 0.0 and float(value) <= 1.0
		KEY_LOG_LEVEL:
			return value is int and int(value) >= 0 and int(value) < LOG_LEVELS.size()
	return false


static func _normalized(key: String, value: Variant) -> Variant:
	if key == KEY_UI_SCALE or key == KEY_VOLUME:
		return float(value)
	return value
