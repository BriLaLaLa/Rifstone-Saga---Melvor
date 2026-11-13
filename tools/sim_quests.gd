extends SceneTree
## Balance tool for the Noticeboard quests (M20-01, F-134/F-135 in docs/02_FORMULAS.md). Read-only: nothing is written.
## For every quest type and tier it prints the hours needed to complete the objective (raw gathering for gather and craft,
## kills per hour measured by tools/sim_combat.gd for kill), the gold per hour of the quest and its ratio with the gold per
## hour of combat of the same tier. Parameters: balance.json "quest" when it exists (M20-02); until then the defaults below,
## which are the values fixed by M20-01.
##
## Usage: godot --headless --path . -s tools/sim_quests.gd [-- cap=<hours> ratio=<max gold ratio>]
## Exit code 1 if some quest needs more than `cap` hours (default 0.6) or pays more than `ratio` times the combat gold of
## the same time (default 0.7).

const ACTION_FILES: Array[String] = ["forestry", "quarrying", "angling", "forging", "hearthcraft", "woodwright"]
const ACTIONS_DIR: String = "res://data/actions/"
const BALANCE_PATH: String = "res://data/config/balance.json"
const WOODS: Array[String] = ["redbirch", "ashpine", "thornalder", "duskelm", "shardcedar", "veilcypress", "emberlarch", "riftspruce"]
const METALS: Array[String] = ["emberbronze", "ashlead", "stormzinc", "duskcobalt", "glimmerite", "palecinnabar", "emberheart", "riftite"]
const FISH: Array[String] = ["brookfin", "ashgill", "redscale", "dusk_eel", "shard_gar", "mist_barbel", "ember_sturgeon", "riftmaw"]
## Same areas and measurements as tools/sim_village.gd (sim_combat, scope all, M19-01 run); kills/h from the same run.
const GOLD_PER_HOUR: Array[float] = [923.0, 2349.0, 3721.0, 2514.0, 5438.0, 7005.0, 8189.0, 8586.0]
const KILLS_PER_HOUR: Array[float] = [213.0, 268.0, 244.0, 156.0, 222.0, 236.0, 222.0, 194.0]

const DEFAULT_PARAMS: Dictionary = {
	"gold_by_tier": [80, 250, 340, 380, 600, 800, 950, 1030],
	"types": {
		"kill": {"base": 40, "per_tier": 8, "gold_mult": 1.0},
		"gather": {"base": 150, "per_tier": 15, "gold_mult": 0.8},
		"craft": {"base": 30, "per_tier": 4, "gold_mult": 1.0, "mult": {"forging": 1.0, "hearthcraft": 3.0, "woodwright": 4.0}},
	},
}

var _producers: Dictionary = {}


func _initialize() -> void:
	quit(run(OS.get_cmdline_user_args()))


func run(args: PackedStringArray) -> int:
	var cap: float = 0.6
	var ratio_cap: float = 0.7
	for arg: String in args:
		if arg.begins_with("cap="):
			cap = float(arg.get_slice("=", 1))
		elif arg.begins_with("ratio="):
			ratio_cap = float(arg.get_slice("=", 1))
		else:
			printerr("sim_quests: bad argument '%s'" % arg)
			return 1
	if not _load_actions():
		return 1
	var params: Dictionary = _params()
	var worst_h: float = 0.0
	var worst_ratio: float = 0.0
	print_rich("| type | skill | tier | target | hours | quest gold | gold/h of the quest | ratio vs combat |")
	print_rich("|---|---|---|---|---|---|---|---|")
	for type: String in ["kill", "gather", "craft"]:
		var spec: Dictionary = params["types"][type]
		for skill: String in _skills_of(type):
			for tier: int in range(1, 9):
				var target: int = (int(spec["base"]) + int(spec["per_tier"]) * (tier - 1)) * int(spec.get("mult", {}).get(skill, 1))
				var hours: float = _hours(type, skill, tier, target)
				var gold: float = float(int(params["gold_by_tier"][tier - 1])) * float(spec["gold_mult"])
				var ratio: float = (gold / hours) / GOLD_PER_HOUR[tier - 1]
				worst_h = maxf(worst_h, hours)
				worst_ratio = maxf(worst_ratio, ratio)
				print_rich("| %s | %s | %d | %d | %.2f | %d | %d | %.2f |" % [type, skill, tier, target, hours, int(gold), int(gold / hours), ratio])
	print_rich("worst quest: %.2f h (cap %.2f h); worst gold ratio %.2f (cap %.2f)" % [worst_h, cap, worst_ratio, ratio_cap])
	return 1 if (worst_h > cap or worst_ratio > ratio_cap) else 0


func _skills_of(type: String) -> Array[String]:
	match type:
		"kill":
			return ["combat"]
		"gather":
			return ["forestry", "quarrying", "angling"]
	return ["forging", "hearthcraft", "woodwright"]


func _item(type: String, skill: String, tier: int) -> String:
	match skill:
		"forestry": return "%s_log" % WOODS[tier - 1]
		"quarrying": return "%s_ore" % METALS[tier - 1]
		"angling": return FISH[tier - 1]
		"forging": return "%s_plate" % METALS[tier - 1]
		"hearthcraft": return "seared_%s" % FISH[tier - 1]
		"woodwright": return "%s_grip" % WOODS[tier - 1]
	return ""


func _hours(type: String, skill: String, tier: int, target: int) -> float:
	if type == "kill":
		return float(target) / KILLS_PER_HOUR[tier - 1]
	return float(target) * _seconds(_item(type, skill, tier)) / 3600.0


func _params() -> Dictionary:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(BALANCE_PATH))
	if raw is Dictionary and (raw as Dictionary).has("quest"):
		var quest: Dictionary = (raw as Dictionary)["quest"]
		return {"gold_by_tier": quest["gold_by_tier"], "types": quest["types"]}
	return DEFAULT_PARAMS


## Seconds to make one unit of `item` from raw gathering: (interval + ingredients) / output quantity, recursive.
func _seconds(item: String) -> float:
	var action: Dictionary = _producers.get(item, {})
	if action.is_empty():
		printerr("sim_quests: no action produces '%s'" % item)
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
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("%s%s.json" % [ACTIONS_DIR, file]))
		if not (raw is Dictionary):
			printerr("sim_quests: cannot read %s" % file)
			return false
		for action: Dictionary in (raw as Dictionary)["actions"]:
			if not action.has("outputs"):
				continue
			for output: Dictionary in action["outputs"]:
				if not _producers.has(String(output["item"])):
					_producers[String(output["item"])] = action
	return true
