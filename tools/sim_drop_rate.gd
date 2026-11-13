extends SceneTree
## M17-02 (V5, Q85): measured equipment drop rate per area and character level on the real data. Only measures.
## Every cell = `kills` kills of the packs of the area (weighted like the fight) through the real `KillRewards.roll_pool`
## (F-121), fixed seed, a real session at that character level. Monoliths (F-127, guaranteed piece) are not counted.
## Classes are reached through load()/call (as tools/sim_combat.gd) because autoloads are not visible at parse time.
##
## Usage: godot --headless --path . -s tools/sim_drop_rate.gd [-- kills=<n> levels=10,20,40,70]
## Output through print_rich; exit 1 on a bad argument or invalid data. Nothing is written.

const GAME_DATA_PATH: String = "res://core/data/game_data.gd"
const SESSION_PATH: String = "res://core/session/game_session.gd"
const EVENTS_PATH: String = "res://core/autoload/event_bus.gd"
const REWARDS_PATH: String = "res://systems/combat/kill_rewards.gd"
const DEFAULTS: Dictionary = {"kills": "50000", "levels": "10,20,40,70"}


## Counts what the pool gives instead of storing it.
class CountSink extends "res://systems/combat/loot_sink.gd":
	var pieces: int = 0
	var magic: int = 0
	var rare: int = 0
	var wearable: int = 0
	var blueprints: int = 0
	var level: int = 1
	var data: Object

	func add(_item_id: StringName, qty: int) -> bool:
		blueprints += qty  # roll_pool only adds blueprints here
		return true

	func add_piece(inst: Object) -> void:
		pieces += 1
		if inst.rarity == &"magic":
			magic += 1
		elif inst.rarity == &"rare":
			rare += 1
		var item: Object = data.call("item", inst.base_id)
		if item.equip != null and int(item.equip.requirements.get(&"character", 0)) <= level:
			wearable += 1


func _initialize() -> void:
	quit(run(OS.get_cmdline_user_args()))


func run(args: PackedStringArray) -> int:
	var opts: Dictionary = DEFAULTS.duplicate()
	for arg: String in args:
		var parts: PackedStringArray = arg.split("=", true, 1)
		if parts.size() != 2 or not DEFAULTS.has(parts[0]):
			printerr("sim_drop_rate: bad argument '%s'" % arg)
			return 1
		opts[parts[0]] = parts[1]
	var data: Object = (load(GAME_DATA_PATH) as GDScript).call("load_from_dirs", "res://data", "res://data/config")
	if not data.call("is_valid"):
		printerr("sim_drop_rate: data is not valid")
		return 1
	var kills: int = int(opts["kills"])
	var chance: float = float(data.call("balance_value", "loot.equipment.chance_pct"))
	print_rich("equipment.chance_pct = %s, blueprint = %s, kills per cell = %d" % [chance,
		data.call("balance_value", "loot.blueprint.chance_pct"), kills])
	print_rich("| area | req | level | pieces/100 | kills/piece | magic/100 | rare/100 | wearable/100 | blueprints/100 | avg L_m |")
	print_rich("|---|---|---|---|---|---|---|---|---|---|")
	for area: Object in data.call("areas"):
		for level_text: String in str(opts["levels"]).split(","):
			print_rich(cell(data, area, int(level_text), kills))
	print_rich("P(>=3 pieces in 20 kills) at p=%.3f: %.4f%%" % [chance / 100.0, 100.0 * binom_at_least(3, 20, chance / 100.0)])
	print_rich("P(>=3 pieces in 20 kills) at p=0.100: %.4f%%" % [100.0 * binom_at_least(3, 20, 0.1)])
	return 0


func cell(data: Object, area: Object, level: int, kills: int) -> String:
	var events: Node = (load(EVENTS_PATH) as GDScript).new()
	var session: Node = (load(SESSION_PATH) as GDScript).new(data, events, 7000 + level * 10 + area.order)
	session.add_child(events)
	session.new_game()
	var missing: int = data.call("character_xp_table").xp_for_level(level) - session.character.get_xp()
	if missing > 0:
		session.character.add_xp(missing)
	var rewards: GDScript = load(REWARDS_PATH) as GDScript
	var sink: Object = CountSink.new()
	sink.level = level
	sink.data = data
	var total_weight: int = 0
	for pack: Object in area.packs:
		total_weight += pack.weight
	var done: int = 0
	var lm_sum: int = 0
	while done < kills:
		var pick: int = session.rng.randi_range(1, total_weight)
		var chosen: Object = area.packs[0]
		for pack: Object in area.packs:
			pick -= pack.weight
			if pick <= 0:
				chosen = pack
				break
		for monster_id: StringName in chosen.monster_ids:
			var def: Object = data.call("monster", monster_id)
			rewards.call("roll_pool", session, sink, def, &"monster")
			lm_sum += maxi(def.attack_level, maxi(def.power_level, def.defence_level))
			done += 1
	var n: float = float(done)
	var line: String = "| %s | %d | %d | %.2f | %.1f | %.3f | %.3f | %.2f | %.3f | %.1f |" % [area.id,
		int(area.requirements.get(&"character", 1)), level, 100.0 * sink.pieces / n, n / maxf(1.0, sink.pieces),
		100.0 * sink.magic / n, 100.0 * sink.rare / n, 100.0 * sink.wearable / n, 100.0 * sink.blueprints / n,
		float(lm_sum) / n]
	session.free()
	return line


## P(X >= k) for X ~ Binomial(n, p).
static func binom_at_least(k: int, n: int, p: float) -> float:
	var below: float = 0.0
	for i: int in k:
		below += choose(n, i) * pow(p, i) * pow(1.0 - p, n - i)
	return 1.0 - below


static func choose(n: int, k: int) -> float:
	var r: float = 1.0
	for i: int in k:
		r = r * float(n - i) / float(i + 1)
	return r
