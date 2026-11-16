extends SceneTree
## Generates data/encounters/nodes.json (M24-05, docs/04_DATA_SCHEMA_M24.md §29.3, docs/02_FORMULAS_M24.md F-154): for every area of
## data/combat/areas.json the four gathering nodes with the weights of its theme (they sum to 100, none below 10) and `max_level` =
## the `level_max` of the area. The themes are declared below; the output is committed: the game never runs this script. Idempotent.
## Fails (exit 1, nothing written) for an area without a theme, a theme that does not sum to 100 or has a weight below 10.
## `--check` writes nothing and exits 1 if the file differs from the generated text.
##
## Usage: godot --headless --path . -s tools/gen_nodes.gd [-- --check]

const AREAS_PATH: String = "res://data/combat/areas.json"
const NODES_PATH: String = "res://data/encounters/nodes.json"
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


func _initialize() -> void:
	var areas: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(AREAS_PATH)) as Dictionary
	var result: Dictionary = generate(areas["areas"] as Array)
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
static func generate(areas: Array) -> Dictionary:
	var errors: PackedStringArray = []
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
			nodes.append({"skill": SKILLS[index], "weight": int(weights[index])})
		if sum != TOTAL:
			errors.append("area '%s': the weights sum to %d, not %d" % [id, sum, TOTAL])
		rows.append("    " + JSON.stringify({"area": id, "max_level": int((area as Dictionary)["level_max"]), "nodes": nodes}, "", false))
	if not errors.is_empty():
		return {"text": "", "errors": errors}
	return {"text": '{\n  "areas": [\n%s\n  ]\n}\n' % ",\n".join(rows), "errors": errors}
