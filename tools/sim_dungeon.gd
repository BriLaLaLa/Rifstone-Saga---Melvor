extends SceneTree
## Balance tool for the Dungeon (docs/02_FORMULAS.md F-144, M22-07): drives the real DungeonSystem and CombatEngine on a session
## built from the real data. For each character level it plays whole runs of the Monkey Den (a ticket each, the choices made by
## `policy`), then measures the ticket rate in the areas 4-10 and checks every threshold of F-144. Exit 1 if a threshold fails.
## It does not use OfflineSimulator: offline the run is frozen (F-144 rule 2).
##
## Usage: godot --headless --path . -s tools/sim_dungeon.gd [-- key=value ...]
##   level=all|<n>       character level(s): all = 40,45,55 (default all)
##   runs=<n>            runs per level and policy (default 200; F-144 asks 500 for the published table)
##   policy=random|cautious|both   how the exits are chosen (default random; the thresholds apply to random)
##   seed=<n>            session seed (default 1)
##   setup=sword_shield|greatsword|dual, material=plate|leather|cloth (default leather), slice=<s> (default 3)
##   tier=<n>            auto-eat tier of the dungeon hero (default 1: the field rations owned from the start, F-144)
##   area_hours=<h>      simulated hours per area for the ticket rate (default 3; 0 = skip the ticket measure)
##   root=<res path>     content root (default res://data)
## Nothing is written. Output goes through print_rich/printerr (bare print is forbidden).

const GAME_DATA_PATH: String = "res://core/data/game_data.gd"
const COMBAT_TOOL: String = "res://tools/sim_combat.gd"
const CONFIG_ROOT: String = "res://data/config"
const DUNGEON_ID: StringName = &"monkey_den"
const TICKET: StringName = &"dungeon_ticket_monkey_den"
const LEVELS: Array[int] = [40, 45, 55]
const HOUR_MS: int = 3_600_000
const RUN_CAP_MS: int = 3_600_000
const DEFAULTS: Dictionary = {
	"level": "all", "runs": "200", "policy": "random", "seed": "1", "setup": "sword_shield", "material": "leather",
	"slice": "3", "area_hours": "3", "root": "res://data", "tier": "1",
}
const Stats := preload("res://tools/sim_dungeon_stats.gd")
const Tickets := preload("res://tools/sim_dungeon_tickets.gd")
const RECOMMENDED: int = 45


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
		printerr("sim_dungeon: %s" % opts["error"])
		return 1
	var data: Object = (load(GAME_DATA_PATH) as GDScript).call("load_from_dirs", str(opts["root"]), CONFIG_ROOT)
	if not data.call("is_valid"):
		printerr("sim_dungeon: data is not valid")
		return 1
	var lines: PackedStringArray = PackedStringArray()
	var failures: PackedStringArray = report(data, opts, lines)
	for line: String in lines:
		print_rich(line)
	for failure: String in failures:
		printerr("sim_dungeon: OUT OF THRESHOLD: %s" % failure)
	return 1 if not failures.is_empty() else 0


## Runs every measurement, appends the tables to `lines` and returns the failed thresholds.
static func report(data: Object, opts: Dictionary, lines: PackedStringArray) -> PackedStringArray:
	var failures: PackedStringArray = PackedStringArray()
	var levels: Array[int] = LEVELS.duplicate()
	if str(opts["level"]) != "all":
		levels = [int(opts["level"])]
	var policies: Array[String] = [str(opts["policy"])]
	if str(opts["policy"]) == "both":
		policies = ["random", "cautious"]
	lines.append("| level | policy | runs | won % | min (mean/p90) | food runs % / mean / max | pieces | rare+ | dust | crystals | gold | cards | legend/win | legend/run |")
	lines.append("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
	var stats: Dictionary = {}
	for policy: String in policies:
		for level: int in levels:
			var runs: Array[Dictionary] = play(data, level, policy, int(opts["runs"]), int(opts["seed"]), opts)
			var s: Dictionary = Stats.summarize(runs)
			stats["%s/%d" % [policy, level]] = s
			lines.append("| %d | %s | %d | %.1f | %.1f / %.1f | %.0f / %.0f / %d | %.2f | %.2f | %.0f | %.2f | %.0f | %.2f | %.3f | %.3f |" % [
				level, policy, runs.size(), s["won"] * 100.0, s["min_mean"], s["min_p90"], s["food_runs"] * 100.0, s["food_mean"], s["food_max"],
				s["pieces"], s["rare"], s["dust"], s["crystals"], s["gold"], s["cards"], s["legend_win"], s["legend_run"]])
			if policy == "random":
				failures.append_array(Stats.check_level(level, s))
	var focus: String = "random/%d" % RECOMMENDED
	if stats.has(focus):
		lines.append("")
		lines.append("deaths by room: %s" % str((stats[focus] as Dictionary)["deaths"]))
		lines.append("| room (level %d, random) | rooms | gross hp lost %% of max (mean) |" % RECOMMENDED)
		lines.append("|---|---|---|")
		var rooms: Dictionary = (stats[focus] as Dictionary)["rooms"]
		for kind: String in rooms:
			lines.append("| %s | %d | %.1f |" % [kind, rooms[kind][1], rooms[kind][0]])
		failures.append_array(Stats.check_rooms(stats[focus]))
	if int(float(opts["area_hours"])) > 0:
		failures.append_array(Tickets.tickets_report(data, opts, stats, lines))
	return failures



## `runs` whole runs on one session (the character, the set and the food do not change from run to run).
static func play(data: Object, level: int, policy: String, runs: int, seed_value: int, opts: Dictionary) -> Array[Dictionary]:
	var tool: GDScript = load(COMBAT_TOOL) as GDScript
	var session: Object = tool.call("_new_session", data, seed_value * 1000 + level)
	var xp_before: int = tool.call("_set_level", session, level)
	var grade: int = tool.call("auto_grade", data, level)
	tool.call("_equip_set", session, grade, StringName(str(opts["setup"])), StringName(str(opts["material"])))
	tool.call("_fill_loadout", session, data)
	var food_id: StringName = tool.call("food_for_grade", data, grade)
	session.bank.add(food_id, 100000000)
	session.equipment.set_food(food_id)
	tool.call("_set_tier", session, int(opts["tier"]))
	session.deposit.register_occupant(&"sim:room", func() -> int: return -100000)
	var def: Object = data.call("dungeon", DUNGEON_ID)
	var hint_kinds: Dictionary = {}
	for room_type: Object in def.room_types:
		hint_kinds[str(room_type.hint)] = str(room_type.id)
	var trace: Dictionary = {"kind": "", "prev": -1, "max": 1, "food": 0, "loss": {}, "boss": 0.0, "boss_seen": false}
	_listen(session, trace)
	var result: Array[Dictionary] = []
	var slice_ms: int = maxi(1, int(float(opts["slice"]) * 1000.0))
	for _i: int in runs:
		result.append(one_run(session, data, policy, hint_kinds, trace, slice_ms, xp_before, tool))
	session.free()
	return result


static func _listen(session: Object, trace: Dictionary) -> void:
	session.events.dungeon_room_entered.connect(func(_layer: int, kind: StringName) -> void:
		trace["kind"] = str(kind)
		_room_count(trace, str(kind)))
	session.events.dungeon_stage_started.connect(func(stage: int, _id: StringName) -> void:
		trace["kind"] = "boss_%d" % stage
		trace["boss_seen"] = true
		_room_count(trace, "boss_%d" % stage))
	session.events.player_hp_changed.connect(func(hp: int, max_hp: int) -> void:
		var previous: int = int(trace["prev"])
		trace["max"] = max_hp
		if previous >= 0 and hp < previous and str(trace["kind"]) != "":
			var lost: float = float(previous - hp) / max_hp * 100.0
			var key: String = str(trace["kind"])
			trace["loss"][key][0] += lost
			if key.begins_with("boss_"):
				trace["boss"] += lost
		trace["prev"] = hp)
	session.events.food_eaten.connect(func(_id: StringName, _healed: int) -> void: trace["food"] += 1)


static func _room_count(trace: Dictionary, key: String) -> void:
	if not (trace["loss"] as Dictionary).has(key):
		trace["loss"][key] = [0.0, 0]
	trace["loss"][key][1] += 1


static func one_run(session: Object, data: Object, policy: String, hint_kinds: Dictionary, trace: Dictionary, slice_ms: int, pinned_xp: int, tool: GDScript) -> Dictionary:
	trace.merge({"kind": "", "prev": -1, "food": 0, "loss": {}, "boss": 0.0, "boss_seen": false}, true)
	var before: Dictionary = _inventory(session, data)
	session.bank.add(TICKET, 1)
	var opened: Object = session.dungeon.open(DUNGEON_ID)
	if not opened.ok:
		printerr("sim_dungeon: cannot open the dungeon: %s" % opened.reason)
		return _empty_row()
	var result: Dictionary = {"outcome": "aborted"}
	var finished: Callable = func(o: StringName, _rooms: int, _pieces: int) -> void: result["outcome"] = str(o)
	session.events.dungeon_finished.connect(finished)
	var elapsed: int = 0
	while session.dungeon.is_active() and elapsed < RUN_CAP_MS:
		var state: Dictionary = session.dungeon.state()
		var phase: StringName = state["phase"]
		if phase == &"await" or phase == &"event":
			session.dungeon.choose(_pick(state["choices"], phase, policy, hint_kinds, session))
		else:
			session.advance(slice_ms)
			elapsed += slice_ms
			tool.call("_pin_level", session, pinned_xp)
	if session.dungeon.is_active():
		session.dungeon.flee()
	session.events.dungeon_finished.disconnect(finished)
	if session.combat.is_active():
		session.combat.stop()
	var after: Dictionary = _inventory(session, data)
	var room_loss: Dictionary = {}
	for key: String in trace["loss"]:
		var entry: Array = trace["loss"][key]
		var kind: String = "boss" if key.begins_with("boss_") else key
		var sum: Array = room_loss.get(kind, [0.0, 0])
		sum[0] = float(sum[0]) + float(entry[0])
		sum[1] = int(sum[1]) + ((1 if key == "boss_1" else 0) if kind == "boss" else int(entry[1]))
		room_loss[kind] = sum
	var row: Dictionary = {
		"outcome": str(result["outcome"]), "ms": elapsed, "food": int(trace["food"]), "room_loss": room_loss,
		"boss_loss": float(trace["boss"]) if bool(trace["boss_seen"]) else -1.0, "died_in": str(trace["kind"]) if result["outcome"] != "won" else "",
	}
	for key: String in ["pieces", "rare", "dust", "crystals", "gold", "cards", "legend"]:
		row[key] = float(after[key]) - float(before[key])
	row["room_loss"] = _per_room(room_loss)
	return row


## Per kind [mean hp lost % per room, rooms]: the boss counts as one "room" per run (its three stages together).
static func _per_room(room_loss: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for kind: String in room_loss:
		out[kind] = [room_loss[kind][0], room_loss[kind][1]]
	return out


static func _empty_row() -> Dictionary:
	return {"outcome": "aborted", "died_in": "", "ms": 0, "food": 0, "room_loss": {}, "boss_loss": -1.0, "pieces": 0.0, "rare": 0.0, "dust": 0.0,
		"crystals": 0.0, "gold": 0.0, "cards": 0.0, "legend": 0.0}


## Everything the run can add: pieces by rarity in the Armory, Dust, Crystals, Cards in the Bank and Cards, gold in the wallet.
static func _inventory(session: Object, data: Object) -> Dictionary:
	var pieces: int = 0
	var rare: int = 0
	var legend: int = 0
	for inst: Object in session.armory.instances():
		pieces += 1
		var rarity: String = str(inst.rarity)
		rare += 1 if rarity == "rare" or rarity == "masterwork" or rarity == "legendary" else 0
		legend += 1 if rarity == "legendary" else 0
	var crystals: int = 0
	for item: Object in data.call("items"):
		if item.category == &"currency":
			crystals += session.bank.get_count(item.id)
	return {"pieces": pieces, "rare": rare, "legend": legend, "crystals": crystals, "dust": session.bank.get_count(&"rift_dust"),
		"gold": session.wallet.get_gold(), "cards": session.cards.cards().size()}


## Index of the choice. `random`: uniform with the generator of the slot is not touched (a local counter would bias): uses its own RNG.
static func _pick(choices: Array, phase: StringName, policy: String, hint_kinds: Dictionary, session: Object) -> int:
	if policy != "cautious":
		return int(_rng(session).randi_range(0, choices.size() - 1))
	var best: int = 0
	var best_score: int = -1000
	for i: int in choices.size():
		var choice: Dictionary = choices[i]
		var score: int = 0
		if phase == &"event":
			score = 1 if choice["id"] == &"rest" or choice["id"] == &"dash" else 0
		else:
			match hint_kinds.get(str(choice["hint"]), ""):
				"rest": score = 3
				"miniboss", "horde": score = -3
				"elite": score = -1
				"": score = 0
		if score > best_score:
			best = i
			best_score = score
	return best


static var _choice_rng: RandomNumberGenerator = null


## The choices come from a generator of their own (the slot's must stay the game's).
static func _rng(_session: Object) -> RandomNumberGenerator:
	if _choice_rng == null:
		_choice_rng = RandomNumberGenerator.new()
		_choice_rng.seed = 424242
	return _choice_rng

