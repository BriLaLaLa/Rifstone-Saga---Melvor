extends RefCounted
## Not a test (GUT only runs `test_*.gd`): a GameData of the real data (res://data) whose `nodes.json` carries the resource tables of F-201
## (docs/02_FORMULAS_M35B.md), computed here from the real actions and areas, so the CORE tests do not wait for `data/` of M35B-2.

const PreRun := preload("res://tests/helpers/gut_pre_run.gd")
const PROFILE: Array = [[-2, 5], [-1, 25], [0, 55], [1, 15]]
const SKILLS: Array[String] = ["forestry", "quarrying", "angling", "herbalism"]

static var _built: bool = false


static func data() -> GameData:
	var root: String = PreRun.test_dir("zone_tables_data")
	if not _built:
		_copy("res://data", root)
		_write_nodes(root)
		_built = true
	var loaded: GameData = GameData.load_from_dirs(root, root.path_join("config"))
	assert(loaded.is_valid(), "zone tables data is not valid: %s" % ["\n".join(loaded.errors)])
	return loaded


## F-201: `[{"action": id, "weight": int}]` of one discipline in an area of levels `level_min..level_max` (actions: `[{"id", "level"}]` by level).
static func table(actions: Array, level_min: int, level_max: int) -> Array:
	var home: int = 0
	for i: int in actions.size():
		if int(actions[i]["level"]) <= (level_min + level_max) / 2:
			home = i
	var raws: Array = []  # [index, raw]
	var sum: int = 0
	for row: Array in PROFILE:
		var index: int = home + int(row[0])
		if index >= 0 and index < actions.size():
			raws.append([index, int(row[1])])
			sum += int(row[1])
	var weights: Array = []
	var used: int = 0
	for raw: Array in raws:
		weights.append(int(raw[1]) * 100 / sum)
		used += int(weights[-1])
	var order: Array = range(raws.size())
	order.sort_custom(func(a: int, b: int) -> bool:
		var ra: int = int(raws[a][1]) * 100 % sum
		var rb: int = int(raws[b][1]) * 100 % sum
		return ra > rb or (ra == rb and a < b))
	for i: int in 100 - used:
		weights[order[i]] = int(weights[order[i]]) + 1
	var result: Array = []
	for i: int in raws.size():
		result.append({"action": actions[int(raws[i][0])]["id"], "weight": weights[i]})
	return result


static func _write_nodes(root: String) -> void:
	var areas: Dictionary = {}
	for a: Dictionary in _json("res://data/combat/areas.json")["areas"]:
		areas[a["id"]] = a
	var actions: Dictionary = {}
	for skill: String in SKILLS:
		var list: Array = _json("res://data/actions/%s.json" % skill)["actions"]
		list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["level"]) < int(b["level"]))
		actions[skill] = list
	var content: Dictionary = _json("res://data/encounters/nodes.json")
	for area: Dictionary in content["areas"]:
		for node: Dictionary in area["nodes"]:
			var def: Dictionary = areas[area["area"]]
			node["resources"] = table(actions[node["skill"]], int(def["level_min"]), int(def["level_max"]))
	var file := FileAccess.open(root.path_join("encounters/nodes.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(content))
	file.close()


static func _json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path)) as Dictionary


static func _copy(from: String, to: String) -> void:
	DirAccess.make_dir_recursive_absolute(to)
	for dir: String in DirAccess.get_directories_at(from):
		_copy(from.path_join(dir), to.path_join(dir))
	for name: String in DirAccess.get_files_at(from):
		if name.ends_with(".json"):
			var file := FileAccess.open(to.path_join(name), FileAccess.WRITE)
			file.store_string(FileAccess.get_file_as_string(from.path_join(name)))
			file.close()
