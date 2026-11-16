extends RefCounted
## Not a test (GUT only runs `test_*.gd`): the real game data plus the `auction_house` building of docs/04_DATA_SCHEMA.md §28
## (M23-03 adds it to data/village/buildings.json; until then it is appended to a private copy of the data folder, once per run).

const PreRun := preload("res://tests/helpers/gut_pre_run.gd")
const BUILDING_ID: StringName = &"auction_house"
const SPEC: Dictionary = {
	"id": "auction_house", "name": "Casa d'Aste", "description": "Banchi dove i prezzi salgono e scendono con le vendite.",
	"icon": "coins", "order": 8, "buildable": true, "map_pos": [0.86, 0.49], "page": "auction", "unlocks_auction": true,
	"cost_spec": {"wood": [{"component": "shieldcore", "weight": 0.25}, {"component": "handle", "weight": 0.25}],
		"plate": 0.5, "food": 0, "gold_weight": 1.0},
}

static var _data: GameData = null


## The real data with the Auction House building (levels 1..max_level generated with F-131).
static func data() -> GameData:
	if _data == null:
		var root: String = PreRun.test_dir("auction_data")
		_copy("res://data", root)
		var path: String = root.path_join("village/buildings.json")
		var file: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path)) as Dictionary
		(file["buildings"] as Array).append(building(TestFactory.real_data()))
		_write(path, JSON.stringify(file))
		_data = GameData.load_from_dirs(root, TestFactory.CONFIG_ROOT)
		assert(_data.is_valid(), "auction test data is not valid: %s" % ["\n".join(_data.errors)])
	return _data


## The building as a raw dictionary, with its generated levels.
static func building(real: GameData) -> Dictionary:
	var params: Dictionary = real.balance_value("village") as Dictionary
	var result: Dictionary = SPEC.duplicate(true)
	var levels: Array = []
	for level: int in range(1, int(params["max_level"]) + 1):
		levels.append(DataValidatorVillage.levels_for(SPEC, params, level))
	result["levels"] = levels
	return result


## A new session on `data()` with the Auction House at `level` and a plain Deposit.
static func session(level: int, seed_value: int = 1234) -> GameSession:
	var result: GameSession = TestFactory.session_no_kit(seed_value, data())
	result.village.from_save({"levels": {String(BUILDING_ID): level}})
	return result


static func _copy(from: String, to: String) -> void:
	DirAccess.make_dir_recursive_absolute(to)
	for dir: String in DirAccess.get_directories_at(from):
		_copy(from.path_join(dir), to.path_join(dir))
	for file_name: String in DirAccess.get_files_at(from):
		if file_name.ends_with(".json"):
			_write(to.path_join(file_name), FileAccess.get_file_as_string(from.path_join(file_name)))


static func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
