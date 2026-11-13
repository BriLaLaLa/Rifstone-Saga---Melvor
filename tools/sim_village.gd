extends SceneTree
## Balance tool for the Village (M19-01, F-131/F-132 in docs/02_FORMULAS.md). Read-only: nothing is written.
## For every building and level it prints the hours needed to farm the cost: materials are produced from raw gathering
## with the real action data (interval and ingredients of data/actions/*.json, no modifiers, no helpers, no mastery:
## an upper bound), gold is converted with the gold per hour measured by tools/sim_combat.gd (M19-01 run, scope "all").
## Parameters: balance.json "village" and data/village/buildings.json when they exist (M19-02); until then the
## defaults below, which are the values fixed by M19-01 (docs/02_FORMULAS.md F-131).
##
## Usage: godot --headless --path . -s tools/sim_village.gd [-- cap=<hours>]
## Exit code 1 if some single level needs more than `cap` hours (default 1.0).

const ACTION_FILES: Array[String] = ["forestry", "quarrying", "angling", "forging", "hearthcraft", "woodwright"]
const BALANCE_PATH: String = "res://data/config/balance.json"
const BUILDINGS_PATH: String = "res://data/village/buildings.json"
const ACTIONS_DIR: String = "res://data/actions/"
const WOODS: Array[String] = ["redbirch", "ashpine", "thornalder", "duskelm", "shardcedar", "veilcypress", "emberlarch", "riftspruce"]
const METALS: Array[String] = ["emberbronze", "ashlead", "stormzinc", "duskcobalt", "glimmerite", "palecinnabar", "emberheart", "riftite"]
const FISH: Array[String] = ["brookfin", "ashgill", "redscale", "dusk_eel", "shard_gar", "mist_barbel", "ember_sturgeon", "riftmaw"]
## Gold per hour of the area matching grade 1..8 (sim_combat, scope all: redrock_plains, whisper_wood, dry_uplands,
## cracked_mines, ash_marsh, weeping_gorge, black_glass_desert, sunken_citadel).
const GOLD_PER_HOUR: Array[float] = [923.0, 2349.0, 3721.0, 2514.0, 5438.0, 7005.0, 8189.0, 8586.0]

const DEFAULT_PARAMS: Dictionary = {
	"max_level": 8, "woodwright_levels": [1, 10, 20, 30, 45, 60, 75, 90], "gold_base": 300, "gold_growth": 1.4,
	"qty": {"wood": {"base": 20, "per_level": 20}, "plate": {"base": 4, "per_level": 4}, "food": {"base": 10, "per_level": 6}},
}
const DEFAULT_BUILDINGS: Array[Dictionary] = [
	{"id": "storehouse", "gold_weight": 1.0, "wood": [{"component": "shieldcore", "weight": 0.5}], "plate": 0.5, "food": 0.0},
	{"id": "inn", "gold_weight": 0.8, "wood": [{"component": "grip", "weight": 0.5}], "plate": 0.0, "food": 1.0},
	{"id": "forge", "gold_weight": 1.0, "wood": [{"component": "handle", "weight": 0.5}], "plate": 1.0, "food": 0.0},
	{"id": "sawmill", "gold_weight": 0.6, "wood": [{"component": "grip", "weight": 0.75}, {"component": "handle", "weight": 0.75}], "plate": 0.0, "food": 0.0},
	{"id": "loot_shed", "gold_weight": 0.8, "wood": [{"component": "handle", "weight": 0.5}], "plate": 0.5, "food": 0.0},
]

var _producers: Dictionary = {}   # item id -> action dictionary


func _initialize() -> void:
	quit(run(OS.get_cmdline_user_args()))


func run(args: PackedStringArray) -> int:
	var cap: float = 1.0
	for arg: String in args:
		if arg.begins_with("cap="):
			cap = float(arg.get_slice("=", 1))
		else:
			printerr("sim_village: bad argument '%s'" % arg)
			return 1
	if not _load_actions():
		return 1
	var params: Dictionary = _params()
	var worst: float = 0.0
	print("| building | level | woodwright | materials h | gold h | total h | cumulative h |")
	print("|---|---|---|---|---|---|---|")
	for building: Dictionary in _buildings():
		var cumulative: float = 0.0
		for level: int in range(1, int(params["max_level"]) + 1):
			var mat_s: float = _materials_seconds(building, params, level)
			var gold: float = _gold(building, params, level)
			var mat_h: float = mat_s / 3600.0
			var gold_h: float = gold / GOLD_PER_HOUR[level - 1]
			var total: float = mat_h + gold_h
			cumulative += total
			worst = maxf(worst, total)
			print("| %s | %d | %d | %.2f | %.2f | %.2f | %.2f |" % [building["id"], level,
					int(params["woodwright_levels"][level - 1]), mat_h, gold_h, total, cumulative])
	print("worst single level: %.2f h (cap %.2f h)" % [worst, cap])
	return 1 if worst > cap else 0


func _params() -> Dictionary:
	var raw: Variant = _read_json(BALANCE_PATH)
	if raw is Dictionary and (raw as Dictionary).has("village"):
		return (raw as Dictionary)["village"]
	return DEFAULT_PARAMS


func _buildings() -> Array[Dictionary]:
	var raw: Variant = _read_json(BUILDINGS_PATH)
	if not (raw is Dictionary):
		return DEFAULT_BUILDINGS
	var out: Array[Dictionary] = []
	for b: Dictionary in (raw as Dictionary).get("buildings", []):
		if not bool(b.get("buildable", true)):
			continue
		var spec: Dictionary = b["cost_spec"]
		out.append({"id": b["id"], "gold_weight": float(spec.get("gold_weight", 0.0)), "wood": spec.get("wood", []),
				"plate": float(spec.get("plate", 0.0)), "food": float(spec.get("food", 0.0))})
	return out


## F-131: quantity of one cost line at `level` (1..max_level).
func _qty(params: Dictionary, kind: String, weight: float, level: int) -> int:
	var q: Dictionary = params["qty"][kind]
	return maxi(1, ceili(float(int(q["base"]) + int(q["per_level"]) * level) * weight))


func _gold(building: Dictionary, params: Dictionary, level: int) -> float:
	var raw: float = float(params["gold_base"]) * pow(float(params["gold_growth"]), level - 1) * float(building["gold_weight"])
	return floorf(raw / 10.0 + 0.5) * 10.0


func _materials_seconds(building: Dictionary, params: Dictionary, level: int) -> float:
	var total: float = 0.0
	for line: Dictionary in building["wood"]:
		var item: String = "%s_%s" % [WOODS[level - 1], line["component"]]
		total += _qty(params, "wood", float(line["weight"]), level) * _seconds(item)
	if float(building["plate"]) > 0.0:
		total += _qty(params, "plate", float(building["plate"]), level) * _seconds("%s_plate" % METALS[level - 1])
	if float(building["food"]) > 0.0:
		total += _qty(params, "food", float(building["food"]), level) * _seconds("seared_%s" % FISH[level - 1])
	return total


## Seconds to make one unit of `item` from raw gathering: (interval + ingredients) / output quantity, recursive.
func _seconds(item: String) -> float:
	var action: Dictionary = _producers.get(item, {})
	if action.is_empty():
		printerr("sim_village: no action produces '%s'" % item)
		return 0.0
	var seconds: float = float(action["interval_ms"]) / 1000.0
	for input: Dictionary in action["inputs"]:
		seconds += float(input["qty"]) * _seconds(String(input["item"]))
	var out_qty: float = 1.0
	for output: Dictionary in action["outputs"]:
		if String(output["item"]) == item:
			out_qty = float(output["qty"])
	return seconds / out_qty


func _load_actions() -> bool:
	for file: String in ACTION_FILES:
		var raw: Variant = _read_json("%s%s.json" % [ACTIONS_DIR, file])
		if not (raw is Dictionary):
			printerr("sim_village: cannot read %s" % file)
			return false
		for action: Dictionary in (raw as Dictionary)["actions"]:
			if not action.has("outputs"):
				continue
			for output: Dictionary in action["outputs"]:
				if not _producers.has(String(output["item"])):
					_producers[String(output["item"])] = action
	return true


func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))
