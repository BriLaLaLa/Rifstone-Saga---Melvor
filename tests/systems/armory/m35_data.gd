extends RefCounted
## Not a test (GUT only runs `test_*.gd`): a GameData of the real data (res://data), copied under the test folder. Since M35-D2 the tool heads,
## balance keys and stats are in `data/` itself.

const PreRun := preload("res://tests/helpers/gut_pre_run.gd")

static var _data: GameData = null
static var _built: bool = false


static func data() -> GameData:
	if _data == null:
		_data = fresh()
	return _data


## A GameData of its own, for a test that changes `balance` (the one of `data()` is shared by every test).
static func fresh() -> GameData:
	var root: String = PreRun.test_dir("m35_data")
	var config: String = root.path_join("config")
	if not _built:
		_copy("res://data", root)
		_built = true
	var loaded: GameData = GameData.load_from_dirs(root, config)
	assert(loaded.is_valid(), "M35 test data is not valid: %s" % ["\n".join(loaded.errors)])
	return loaded


static func _copy(from: String, to: String) -> void:
	DirAccess.make_dir_recursive_absolute(to)
	for dir: String in DirAccess.get_directories_at(from):
		_copy(from.path_join(dir), to.path_join(dir))
	for name: String in DirAccess.get_files_at(from):
		if name.ends_with(".json"):
			var file := FileAccess.open(to.path_join(name), FileAccess.WRITE)
			file.store_string(FileAccess.get_file_as_string(from.path_join(name)))
			file.close()

