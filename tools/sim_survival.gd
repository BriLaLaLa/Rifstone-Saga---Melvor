extends SceneTree
## M17-04b: survival measurement. For each character level, in the area that fits the level and in the one before it,
## prints deaths, kills and food per hour for the real starting kit (sword and shield of balance.json `start`, no armour)
## and, with gear=set, for the forged set of the grade the level can wear (tools/sim_combat.gd helpers).
## Usage: godot --headless --path . -s tools/sim_survival.gd [-- levels=1,5,10 gear=start|set|both hours=1 seed=1234 area=<id>]
## Nothing is written. Reuses the static helpers of sim_combat.gd (level pin, set, food).

const SIM: String = "res://tools/sim_combat.gd"
const DEFAULTS: Dictionary = {"levels": "1,5,10,20,40,60", "gear": "both", "hours": "1", "seed": "1234", "area": ""}


func _initialize() -> void:
	var opts: Dictionary = DEFAULTS.duplicate()
	for arg: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = arg.split("=", true, 1)
		if parts.size() != 2 or not DEFAULTS.has(parts[0]):
			printerr("sim_survival: bad argument '%s'" % arg)
			quit(1)
			return
		opts[parts[0]] = parts[1]
	var sim: GDScript = load(SIM) as GDScript
	var data: Object = (load("res://core/data/game_data.gd") as GDScript).call("load_from_dirs", "res://data", "res://data/config")
	if not data.call("is_valid"):
		printerr("sim_survival: data is not valid")
		quit(1)
		return
	print_rich("| gear | level | area | deaths/h | kills/h | food/h | hp |")
	print_rich("|---|---|---|---|---|---|---|")
	var areas: Array = data.call("areas")
	for level_text: String in str(opts["levels"]).split(","):
		var level: int = int(level_text)
		var fit: int = 0
		for i: int in range(areas.size()):
			if int(areas[i].requirements.get(&"character", 1)) <= level:
				fit = i
		for index: int in range(areas.size()) if str(opts["area"]) != "" else [fit - 1, fit]:
			if index < 0 or (str(opts["area"]) != "" and str(opts["area"]) != str(areas[index].id)):
				continue
			for gear: String in ["start", "set"]:
				if str(opts["gear"]) in ["both", gear]:
					var r: Dictionary = measure(sim, data, areas[index], level, gear, opts)
					print_rich("| %s | %d | %s | %.1f | %.0f | %.0f | %d |" % [gear, level, areas[index].id, r["deaths"], r["kills"], r["food"], r["hp"]])
	quit(0)


static func measure(sim: GDScript, data: Object, area: Object, level: int, gear: String, opts: Dictionary) -> Dictionary:
	var session: Object = sim.call("_new_session", data, int(opts["seed"]))
	var xp_before: int = sim.call("_set_level", session, level)
	var grade: int = 1
	if gear == "set":
		grade = sim.call("auto_grade", data, level)
		sim.call("_equip_set", session, grade, &"sword_shield", &"plate")
	var food_id: StringName = StringName(str(data.call("balance_value", "start.food"))) if gear == "start" else sim.call("food_for_grade", data, grade)
	session.bank.add(food_id, 1000000)
	session.equipment.set_food(food_id)
	sim.call("_set_tier", session, maxi(1, sim.call("auto_tier", data, level)))
	var hp: int = int(session.combat.player_stats().max_hp)
	var food_start: int = session.bank.get_count(food_id)
	var total_ms: int = int(float(opts["hours"]) * 3600000.0)
	var elapsed: int = 0
	while elapsed < total_ms:
		if not session.combat.is_active() and not session.combat.start(area.id).ok:
			break
		session.advance(30000)
		elapsed += 30000
		sim.call("_pin_level", session, xp_before)
	var kills: int = 0
	var counts: Dictionary = session.combat.total_kills()
	for id: Variant in counts:
		kills += int(counts[id])
	var h: float = float(elapsed) / 3600000.0
	var row: Dictionary = {"deaths": session.combat.deaths() / h, "kills": kills / h, "food": (food_start - session.bank.get_count(food_id)) / h, "hp": hp}
	session.free()
	return row
