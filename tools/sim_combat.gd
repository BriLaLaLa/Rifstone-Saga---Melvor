extends SceneTree
## Balance tool for combat (docs/02_FORMULAS.md §8.5, M5-06): drives the real CombatEngine on sessions built from the
## real data and prints, per area and per pack scope, deaths, kills, xp, gold and food per simulated hour.
##
## Usage: godot --headless --path . -s tools/sim_combat.gd [-- key=value ...]
##   area=<id>|all        areas to measure (default all)
##   scope=easiest|all|both|<pack index>   packs fought: the lowest-hp pack, every pack (weighted), or both (default)
##   hours=<n>            simulated hours per measurement (default 1)
##   seed=<n>             session seed (default 1234)
##   grade=auto|<n>       grade of the forged set and of the food (auto = highest grade the area's level can wear)
##   setup=sword_shield|greatsword|dual   weapon assembly (default sword_shield)
##   level=auto|<n>       character level, kept fixed during the run (auto = mean attack level of the area's monsters)
##   tier=auto|<n>        field rations tier (auto = the shop tiers whose requirement the level meets)
##   food=<n>             pieces of food in the bank at the start (default 1000000)
##   slice=<s>            seconds simulated between level pins (default 30)
##   root=<res path>      content root (default res://data), config root is res://data/config
## Nothing is written: no save slot is touched. Numbers come from the data; the arguments only choose the scenario.
## GameData and the sessions use the Log autoload, which does not exist while this `-s` script is compiled: they
## are reached through paths and dynamic calls, as in tools/validate_data.gd.

const GAME_DATA_PATH: String = "res://core/data/game_data.gd"
const SESSION_PATH: String = "res://core/session/game_session.gd"
const EVENTS_PATH: String = "res://core/autoload/event_bus.gd"
const CONFIG_ROOT: String = "res://data/config"
const HOUR_MS: int = 3600000
const ARMOR_SLOTS: Array[StringName] = [&"body", &"legs", &"head", &"feet", &"hands"]

const DEFAULTS: Dictionary = {
	"area": "all", "scope": "both", "hours": "1", "seed": "1234", "grade": "auto", "setup": "sword_shield",
	"level": "auto", "tier": "auto", "food": "1000000", "slice": "30", "root": "res://data",
}


func _initialize() -> void:
	quit(run(OS.get_cmdline_user_args()))


## Parses `key=value` arguments over DEFAULTS; unknown keys are an error (returned under "error").
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
		printerr("sim_combat: %s" % opts["error"])
		return 1
	var game_data: GDScript = load(GAME_DATA_PATH) as GDScript
	var data: Object = game_data.call("load_from_dirs", str(opts["root"]), CONFIG_ROOT)
	if not data.call("is_valid"):
		printerr("sim_combat: data is not valid")
		return 1
	var lines: PackedStringArray = report(data, opts)
	for line: String in lines:
		print(line)
	return 0


## Runs every requested measurement and returns the table lines.
static func report(data: Object, opts: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("| area | scope | grade | level | tier | deaths/h | kills/h | xp/h | gold/h | food/h |")
	lines.append("|---|---|---|---|---|---|---|---|---|---|")
	for area: Object in data.call("areas"):
		if str(opts["area"]) != "all" and str(opts["area"]) != str(area.id):
			continue
		for scope: String in scopes(str(opts["scope"])):
			var row: Dictionary = measure(data, area, scope, opts)
			lines.append("| %s | %s | %d | %d | %d | %s | %s | %s | %s | %s |" % [
				area.id, scope, row["grade"], row["level"], row["tier"], _per_hour(row["deaths"], row),
				_per_hour(row["kills"], row), _per_hour(row["xp"], row), _per_hour(row["gold"], row),
				_per_hour(row["food"], row)])
	return lines


static func scopes(scope: String) -> Array[String]:
	if scope == "both":
		return ["easiest", "all"]
	return [scope]


static func _per_hour(value: Variant, row: Dictionary) -> String:
	var hours: float = float(row["ms"]) / HOUR_MS
	return "%.1f" % (float(value) / hours) if hours > 0.0 else "0"


## Index of the pack with the lowest total monster hp (the easiest group of the area).
static func easiest_pack(data: Object, area: Object) -> int:
	var best: int = 0
	var best_hp: int = -1
	for i: int in range(area.packs.size()):
		var hp: int = 0
		for monster_id: StringName in area.packs[i].monster_ids:
			hp += int(data.call("monster", monster_id).hp)
		if best_hp < 0 or hp < best_hp:
			best = i
			best_hp = hp
	return best


## Mean attack level of the distinct monsters of the area, rounded: the level of a player fighting on par.
static func auto_level(data: Object, area: Object) -> int:
	var total: int = 0
	for monster_id: StringName in area.monster_ids:
		total += int(data.call("monster", monster_id).attack_level)
	return roundi(float(total) / maxi(1, area.monster_ids.size()))


## Highest grade whose pieces the level can wear (smallest requirement among equipment of that grade).
static func auto_grade(data: Object, level: int) -> int:
	var best: int = 1
	for item: Object in data.call("items"):
		if item.category == &"equipment" and item.equip != null and int(item.equip.requirements.get(&"character", 0)) <= level:
			best = maxi(best, int(item.equip.grade))
	return best


## Number of field rations purchases whose character requirement the level meets (shop entries with auto_eat_tier).
static func auto_tier(data: Object, level: int) -> int:
	var tier: int = 0
	for entry: Object in data.call("shop_entries"):
		for mod: Object in entry.effect_modifiers:
			if mod.stat == &"auto_eat_tier" and entry.req_character <= level:
				tier += int(mod.value)
	return tier


## One measurement: a fresh session with the forged set of the grade, food of the grade and rations, fights `scope`
## for hours of simulated time. The level is pinned (see _pin_level) so that leveling up does not change the player.
static func measure(data: Object, area: Object, scope: String, opts: Dictionary) -> Dictionary:
	var level: int = auto_level(data, area) if opts["level"] == "auto" else int(opts["level"])
	var grade: int = auto_grade(data, level) if opts["grade"] == "auto" else int(opts["grade"])
	var tier: int = auto_tier(data, level) if opts["tier"] == "auto" else int(opts["tier"])
	var session: Object = _new_session(data, int(opts["seed"]))
	var xp_before: int = _set_level(session, level)
	_equip_set(session, grade, StringName(str(opts["setup"])))
	var food_id: StringName = food_for_grade(data, grade)
	session.bank.add(food_id, int(opts["food"]))
	session.equipment.set_food(food_id)
	_set_tier(session, tier)
	var saved_packs: Array = area.packs
	if scope != "all":
		var index: int = easiest_pack(data, area) if scope == "easiest" else int(scope)
		area.packs = saved_packs.slice(index, index + 1)
	var total_ms: int = int(float(opts["hours"]) * HOUR_MS)
	var slice_ms: int = maxi(1, int(float(opts["slice"]) * 1000.0))
	var gold_start: int = session.wallet.get_gold()
	var food_start: int = session.bank.get_count(food_id)
	var elapsed: int = 0
	var engine: Object = session.combat
	while elapsed < total_ms:
		if not engine.is_active():
			if not engine.start(area.id).ok:
				break
		var step: int = mini(slice_ms, total_ms - elapsed)
		session.advance(step)
		elapsed += step
		_pin_level(session, xp_before)
	area.packs = saved_packs
	var kills: int = 0
	var kill_xp: int = 0
	var counts: Dictionary = engine.total_kills()
	for monster_id: Variant in counts:
		kills += int(counts[monster_id])
		kill_xp += int(counts[monster_id]) * int(data.call("monster", monster_id).xp)
	return {
		"grade": grade, "level": level, "tier": tier, "ms": elapsed, "deaths": engine.deaths(),
		"kills": kills, "xp": kill_xp, "gold": session.wallet.get_gold() - gold_start,
		"food": food_start - session.bank.get_count(food_id),
	}


static func food_for_grade(data: Object, grade: int) -> StringName:
	var foods: Array[Object] = []
	for item: Object in data.call("items"):
		if item.category == &"food":
			foods.append(item)
	foods.sort_custom(func(a: Object, b: Object) -> bool: return a.sort_order < b.sort_order)
	return foods[clampi(grade - 1, 0, foods.size() - 1)].id


static func _new_session(data: Object, seed_value: int) -> Object:
	var events: Node = (load(EVENTS_PATH) as GDScript).new()
	var session: Node = (load(SESSION_PATH) as GDScript).new(data, events, seed_value)
	session.add_child(events)
	session.new_game()
	return session


static func _set_level(session: Object, level: int) -> int:
	var missing: int = session.data.call("character_xp_table").xp_for_level(level) - session.character.get_xp()
	if missing > 0:
		session.character.add_xp(missing)
	return session.character.get_xp()

## Keeps the character at the starting experience: kills would otherwise raise the level during the hour. The engine
## recomputes its stats on `modifiers_changed`. The xp of the report is computed from the kills (F-28 base xp).
static func _pin_level(session: Object, pinned_xp: int) -> void:
	if session.character.get_xp() == pinned_xp:
		return
	session.character.from_save({"class": String(session.character.class_id()), "xp": pinned_xp})
	session.events.modifiers_changed.emit()



static func _equip_set(session: Object, grade: int, setup: StringName) -> void:
	var by_slot: Dictionary = {}
	for item: Object in session.data.call("items"):
		if item.category == &"equipment" and item.equip != null and item.equip.grade == grade:
			var key: String = "%s/%s" % [item.equip.slot, item.equip.kind]
			by_slot[key] = item.id
	var worn: Array[StringName] = []
	for slot: StringName in ARMOR_SLOTS:
		worn.append(by_slot["%s/" % slot])
	match setup:
		&"greatsword":
			worn.append(by_slot["weapon/greatsword"])
		&"dual":
			worn.append(by_slot["weapon/sword"])
			worn.append(by_slot["weapon/sword"])
		_:
			worn.append(by_slot["weapon/sword"])
			worn.append(by_slot["offhand/shield"])
	for base_id: StringName in worn:
		var uid: int = session.armory.create(base_id, &"common", 1)
		var slot: StringName = StringName(session.data.call("item", base_id).equip.slot)
		if setup == &"dual" and slot == &"weapon" and session.equipment.get_uid(&"weapon") != 0:
			slot = &"offhand"
		var result: Object = session.equipment.equip(uid, slot)
		if not result.ok:
			printerr("sim_combat: cannot equip %s: %s" % [base_id, result.reason])


static func _set_tier(session: Object, tier: int) -> void:
	var modifier_class: GDScript = load("res://core/modifiers/modifier.gd") as GDScript
	var list: Array = Array([], TYPE_OBJECT, &"RefCounted", modifier_class)
	list.append(modifier_class.call("make", &"auto_eat_tier", float(tier)))
	session.modifiers.set_source(&"sim:rations", list)
