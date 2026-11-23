extends SceneTree
## Generates data/encounters/nodes.json (M24-05, docs/04_DATA_SCHEMA_M24.md §29.3, docs/02_FORMULAS_M24.md F-154): for every area of
## data/combat/areas.json the four gathering nodes with the weights of its theme (they sum to 100, none below 10) and `max_level` =
## the `level_max` of the area. The themes are declared below; the output is committed: the game never runs this script. Idempotent.
## M35B (docs/02_FORMULAS_M35B.md F-201, docs/04_DATA_SCHEMA_M35B.md §36.1): every node also gets `resources`, the per-zone resource
## weights (integer percentages summing to 100, ascending by level) computed from the actions of data/actions/<skill>.json and the profile
## in balance.json `encounters.resource_profile` (largest remainder method).
## Fails (exit 1, nothing written) for an area without a theme, a theme that does not sum to 100 or has a weight below 10, a discipline
## with fewer actions than the profile needs, or a malformed profile.
## `--check` writes nothing and exits 1 if the file differs from the generated text.
##
## Usage: godot --headless --path . -s tools/gen_nodes.gd [-- --check]

const AREAS_PATH: String = "res://data/combat/areas.json"
const NODES_PATH: String = "res://data/encounters/nodes.json"
const ACTIONS_DIR: String = "res://data/actions/"
const BALANCE_PATH: String = "res://data/config/balance.json"
const SKILLS: Array[String] = ["forestry", "quarrying", "angling", "herbalism"]
const TOTAL: int = 100
const MIN_WEIGHT: int = 10
## Weights per area, in the order of SKILLS (forestry, quarrying, angling, herbalism): woods give timber, mines ore, marshes fish and herbs.
const THEMES: Dictionary = {
	"redrock_plains": [30, 20, 25, 25],
	"whisper_wood": [45, 10, 20, 25],
	"dry_uplands": [25, 30, 15, 30],
	"cracked_mines": [10, 60, 15, 15],
	"ash_marsh": [15, 10, 35, 40],
	"weeping_gorge": [15, 35, 30, 20],
	"rift_threshold": [20, 25, 20, 35],
	"black_glass_desert": [10, 50, 10, 30],
	"sunken_citadel": [20, 20, 45, 15],
	"rift_heart": [25, 25, 20, 30],
}
## Optional per-area overrides (docs/04_DATA_SCHEMA_M25.md §30.1, Q127): `{area: {skill: level}}`. Empty = fields omitted (difficulty = max_level, min_level 1).
const DIFFICULTY: Dictionary = {}
const MIN_LEVEL: Dictionary = {}


func _initialize() -> void:
	var areas: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(AREAS_PATH)) as Dictionary
	var balance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BALANCE_PATH)) as Dictionary
	var profile: Array = (balance.get("encounters", {}) as Dictionary).get("resource_profile", []) as Array
	var actions: Dictionary = {}
	for skill: String in SKILLS:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ACTIONS_DIR + skill + ".json"))
		actions[skill] = (parsed as Dictionary).get("actions", []) as Array if parsed is Dictionary else []
	var result: Dictionary = generate(areas["areas"] as Array, actions, profile)
	for message: String in result["errors"] as PackedStringArray:
		printerr("gen_nodes: " + message)
	if not (result["errors"] as PackedStringArray).is_empty():
		quit(1)
		return
	var text: String = result["text"] as String
	var current: String = FileAccess.get_file_as_string(NODES_PATH)
	if OS.get_cmdline_user_args().has("--check"):
		print_rich("gen_nodes: " + ("up to date" if text == current else "OUT OF DATE (rerun tools/gen_nodes.gd)"))
		quit(0 if text == current else 1)
		return
	if text != current:
		DirAccess.make_dir_recursive_absolute(NODES_PATH.get_base_dir())
		var file: FileAccess = FileAccess.open(NODES_PATH, FileAccess.WRITE)
		file.store_string(text)
		file.close()
	print_rich("gen_nodes: %s" % ("written" if text != current else "unchanged"))
	quit(0)


## `{"text": String, "errors": PackedStringArray}` for the `areas` list of areas.json (with errors the text is empty).
## `actions`: `{skill: Array of action dictionaries}`; `profile`: `[{offset, weight}]` (balance.json `encounters.resource_profile`).
static func generate(areas: Array, actions: Dictionary, profile: Array) -> Dictionary:
	var errors: PackedStringArray = _check_profile(profile)
	var ladders: Dictionary = {}
	for skill: String in SKILLS:
		var ladder: Array = _ladder(actions.get(skill, []) as Array)
		ladders[skill] = ladder
		if ladder.is_empty():
			errors.append("skill '%s' has no actions" % skill)
		elif ladder.size() < profile.size():
			errors.append("skill '%s' has %d actions, the profile needs %d" % [skill, ladder.size(), profile.size()])
	var rows: PackedStringArray = []
	for area: Variant in areas:
		var id: String = str((area as Dictionary)["id"])
		if not THEMES.has(id):
			errors.append("area '%s' has no theme" % id)
			continue
		var weights: Array = THEMES[id] as Array
		var sum: int = 0
		var nodes: Array = []
		for index: int in SKILLS.size():
			sum += int(weights[index])
			if int(weights[index]) < MIN_WEIGHT:
				errors.append("area '%s': weight of %s below %d" % [id, SKILLS[index], MIN_WEIGHT])
			var node: Dictionary = {"skill": SKILLS[index], "weight": int(weights[index])}
			var overrides: Dictionary = DIFFICULTY.get(id, {}) as Dictionary
			if overrides.has(SKILLS[index]):
				node["difficulty"] = int(overrides[SKILLS[index]])
			overrides = MIN_LEVEL.get(id, {}) as Dictionary
			if overrides.has(SKILLS[index]):
				node["min_level"] = int(overrides[SKILLS[index]])
			if errors.is_empty():
				var table: Array = resource_table(ladders[SKILLS[index]] as Array, int((area as Dictionary)["level_min"]), int((area as Dictionary)["level_max"]), profile)
				if table.is_empty():
					errors.append("area '%s': no resources for %s" % [id, SKILLS[index]])
				node["resources"] = table
			nodes.append(node)
		if sum != TOTAL:
			errors.append("area '%s': the weights sum to %d, not %d" % [id, sum, TOTAL])
		rows.append("    " + JSON.stringify({"area": id, "max_level": int((area as Dictionary)["level_max"]), "nodes": nodes}, "", false))
	if not errors.is_empty():
		return {"text": "", "errors": errors}
	return {"text": '{\n  "areas": [\n%s\n  ]\n}\n' % ",\n".join(rows), "errors": errors}


## F-201: `[{action, weight}]` for one zone and one discipline. `ladder` = `[{id, level}]` ascending by level (see `_ladder`); weights are
## integer percentages summing to 100 (largest remainder, ties to the lower level); entries ascending by level.
static func resource_table(ladder: Array, level_min: int, level_max: int, profile: Array) -> Array:
	var median: int = (level_min + level_max) / 2
	var home: int = 0
	for index: int in ladder.size():
		if int((ladder[index] as Dictionary)["level"]) <= median:
			home = index
	var ids: Array[String] = []
	var raws: Array[int] = []
	var total_raw: int = 0
	for index: int in ladder.size():
		for entry: Variant in profile:
			if int((entry as Dictionary)["offset"]) == index - home:
				ids.append(str((ladder[index] as Dictionary)["id"]))
				raws.append(int((entry as Dictionary)["weight"]))
				total_raw += int((entry as Dictionary)["weight"])
	var result: Array[int] = []
	var remainders: Array[int] = []
	var assigned: int = 0
	for raw: int in raws:
		result.append(raw * TOTAL / total_raw)
		remainders.append(raw * TOTAL % total_raw)
		assigned += raw * TOTAL / total_raw
	var order: Array[int] = []
	for i: int in raws.size():
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool: return remainders[a] > remainders[b] or (remainders[a] == remainders[b] and a < b))
	for k: int in TOTAL - assigned:
		result[order[k]] += 1
	var table: Array = []
	for i: int in raws.size():
		if result[i] >= 1:
			table.append({"action": ids[i], "weight": result[i]})
	return table


## Actions as `[{id, level}]` sorted by level (stable: ties keep the file order).
static func _ladder(actions: Array) -> Array:
	var ladder: Array = []
	for action: Variant in actions:
		ladder.append({"id": str((action as Dictionary)["id"]), "level": int((action as Dictionary)["level"])})
	ladder.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["level"]) < int(b["level"]))
	return ladder


static func _check_profile(profile: Array) -> PackedStringArray:
	var errors: PackedStringArray = []
	if profile.is_empty():
		errors.append("balance.json encounters.resource_profile is missing or empty")
	var seen: Dictionary = {}
	for entry: Variant in profile:
		if not entry is Dictionary or not (entry as Dictionary).has("offset") or not (entry as Dictionary).has("weight"):
			errors.append("resource_profile entry needs offset and weight")
			continue
		var offset: int = int((entry as Dictionary)["offset"])
		if seen.has(offset) or offset < -3 or offset > 3:
			errors.append("resource_profile offset %d duplicated or outside -3..3" % offset)
		seen[offset] = true
		if int((entry as Dictionary)["weight"]) < 1:
			errors.append("resource_profile weight of offset %d below 1" % offset)
	return errors
