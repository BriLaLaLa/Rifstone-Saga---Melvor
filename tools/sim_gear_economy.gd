extends SceneTree
## Balance tool for Rift Stones and Rift currencies (M9-07, DECISIONS_LOG 2026-11-07 M8 (c)). Read-only: nothing is
## written, no production data is touched. It reuses tools/sim_combat.gd for the pieces per hour and the player stats
## of the area, then prints (1) the shards per hour from gathering and from kills, (2) the cost of each stone and
## currency in hours of shard income, (3) the uplift of N socketed stones on the stats of the area's hero.
##
## Usage: godot --headless --path . -s tools/sim_gear_economy.gd [-- stones=<n>]   (default 6 stones socketed)
## Output goes through print_rich/printerr, like the other tools.

const SIM_PATH: String = "res://tools/sim_combat.gd"
const GAME_DATA_PATH: String = "res://core/data/game_data.gd"
const HOUR_MS: int = 3600000
const BASE_SHARD_KEY: String = "gathering.rift_shard_base_chance_pct"
const SHARD_ITEM: StringName = &"rift_shard"
const STAT_FOR_FAMILY: Dictionary = {
	"ember": &"power_bonus", "eye": &"accuracy_bonus", "shade": &"evasion_bonus", "root": &"max_hp_flat",
}
const GRADE_FOR_AREA: Array[String] = ["chip", "chip", "stone", "heart"]


func _initialize() -> void:
	quit(run(OS.get_cmdline_user_args()))


func run(args: PackedStringArray) -> int:
	var stones: int = 6
	for arg: String in args:
		if arg.begins_with("stones="):
			stones = int(arg.get_slice("=", 1))
		else:
			printerr("sim_gear_economy: bad argument '%s'" % arg)
			return 1
	var sim: GDScript = load(SIM_PATH) as GDScript
	var data: Object = (load(GAME_DATA_PATH) as GDScript).call("load_from_dirs", "res://data", "res://data/config")
	if data == null:
		printerr("sim_gear_economy: data did not load")
		return 1
	for line: String in _shard_income(data, sim) + _costs(data) + _uplift(data, sim, stones):
		print_rich(line)
	return 0


func _shard_income(data: Object, sim: GDScript) -> PackedStringArray:
	var lines: PackedStringArray = ["", "[b]Shards per hour[/b] (gathering = base chance per action; kills = kills/h x mean chance of the packs)",
		"| source | actions or kills / h | shards / h |", "|---|---|---|"]
	var base_pct: float = float(data.call("balance_value", BASE_SHARD_KEY))
	for interval_ms: int in [3000, 4000, 5000]:
		var actions: float = float(HOUR_MS) / interval_ms
		lines.append("| gathering %d ms | %.0f | %.2f |" % [interval_ms, actions, actions * base_pct / 100.0])
	var opts: Dictionary = sim.call("parse_args", PackedStringArray(["scope=all"]))
	for area: Object in data.call("areas"):
		var row: Dictionary = sim.call("measure", data, area, "all", opts)
		var chance: float = _mean_pack_chance(data, area)
		lines.append("| kills %s | %.0f | %.2f |" % [area.id, row["kills"], row["kills"] * chance / 100.0])
	return lines


func _mean_pack_chance(data: Object, area: Object) -> float:
	var weighted: float = 0.0
	var monsters: float = 0.0
	for pack: Object in area.packs:
		for monster_id: StringName in pack.monster_ids:
			weighted += pack.weight * float(data.call("monster", monster_id).rift_shard_chance)
			monsters += pack.weight
	return weighted / maxf(monsters, 1.0)


func _costs(data: Object) -> PackedStringArray:
	var lines: PackedStringArray = ["", "[b]Cost of stones and currencies[/b] (shards; hours = shards / 6 per h of 3 s gathering)",
		"| recipe | level | shards | other input | hours of shards |", "|---|---|---|---|---|"]
	for recipe: Object in data.call("actions_for_skill", &"riftbinding"):
		if not (str(recipe.id).begins_with("bind_stone_") or str(recipe.id).begins_with("bind_currency_")):
			continue
		var shards: int = 0
		var other: PackedStringArray = []
		for input: Object in recipe.inputs:
			if input.item_id == SHARD_ITEM:
				shards = input.qty
			else:
				other.append("%d %s" % [input.qty, input.item_id])
		lines.append("| %s | %d | %d | %s | %.1f |" % [recipe.id, recipe.level, shards, ", ".join(other), shards / 6.0])
	return lines


func _uplift(data: Object, sim: GDScript, stones: int) -> PackedStringArray:
	var lines: PackedStringArray = ["", "[b]Uplift of %d stones of the grade of the area (all in the same family)[/b]" % stones,
		"| area | stat | base | +%d stones | change %% |" % stones, "|---|---|---|---|---|"]
	var opts: Dictionary = sim.call("parse_args", PackedStringArray([]))
	var index: int = 0
	for area: Object in data.call("areas"):
		var grade_name: String = GRADE_FOR_AREA[mini(index, GRADE_FOR_AREA.size() - 1)]
		index += 1
		var level: int = sim.call("auto_level", data, area)
		var grade: int = sim.call("auto_grade", data, level)
		var session: Object = sim.call("_new_session", data, 1)
		sim.call("_set_level", session, level)
		sim.call("_equip_set", session, grade, &"sword_shield")
		var base: Object = session.combat.player_stats()
		for family: String in STAT_FOR_FAMILY:
			var stat: StringName = STAT_FOR_FAMILY[family]
			var stone: Object = data.call("item", StringName("stone_%s_%s" % [family, grade_name]))
			var value: float = float(stone.stone_modifiers[0].value) * stones
			sim.call("_set_modifier", session, &"sim:stones", stat, value)
			var boosted: Object = session.combat.player_stats()
			var field: String = {&"power_bonus": "max_hit", &"accuracy_bonus": "accuracy", &"evasion_bonus": "evasion",
				&"max_hp_flat": "max_hp"}[stat]
			var before: float = float(base.get(field))
			var after: float = float(boosted.get(field))
			lines.append("| %s (L%d) | %s | %.0f | %.0f | %+.1f |" % [area.id, level, field, before, after,
				(after - before) * 100.0 / maxf(before, 1.0)])
		session.free()
	return lines
