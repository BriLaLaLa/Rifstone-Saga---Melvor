extends GutTest
## Base class of the M10 data tests (not a test file: GUT only runs `test_*.gd`). Gives the `raw` dictionary of
## DataValidator for the M10 fixtures (res://tests/fixtures/data/m10, 04_DATA_SCHEMA.md §18: its own balance.json and
## stats.json in `config/`), a fresh copy at each call, and the helpers to break one rule and expect one error.

const PreRun := preload("res://tests/helpers/gut_pre_run.gd")
const M10_ROOT: String = "res://tests/fixtures/data/m10"
const M10_CONFIG: String = "res://tests/fixtures/data/m10/config"
const BALANCE: String = "balance.json"


static func m10_raw() -> Dictionary:
	var errors: PackedStringArray = []
	var raw: Dictionary = {
		"balance": _read([M10_CONFIG.path_join(GameData.BALANCE_FILE)], errors),
		"stats": _read([M10_CONFIG.path_join(GameData.STATS_FILE)], errors),
	}
	for section: String in GameData.CONTENT_FILES:
		raw[section] = _read([M10_ROOT.path_join(GameData.CONTENT_FILES[section])], errors)
	for section: String in GameData.CONTENT_DIRS:
		raw[section] = _read(JsonLoader.list_json_files(M10_ROOT.path_join(GameData.CONTENT_DIRS[section]), errors),
				errors)
	# M13-04: the Card, modifier and boss rules always apply; the M10 fixtures have no map files, so the complete ones of
	# the main fixtures (the monsters and items they use exist in both sets) stand in for them.
	var main: String = "res://tests/fixtures/data"
	raw["map_mods"] = _read([main.path_join(GameData.CONTENT_FILES["map_mods"])], errors)
	raw["bosses"] = _read([main.path_join(GameData.CONTENT_FILES["bosses"])], errors)
	(raw["items"] as Dictionary)[main.path_join("items/maps.json")] = JsonLoader.load_file(main.path_join("items/maps.json"), errors)
	for path: Variant in raw["items"] as Dictionary:
		upgrade_blueprints((raw["items"] as Dictionary)[path] as Dictionary)
	assert(errors.is_empty(), "M10 fixture files must load: %s" % [errors])
	return raw


## GameData of the M10 fixtures: a copy of the tree in a test folder with the map files of the main fixtures added (the
## Card, modifier and boss rules always apply since M13-04; the M10 fixtures have none).
static func load_m10() -> GameData:
	var root: String = PreRun.test_dir("m10_base")
	_copy_tree(M10_ROOT, root)
	var bp_path: String = root.path_join("items/blueprints.json")
	var bp_file: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(bp_path)) as Dictionary
	upgrade_blueprints(bp_file)
	var bp_out := FileAccess.open(bp_path, FileAccess.WRITE)
	bp_out.store_string(JSON.stringify(bp_file))
	bp_out.close()
	for file_name: String in ["maps/map_mods.json", "maps/bosses.json", "items/maps.json"]:
		var out := FileAccess.open(root.path_join(file_name), FileAccess.WRITE)
		out.store_string(FileAccess.get_file_as_string("res://tests/fixtures/data".path_join(file_name)))
		out.close()
	return GameData.load_from_dirs(root, M10_CONFIG)


## M14-05: the M10 snapshot has blueprints with the single `rare_component` of M10; the rule that accepted it is gone, so
## they are rewritten here (to two different rare components, Q68) as the fixture files are read-only.
static func upgrade_blueprints(file: Dictionary) -> void:
	for e: Variant in file.get("items", []) as Array:
		var bp: Variant = (e as Dictionary).get("blueprint")
		if bp is Dictionary and (bp as Dictionary).has("rare_component"):
			var first: Dictionary = (bp as Dictionary)["rare_component"] as Dictionary
			var second: String = "test_plank" if first["item"] != "test_plank" else "test_log"
			(bp as Dictionary).erase("rare_component")
			(bp as Dictionary)["rare_components"] = [first, {"item": second, "qty": 1}]


static func _copy_tree(from: String, to: String) -> void:
	DirAccess.make_dir_recursive_absolute(to)
	for dir: String in DirAccess.get_directories_at(from):
		if dir != "config":
			_copy_tree(from.path_join(dir), to.path_join(dir))
	for file_name: String in DirAccess.get_files_at(from):
		if file_name.ends_with(".json"):
			var out := FileAccess.open(to.path_join(file_name), FileAccess.WRITE)
			out.store_string(FileAccess.get_file_as_string(from.path_join(file_name)))
			out.close()


static func validate(raw: Dictionary) -> PackedStringArray:
	var errors: PackedStringArray = []
	DataValidator.validate(raw, errors)
	return errors


static func file_of(raw: Dictionary, section: String, file_name: String) -> Dictionary:
	for path: String in raw[section]:
		if path.get_file() == file_name:
			return raw[section][path] as Dictionary
	assert(false, "no file %s in section %s" % [file_name, section])
	return {}


static func entry_of(raw: Dictionary, section: String, file_name: String, list_key: String, index: int) -> Dictionary:
	return (file_of(raw, section, file_name)[list_key] as Array)[index] as Dictionary


## The item `id` of items/<file_name>.
static func item_of(raw: Dictionary, file_name: String, id: String) -> Dictionary:
	for e: Variant in file_of(raw, "items", file_name)["items"] as Array:
		if (e as Dictionary)["id"] == id:
			return e as Dictionary
	assert(false, "no item %s in %s" % [id, file_name])
	return {}


static func balance(raw: Dictionary) -> Dictionary:
	return file_of(raw, "balance", BALANCE)


static func _read(paths: PackedStringArray, errors: PackedStringArray) -> Dictionary:
	var files: Dictionary = {}
	for path: String in paths:
		files[path] = JsonLoader.load_file(path, errors)
	return files


## Expects one validation error that contains every fragment.
func expect_error(raw: Dictionary, fragments: Array[String]) -> void:
	var errors: PackedStringArray = validate(raw)
	for message: String in errors:
		var matched: bool = true
		for fragment: String in fragments:
			matched = matched and message.contains(fragment)
		if matched:
			assert_true(true)
			return
	fail_test("no error with %s in %s" % [fragments, errors])
