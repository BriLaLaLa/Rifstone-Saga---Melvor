extends SceneTree
## Generates data/quests/quests.json (M20-02, docs/02_FORMULAS.md F-134, docs/04_DATA_SCHEMA.md §25): the 56 Noticeboard quests,
## from balance.json `quest`, data/actions/ (producer and level of each item) and data/items/ (names). Idempotent: rerunning
## it does not change the file. Fails (exit 1, nothing written) if an item does not exist or is not produced by an action of
## its skill. The output is committed: the game never runs this script. `--check` writes nothing and exits 1 if the file
## differs from the generated text.
##
## Usage: godot --headless --path . -s tools/gen_quests.gd [-- --check]

const BALANCE_PATH: String = "res://data/config/balance.json"
const QUESTS_PATH: String = "res://data/quests/quests.json"
const ITEMS_DIR: String = "res://data/items"
const ACTIONS_DIR: String = "res://data/actions"
const VALIDATOR_PATH: String = "res://core/data/data_validator_quests.gd"


func _initialize() -> void:
	var check_only: bool = OS.get_cmdline_user_args().has("--check")
	var balance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BALANCE_PATH)) as Dictionary
	var result: Dictionary = generate(balance["quest"] as Dictionary, read_dir(ITEMS_DIR), read_dir(ACTIONS_DIR))
	for message: String in result["errors"] as PackedStringArray:
		printerr("gen_quests: " + message)
	if not (result["errors"] as PackedStringArray).is_empty():
		quit(1)
		return
	var text: String = result["text"] as String
	var current: String = FileAccess.get_file_as_string(QUESTS_PATH)
	if check_only:
		print_rich("gen_quests: " + ("up to date" if text == current else "OUT OF DATE (rerun tools/gen_quests.gd)"))
		quit(0 if text == current else 1)
		return
	if text != current:
		var file: FileAccess = FileAccess.open(QUESTS_PATH, FileAccess.WRITE)
		file.store_string(text)
		file.close()
	print_rich("gen_quests: %s" % ("written" if text != current else "unchanged"))
	quit(0)


## F-134 for one quest (same pure function as the validator uses). `lookup` is DataValidatorQuests.lookup_from.
static func quest_for(type: String, skill: String, tier: int, params: Dictionary, lookup: Dictionary) -> Dictionary:
	# Loaded at run time: this script starts before the autoloads exist and the validator classes need `Log`.
	return (load(VALIDATOR_PATH) as GDScript).call("quest_for", type, skill, tier, params, lookup) as Dictionary


## `{"text": String, "errors": PackedStringArray}`: the whole file text for the `quest` parameters and the parsed files of
## data/items/ and data/actions/ (path -> object). With errors the text is empty.
static func generate(params: Dictionary, items_files: Dictionary, actions_files: Dictionary) -> Dictionary:
	var validator: GDScript = load(VALIDATOR_PATH) as GDScript
	var lookup: Dictionary = validator.call("lookup_from", items_files, actions_files) as Dictionary
	var all: Dictionary = validator.call("all_for", params, lookup) as Dictionary
	var errors: PackedStringArray = all["errors"] as PackedStringArray
	if not errors.is_empty():
		return {"text": "", "errors": errors}
	var rows: PackedStringArray = []
	for quest: Dictionary in all["quests"] as Array:
		rows.append("    " + JSON.stringify(quest, "", false))
	return {"text": '{\n  "quests": [\n%s\n  ]\n}\n' % ",\n".join(rows), "errors": errors}


## The parsed `.json` files of a folder: `{path: top-level object}`.
static func read_dir(dir: String) -> Dictionary:
	var files: Dictionary = {}
	for file: String in DirAccess.get_files_at(dir):
		if file.ends_with(".json"):
			files[dir.path_join(file)] = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join(file)))
	return files
