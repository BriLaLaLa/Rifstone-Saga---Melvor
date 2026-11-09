extends RefCounted
## Not a test (GUT only runs `test_*.gd`): GameData of the main fixtures (res://tests/fixtures/data, the real
## configuration) plus the M14 content of res://tests/fixtures/data/m14: one legendary per effect type of F-120 (every
## source has chance_pct 100, bosses boss_grade_1..5 and the Monoliths test_stone / test_loot_stone), three legendary tools
## and the three gathering skills of their slots (forestry, quarrying, angling; actions `<skill>_a` level 1 -> test_twig
## and `<skill>_b` level 10 -> test_log). The content is copied once per run to user:// (below PreRun.test_dir).
##
## Legendaries by source: boss_grade_1 fx_leg_blockheal, fx_leg_killheal; boss_grade_2 fx_leg_pierce, fx_leg_cap,
## fx_leg_convert; boss_grade_3 fx_leg_double, fx_leg_execute; boss_grade_4 fx_leg_timer; boss_grade_5 fx_leg_hatchet;
## test_stone fx_leg_rod, fx_leg_pick; test_loot_stone fx_leg_monolith, fx_leg_cards.

const PreRun := preload("res://tests/helpers/gut_pre_run.gd")
const MAIN_ROOT: String = "res://tests/fixtures/data"
const EXTRA_ROOT: String = "res://tests/fixtures/data/m14"
const SKIPPED_DIRS: PackedStringArray = ["m10", "m14"]

static var _data: GameData = null
static var _root: String = ""
static var _cache: Dictionary[String, GameData] = {}


## The M14 content with the real configuration.
static func data() -> GameData:
	if _data == null:
		_data = GameData.load_from_dirs(_content_root(), TestFactory.CONFIG_ROOT)
		assert(_data.is_valid(), "M14 test data is not valid: %s" % ["\n".join(_data.errors)])
	return _data


## The M14 content with `fracture.groups` = `groups` in a private copy of the configuration (for the Fracture flows).
static func data_with_groups(groups: int) -> GameData:
	var key: String = "groups:%d" % groups
	if not _cache.has(key):
		var dir: String = PreRun.test_dir("m14_config_%d" % groups)
		DirAccess.make_dir_recursive_absolute(dir)
		var balance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TestFactory.CONFIG_ROOT.path_join("balance.json")))
		(balance["fracture"] as Dictionary)["groups"] = groups
		_write(dir.path_join("balance.json"), JSON.stringify(balance))
		_write(dir.path_join("stats.json"), FileAccess.get_file_as_string(TestFactory.CONFIG_ROOT.path_join("stats.json")))
		var loaded: GameData = GameData.load_from_dirs(_content_root(), dir)
		assert(loaded.is_valid(), "M14 test data is not valid: %s" % ["\n".join(loaded.errors)])
		DirAccess.remove_absolute(dir.path_join("balance.json"))
		DirAccess.remove_absolute(dir.path_join("stats.json"))
		DirAccess.remove_absolute(dir)
		_cache[key] = loaded
	return _cache[key]


# The folder with the copy of the fixtures plus the M14 content (built once per run).
static func _content_root() -> String:
	if _root.is_empty():
		_root = PreRun.test_dir("m14_data")
		_copy(MAIN_ROOT, _root)
		_merge(_root.path_join("items/equipment.json"), EXTRA_ROOT.path_join("equipment.json"), "items")
		_merge(_root.path_join("items/tools.json"), EXTRA_ROOT.path_join("tools.json"), "items")
		_merge(_root.path_join("combat/monsters.json"), EXTRA_ROOT.path_join("monsters.json"), "monsters")
		_merge(_root.path_join("skills/skills.json"), EXTRA_ROOT.path_join("skills.json"), "skills")
		_add_contracts(_root.path_join("items/contracts.json"))
		for file_name: String in DirAccess.get_files_at(EXTRA_ROOT.path_join("actions")):
			if file_name.ends_with(".json"):
				_write(_root.path_join("actions").path_join(file_name),
						FileAccess.get_file_as_string(EXTRA_ROOT.path_join("actions").path_join(file_name)))
	return _root


# The helpers need one contract per gathering skill and grade (M12): the new skills get theirs.
static func _add_contracts(path: String) -> void:
	var target: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var order: int = 1000
	for skill: String in ["forestry", "quarrying", "angling"]:
		for grade: String in ["apprentice", "journeyman", "expert", "master"]:
			order += 10
			(target["items"] as Array).append({"id": "contract_%s_%s" % [skill, grade], "name": "Contratto di prova %s %s" % [skill, grade],
					"category": "contract", "icon": "res://assets/icons/items/contract_test_gather.png", "value": 0, "sort_order": order,
					"description": "Contratto di prova per un aiutante.", "contract": {"skill": skill, "grade": grade}})
	_write(path, JSON.stringify(target))


# Appends the `key` list of `extra_path` to the same list of the JSON at `target_path`.
static func _merge(target_path: String, extra_path: String, key: String) -> void:
	var target: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(target_path))
	var extra: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(extra_path))
	(target[key] as Array).append_array(extra[key] as Array)
	_write(target_path, JSON.stringify(target))


static func _copy(from: String, to: String) -> void:
	DirAccess.make_dir_recursive_absolute(to)
	for dir: String in DirAccess.get_directories_at(from):
		if not SKIPPED_DIRS.has(dir):
			_copy(from.path_join(dir), to.path_join(dir))
	for file_name: String in DirAccess.get_files_at(from):
		if file_name.ends_with(".json"):
			_write(to.path_join(file_name), FileAccess.get_file_as_string(from.path_join(file_name)))


static func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
