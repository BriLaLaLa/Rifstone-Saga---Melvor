extends GutTest
## Base class of the M10 data tests (not a test file: GUT only runs `test_*.gd`). Gives the `raw` dictionary of
## DataValidator for the M10 fixtures (res://tests/fixtures/data/m10, 04_DATA_SCHEMA.md §18: its own balance.json and
## stats.json in `config/`), a fresh copy at each call, and the helpers to break one rule and expect one error.

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
	assert(errors.is_empty(), "M10 fixture files must load: %s" % [errors])
	return raw


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
