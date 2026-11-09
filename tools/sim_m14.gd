extends SceneTree
## Balance tool of the Alpha (docs/02_FORMULAS.md §5e, §8.4, M14-10): the targets of ALPHA.md §10 measured on the real data.
## It reuses tools/sim_combat.gd (drops, Rift Dust), tools/sim_fracture.gd (duration of the Fractures) and
## tools/sim_progress.gd (B1), and adds the Armour and Barrier reduction by level and the legendary rate of the Fractures.
##
## Usage: godot --headless --path . -s tools/sim_m14.gd [-- key=value ...]
##   hours=<n>        simulated hours per area for the drops (default 24)
##   seeds=<a,b,c>    seeds of the Fracture runs (default 1,2,3,4,5,6)
##   seed=<n>         seed of the area runs (default 1234)
##   part=all|drops|armor|fractures|legendary|progress   section to print (default all)
## Nothing is written. Output goes through print_rich/printerr (bare print is forbidden).

const GAME_DATA_PATH: String = "res://core/data/game_data.gd"
const COMBAT_TOOL: String = "res://tools/sim_combat.gd"
const FRACTURE_TOOL: String = "res://tools/sim_fracture.gd"
const PROGRESS_TOOL: String = "res://tools/sim_progress.gd"
const CONFIG_ROOT: String = "res://data/config"
const ARMOR_LEVELS: Array[int] = [1, 50, 90]
## Minutes between two Fractures spent outside the fight (choosing a Card, collecting the bag): added to the duration.
const FRACTURE_OVERHEAD_MIN: float = 2.0
const DEFAULTS: Dictionary = {"hours": "24", "seeds": "1,2,3,4,5,6", "seed": "1234", "part": "all"}


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
		printerr("sim_m14: %s" % opts["error"])
		return 1
	var data: Object = (load(GAME_DATA_PATH) as GDScript).call("load_from_dirs", "res://data", CONFIG_ROOT)
	if not data.call("is_valid"):
		printerr("sim_m14: data is not valid")
		return 1
	var part: String = str(opts["part"])
	var lines: PackedStringArray = PackedStringArray()
	if part in ["all", "drops"]:
		lines.append_array(drops_report(data, opts))
	if part in ["all", "armor"]:
		lines.append_array(armor_report(data))
	if part in ["all", "fractures", "legendary"]:
		lines.append_array(fracture_report(data, opts))
	if part in ["all", "progress"]:
		var sim: GDScript = load(COMBAT_TOOL) as GDScript
		lines.append_array((load(PROGRESS_TOOL) as GDScript).call("report", sim, data, sim.call("parse_args", ["scope=all"])))
	for line: String in lines:
		print_rich(line)
	return 0


## Drops per 30 minutes in each area at the level of its monsters (grade of the set from the level, see sim_combat).
static func drops_report(data: Object, opts: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	out.append("| area | kills/h | pieces/30 min | magic/30 min | hours per rare | projects/h | dust/h | gold/h |")
	out.append("|---|---|---|---|---|---|---|---|")
	for area: Object in data.call("areas"):
		var row: Dictionary = area_drops(data, area, float(opts["hours"]), int(opts["seed"]))
		out.append("| %s | %.0f | %.2f | %.2f | %.1f | %.2f | %.0f | %.0f |" % [area.id, row["kills_h"], row["pieces_30"],
			row["magic_30"], row["hours_per_rare"], row["projects_h"], row["dust_h"], row["gold_h"]])
	out.append("")
	return out


## One long run of `area` (all packs) turned into per-hour figures.
static func area_drops(data: Object, area: Object, hours: float, seed_value: int) -> Dictionary:
	var sim: GDScript = load(COMBAT_TOOL) as GDScript
	var opts: Dictionary = sim.call("parse_args", PackedStringArray(["hours=%s" % hours, "seed=%d" % seed_value]))
	var row: Dictionary = sim.call("measure", data, area, "all", opts)
	var h: float = float(row["ms"]) / 3600000.0
	return {
		"kills_h": row["kills"] / h, "pieces_30": row["pieces"] / h / 2.0, "magic_30": row["magic"] / h / 2.0,
		"hours_per_rare": h / maxf(1.0, float(row["rare"])), "projects_h": row["bps"] / h, "dust_h": row["dust"] / h,
		"gold_h": row["gold"] / h, "deaths_h": row["deaths"] / h, "pieces": row["pieces"], "magic": row["magic"],
		"rare": row["rare"], "hours": h,
	}


## Reduction of the worn set (grade of the level, shield and sword) against a monster of the character's level: the stat of the
## material gives `armor_pct` (Armour, blade and marksmanship) and `barrier_pct` (Barrier, arcana). F-117.
static func armor_reduction(data: Object, level: int, material: StringName) -> Dictionary:
	var sim: GDScript = load(COMBAT_TOOL) as GDScript
	var session: Object = sim.call("_new_session", data, 1)
	sim.call("_set_level", session, level)
	sim.call("_equip_set", session, sim.call("auto_grade", data, level), &"sword_shield", material)
	var me: Object = session.combat.player_stats()
	var result: Dictionary = {
		"armor": me.armor, "barrier": me.barrier,
		"armor_pct": me.reduction_against(&"blade", level, data), "barrier_pct": me.reduction_against(&"arcana", level, data),
	}
	session.free()
	return result


static func armor_report(data: Object) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	out.append("| level | material | armor | barrier | armor % | barrier % |")
	out.append("|---|---|---|---|---|---|")
	for level: int in ARMOR_LEVELS:
		for material: StringName in [&"plate", &"leather", &"cloth"]:
			var r: Dictionary = armor_reduction(data, level, material)
			out.append("| %d | %s | %d | %d | %.1f | %.1f |" % [level, material, r["armor"], r["barrier"], r["armor_pct"], r["barrier_pct"]])
	out.append("")
	return out


## Hours between two legendaries of the bosses of Fractures: `grade`'s boss gives every legendary of its source its own roll
## (F-120); a Fracture takes `minutes` of fight plus the overhead, and is won in `win_rate` of the runs.
static func legendary_hours(data: Object, grade: int, minutes: float, win_rate: float) -> float:
	var per_win: float = 0.0
	for item: Object in data.call("items"):
		if item.equip != null and item.equip.legendary != null and item.equip.legendary.source_type == &"boss" \
				and str(item.equip.legendary.source_id) == "boss_grade_%d" % grade:
			per_win += float(item.equip.legendary.chance_pct) / 100.0
	var per_hour: float = 60.0 / (minutes + FRACTURE_OVERHEAD_MIN) * win_rate * per_win
	return 1.0 / per_hour if per_hour > 0.0 else INF


## Runs `seeds` Fractures of `grade` at the recommended level; returns won/total, the mean minutes of the won runs and the means.
static func fracture_runs(data: Object, grade: int, seeds: PackedStringArray, material: String = "leather") -> Dictionary:
	var tool: GDScript = load(FRACTURE_TOOL) as GDScript
	var opts: Dictionary = tool.call("parse_args", PackedStringArray(["material=%s" % material, "cap=120", "rarity=magic"]))
	var level: int = int((data.call("balance_value", "fracture.grades")[grade - 1] as Dictionary)["recommended_level"])
	var won: int = 0
	var won_ms: float = 0.0
	var dust: float = 0.0
	for seed_text: String in seeds:
		var row: Dictionary = tool.call("measure", data, grade, level, int(seed_text), opts)
		dust += float(row["dust"])
		if row["outcome"] == "won":
			won += 1
			won_ms += float(row["ms"])
	return {"won": won, "total": seeds.size(), "minutes": won_ms / maxf(1.0, float(won)) / 60000.0, "dust": dust / seeds.size()}


static func fracture_report(data: Object, opts: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	out.append("| grade | level | won | minutes (won) | dust | hours per boss legendary |")
	out.append("|---|---|---|---|---|---|")
	var seeds: PackedStringArray = str(opts["seeds"]).split(",")
	for grade: int in range(1, 11):
		var r: Dictionary = fracture_runs(data, grade, seeds)
		var level: int = int((data.call("balance_value", "fracture.grades")[grade - 1] as Dictionary)["recommended_level"])
		out.append("| %d | %d | %d/%d | %.1f | %.0f | %.1f |" % [grade, level, r["won"], r["total"], r["minutes"], r["dust"],
			legendary_hours(data, grade, r["minutes"], float(r["won"]) / r["total"])])
	out.append("")
	return out
