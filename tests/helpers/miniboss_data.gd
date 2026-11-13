class_name MinibossData
extends RefCounted
## Not a test (GUT only runs `test_*.gd`): the real data with `miniboss.chance_pct` changed, for the miniboss tests (F-139). The
## shared real data is never modified: a copy of the configuration is written under user:// only while loading, then removed.

const PreRun := preload("res://tests/helpers/gut_pre_run.gd")

static var _cache: Dictionary[int, GameData] = {}


## The real content with `miniboss.chance_pct` = `chance_pct` (whole percent).
static func data(chance_pct: int) -> GameData:
	if _cache.has(chance_pct):
		return _cache[chance_pct]
	var dir: String = PreRun.test_dir("miniboss_chance_%d" % chance_pct)
	DirAccess.make_dir_recursive_absolute(dir)
	var balance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/config/balance.json"))
	(balance["miniboss"] as Dictionary)["chance_pct"] = float(chance_pct)
	_write(dir.path_join("balance.json"), JSON.stringify(balance))
	_write(dir.path_join("stats.json"), FileAccess.get_file_as_string("res://data/config/stats.json"))
	var loaded: GameData = GameData.load_from_dirs(TestFactory.REAL_CONTENT_ROOT, dir)
	assert(loaded.is_valid(), "miniboss test data is not valid: %s" % "\n".join(loaded.errors))
	DirAccess.remove_absolute(dir.path_join("balance.json"))
	DirAccess.remove_absolute(dir.path_join("stats.json"))
	DirAccess.remove_absolute(dir)
	_cache[chance_pct] = loaded
	return loaded


static func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
