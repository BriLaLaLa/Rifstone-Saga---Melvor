extends RefCounted
## Not a test (GUT only runs `test_*.gd`): the real data (res://data) with the M35-D content that M35-D2 will write, built in a temporary copy
## under the test folder: four unique tools with two heads each (F-197), `tool_upgrade` with `units_per_level_pct`, `head_steps` and
## `respec_pct`, `start.tools` with the Sickle, and the stats `node_units_pct`, `node_rich_pct`, `byproduct_chance_pct` (04_DATA_SCHEMA_M35 §35).
## Remove it when D2 has put all this in `data/`.

const PreRun := preload("res://tests/helpers/gut_pre_run.gd")
const NOTE: String = "values copied from docs/02_FORMULAS_M35.md F-197"

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
		_patch(root.path_join("items/tools.json"), _tools)
		_patch(config.path_join("balance.json"), _balance)
		_patch(config.path_join("stats.json"), add_stats)
		_built = true
	var loaded: GameData = GameData.load_from_dirs(root, config)
	assert(loaded.is_valid(), "M35 test data is not valid: %s" % ["\n".join(loaded.errors)])
	return loaded


static func _patch(path: String, change: Callable) -> void:
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	change.call(raw)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(raw))
	file.close()


static func _balance(raw: Dictionary) -> void:
	var upgrade: Dictionary = raw["tool_upgrade"]
	upgrade["units_per_level_pct"] = 1
	upgrade["head_steps"] = [3, 6, 9]
	upgrade["respec_pct"] = 25
	((raw["start"] as Dictionary)["tools"] as Array).append({"base": "unique_sickle"})


static func add_stats(raw: Dictionary) -> void:
	var list: Array = raw["stats"]
	for stat: Array in [["node_units_pct", 200, "F-198", "tests/systems/encounters/test_attempts.gd::test_node_units_pct"],
			["node_rich_pct", 100, "F-199", "tests/systems/encounters/test_node_work.gd::test_node_rich_pct"],
			["byproduct_chance_pct", 100, "F-199", "tests/systems/actions/test_gathering_resolver.gd::test_byproduct_chance_pct"]]:
		list.append({"id": stat[0], "name": stat[0], "format": "pct", "min": 0, "max": stat[1], "description": "Prova.",
				"formula": stat[2], "test": stat[3]})


static func _tools(raw: Dictionary) -> void:
	var items: Array = raw["items"]
	for entry: Dictionary in items:
		(entry["equip"] as Dictionary).erase("upgrade_extras")
	var heads: Dictionary = {
		"unique_hatchet": [_head("hatchet_wide", [{"node_units_pct": 5}]), _head("hatchet_fine", [{"double_item_chance": 4, "byproduct_chance_pct": 1}])],
		"unique_pick": [_head("pick_vein", [{"node_units_pct": 5}]), _head("pick_quarry", [{"node_rich_pct": 6, "double_item_chance": 2}])],
		"unique_rod": [_head("rod_net", [{"node_units_pct": 5}]), _head("rod_hook", [{"rift_shard_chance": 8, "double_item_chance": 3}], {"rift_shard_chance": 9})],
		"unique_sickle": [_head("sickle_basket", [{"node_units_pct": 5}]), _head("sickle_bundle", [{"node_rich_pct": 4, "double_item_chance": 3}])],
	}
	var sickle: Dictionary = (items[0] as Dictionary).duplicate(true)
	sickle["id"] = "unique_sickle"
	sickle["name"] = "Falcetto"
	sickle["sort_order"] = 40
	sickle["description"] = "L'attrezzo dell'Erborista."
	var equip: Dictionary = sickle["equip"]
	equip["slot"] = "tool_herbalism"
	equip["modifiers"] = [{"stat": "skill_interval_pct", "value": -5, "scope": "skill:herbalism"}]
	items.append(sickle)
	for entry: Dictionary in items:
		(entry["equip"] as Dictionary)["heads"] = heads[entry["id"]]


## A head: `step` is the modifiers of steps +3 and +6; `last` overrides the values of step +9 (default: the same).
static func _head(id: String, mods: Array, last: Dictionary = {}) -> Dictionary:
	var values: Dictionary = mods[0]
	var step: Array = []
	var final: Array = []
	for stat: String in values:
		step.append({"stat": stat, "value": values[stat]})
		final.append({"stat": stat, "value": last.get(stat, values[stat])})
	return {"id": id, "name": id.capitalize(), "description": NOTE, "steps": [step, step.duplicate(true), final]}


static func _copy(from: String, to: String) -> void:
	DirAccess.make_dir_recursive_absolute(to)
	for dir: String in DirAccess.get_directories_at(from):
		_copy(from.path_join(dir), to.path_join(dir))
	for name: String in DirAccess.get_files_at(from):
		if name.ends_with(".json"):
			var file := FileAccess.open(to.path_join(name), FileAccess.WRITE)
			file.store_string(FileAccess.get_file_as_string(from.path_join(name)))
			file.close()
