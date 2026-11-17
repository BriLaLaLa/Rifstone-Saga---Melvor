extends SceneTree
## Balance tool for the profession colours (M26-11, F-166/F-167/F-168 in docs/02_FORMULAS_M26.md). Read-only: nothing is written.
## For forging, woodwright and hearthcraft it plays the policy "highest known recipe" (the artisan action with the highest `level`
## <= the discipline level among trainer recipes and bought schemes; ties: highest xp; its same-discipline intermediates, e.g. the
## ingots of a plate, are crafted too) and prints the hours to reach the grade caps (20, 40, 60, 80, 99), BEFORE (M25: every cycle
## gives the full `xp`) and AFTER (colours: expected xp = xp x chance(L), F-167; the remainder of F-168 is its mean). Raw gathering
## time of other disciplines is not counted (gathering runs in the encounter cycle, in parallel). It also prints the gold spent in
## schemes (only the ones the policy uses, plus the sum of all the schemes up to the level) and in reagents (price x units), and
## the same gold as hours of combat gold at the tier of the moment (GOLD_PER_HOUR of tools/sim_quests.gd).
##
## Usage: godot --headless --path . -s tools/sim_professions.gd [-- cap_ratio=<max after/before hours at the last cap>]
## Exit code 1 if a discipline stalls (xp/h = 0 below level 99) or if after/before at level 99 exceeds `cap_ratio` (default 3.0).

const SKILLS: Array[String] = ["forging", "woodwright", "hearthcraft"]
const CAPS: Array[int] = [20, 40, 60, 80, 99]
const TIER_LEVELS: Array[int] = [1, 10, 20, 30, 45, 60, 75, 90]
const GOLD_PER_HOUR: Array[float] = [923.0, 2349.0, 3721.0, 2514.0, 5438.0, 7005.0, 8189.0, 8586.0]
const PPM: int = 1_000_000

var _balance: Dictionary = {}
var _actions: Dictionary = {}  # skill -> Array[Dictionary]
var _producers: Dictionary = {}  # item -> action (same skill)
var _scheme_price: Dictionary = {}  # action id -> gold
var _reagent_price: Dictionary = {}  # item id -> gold


func _initialize() -> void:
	quit(run(OS.get_cmdline_user_args()))


func run(args: PackedStringArray) -> int:
	var cap_ratio: float = 3.0
	for arg: String in args:
		if arg.begins_with("cap_ratio="):
			cap_ratio = float(arg.get_slice("=", 1))
		else:
			printerr("sim_professions: bad argument '%s'" % arg)
			return 1
	if not _load():
		return 1
	var code: int = 0
	print_rich("| skill | cap | hours before (M25) | hours after (colours) | after/before | scheme gold (used / all up to level) | reagent gold | gold as combat hours (used+reagents) |")
	print_rich("|---|---|---|---|---|---|---|---|")
	for skill: String in SKILLS:
		var before: Array = _play(skill, false)
		var after: Array = _play(skill, true)
		for i: int in CAPS.size():
			var b: Dictionary = before[i]
			var a: Dictionary = after[i]
			var ratio: float = float(a["hours"]) / maxf(0.0001, float(b["hours"]))
			print_rich("| %s | %d | %.1f | %.1f | %.2f | %d / %d | %d | %.1f |" % [skill, CAPS[i], b["hours"], a["hours"], ratio,
					int(a["scheme_gold"]), int(a["all_scheme_gold"]), int(a["reagent_gold"]), a["combat_hours"]])
			if is_inf(float(a["hours"])):
				code = 1
			elif CAPS[i] == 99 and ratio > cap_ratio:
				printerr("sim_professions: %s after/before %.2f > %.2f" % [skill, ratio, cap_ratio])
				code = 1
	return code


## Plays one discipline from level 1 to 99. Returns one row per cap (see CAPS).
func _play(skill: String, colours: bool) -> Array:
	var rows: Array = []
	var level: int = 1
	var hours: float = 0.0
	var scheme_gold: float = 0.0
	var reagent_gold: float = 0.0
	var combat_gold: float = 0.0
	var bought: Dictionary = {}
	var next_cap: int = 0
	while next_cap < CAPS.size():
		var best: Dictionary = _best(skill, level, bought)
		if not bought.has(best["id"]) and _scheme_price.has(best["id"]):
			bought[best["id"]] = true
			scheme_gold += float(_scheme_price[best["id"]])
		var chain: Array = []
		_chain(skill, best, 1.0, chain)
		var seconds: float = 0.0
		var xp: float = 0.0
		var reagents: float = 0.0
		for link: Dictionary in chain:
			var action: Dictionary = link["action"]
			var mult: float = float(link["mult"])
			seconds += mult * float(action["interval_ms"]) / 1000.0
			xp += mult * float(action["xp"]) * (_chance(action, level) if colours else 1.0)
			for input: Dictionary in action["inputs"]:
				reagents += mult * float(input["qty"]) * float(_reagent_price.get(String(input["item"]), 0))
		var need: float = float(_xp_for_level(level + 1) - _xp_for_level(level))
		if xp <= 0.0:
			for j: int in range(next_cap, CAPS.size()):
				rows.append({"hours": INF, "scheme_gold": scheme_gold, "all_scheme_gold": 0, "reagent_gold": reagent_gold, "combat_hours": 0.0})
			return rows
		var units: float = need / xp
		var dh: float = units * seconds / 3600.0
		hours += dh
		reagent_gold += units * reagents
		combat_gold += dh * GOLD_PER_HOUR[_tier(level)]
		level += 1
		if level >= CAPS[next_cap]:
			var spent: float = scheme_gold + reagent_gold
			rows.append({"hours": hours, "scheme_gold": scheme_gold, "all_scheme_gold": _all_schemes(skill, level), "reagent_gold": reagent_gold,
					"combat_hours": spent / maxf(1.0, combat_gold / hours)})
			next_cap += 1
	return rows


## Highest-level known recipe: trainer recipes, plus schemes (assumed bought when needed; the price is counted once).
func _best(skill: String, level: int, _bought: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	for action: Dictionary in _actions[skill]:
		if not _is_final(action, level):
			continue
		if best.is_empty() or int(action["level"]) > int(best["level"]) \
				or (int(action["level"]) == int(best["level"]) and int(action["xp"]) > int(best["xp"])):
			best = action
	return best


func _is_final(action: Dictionary, level: int) -> bool:
	if action.get("single", false) or not action.has("colors") or int(action["level"]) > level:
		return false
	return not action.get("discover", false) or _scheme_price.has(String(action["id"]))


## The action plus, recursively, the same-discipline actions that make its inputs (units per unit of the top action).
func _chain(skill: String, action: Dictionary, mult: float, out: Array) -> void:
	out.append({"action": action, "mult": mult})
	var out_qty: float = 1.0
	for output: Dictionary in action["outputs"]:
		out_qty = float(output["qty"])
		break
	for input: Dictionary in action["inputs"]:
		var producer: Dictionary = _producers.get(String(input["item"]), {})
		if not producer.is_empty() and String(producer["skill"]) == skill:
			_chain(skill, producer, mult * float(input["qty"]) / out_qty, out)


func _chance(action: Dictionary, level: int) -> float:
	var colors: Dictionary = action["colors"]
	var y: int = int(colors["yellow"])
	var x: int = int(colors["grey"])
	if level < y:
		return 1.0
	if level >= x:
		return 0.0
	return float((x - level) * PPM / (x - y)) / float(PPM)


func _all_schemes(skill: String, level: int) -> float:
	var total: float = 0.0
	for action: Dictionary in _actions[skill]:
		if int(action["level"]) <= level and _scheme_price.has(String(action["id"])):
			total += float(_scheme_price[String(action["id"])])
	return total


func _tier(level: int) -> int:
	var tier: int = 0
	for i: int in TIER_LEVELS.size():
		if TIER_LEVELS[i] <= level:
			tier = i
	return tier


func _xp_for_level(level: int) -> int:
	var curve: Dictionary = _balance["xp_curve"]
	var total: int = 0
	for k: int in range(1, level):
		total += int(floor(float(curve["base"]) * pow(float(curve["growth"]), k - 1) + float(curve["linear"]) * (k - 1)))
	return total


func _load() -> bool:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/config/balance.json"))
	if not (raw is Dictionary):
		printerr("sim_professions: cannot read balance.json")
		return false
	_balance = raw
	for skill: String in SKILLS:
		var file: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/actions/%s.json" % skill))
		if not (file is Dictionary):
			printerr("sim_professions: cannot read %s" % skill)
			return false
		var list: Array = []
		for action: Dictionary in (file as Dictionary)["actions"]:
			action["skill"] = skill
			list.append(action)
			for output: Dictionary in action.get("outputs", []):
				if not _producers.has(String(output["item"])):
					_producers[String(output["item"])] = action
		_actions[skill] = list
	var shop: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/shop/shop.json"))
	if not (shop is Dictionary):
		printerr("sim_professions: cannot read shop.json")
		return false
	for entry: Dictionary in (shop as Dictionary)["entries"]:
		if not (entry.get("effect", {}) is Dictionary) or not (entry["effect"] as Dictionary).has("item"):
			continue
		var item: String = String(entry["effect"]["item"]["item"])
		var gold: int = int(entry["cost"].get("gold", 0))
		if item.begins_with("recipe_"):
			_scheme_price[item.trim_prefix("recipe_")] = gold
		elif item.begins_with("reagent_"):
			_reagent_price[item] = gold
	return true
