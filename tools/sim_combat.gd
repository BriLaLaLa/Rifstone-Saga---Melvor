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
##   loadout=none|auto    auto fills the open trait and ability slots with the first unlocked ones the assembly allows (default none)
##   loot=0|1             1 adds the M7 tables: pieces by rarity, Rift Stones and the expected cost of refinement (default 0)
##   root=<res path>      content root (default res://data), config root is res://data/config
## Nothing is written: no save slot is touched. Numbers come from the data; the arguments only choose the scenario.
## GameData and the sessions use the Log autoload, which does not exist while this `-s` script is compiled: they
## are reached through paths and dynamic calls, as in tools/validate_data.gd.
## Output goes through print_rich/printerr, like the other tools (bare print is forbidden).

const GAME_DATA_PATH: String = "res://core/data/game_data.gd"
const SESSION_PATH: String = "res://core/session/game_session.gd"
const EVENTS_PATH: String = "res://core/autoload/event_bus.gd"
const CONFIG_ROOT: String = "res://data/config"
const HOUR_MS: int = 3600000
const ARMOR_SLOTS: Array[StringName] = [&"body", &"legs", &"head", &"feet", &"hands"]

const DEFAULTS: Dictionary = {
	"area": "all", "scope": "both", "hours": "1", "seed": "1234", "grade": "auto", "setup": "sword_shield",
	"level": "auto", "tier": "auto", "food": "1000000", "slice": "30", "root": "res://data", "loot": "0",
	"loadout": "none",
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
		print_rich(line)
	return 0


## Runs every requested measurement and returns the table lines.
static func report(data: Object, opts: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("| area | scope | grade | level | tier | deaths/h | kills/h | xp/h | gold/h | food/h |")
	lines.append("|---|---|---|---|---|---|---|---|---|---|")
	var loot_lines: PackedStringArray = PackedStringArray()
	loot_lines.append("| area | scope | pieces/h | magic/h | rare/h | stones/h | stone kills/h | stone deaths/h | stone ttk s | stone hp lost % |")
	loot_lines.append("|---|---|---|---|---|---|---|---|---|---|")
	for area: Object in data.call("areas"):
		if str(opts["area"]) != "all" and str(opts["area"]) != str(area.id):
			continue
		for scope: String in scopes(str(opts["scope"])):
			var row: Dictionary = measure(data, area, scope, opts)
			lines.append("| %s | %s | %d | %d | %d | %s | %s | %s | %s | %s |" % [
				area.id, scope, row["grade"], row["level"], row["tier"], _per_hour(row["deaths"], row),
				_per_hour(row["kills"], row), _per_hour(row["xp"], row), _per_hour(row["gold"], row),
				_per_hour(row["food"], row)])
			loot_lines.append("| %s | %s | %s | %s | %s | %s | %s | %s | %.1f | %.1f |" % [
				area.id, scope, _per_hour(row["pieces"], row), _per_hour(row["magic"], row, 2),
				_per_hour(row["rare"], row, 2), _per_hour(row["stones"], row, 2), _per_hour(row["stone_kills"], row, 2),
				_per_hour(row["stone_deaths"], row, 2), row["stone_ttk"], row["stone_loss"]])
	if str(opts["loot"]) == "1":
		lines.append("")
		lines.append_array(loot_lines)
		lines.append("")
		lines.append_array(refine_report(data))
	return lines


## Expected cost of refining a piece of each grade from +0 to +5 / +7 / +9 (F-86, no modifiers): attempts, gold,
## ingots, shards and Seals, without the Seal (a failure from +4 drops a level) and with it (a failure keeps the level).
static func refine_report(data: Object) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	out.append("| grade | target | seal | attempts | gold | ingots | shards | seals |")
	out.append("|---|---|---|---|---|---|---|---|")
	var table: Array = data.call("balance_value", "upgrade.levels")
	var from_level: int = int(data.call("balance_value", "upgrade.downgrade_from"))
	for grade: int in [1, 3, 5, 8]:
		for target: int in [5, 7, 9]:
			for seal: bool in [false, true]:
				var e: Dictionary = expected_refine(table, from_level, grade, target, seal)
				out.append("| T%d | +%d | %s | %.1f | %d | %.1f | %.1f | %.1f |" % [grade, target,
					"yes" if seal else "no", e["attempts"], roundi(e["gold"]), e["ingots"], e["shards"], e["seals"]])
	return out


## Expected totals to go from +0 to `target` (value iteration on the chain N -> N+1 / failure state).
static func expected_refine(table: Array, downgrade_from: int, grade: int, target: int, seal: bool) -> Dictionary:
	var result: Dictionary = {}
	for key: String in ["attempts", "gold", "ingots", "shards", "seals"]:
		var e: Array[float] = []
		e.resize(target + 1)
		e.fill(0.0)
		for sweep: int in 4000:
			for n: int in range(target - 1, -1, -1):
				var row: Dictionary = table[n]
				var p: float = float(row["success_pct"]) / 100.0
				var cost: float = 0.0
				match key:
					"attempts": cost = 1.0
					"gold": cost = float(row["gold_per_grade"]) * grade
					"ingots": cost = float(row["ingots"])
					"shards": cost = float(row["shards"])
					"seals": cost = (1.0 - p) if seal and n >= downgrade_from else 0.0
				var fail_to: int = n if (seal or n < downgrade_from) else n - 1
				e[n] = cost + p * e[n + 1] + (1.0 - p) * e[fail_to]
		result[key] = e[0]
	return result


static func scopes(scope: String) -> Array[String]:
	if scope == "both":
		return ["easiest", "all"]
	return [scope]


static func _per_hour(value: Variant, row: Dictionary, decimals: int = 1) -> String:
	var hours: float = float(row["ms"]) / HOUR_MS
	return ("%." + str(decimals) + "f") % (float(value) / hours) if hours > 0.0 else "0"


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
	if opts["loadout"] == "auto":
		_fill_loadout(session, data)
	var food_id: StringName = food_for_grade(data, grade)
	session.bank.add(food_id, int(opts["food"]))
	session.equipment.set_food(food_id)
	_set_tier(session, tier)
	var stone_fight: Array[float] = stone_estimate(data, area, session)
	# The packs stay (a Rift Stone summons one by index): the scope only gives the others weight 0.
	var saved_weights: Array[int] = []
	for pack: Object in area.packs:
		saved_weights.append(int(pack.weight))
	if scope != "all":
		var index: int = easiest_pack(data, area) if scope == "easiest" else int(scope)
		for i: int in range(area.packs.size()):
			if i != index:
				area.packs[i].weight = 0
	_set_modifier(session, &"sim:armory", &"armory_slots", 10000.0)  # keep every drop: they are counted at the end
	var worn_uids: Array[int] = []
	for inst: Object in session.armory.instances():
		worn_uids.append(int(inst.uid))
	var tally: Dictionary = {"stones": 0, "stone_kills": 0, "stone_deaths": 0, "in_stone": false}
	session.events.rift_stone_appeared.connect(func(_id: StringName) -> void: tally["stones"] += 1)
	session.events.encounter_started.connect(func(ids: Array[StringName]) -> void:
		tally["in_stone"] = false
		for id: StringName in ids:
			if data.call("has_rift_stone", id):
				tally["in_stone"] = true)
	session.events.monster_killed.connect(func(_i: int, id: StringName) -> void:
		if data.call("has_rift_stone", id):
			tally["stone_kills"] += 1)
	session.events.player_died.connect(func() -> void:
		if tally["in_stone"]:
			tally["stone_deaths"] += 1)
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
	for i: int in range(area.packs.size()):
		area.packs[i].weight = saved_weights[i]
	var pieces: Dictionary = {"common": 0, "magic": 0, "rare": 0}
	for inst: Object in session.armory.instances():
		if not worn_uids.has(int(inst.uid)):
			pieces[str(inst.rarity)] += 1
	var kills: int = 0
	var kill_xp: int = 0
	var counts: Dictionary = engine.total_kills()
	for monster_id: Variant in counts:
		kills += int(counts[monster_id])
		kill_xp += int(counts[monster_id]) * int(data.call("monster", monster_id).xp)
	var row: Dictionary = {
		"grade": grade, "level": level, "tier": tier, "ms": elapsed, "deaths": engine.deaths(),
		"kills": kills, "xp": kill_xp, "gold": session.wallet.get_gold() - gold_start,
		"food": food_start - session.bank.get_count(food_id),
		"pieces": int(pieces["common"]) + int(pieces["magic"]) + int(pieces["rare"]), "magic": pieces["magic"],
		"rare": pieces["rare"], "stones": tally["stones"], "stone_kills": tally["stone_kills"],
		"stone_deaths": tally["stone_deaths"],
		"stone_ttk": stone_fight[0], "stone_loss": stone_fight[1],
	}
	session.free()  # the session is a Node outside any tree: free it, no orphans
	return row


## [seconds to kill the stone of the area, % of the player's hp lost to its pulses meanwhile] for the current gear,
## from the average hit (no abilities, no food): the same F-22..F-25 steps the engine uses. [0, 0] without a stone.
static func stone_estimate(data: Object, area: Object, session: Object) -> Array[float]:
	var def: Object = data.call("rift_stone_for_area", area.id)
	if def == null:
		return [0.0, 0.0]
	var math: GDScript = load("res://systems/combat/combat_math.gd") as GDScript
	var me: Object = session.combat.player_stats()
	var stone: Object = (load("res://systems/combat/rift_stone.gd") as GDScript).call("enemy", def, data)
	var relation: StringName = math.call("triangle", me.style, stone.stats.style, data)
	var avg: int = int(math.call("triangle_damage", int((me.min_hit + me.max_hit) / 2), relation, data))
	avg = int(math.call("damage_after_dr", avg, math.call("effective_dr", stone.stats.damage_reduction, relation, data)))
	var dps: float = float(math.call("hit_chance", me.accuracy, stone.stats.evasion, data)) * avg / (me.attack_interval_ms / 1000.0)
	var ttk: float = float(def.hp) / maxf(dps, 0.001)
	var back: StringName = math.call("triangle", stone.stats.style, me.style, data)
	var pulse: int = int(math.call("damage_after_dr", def.pulse_damage, math.call("effective_dr", me.damage_reduction, back, data)))
	return [ttk, ttk / (def.pulse_ms / 1000.0) * pulse * 100.0 / me.max_hp]


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


## Fills the open slots with the first trait / ability (file order) that is unlocked, allowed by the worn assembly and
## not yet chosen: a neutral, reproducible choice, not the best one.
static func _fill_loadout(session: Object, data: Object) -> void:
	var def: Object = data.call("character_class", session.character.class_id())
	var setup_id: StringName = session.equipment.setup()
	var level: int = session.character.get_level()
	var chosen: Array[StringName] = []
	for i: int in range(session.loadout.trait_slots()):
		for entry: Object in def.traits:
			if entry.unlock_level <= level and entry.allows_setup(setup_id) and not chosen.has(entry.id):
				if session.loadout.set_trait(i, entry.id).ok:
					chosen.append(entry.id)
					break
	chosen.clear()
	for i: int in range(session.loadout.ability_slots()):
		for entry: Object in def.abilities:
			if entry.unlock_level <= level and entry.allows_setup(setup_id) and not chosen.has(entry.id):
				if session.loadout.set_ability(i, entry.id).ok:
					chosen.append(entry.id)
					break


static func _set_tier(session: Object, tier: int) -> void:
	_set_modifier(session, &"sim:rations", &"auto_eat_tier", float(tier))


static func _set_modifier(session: Object, source: StringName, stat: StringName, value: float) -> void:
	var modifier_class: GDScript = load("res://core/modifiers/modifier.gd") as GDScript
	var list: Array = Array([], TYPE_OBJECT, &"RefCounted", modifier_class)
	list.append(modifier_class.call("make", stat, value))
	session.modifiers.set_source(source, list)
