extends SceneTree
## M32-05: meat as food. For a character WITHOUT Fishing (no fish food), per area: the food consumed per hour in combat
## (healing/h, from tools/sim_combat.gd on the real engine) against the healing/h that the meat of the area gives once cooked
## (kills/h of each animal x drop chance x mean qty x heal of the cooked item of the recipe that eats that meat).
## Usage: godot --headless --path . -s tools/sim_meat.gd [-- hours=<n> seed=<n> area=<id>|all scope=all|easiest]
## Nothing is written. Prints a table; exit 0 (the numbers are a report, a fascia under the consumption is not an error of the tool).

const SIM: String = "res://tools/sim_combat.gd"
const DEFAULTS: Dictionary = {"hours": "2", "seed": "1234", "area": "all", "scope": "all"}


func _initialize() -> void:
	var opts: Dictionary = DEFAULTS.duplicate()
	for arg: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = arg.split("=", true, 1)
		if parts.size() != 2 or not DEFAULTS.has(parts[0]):
			printerr("sim_meat: bad argument '%s'" % arg)
			quit(1)
			return
		opts[parts[0]] = parts[1]
	var sim: GDScript = load(SIM) as GDScript
	var data: Object = (load("res://core/data/game_data.gd") as GDScript).call("load_from_dirs", "res://data", "res://data/config")
	if not data.call("is_valid"):
		printerr("sim_meat: data is not valid")
		quit(1)
		return
	var base: Dictionary = sim.call("parse_args", PackedStringArray(["hours=" + str(opts["hours"]), "seed=" + str(opts["seed"]), "scope=" + str(opts["scope"])]))
	print_rich("| area | level | deaths/h | kills/h | eaten/h | heal eaten/h | meat/h | heal meat/h | meat / need |")
	print_rich("|---|---|---|---|---|---|---|---|---|")
	for area: Object in data.call("areas"):
		if str(opts["area"]) != "all" and str(opts["area"]) != str(area.id):
			continue
		var row: Dictionary = sim.call("measure", data, area, str(opts["scope"]), base)
		var hours: float = float(row["ms"]) / 3600000.0
		var food: Object = data.call("item", sim.call("food_for_grade", data, row["grade"]))
		var need: float = float(row["food"]) * float(food.food_heal) / hours
		var meat: float = 0.0
		var heal: float = 0.0
		for monster_id: Variant in row["counts"]:
			var m: Object = data.call("monster", monster_id)
			for drop: Object in m.drops:
				var recipe: Object = _recipe_eating(data, drop.item_id)
				if recipe == null:
					continue
				var per_hour: float = float(row["counts"][monster_id]) / hours * drop.chance_pct / 100.0 * (drop.qty_min + drop.qty_max) / 2.0
				meat += per_hour
				heal += per_hour * float(data.call("item", recipe.outputs[0].item_id).food_heal)
		print_rich("| %s | %d | %.1f | %.0f | %.0f | %.0f | %.1f | %.0f | %.2f |" % [area.id, row["level"],
			float(row["deaths"]) / hours, float(row["kills"]) / hours, float(row["food"]) / hours, need, meat, heal, heal / maxf(need, 1.0)])
	quit(0)


static func _recipe_eating(data: Object, item_id: StringName) -> Object:
	for action: Object in data.call("actions_for_skill", &"hearthcraft"):
		for input: Object in action.inputs:
			if input.item_id == item_id and str(action.id).begins_with("cook_"):
				return action
	return null
