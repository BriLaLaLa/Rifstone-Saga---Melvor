extends SceneTree
## Validates the game data and exits with code 1 if it is not valid (docs/03_ARCHITECTURE.md §10).
##
## Usage: godot --headless --path . -s tools/validate_data.gd [-- <content_root> [<config_root>]]
## Defaults: res://data and res://data/config (fixtures: `-- res://tests/fixtures/data`).
## Output goes through printerr/print_rich, like the other tools. The DataRegistry autoload also loads res://data
## at startup and logs its own result: the lines of this tool are the ones prefixed with "validate_data".
##
## GameData (and the Def classes it compiles) use the Log autoload, whose global name does not exist yet while a
## `-s` script is being compiled. So GameData is loaded by path in `_initialize()`, when the autoloads exist, and is
## not referenced by type here: its API is reached through the loaded script.

const GAME_DATA_PATH: String = "res://core/data/game_data.gd"
const DEFAULT_CONTENT_ROOT: String = "res://data"
const DEFAULT_CONFIG_ROOT: String = "res://data/config"


func _initialize() -> void:
	quit(_run())


func _run() -> int:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var content_root: String = args[0] if args.size() > 0 else DEFAULT_CONTENT_ROOT
	var config_root: String = args[1] if args.size() > 1 else DEFAULT_CONFIG_ROOT
	var game_data: GDScript = load(GAME_DATA_PATH) as GDScript
	if game_data == null:
		printerr("validate_data: cannot load %s" % GAME_DATA_PATH)
		return 1
	var data: RefCounted = game_data.call("load_from_dirs", content_root, config_root) as RefCounted
	var errors: PackedStringArray = data.get("errors") as PackedStringArray
	if errors.is_empty():
		print_rich("validate_data: OK (%s, %s)" % [content_root, config_root])
		return 0
	for message: String in errors:
		printerr("validate_data: %s" % message)
	printerr("validate_data: FAILED (%d errors in %s, %s)" % [errors.size(), content_root, config_root])
	return 1
