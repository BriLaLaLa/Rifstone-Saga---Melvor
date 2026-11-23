extends SceneTree
## Balance tool for the cycle of encounters (docs/02_FORMULAS_M24.md F-156, docs/02_FORMULAS_M25.md F-161..F-165, M25 QA): drives the real
## CombatEngine on a session built from the real data (attempts, yield, rich nodes), checks the thresholds of F-156 and the closed form F-165 (+-5%).
##
## Usage: godot --headless --path . -s tools/sim_encounters.gd [-- key=value ...]
##   hours=<n>          simulated hours (default 12)
##   area=<id>          area fought (default redrock_plains)
##   level=auto|<n>     character level, kept fixed (auto = mean attack level of the area's monsters, as sim_combat)
##   learned=<a,b>|auto disciplines learned (auto = the two gathering disciplines with the highest weight in the area)
##   seed=<n>           session seed (default 1234)
##   nodes=1|0          0 = reference "before M24": node_chance_pct 0 and travel_ms = combat.respawn_ms
##   slice=<s>          seconds between pins of the levels (default 30)
##   tool=1|0           0 = clear the sources of skill_interval_pct (tools, mastery nodes) before the run (diagnosis Q123)
##   root=<res path>    content root (default res://data)
## The discipline levels are pinned at the cap of the area (M35B: L = max_level, the resource is the expected one of F-203); the level of the character as in sim_combat.
## Exit 0 if every threshold passes, 1 otherwise. Nothing is written. GameData and the sessions use the Log autoload, which does not
## exist while this `-s` script is compiled: they are reached through paths and dynamic calls. Output: print_rich/printerr.

const GAME_DATA_PATH: String = "res://core/data/game_data.gd"
const COMBAT_TOOL: String = "res://tools/sim_combat.gd"
const CYCLE_PATH: String = "res://systems/encounters/encounter_cycle.gd"
const CONFIG_ROOT: String = "res://data/config"
const HOUR_MS: int = 3600000
const DEFAULTS: Dictionary = {
	"hours": "12", "area": "redrock_plains", "level": "auto", "learned": "auto", "seed": "1234", "nodes": "1", "slice": "30", "tool": "1",
	"root": "res://data",
}
## Thresholds of F-156 (the values are the document's, not game data).
const KILLS_RATIO_MIN: float = 0.90
const UNITS_MIN: float = 300.0
const UNITS_MAX: float = 600.0
const XP_RATIO_MIN: float = 0.30
const CLOSED_FORM_TOLERANCE: float = 0.05


func _initialize() -> void:
	quit(run(OS.get_cmdline_user_args()))


static func parse_args(args: PackedStringArray) -> Dictionary:
	var opts: Dictionary = DEFAULTS.duplicate()
	for arg: String in args:
		var parts: PackedStringArray = arg.split("=", true, 1)
		if parts.size() != 2 or not DEFAULTS.has(parts[0]):
			opts["error"] = "bad argument '%s'" % arg
			return opts
		opts[parts[0]] = parts[1]
	return opts


func run(args: PackedStringArray) -> int:
	var opts: Dictionary = parse_args(args)
	if opts.has("error"):
		printerr("sim_encounters: %s" % opts["error"])
		return 1
	var data: Object = _load_data(opts)
	if not data.call("is_valid"):
		printerr("sim_encounters: data is not valid")
		return 1
	var lines: PackedStringArray = PackedStringArray()
	var failures: PackedStringArray = report(opts, lines)
	for line: String in lines:
		print_rich(line)
	for failure: String in failures:
		printerr("sim_encounters: OUT OF THRESHOLD: %s" % failure)
	return 1 if not failures.is_empty() else 0


static func _load_data(opts: Dictionary) -> Object:
	return (load(GAME_DATA_PATH) as GDScript).call("load_from_dirs", str(opts["root"]), CONFIG_ROOT)


## Runs the requested measurement (plus the reference when `nodes=1`), appends the tables and returns the failed thresholds.
static func report(opts: Dictionary, lines: PackedStringArray) -> PackedStringArray:
	var failures: PackedStringArray = PackedStringArray()
	var row: Dictionary = measure(_load_data(opts), opts, str(opts["nodes"]) == "1")
	lines.append("area %s, level %d, %.1f h, seed %s, nodes=%s" % [opts["area"], row["level"], row["hours"], opts["seed"], opts["nodes"]])
	lines.append("| encounters/h | fights/h | kills/h | nodes worked/h | skipped/h | E_F s | deaths | recipes/h | copper/h |")
	lines.append("|---|---|---|---|---|---|---|---|---|")
	lines.append("| %.2f | %.2f | %.1f | %.2f | %.2f | %.2f | %d | %.2f | %.0f |" % [row["per_hour"], row["fights_per_hour"], row["kills_per_hour"],
		row["worked_per_hour"], row["skipped_per_hour"], row["fight_ms"] / 1000.0, row["deaths"], row["recipes_per_hour"], row["gold_per_hour"]])
	if str(opts["nodes"]) != "1":
		return failures
	lines.append("")
	lines.append("| discipline | weight | worked/h | resource | color (last) | units/h | xp/h | dedicated xp/h | xp ratio | mean node s |")
	lines.append("|---|---|---|---|---|---|---|---|---|---|")
	for skill: StringName in row["learned"]:
		var s: Dictionary = row["skills"][skill]
		var ratio: float = s["xp_per_hour"] / maxf(s["dedicated_xp"], 0.001)
		lines.append("| %s | %d | %.2f | %s | %s | %.1f | %.0f | %.0f | %.2f | %.2f |" % [skill, s["weight"], s["worked_per_hour"], s["action"],
			s["color"], s["units_per_hour"], s["xp_per_hour"], s["dedicated_xp"], ratio, s["mean_ms"] / 1000.0])
		if s["units_per_hour"] < UNITS_MIN or s["units_per_hour"] > UNITS_MAX:
			lines.append("  measure (2): %s units/h %.1f outside %d..%d" % [skill, s["units_per_hour"], UNITS_MIN, UNITS_MAX])
		if ratio < XP_RATIO_MIN:
			lines.append("  measure (3): %s xp/h is %.0f%% of the dedicated work (min %d%%)" % [skill, ratio * 100.0, XP_RATIO_MIN * 100.0])
	var ref_opts: Dictionary = opts.duplicate()
	ref_opts["nodes"] = "0"
	var ref: Dictionary = measure(_load_data(opts), ref_opts, false)
	var kills_ratio: float = row["kills_per_hour"] / maxf(ref["kills_per_hour"], 0.001)
	lines.append("")
	lines.append("(1) kills/h with the cycle %.1f, reference (nodes=0) %.1f: ratio %.3f (min %.2f)" % [row["kills_per_hour"], ref["kills_per_hour"],
		kills_ratio, KILLS_RATIO_MIN])
	if kills_ratio < KILLS_RATIO_MIN:
		failures.append("(1) kills/h ratio %.3f under %.2f" % [kills_ratio, KILLS_RATIO_MIN])
	lines.append("")
	lines.append("closed form F-165 (F-155 node durations, measured E_F %.0f ms; encounters/h, fights/h, nodes worked/h, units/h, node s):" % row["fight_ms"])
	var expected: Dictionary = row["expected"]
	var expected_nodes: float = 0.0
	for value: Variant in (expected["nodes_per_hour"] as Dictionary).values():
		expected_nodes += float(value)
	var checks: Array = [["encounters/h", row["per_hour"], expected["per_hour"], 0.0], ["fights/h", row["fights_per_hour"], expected["fights_per_hour"], 0.0],
		["nodes worked/h", row["worked_per_hour"], expected_nodes, 2.0 / sqrt(maxf(1.0, float(row["worked"])))]]
	for skill: StringName in row["learned"]:
		lines.append("  skill_interval_pct sources of %s at the end: %s" % [skill, row["interval_sources_%s" % skill]])
	var rich_ms_mult: float = float(expected["ms_mult"])
	for skill: StringName in row["learned"]:
		var s: Dictionary = row["skills"][skill]
		var noise: float = 2.0 / sqrt(maxf(1.0, s["worked_per_hour"] * row["hours"]))
		checks.append(["%s units/h" % skill, s["units_per_hour"], (expected["units_per_hour"] as Dictionary)[skill], noise])
		checks.append(["%s node s (F-155 x mM)" % skill, s["mean_ms"] / 1000.0, s["f155_ms"] * rich_ms_mult / 1000.0, noise])
	for check: Array in checks:
		var gap: float = (float(check[1]) - float(check[2])) / maxf(float(check[2]), 0.001)
		var tolerance: float = maxf(CLOSED_FORM_TOLERANCE, float(check[3]))  # the node count carries its own sampling noise
		lines.append("  %s: measured %.2f, expected %.2f, gap %+.1f%% (tolerance %.1f%%)" % [check[0], check[1], check[2], gap * 100.0, tolerance * 100.0])
		if absf(gap) > tolerance:
			failures.append("closed form: %s gap %+.1f%% over %.1f%%" % [check[0], gap * 100.0, tolerance * 100.0])
	expected_lines(_load_data(opts), lines)
	return failures


## One measurement: a fresh session (forged set, food, rations as sim_combat), disciplines learned at the grade that covers the area,
## the area fought for `hours`. `with_expected` adds the closed form F-156. The reference run (`nodes=0`) edits only its own `data`.
static func measure(data: Object, opts: Dictionary, with_expected: bool) -> Dictionary:
	var combat_tool: GDScript = load(COMBAT_TOOL) as GDScript
	var cycle: GDScript = load(CYCLE_PATH) as GDScript
	var area: Object = data.call("area", StringName(str(opts["area"])))
	var nodes_def: Object = data.call("area_nodes", area.id)
	var balance: Dictionary = data.get("_balance") as Dictionary
	if str(opts["nodes"]) != "1":
		(balance["encounters"] as Dictionary)["node_chance_pct"] = 0
		(balance["encounters"] as Dictionary)["travel_ms"] = (balance["combat"] as Dictionary)["respawn_ms"]
	var level: int = int(combat_tool.call("auto_level", data, area)) if str(opts["level"]) == "auto" else int(opts["level"])
	var grade: int = int(combat_tool.call("auto_grade", data, level))
	var session: Object = combat_tool.call("_new_session", data, int(opts["seed"]))
	var xp_before: int = int(combat_tool.call("_set_level", session, level))
	combat_tool.call("_equip_set", session, grade, &"sword_shield", &"plate")
	var food_id: StringName = combat_tool.call("food_for_grade", data, grade)
	session.bank.add(food_id, 1000000)
	session.equipment.set_food(food_id)
	combat_tool.call("_set_tier", session, combat_tool.call("auto_tier", data, level))
	session.deposit.register_occupant(&"sim:room", func() -> int: return -10000)
	var weights: Dictionary = {}
	for entry: Object in nodes_def.entries:
		weights[entry.skill] = int(entry.weight)
	var learned: Array[StringName] = _learned(str(opts["learned"]), nodes_def, data)
	var pinned: Dictionary = {}
	for skill: StringName in learned:
		session.disciplines._grades[skill] = (data.call("trainer_grades") as Array).size()
		var missing: int = int(data.call("xp_table").xp_for_level(int(nodes_def.max_level))) - int(session.skills.get_xp(skill))
		session.skills.add_xp(skill, missing)
		pinned[skill] = int(session.skills.get_xp(skill))
	if str(opts["tool"]) == "0":
		_clear_interval_sources(session, learned, cycle, nodes_def, data)
	var tally: Dictionary = _tally(session)
	var total_ms: int = int(float(opts["hours"]) * HOUR_MS)
	var slice_ms: int = maxi(1, int(float(opts["slice"]) * 1000.0))
	var gold_start: int = session.wallet.get_gold()
	var elapsed: int = 0
	while elapsed < total_ms:
		if not session.combat.is_active() and not session.combat.start(area.id).ok:
			break
		var step_ms: int = mini(slice_ms, total_ms - elapsed)
		session.advance(step_ms)
		elapsed += step_ms
		combat_tool.call("_pin_level", session, xp_before)
		for skill: StringName in pinned:
			if int(session.skills.get_xp(skill)) != int(pinned[skill]):
				session.skills._xp[skill] = int(pinned[skill])
				session.skills._apply_level_source(skill)
	var hours: float = float(elapsed) / HOUR_MS
	var started: int = int(tally["fights"])
	var fight_ms: float = float(elapsed - int(tally["travel_ms"]) - int(tally["node_ms"])) / maxf(1.0, float(tally["cleared"]))
	var recipes: int = _recipes(session, data, int(tally["recipes_lost"]))
	var row: Dictionary = {
		"level": level, "hours": hours, "per_hour": float(started + int(tally["worked"]) + int(tally["skipped"])) / hours,
		"fights_per_hour": float(started) / hours, "kills_per_hour": float(tally["kills"]) / hours, "fight_ms": fight_ms,
		"worked": int(tally["worked"]), "worked_per_hour": float(tally["worked"]) / hours, "skipped_per_hour": float(tally["skipped"]) / hours,
		"deaths": session.combat.deaths(), "recipes_per_hour": float(recipes) / hours, "learned": learned,
		"gold_per_hour": float(session.wallet.get_gold() - gold_start) / hours, "skills": {},
	}
	var params: Dictionary = {"travel_ms": int(data.call("balance_value", "encounters.travel_ms")),
		"node_chance_pct": float(data.call("balance_value", "encounters.node_chance_pct")), "fight_ms": fight_ms,
		"skip_ms": int(data.call("balance_value", "encounters.skip_ms")), "node_units": int(data.call("balance_value", "encounters.node_units")),
		"weights": weights, "learned": learned, "node_ms": {}, "yield": {}, "unit_bonus_pct": {}, "rich_by_skill": {},
		"rich_chance_pct": int(data.call("balance_value", "encounters.rich_chance_pct")),
		"rich_ms_pct": int(data.call("balance_value", "encounters.rich_ms_pct")), "rich_units_pct": int(data.call("balance_value", "encounters.rich_units_pct"))}
	for skill: StringName in learned:
		var worked: int = int((tally["skill_worked"] as Dictionary).get(skill, 0))
		var mean_ms: float = float((tally["skill_ms"] as Dictionary).get(skill, 0)) / maxf(1.0, float(worked))
		var step_def: Object = _step(cycle, data, area.id, skill, int(nodes_def.max_level))
		var f155_ms: int = int(cycle.call("node_duration_ms", session, skill, step_def))
		(params["node_ms"] as Dictionary)[skill] = f155_ms
		var diff: int = int(cycle.call("difficulty", session, area.id, skill))
		var parts: PackedStringArray = PackedStringArray()
		for entry: Dictionary in session.modifiers.breakdown(&"skill_interval_pct", ModifierContext.for_action(skill, step_def.id)):
			parts.append("%s %+.1f" % [entry["source"], entry["value"]])
		row["interval_sources_%s" % skill] = ", ".join(parts)
		(params["yield"] as Dictionary)[skill] =int(cycle.call("yield_pct", session, int(session.skills.get_level(skill)), diff))
		# M35 (F-198, F-199): the heads of the tools change `u` and `p` of the skill; the closed form reads them from the modifiers
		(params["unit_bonus_pct"] as Dictionary)[skill] = int(cycle.call("units_bonus_pct", session, skill, step_def))
		(params["rich_by_skill"] as Dictionary)[skill] = float(cycle.call("rich_chance", session, skill, step_def))
		var action: String = _top_key(tally["skill_actions"].get(skill, {}))
		var def: Object = data.call("action", StringName(action)) if action != "" else null
		var dedicated: float = float(HOUR_MS) / float(def.interval_ms) * float(def.xp) if def != null else 0.0
		row["skills"][skill] = {"weight": int(weights.get(skill, 0)), "worked_per_hour": float(worked) / hours, "action": action,
			"color": str(tally["last_color"].get(skill, "")), "units_per_hour": float((tally["skill_units"] as Dictionary).get(skill, 0)) / hours,
			"xp_per_hour": float((tally["skill_xp"] as Dictionary).get(skill, 0)) / hours, "dedicated_xp": dedicated, "mean_ms": mean_ms, "f155_ms": f155_ms}
	if with_expected:
		row["expected"] = cycle.call("expected", params)
		var rich: float = float(params["rich_chance_pct"]) / 100.0
		row["expected"]["ms_mult"] = 1.0 + rich * (float(params["rich_ms_pct"]) / 100.0 - 1.0)
	session.free()
	return row


## M35B (F-203): the representative resource of the skill at level `level` in the area: the eligible entry with the highest effective chance
## (the first on a tie), else the fallback. The tally of the run still counts the resources that really came up.
static func _step(cycle: GDScript, data: Object, area_id: StringName, skill: StringName, level: int) -> Object:
	var best: Object = null
	var best_pct: float = 0.0
	for row: Dictionary in cycle.call("resource_odds", data, area_id, skill, level):
		if bool(row["workable"]) and (best == null or float(row["pct_effective"]) > best_pct):
			best = row["action"]
			best_pct = float(row["pct_effective"])
	return best if best != null else cycle.call("fallback_action", data, skill, level)


## M35B (F-203): `E[xp_pct]` of the node of `skill` in the area at level `level`, `sum(P_eff/100 x xp_pct(color(level - level(e))))`; 100% of the
## fallback when no entry is eligible. Pure measure, no failure (Q226).
static func expected_xp_pct(cycle: GDScript, data: Object, area_id: StringName, skill: StringName, level: int) -> float:
	var total: float = 0.0
	var rows: Array = cycle.call("resource_odds", data, area_id, skill, level)
	for row: Dictionary in rows:
		if bool(row["workable"]):
			total += float(row["pct_effective"]) / 100.0 * float(cycle.call("color", data, level, int(row["action"].level))["xp_pct"])
	if total == 0.0:
		var fallback: Object = cycle.call("fallback_action", data, skill, level)
		return float(cycle.call("color", data, level, int(fallback.level))["xp_pct"]) if fallback != null else 0.0
	return total


## M35B (F-203, Q226): the expected `xp_pct` per area and gathering discipline at `L` = the cap of the zone, a measure to report (no threshold).
static func expected_lines(data: Object, lines: PackedStringArray) -> void:
	var cycle: GDScript = load(CYCLE_PATH) as GDScript
	lines.append("")
	lines.append("F-203 expected xp_pct of a node at L = max_level of the zone (measure, thresholds (2) and (3) of F-156 are reported, not enforced):")
	for area: Object in data.call("areas"):
		var nodes_def: Object = data.call("area_nodes", area.id)
		if nodes_def == null:
			continue
		var cells: PackedStringArray = PackedStringArray()
		for entry: Object in nodes_def.entries:
			cells.append("%s %.1f%%" % [entry.skill, expected_xp_pct(cycle, data, area.id, entry.skill, int(nodes_def.max_level))])
		lines.append("  %s (L %d): %s" % [area.id, int(nodes_def.max_level), ", ".join(cells)])


## Q123 diagnosis: clears every source that contributes to `skill_interval_pct` for the worked step of a learned discipline.
static func _clear_interval_sources(session: Object, learned: Array[StringName], cycle: GDScript, nodes_def: Object, data: Object) -> void:
	for skill: StringName in learned:
		var step: Object = _step(cycle, data, nodes_def.area, skill, int(nodes_def.max_level))
		var ctx: ModifierContext = ModifierContext.for_action(skill, step.id)
		for entry: Dictionary in session.modifiers.breakdown(&"skill_interval_pct", ctx):
			session.modifiers.clear_source(entry["source"])


## Learned disciplines: the argument, or the two gathering disciplines of the area with the highest weight (file order on a tie).
static func _learned(arg: String, nodes_def: Object, data: Object) -> Array[StringName]:
	var result: Array[StringName] = []
	if arg != "auto":
		for part: String in arg.split(",", false):
			result.append(StringName(part))
		return result
	var entries: Array = nodes_def.entries.duplicate()
	entries.sort_custom(func(a: Object, b: Object) -> bool: return a.weight > b.weight)
	var limit: int = int(data.call("balance_value", "disciplines.max_per_category"))
	for entry: Object in entries:
		if result.size() < limit and data.call("skill", entry.skill).category == &"gathering":
			result.append(entry.skill)
	return result


static func _top_key(counts: Dictionary) -> String:
	var best: String = ""
	var best_count: int = -1
	for key: Variant in counts:
		if int(counts[key]) > best_count:
			best = str(key)
			best_count = int(counts[key])
	return best


## Recipe items dropped: in the Deposit, in the loot bag or lost to a full bag (`lost`, counted from `loot_lost`).
static func _recipes(session: Object, data: Object, lost: int) -> int:
	var total: int = lost
	for item: Object in data.call("items"):
		if item.category == &"recipe":
			total += int(session.bank.get_count(item.id))
	for entry: Dictionary in session.combat.loot.items():
		if data.call("item", entry["item"]).category == &"recipe":
			total += int(entry["qty"])
	return total


## Connects the counters of the run to the session events and returns the dictionary they fill.
static func _tally(session: Object) -> Dictionary:
	var t: Dictionary = {"fights": 0, "cleared": 0, "kills": 0, "worked": 0, "skipped": 0, "travel_ms": 0, "node_ms": 0,
		"skill_worked": {}, "skill_ms": {}, "skill_units": {}, "skill_xp": {}, "skill_actions": {}, "last_color": {}, "recipes_lost": 0}
	var events: Object = session.events
	events.encounter_started.connect(func(_ids: Array[StringName]) -> void: t["fights"] += 1)
	events.encounter_cleared.connect(func() -> void: t["cleared"] += 1)
	events.monster_killed.connect(func(_i: int, _id: StringName) -> void: t["kills"] += 1)
	events.travel_started.connect(func(_k: StringName, _s: StringName, duration_ms: int) -> void: t["travel_ms"] += duration_ms)
	events.node_started.connect(func(skill: StringName, _a: StringName, skipped: bool, duration_ms: int) -> void:
		t["node_ms"] += duration_ms
		if skipped:
			t["skipped"] += 1
		else:
			t["worked"] += 1
			t["skill_worked"][skill] = int(t["skill_worked"].get(skill, 0)) + 1
			t["skill_ms"][skill] = int(t["skill_ms"].get(skill, 0)) + duration_ms)
	events.node_finished.connect(func(skill: StringName, action: StringName, units: int, _reason: StringName) -> void:
		t["skill_units"][skill] = int(t["skill_units"].get(skill, 0)) + units
		var actions: Dictionary = t["skill_actions"].get(skill, {})
		actions[str(action)] = int(actions.get(str(action), 0)) + 1
		t["skill_actions"][skill] = actions
		var def: Object = session.data.call("action", action)
		t["last_color"][skill] = (load(CYCLE_PATH) as GDScript).call("color", session.data, session.skills.get_level(skill), def.level)["id"])
	events.loot_lost.connect(func(item: StringName, qty: int) -> void:
		if session.data.call("item", item).category == &"recipe":
			t["recipes_lost"] += qty)
	events.xp_gained.connect(func(skill: StringName, amount: int) -> void:
		t["skill_xp"][skill] = int(t["skill_xp"].get(skill, 0)) + amount)
	return t
