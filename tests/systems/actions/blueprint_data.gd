extends RefCounted
## Not a test (GUT only runs `test_*.gd`): GameData of the M10 fixtures (res://tests/fixtures/data/m10, own balance and
## stats) with one smelting recipe per grade added to forging.json, as in the real data (F-90 reads the level and the
## XP of the grade from them): levels 1, 10, 20, 30, 45, 60, 75, 90; XP 8, 14, 22, 32, 46, 64, 86, 116; 2000 ms.
## The content is copied once per run to user:// (below PreRun.test_dir) and loaded from there.

const PreRun := preload("res://tests/helpers/gut_pre_run.gd")
const M10Base := preload("res://tests/data/m10_base.gd")
const M10_ROOT: String = "res://tests/fixtures/data/m10"
const M10_CONFIG: String = "res://tests/fixtures/data/m10/config"
const LEVELS: Array[int] = [1, 10, 20, 30, 45, 60, 75, 90]
const XPS: Array[int] = [8, 14, 22, 32, 46, 64, 86, 116]

static var _data: GameData = null


static func data() -> GameData:
	if _data == null:
		var root: String = PreRun.test_dir("blueprint_data")
		_copy(M10_ROOT, root)
		# M13-04: Cards, modifiers and bosses are mandatory; the M10 fixtures have none, so the main fixtures' stand in.
		for file_name: String in ["maps/map_mods.json", "maps/bosses.json", "items/maps.json"]:
			var map_file := FileAccess.open(root.path_join(file_name), FileAccess.WRITE)
			map_file.store_string(FileAccess.get_file_as_string("res://tests/fixtures/data".path_join(file_name)))
			map_file.close()
		_add_smelting(root.path_join("actions/forging.json"))
		_upgrade_blueprints(root.path_join("items/blueprints.json"))
		_data = GameData.load_from_dirs(root, M10_CONFIG)
		assert(_data.is_valid(), "blueprint test data is not valid: %s" % ["\n".join(_data.errors)])
	return _data


## M14-05: the M10 snapshot has the single `rare_component`, no longer accepted: rewritten as two rare components.
static func _upgrade_blueprints(path: String) -> void:
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	M10Base.upgrade_blueprints(raw)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(raw))
	file.close()


static func _add_smelting(path: String) -> void:
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var ingots: Array = JSON.parse_string(FileAccess.get_file_as_string(M10_CONFIG.path_join("balance.json")))[
			"upgrade"]["ingot_items"]
	for i: int in 8:
		(raw["actions"] as Array).append({"id": "smelt_grade_%d" % (i + 1), "name": "Fondere %d" % (i + 1),
				"level": LEVELS[i], "interval_ms": 2000, "xp": XPS[i], "mastery": false,
				"inputs": [{"item": "test_log", "qty": 2}], "outputs": [{"item": ingots[i], "qty": 1}]})
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(raw))
	file.close()


static func _copy(from: String, to: String) -> void:
	DirAccess.make_dir_recursive_absolute(to)
	for dir: String in DirAccess.get_directories_at(from):
		if dir != "config":
			_copy(from.path_join(dir), to.path_join(dir))
	for name: String in DirAccess.get_files_at(from):
		if name.ends_with(".json"):
			var file := FileAccess.open(to.path_join(name), FileAccess.WRITE)
			file.store_string(FileAccess.get_file_as_string(from.path_join(name)))
			file.close()
