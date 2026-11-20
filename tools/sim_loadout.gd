extends SceneTree
## Loadout helpers of tools/sim_combat.gd (M28-08) and the F-194 balance check (docs/02_FORMULAS_M28.md).
##
## Used by sim_combat: `traits=` / `abilities=` (comma lists of ids, `none` = empty, default `-` = follow `loadout=`).
## Run alone: godot --headless --path . -s tools/sim_loadout.gd [-- key=value ...]
##   levels=25,50,80,95   setups=greatsword,sword_shield,dual,sword   seed=1234   hours=1   groups=a,b,c   items=<id,id>
##   Prints, for each setup and level, group (a) one ability at a time (+none), (b) one trait at a time (+none) and (c) the
##   three full M28 loadouts next to `loadout=auto` and `m27` (the M27 contents only): kills/h (K), deaths/h (D), food/h (F),
##   then the F-194 (1)-(3) verdicts. `files=<txt,txt>` gives the verdicts of tables already printed (no measurement).
##   Exit code 1 on a bad argument. Slow: about 2.5 s of real time per row and simulated hour.
## The M27 contents (the first 12 traits and 6 abilities of rift_blade.json) are the ones of `loadout=auto`.

const SIM_PATH: String = "res://tools/sim_combat.gd"
const EXEMPT: Array[String] = ["first_blood", "hunters_eye"]  # opening_strike and target_rule: pure utility (F-194 (2))
const SETUP_ID: Dictionary = {"greatsword": &"greatsword", "sword_shield": &"sword_shield", "dual": &"dual_swords", "sword": &"sword"}
const M27_TRAITS: Array[StringName] = [&"chain_cleave", &"first_blood", &"ember_thirst", &"hunters_eye", &"last_stand", &"stone_stance",
		&"glass_edge", &"rift_thorns", &"cornered_fury", &"blood_ember", &"giant_breaker", &"greedy_fangs"]
const M27_ABILITIES: Array[StringName] = [&"whirl", &"rift_maul", &"shield_bash", &"ember_breath", &"twin_frenzy", &"blade_volley"]
## Three complete loadouts per setup (offensive, defensive, synergy), by unlock level order; the slots a level cannot open are ignored.
const LOADOUTS: Dictionary = {
	"greatsword": {
		"offensive": {"t": ["giant_breaker", "battle_rhythm", "blood_barter", "sentence"], "a": ["rift_maul", "guard_breaker", "last_swing"]},
		"defensive": {"t": ["last_stand", "colossus", "battle_crust", "blood_ember"], "a": ["ember_breath", "whirl", "quake_slam"]},
		"synergy": {"t": ["heavy_iron", "sentence", "momentum", "fighters_breath"], "a": ["quake_slam", "rift_maul", "last_swing"]}},
	"sword_shield": {
		"offensive": {"t": ["patient_wrath", "battle_rhythm", "blood_barter", "cornered_fury"], "a": ["shield_bash", "shield_toll", "tight_defense"]},
		"defensive": {"t": ["stone_stance", "living_bulwark", "shield_answer", "battle_crust"], "a": ["high_guard", "ember_breath", "shield_toll"]},
		"synergy": {"t": ["shield_answer", "living_bulwark", "patient_wrath", "fighters_breath"], "a": ["high_guard", "shield_bash", "tight_defense"]}},
	"dual": {
		"offensive": {"t": ["twin_wounds", "battle_rhythm", "blood_barter", "cornered_fury"], "a": ["twin_frenzy", "cut_storm", "cross_cuts"]},
		"defensive": {"t": ["dodge_dance", "blood_ember", "battle_crust", "last_stand"], "a": ["thirsting_blade", "twin_frenzy", "cross_cuts"]},
		"synergy": {"t": ["open_wounds", "twin_wounds", "blood_scent", "dodge_dance"], "a": ["cross_cuts", "cut_storm", "thirsting_blade"]}},
	"sword": {
		"offensive": {"t": ["fixed_gaze", "duelist", "battle_rhythm", "blood_barter"], "a": ["lunge", "final_thrust", "deep_cut"]},
		"defensive": {"t": ["blood_ember", "last_stand", "battle_crust", "fighters_breath"], "a": ["lunge", "guard_probe", "deep_cut"]},
		"synergy": {"t": ["foe_reading", "fixed_gaze", "technique_echo", "duelist"], "a": ["guard_probe", "final_thrust", "deep_cut"]}},
}


func _initialize() -> void:
	quit(run(OS.get_cmdline_user_args()))


## `csv` -> ids; "" and "none" = empty.
static func split(csv: String) -> Array[StringName]:
	var out: Array[StringName] = []
	if csv.strip_edges() == "none":
		return out
	for part: String in csv.split(",", false):
		out.append(StringName(part.strip_edges()))
	return out


## Applies the loadout the options ask for (call after the level and the gear are set). `traits=` / `abilities=` given =
## those ids in slot order; otherwise `loadout=auto` fills the open slots. Returns false (and prints) on a refused id.
static func apply(session: Object, data: Object, opts: Dictionary) -> bool:
	var ok: bool = true
	for is_trait: bool in [true, false]:
		var given: String = str(opts["traits" if is_trait else "abilities"])
		var ids: Array[StringName] = []
		if given == "m27":  # only the contents of M27, as `loadout=auto` chose them before M28
			ids = pick(session, data, is_trait, M27_TRAITS if is_trait else M27_ABILITIES)
		elif given != "-":
			ids = split(given)
		elif opts["loadout"] == "auto":
			ids = pick(session, data, is_trait, [])
		ok = set_all(session, ids, is_trait) and ok
	return ok


## Puts `ids` in the slots in order; false if one is refused.
static func set_all(session: Object, ids: Array[StringName], is_trait: bool) -> bool:
	var ok: bool = true
	for i: int in ids.size():
		var result: Object = session.loadout.call("set_trait" if is_trait else "set_ability", i, ids[i])
		if not result.ok:
			printerr("sim_loadout: cannot set %s %s in slot %d: %s" % ["trait" if is_trait else "ability", ids[i], i, result.reason])
			ok = false
	return ok


## The first entries (file order, among `pool` if not empty) unlocked at the level of the character and allowed by the worn assembly,
## one per open slot: what `loadout=auto` chooses.
static func pick(session: Object, data: Object, is_trait: bool, pool: Array[StringName]) -> Array[StringName]:
	var def: Object = data.call("character_class", session.character.class_id())
	var setup_id: StringName = session.equipment.setup()
	var level: int = session.character.get_level()
	var slots: int = int(session.loadout.trait_slots() if is_trait else session.loadout.ability_slots())
	var out: Array[StringName] = []
	for entry: Object in (def.traits if is_trait else def.abilities):
		if out.size() < slots and entry.unlock_level <= level and entry.allows_setup(setup_id) and not out.has(entry.id) \
				and (pool.is_empty() or pool.has(entry.id)):
			out.append(entry.id)
	return out


## The entries (ids) of the class that `setup_id` allows at `level`, file order.
static func available(data: Object, setup_id: StringName, level: int, is_trait: bool) -> Array[StringName]:
	var def: Object = data.call("character_class", &"rift_blade")
	var out: Array[StringName] = []
	for entry: Object in (def.traits if is_trait else def.abilities):
		if entry.unlock_level <= level and entry.allows_setup(setup_id):
			out.append(entry.id)
	return out


## The area whose level interval contains `level` (the first one in order).
static func area_for(data: Object, level: int) -> Object:
	for area: Object in data.call("areas"):
		if int(area.level_min) <= level and level <= int(area.level_max):
			return area
	return null


## The ids of the full loadout `kind` for `setup` at `level`: the listed entries that are unlocked, in order, cut at the open slots and
## completed (if short) with the first other entries that the level and the assembly allow.
static func full_loadout(data: Object, setup: String, level: int, kind: String, is_trait: bool) -> Array[StringName]:
	var sid: StringName = SETUP_ID[setup]
	var allowed: Array[StringName] = available(data, sid, level, is_trait)
	var slots: int = 0
	for at: Variant in data.call("balance_value", "traits.slot_levels" if is_trait else "abilities.slot_levels"):
		slots += 1 if int(at) <= level else 0
	var out: Array[StringName] = []
	for id: String in ((LOADOUTS[setup] as Dictionary)[kind] as Dictionary)["t" if is_trait else "a"]:
		if allowed.has(StringName(id)) and out.size() < slots:
			out.append(StringName(id))
	for id: StringName in allowed:
		if out.size() < slots and not out.has(id):
			out.append(id)
	return out


## One F-194 cell: the sim options for `setup` at `level` with the given explicit lists; returns {"K", "D", "F"} per hour.
static func cell(data: Object, setup: String, level: int, seed_value: int, hours: float, traits: String, abilities: String) -> Dictionary:
	var sim: GDScript = load(SIM_PATH) as GDScript
	var args: PackedStringArray = PackedStringArray(["scope=all", "setup=" + setup, "level=%d" % level,
			"seed=%d" % seed_value, "hours=%s" % str(hours), "traits=" + traits, "abilities=" + abilities])
	if traits == "-" and abilities == "-":
		args.append("loadout=auto")
	var opts: Dictionary = sim.call("parse_args", args)
	var row: Dictionary = sim.call("measure", data, area_for(data, level), "all", opts)
	var h: float = float(row["ms"]) / 3600000.0
	return {"K": float(row["kills"]) / h, "D": float(row["deaths"]) / h, "F": float(row["food"]) / h}


static func run(args: PackedStringArray) -> int:
	var o: Dictionary = {"levels": "25,50,80,95", "setups": "greatsword,sword_shield,dual,sword", "seed": "1234", "hours": "1", "groups": "a,b,c", "files": ""}
	for arg: String in args:
		var parts: PackedStringArray = arg.split("=", true, 1)
		if parts.size() != 2 or not o.has(parts[0]):
			printerr("sim_loadout: bad argument '%s'" % arg)
			return 1
		o[parts[0]] = parts[1]
	var game_data: GDScript = load("res://core/data/game_data.gd") as GDScript
	var data: Object = game_data.call("load_from_dirs", "res://data", "res://data/config")
	if not data.call("is_valid"):
		printerr("sim_loadout: data is not valid")
		return 1
	var all_lines: PackedStringArray = PackedStringArray()
	if str(o["files"]) != "":
		for path: String in str(o["files"]).split(","):
			all_lines.append_array(FileAccess.get_file_as_string(path).split("\n"))
	else:
		for setup: String in str(o["setups"]).split(","):
			for level_text: String in str(o["levels"]).split(","):
				for line: String in table(data, setup, int(level_text), o):
					print_rich(line)
					all_lines.append(line)
	for line: String in verdict(parse(all_lines)):
		print_rich(line)
	return 0


## Table lines (as printed, colour codes allowed) -> {"setup|level": {group: {entry: [K, D, F]}}}.
static func parse(lines: PackedStringArray) -> Dictionary:
	var out: Dictionary = {}
	var key: String = ""
	var colour: RegEx = RegEx.create_from_string("\u001b\\[[0-9;]*m")
	for raw: String in lines:
		var line: String = colour.sub(raw, "", true).strip_edges()
		if line.begins_with("###"):
			var head: PackedStringArray = line.trim_prefix("### ").split(", ")
			key = "%s|%s" % [head[0], head[1].trim_prefix("level ")]
			if not out.has(key):  # files of several runs may give the same cell: the groups add up
				out[key] = {}
		elif key != "" and line.begins_with("| ") and line.split("|").size() >= 7 and line.split("|")[1].strip_edges() in ["a", "b", "c"]:
			var cols: PackedStringArray = line.split("|")
			var group: String = cols[1].strip_edges()
			if not (out[key] as Dictionary).has(group):
				out[key][group] = {}
			out[key][group][cols[2].strip_edges()] = [float(cols[3]), float(cols[4]), float(cols[5])]
	return out


## F-194 (1)-(3) over parsed tables: one line per failure and a count of the checks that passed.
static func verdict(parsed: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var passed: int = 0
	var seen_ok: Dictionary = {}  # "setup|entry" -> true once the entry is not useless in a cell
	var seen_all: Dictionary = {}
	for key: String in parsed:
		var cell: Dictionary = parsed[key]
		for group: String in ["a", "b"]:
			var rows: Dictionary = cell.get(group, {})
			for id: String in rows:
				var me: Array = rows[id]
				var max_k: float = 0.0
				var dominated: bool = true  # D and F no worse than every other
				for other: String in rows:
					if other != id:
						max_k = maxf(max_k, rows[other][0])
						dominated = dominated and me[1] <= rows[other][1] and me[2] <= rows[other][2]
				if rows.size() > 1 and dominated and me[0] >= 1.10 * max_k:
					out.append("FAIL (1) %s group %s: %s dominates (K %.0f vs best other %.0f)" % [key, group, id, me[0], max_k])
				else:
					passed += 1
				if id == "none":
					continue
				var ks: Array = rows.values().map(func(r: Array) -> float: return r[0])
				ks.sort()
				var min_d: float = rows.values().map(func(r: Array) -> float: return r[1]).min()
				var max_d: float = rows.values().map(func(r: Array) -> float: return r[1]).max()
				var min_f: float = rows.values().map(func(r: Array) -> float: return r[2]).min()
				var useful: bool = me[0] >= 0.85 * float(ks[ks.size() / 2]) or (me[1] == min_d and min_d < max_d) or me[2] == min_f
				var entry_key: String = "%s|%s" % [key.split("|")[0], id]
				seen_all[entry_key] = true
				seen_ok[entry_key] = seen_ok.get(entry_key, false) or useful
		var reference: Dictionary = cell.get("c", {})
		var base: Array = reference.get("m27", reference.get("auto", []))
		var best: String = ""
		for id: String in ["offensive", "defensive", "synergy"]:
			if reference.has(id) and (best == "" or reference[id][0] > reference[best][0]):
				best = id
		if base.is_empty() or best == "":
			continue
		var fine: bool = reference[best][0] <= 1.15 * base[0] and reference[best][1] <= base[1]
		if fine:
			passed += 1
		else:
			out.append("FAIL (3) %s: best %s K %.0f D %.2f vs m27 K %.0f D %.2f (x%.2f)" % [key, best, reference[best][0], reference[best][1], base[0], base[1], reference[best][0] / maxf(1.0, base[0])])
	for entry_key: String in seen_all:
		if not seen_ok[entry_key] and not EXEMPT.has(entry_key.split("|")[1]):
			out.append("FAIL (2) %s is useless in every cell it appears" % entry_key)
	out.append("passed checks: %d, failures: %d" % [passed, out.size()])
	return out


## Markdown lines of one setup and level.
static func table(data: Object, setup: String, level: int, o: Dictionary) -> PackedStringArray:
	var seed_value: int = int(o["seed"])
	var hours: float = float(o["hours"])
	var sid: StringName = SETUP_ID[setup]
	var lines: PackedStringArray = PackedStringArray()
	lines.append("")
	lines.append("### %s, level %d, area %s, seed %d" % [setup, level, area_for(data, level).id, seed_value])
	lines.append("| group | entry | K/h | D/h | F/h |")
	lines.append("|---|---|---|---|---|")
	var groups: PackedStringArray = str(o["groups"]).split(",")
	if groups.has("a"):
		_rows(lines, data, setup, level, seed_value, hours, "a", ["none"] + available(data, sid, level, false))
	if groups.has("b"):
		_rows(lines, data, setup, level, seed_value, hours, "b", ["none"] + available(data, sid, level, true))
	if groups.has("c"):
		_rows(lines, data, setup, level, seed_value, hours, "c", ["auto", "m27"] + (LOADOUTS[setup] as Dictionary).keys())
	return lines


static func _rows(lines: PackedStringArray, data: Object, setup: String, level: int, seed_value: int, hours: float, group: String,
		entries: Array) -> void:
	for entry: Variant in entries:
		var traits: String = "-"
		var abilities: String = "-"
		var id: String = str(entry)
		match group:
			"a":
				traits = "none"
				abilities = id
			"b":
				traits = id
				abilities = "none"
			_:
				if id == "m27":
					traits = "m27"
					abilities = "m27"
				elif id != "auto":
					traits = ",".join(full_loadout(data, setup, level, id, true))
					abilities = ",".join(full_loadout(data, setup, level, id, false))
		var r: Dictionary = cell(data, setup, level, seed_value, hours, traits, abilities)
		lines.append("| %s | %s | %.1f | %.2f | %.1f |" % [group, id, r["K"], r["D"], r["F"]])
