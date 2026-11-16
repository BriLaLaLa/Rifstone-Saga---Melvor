extends SceneTree
## Generates data/auction/auction_items.json (M23-02, docs/04_DATA_SCHEMA.md §28, docs/01_GDD.md §34.2): every `material`,
## `component` and `food` item with `value >= 1`, with the Auction House level at which a component or food can be bought.
## The rule is DataValidatorAuction.build (the validator compares the file with it). Idempotent. Fails (exit 1, nothing
## written) if a component or food is produced by no action or at a level outside `village.woodwright_levels`.
## `--lenient` (the minimal test fixtures, whose loose components no action produces) makes such an item sell-only instead of an
## error. `--check` writes nothing and exits 1 if the file differs from the generated text.
##
## Usage: godot --headless --path . -s tools/gen_auction.gd [-- [<content_root> [<config_root>]] [--check] [--lenient]]
## Defaults: res://data and res://data/config (fixtures: `-- res://tests/fixtures/data`; the M10 snapshot has its own config).

const VALIDATOR_PATH: String = "res://core/data/data_validator_auction.gd"
const FILE: String = "auction/auction_items.json"


func _initialize() -> void:
	var args: PackedStringArray = []
	for arg: String in OS.get_cmdline_user_args():
		if not arg.begins_with("--"):
			args.append(arg)
	var content_root: String = args[0] if args.size() > 0 else "res://data"
	var config_root: String = args[1] if args.size() > 1 else "res://data/config"
	var balance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(config_root.path_join("balance.json"))) as Dictionary
	var tier_levels: Array = ((balance["village"] as Dictionary)["woodwright_levels"]) as Array
	var generated: Dictionary = build(read_all(content_root.path_join("items"), "items"),
			read_all(content_root.path_join("actions"), "actions"), tier_levels, not OS.get_cmdline_user_args().has("--lenient"))
	for message: String in generated["errors"] as PackedStringArray:
		printerr("gen_auction: " + message)
	if not (generated["errors"] as PackedStringArray).is_empty():
		quit(1)
		return
	var text: String = generated["text"] as String
	var path: String = content_root.path_join(FILE)
	var current: String = FileAccess.get_file_as_string(path)
	if OS.get_cmdline_user_args().has("--check"):
		print_rich("gen_auction: " + ("up to date" if text == current else "OUT OF DATE (rerun tools/gen_auction.gd)"))
		quit(0 if text == current else 1)
		return
	if text != current:
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		file.store_string(text)
		file.close()
	print_rich("gen_auction: %s (%d items)" % ["written" if text != current else "unchanged", (generated["entries"] as Array).size()])
	quit(0)


## `{"entries": Array[Dictionary], "errors": PackedStringArray, "text": String}` for the raw `items` and `actions` lists
## and `village.woodwright_levels`. Loaded at run time: this script starts before the autoloads exist and the validator
## classes need `Log`.
static func build(items: Array, actions: Array, tier_levels: Array, strict: bool = true) -> Dictionary:
	var validator: GDScript = load(VALIDATOR_PATH) as GDScript
	var result: Dictionary = validator.call("build", items, actions, tier_levels, strict) as Dictionary
	result["text"] = validator.call("file_text", result["entries"]) as String if (result["errors"] as PackedStringArray).is_empty() else ""
	return result


## The pure rule of §28 (same function as the validator uses).
static func entries(items: Array, actions: Array, tier_levels: Array, strict: bool = true) -> Array[Dictionary]:
	return build(items, actions, tier_levels, strict)["entries"] as Array[Dictionary]


## The entries of the list `key` of every `.json` file in a folder, in file order.
static func read_all(dir: String, key: String) -> Array:
	var result: Array = []
	for file: String in DirAccess.get_files_at(dir):
		if file.ends_with(".json"):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join(file)))
			if parsed is Dictionary and (parsed as Dictionary).get(key) is Array:
				result.append_array((parsed as Dictionary)[key] as Array)
	return result
