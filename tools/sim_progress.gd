extends SceneTree
## B1 (M10-07): hours to level 99 and levels gained in 12 h offline, from the xp/h that tools/sim_combat.gd measures.
## F-130 is applied (xp_level_mult of the pinned character level, via sim_combat.kill_xp_of). The xp/h is measured in the highest area the level may enter, at sample levels, and interpolated between them; the global
## xp bonus and the xp of Rift Stones are ignored. Usage: godot --headless --path . -s tools/sim_progress.gd [-- hours=<n> seed=<n> loot=1]; loot=1 prints the expected drops per hour instead
## Output goes through print_rich/printerr, like the other tools.

const SIM_PATH: String = "res://tools/sim_combat.gd"
const GAME_DATA_PATH: String = "res://core/data/game_data.gd"
const CONFIG_ROOT: String = "res://data/config"
const HOUR_MS: int = 3600000
const PROGRESS_LEVELS: Array[int] = [1, 4, 16, 23, 38, 46, 56, 65, 78, 90, 99]


func _initialize() -> void:
	var sim: GDScript = load(SIM_PATH) as GDScript
	var args: PackedStringArray = ["scope=all"]
	args.append_array(OS.get_cmdline_user_args())
	var opts: Dictionary = sim.call("parse_args", args)
	if opts.has("error"):
		printerr("sim_progress: %s" % opts["error"])
		quit(1)
		return
	var data: Object = (load(GAME_DATA_PATH) as GDScript).call("load_from_dirs", str(opts["root"]), CONFIG_ROOT)
	if not data.call("is_valid"):
		printerr("sim_progress: data is not valid")
		quit(1)
		return
	var lines: PackedStringArray = drops_report(sim, data, opts) if str(opts["loot"]) == "1" else report(sim, data, opts)
	for line: String in lines:
		print_rich(line)
	quit(0)


static func report(sim: GDScript, data: Object, opts: Dictionary) -> PackedStringArray:
	var table: Object = data.call("character_xp_table")
	var areas: Array = data.call("areas")
	var reqs: Array[int] = []
	for area: Object in areas:
		reqs.append(int(area.requirements.get(&"character", 1)))
	var rates: Array[float] = []
	var out: PackedStringArray = PackedStringArray()
	out.append("| level | area | xp/h (after mult) |")
	out.append("|---|---|---|")
	for level: int in PROGRESS_LEVELS:
		var sample: Dictionary = opts.duplicate()
		sample["level"] = str(level)
		var idx: int = _area_index(reqs, level)
		var row: Dictionary = sim.call("measure", data, areas[idx], "all", sample)
		rates.append(float(row["xp"]) * HOUR_MS / maxf(1.0, float(row["ms"])))
		out.append("| %d | %s | %d |" % [level, areas[idx].id, roundi(rates[-1])])
	var hours: float = 0.0
	var at_hours: Dictionary = {}
	for level: int in range(1, int(data.call("balance_value", "character_curve.max_level"))):
		hours += float(int(table.xp_for_level(level + 1)) - int(table.xp_for_level(level))) / rate_at(rates, level)
		at_hours[level + 1] = hours
	out.append("")
	out.append("hours to level 16/38/65/99: %.1f / %.1f / %.1f / %.1f" % [at_hours[16], at_hours[38], at_hours[65], at_hours[99]])
	for start: int in [50, 60, 80]:
		var xp: float = float(table.xp_for_level(start))
		var level: int = start
		for _hour: int in 12:  # the rate follows the level reached
			xp += rate_at(rates, level)
			while level < 99 and float(table.xp_for_level(level + 1)) <= xp:
				level += 1
		out.append("12 h offline from level %d: +%d levels (level %d)" % [start, level - start, level])
	return out


static func rate_at(rates: Array[float], level: int) -> float:
	for i: int in range(1, PROGRESS_LEVELS.size()):
		if level <= PROGRESS_LEVELS[i]:
			var t: float = float(level - PROGRESS_LEVELS[i - 1]) / float(PROGRESS_LEVELS[i] - PROGRESS_LEVELS[i - 1])
			return lerpf(rates[i - 1], rates[i], t)
	return rates[-1]


static func _area_index(reqs: Array[int], level: int) -> int:
	var best: int = 0
	for i: int in range(reqs.size()):
		if reqs[i] <= level:
			best = i
	return best


## Expected drops per hour of each area (no noise, F-121): kills/h measured at the mean level of the area, split over the
## monsters by pack weight, times the percentages of `EquipmentPool.table` for the `L_m` of each monster. Pieces and projects
## are listed by piece grade (`g`).
static func drops_report(sim: GDScript, data: Object, opts: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	out.append("| area | kills/h | pieces/h | pieces/h by grade | projects/h | minutes between pieces |")
	out.append("|---|---|---|---|---|---|")
	var pool: GDScript = load("res://core/data/equipment_pool.gd") as GDScript
	for area: Object in data.call("areas"):
		var row: Dictionary = sim.call("measure", data, area, "all", opts)
		var share: Dictionary = {}
		var total: float = 0.0
		for pack: Object in area.packs:
			for monster_id: StringName in pack.monster_ids:
				share[monster_id] = float(share.get(monster_id, 0.0)) + float(pack.weight)
				total += float(pack.weight)
		var kills_h: float = float(row["kills"]) * HOUR_MS / maxf(1.0, float(row["ms"]))
		var pieces: Dictionary = {}
		var all_pieces: float = 0.0
		var all_projects: float = 0.0
		for monster_id: Variant in share:
			var per_hour: float = kills_h * float(share[monster_id]) / total
			var table: Dictionary = pool.call("table", int(pool.call("monster_level", data.call("monster", monster_id))), data)
			for item_id: Variant in table:
				var item: Object = data.call("item", item_id)
				var n: float = per_hour * float(table[item_id]) / 100.0
				if item.equip != null:
					pieces[int(item.equip.grade)] = float(pieces.get(int(item.equip.grade), 0.0)) + n
					all_pieces += n
				else:
					all_projects += n
		out.append("| %s | %.0f | %.2f | %s | %.2f | %.0f |" % [area.id, kills_h, all_pieces, _fmt(pieces), all_projects,
			60.0 / all_pieces if all_pieces > 0.0 else -1.0])
	return out


static func _fmt(by_grade: Dictionary) -> String:
	var keys: Array = by_grade.keys()
	keys.sort()
	var parts: PackedStringArray = PackedStringArray()
	for k: Variant in keys:
		parts.append("G%d:%.2f" % [int(k), float(by_grade[k])])
	return " ".join(parts)
