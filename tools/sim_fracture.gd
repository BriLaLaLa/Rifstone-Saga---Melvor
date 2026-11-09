extends SceneTree
## Balance tool for Fractures (docs/02_FORMULAS.md §7, M13-06): drives the real CombatEngine on sessions built from the
## real data. For each grade it opens a Card and fights the whole Fracture with a character of the recommended level
## (plus `delta`), the forged set, automatic traits and abilities and food; prints duration, outcome, deaths, Cards
## (grade and rarity), pieces, Dust and XP per Fracture, for every seed.
##
## Usage: godot --headless --path . -s tools/sim_fracture.gd [-- key=value ...]
##   grade=all|<1..10>   Card grade(s) (default all)
##   seeds=<a,b,c>       session seeds (default 1,2,3)
##   delta=<n>           character level relative to the recommended one (default 0; -10 = under-levelled)
##   rarity=common|magic|rare   rarity of the opened Card (default magic)
##   setup=sword_shield|greatsword|dual, slice=<s> seconds per step (default 5), cap=<min> abort after (default 90)
##   root=<res path>     content root (default res://data)
##   material=plate|leather|cloth   worn armour and shield (default leather: bosses and Monoliths also strike with Barrier)
## Nothing is written. Output goes through print_rich/printerr (bare print is forbidden).

const GAME_DATA_PATH: String = "res://core/data/game_data.gd"
const COMBAT_TOOL: String = "res://tools/sim_combat.gd"
const CONFIG_ROOT: String = "res://data/config"
const DEFAULTS: Dictionary = {
	"grade": "all", "seeds": "1,2,3", "delta": "0", "rarity": "magic", "setup": "sword_shield", "slice": "5",
	"cap": "90", "root": "res://data", "material": "leather",
}


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
		printerr("sim_fracture: %s" % opts["error"])
		return 1
	var data: Object = (load(GAME_DATA_PATH) as GDScript).call("load_from_dirs", str(opts["root"]), CONFIG_ROOT)
	if not data.call("is_valid"):
		printerr("sim_fracture: data is not valid")
		return 1
	for line: String in report(data, opts):
		print_rich(line)
	return 0


static func report(data: Object, opts: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("| grade | level | seed | outcome | boss at | min | deaths | cards (grade:rarity) | pieces | dust | xp |")
	lines.append("|---|---|---|---|---|---|---|---|---|---|---|---|---|")
	var grades: Array = data.call("balance_value", "fracture.grades")
	var summary: PackedStringArray = PackedStringArray()
	summary.append("")
	summary.append("| grade | level | won | mean min | won min | cards>=grade / fracture | cards / fracture | pieces | dust | xp/h |")
	summary.append("|---|---|---|---|---|---|---|---|---|---|")
	for g: int in range(1, grades.size() + 1):
		if str(opts["grade"]) != "all" and int(opts["grade"]) != g:
			continue
		var level: int = int((grades[g - 1] as Dictionary)["recommended_level"]) + int(opts["delta"])
		var rows: Array[Dictionary] = []
		for seed_text: String in str(opts["seeds"]).split(","):
			var row: Dictionary = measure(data, g, level, int(seed_text), opts)
			rows.append(row)
			lines.append("| %d | %d | %s | %s | %.1f | %.1f | %d | %s | %d | %d | %d | %s |" % [g, level, seed_text, row["outcome"],
				row["boss_at"] / 60000.0, row["ms"] / 60000.0, row["deaths"], row["cards_text"], row["pieces"], row["dust"], row["xp"], row["mods"]])
		summary.append(_summary(g, level, rows))
	lines.append_array(summary)
	return lines


static func _summary(g: int, level: int, rows: Array[Dictionary]) -> String:
	var n: float = rows.size()
	var won: int = 0
	var ms: float = 0.0
	var won_ms: float = 0.0
	var good: int = 0
	var cards: int = 0
	var pieces: int = 0
	var dust: int = 0
	var xp: int = 0
	for row: Dictionary in rows:
		won += 1 if row["outcome"] == "won" else 0
		ms += row["ms"]
		won_ms += row["ms"] if row["outcome"] == "won" else 0.0
		good += int(row["cards_ge"])
		cards += int(row["cards"])
		pieces += int(row["pieces"])
		dust += int(row["dust"])
		xp += int(row["xp"])
	return "| %d | %d | %d/%d | %.1f | %.1f | %.2f | %.2f | %.1f | %.0f | %.0f |" % [g, level, won, rows.size(), ms / n / 60000.0, won_ms / maxf(float(won), 1.0) / 60000.0,
		good / n, cards / n, pieces / n, dust / n, xp / maxf(ms / 3600000.0, 0.001)]


## One Fracture of `grade` fought to its end (won, died, or `aborted` at the cap).
static func measure(data: Object, grade: int, level: int, seed_value: int, opts: Dictionary) -> Dictionary:
	var tool: GDScript = load(COMBAT_TOOL) as GDScript
	var session: Object = tool.call("_new_session", data, seed_value)
	var xp_before: int = tool.call("_set_level", session, level)
	var set_grade: int = tool.call("auto_grade", data, level)
	tool.call("_equip_set", session, set_grade, StringName(str(opts["setup"])), StringName(str(opts["material"])))
	tool.call("_fill_loadout", session, data)
	var food_id: StringName = tool.call("food_for_grade", data, set_grade)
	session.bank.add(food_id, 1000000)
	session.equipment.set_food(food_id)
	tool.call("_set_tier", session, tool.call("auto_tier", data, level))
	session.deposit.register_occupant(&"sim:room", func() -> int: return -10000)
	var worn: Array[int] = []
	for inst: Object in session.armory.instances():
		worn.append(int(inst.uid))
	var result: Dictionary = {"outcome": "aborted", "groups": 0, "boss_at": -1}
	var clock: Dictionary = {"ms": 0}
	session.events.fracture_boss_started.connect(func(_id: StringName) -> void: result["boss_at"] = clock["ms"])
	session.events.fracture_finished.connect(func(outcome: StringName, _g: int, groups: int, _c: int, _p: int) -> void:
		result["outcome"] = str(outcome)
		result["groups"] = groups)
	var uid: int = session.cards.create(grade, StringName(str(opts["rarity"])))
	var dust_before: int = session.bank.get_count(&"rift_dust")
	var mod_names: PackedStringArray = PackedStringArray()
	for roll: Object in session.cards.get_card(uid).mods:
		mod_names.append("%s/%d" % [roll.mod_id, roll.step])
	result["mods"] = ",".join(mod_names)
	var opened: Object = session.fractures.open(uid)
	if not opened.ok:
		printerr("sim_fracture: cannot open the Card: %s" % opened.reason)
	var tally: Dictionary = {"deaths": 0}
	session.events.player_died.connect(func() -> void: tally["deaths"] += 1)
	var slice_ms: int = maxi(1, int(float(opts["slice"]) * 1000.0))
	var cap_ms: int = int(float(opts["cap"]) * 60000.0)
	var elapsed: int = 0
	var xp: int = 0
	while elapsed < cap_ms and session.fractures.is_active():
		session.advance(slice_ms)
		elapsed += slice_ms
		clock["ms"] = elapsed
		xp += session.character.get_xp() - xp_before
		tool.call("_pin_level", session, xp_before)
	if session.fractures.is_active():
		session.fractures.abandon()
	var cards: int = 0
	var cards_ge: int = 0
	var by_kind: Dictionary = {}
	for card: Object in session.cards.cards():
		cards += 1
		if int(card.grade) >= grade:
			cards_ge += 1
		var key: String = "%d:%s" % [card.grade, str(card.rarity).substr(0, 1)]
		by_kind[key] = int(by_kind.get(key, 0)) + 1
	var pieces: int = 0
	for inst: Object in session.armory.instances():
		if not worn.has(int(inst.uid)):
			pieces += 1
	var parts: PackedStringArray = PackedStringArray()
	for key: String in by_kind:
		parts.append("%sx%d" % [key, by_kind[key]])
	result.merge({
		"ms": elapsed, "deaths": tally["deaths"], "cards": cards, "cards_ge": cards_ge,
		"cards_text": ",".join(parts) if not parts.is_empty() else "-", "pieces": pieces,
		"dust": session.bank.get_count(&"rift_dust") - dust_before, "xp": xp,
	}, true)
	session.free()
	return result
