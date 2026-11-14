extends RefCounted
## Ticket rate of tools/sim_dungeon.gd (docs/02_FORMULAS.md F-139, F-144): the areas 4-10 are fought with the hero of the area and
## the tickets per hour are computed from the measured encounters and kills and the chances of the data.

const Stats := preload("res://tools/sim_dungeon_stats.gd")
const COMBAT_TOOL: String = "res://tools/sim_combat.gd"
const TICKET: StringName = &"dungeon_ticket_monkey_den"
const HOUR_MS: int = 3_600_000
const RECOMMENDED: int = 45


## Ticket rate of the areas 4-10 (F-139): the area is fought for `area_hours` with the level of the area; the expected tickets are
## computed from the measured minibosses and Monoliths and the ticket chances of the data (the drops themselves are too rare to count).
static func tickets_report(data: Object, opts: Dictionary, stats: Dictionary, lines: PackedStringArray) -> PackedStringArray:
	var failures: PackedStringArray = PackedStringArray()
	lines.append("")
	lines.append("| area | level | kills/h | encounters/h | miniboss/h (encounters x chance) | monoliths/h (kills x chance) | tickets/h (expected) | hours per ticket | gold/h | rare+/h | hp% per encounter |")
	lines.append("|---|---|---|---|---|---|---|---|---|---|---|")
	var rates: Array[float] = []
	var focus_area: Dictionary = {}
	for area: Object in data.call("areas"):
		if int(area.level_min) < 31:
			continue
		var m: Dictionary = area_rates(data, area, float(opts["area_hours"]), int(opts["seed"]), opts)
		var per_hour: float = float(m["miniboss_h"]) * float(m["p_miniboss"]) + float(m["stones_h"]) * float(m["p_stone"])
		var hours: float = 1.0 / per_hour if per_hour > 0.0 else INF
		rates.append(per_hour)
		if int(area.level_min) <= RECOMMENDED and RECOMMENDED <= int(area.level_max):
			focus_area = m
		lines.append("| %s | %d | %.0f | %.1f | %.2f | %.2f | %.2f | %.2f | %.0f | %.2f | %.1f |" % [area.id, m["level"], m["kills_h"], m["encounters_h"],
			m["miniboss_h"], m["stones_h"], per_hour, hours, m["gold_h"], m["pieces_h"], m["loss_enc"]])
		Stats.check_range(failures, "hours per ticket in %s" % area.id, hours, 1.5, 2.5)
	var s: Dictionary = stats.get("random/%d" % RECOMMENDED, {})
	if s.is_empty() or focus_area.is_empty():
		return failures
	var per_hour_focus: float = float(focus_area["miniboss_h"]) * float(focus_area["p_miniboss"]) + float(focus_area["stones_h"]) * float(focus_area["p_stone"])
	var hours_per_ticket: float = 1.0 / per_hour_focus if per_hour_focus > 0.0 else INF
	var legend_run: float = float(s["won"]) * Stats.legend_expected(data)
	var legend_hours: float = hours_per_ticket / maxf(legend_run, 0.0001)
	var run_hours: float = float(s["min_mean"]) / 60.0
	var gold_ratio: float = (float(s["gold"]) * float(s["won"]) / run_hours) / maxf(float(focus_area["gold_h"]), 1.0)
	var pieces_ratio: float = (float(s["rare"]) * float(s["won"]) / run_hours) / maxf(float(focus_area["pieces_h"]), 0.01)
	lines.append("")
	lines.append("level %d: %.2f h per ticket, %.3f legendaries per run (won x expected) -> **%.1f h of fighting per legendary** (6-14); value per run hour vs area: gold x%.1f, rare+ pieces x%.1f (>= 3)" % [
		RECOMMENDED, hours_per_ticket, legend_run, legend_hours, gold_ratio, pieces_ratio])
	Stats.check_range(failures, "hours of fighting per legendary", legend_hours, 6.0, 14.0)
	if gold_ratio < 3.0:
		failures.append("gold per run hour only x%.1f the area (< 3)" % gold_ratio)
	if pieces_ratio < 3.0:
		failures.append("rare+ pieces per run hour only x%.1f the area (< 3)" % pieces_ratio)
	return failures


## Fights `area` for `hours` and returns the rates per hour plus the ticket chances read from the data.
static func area_rates(data: Object, area: Object, hours: float, seed_value: int, opts: Dictionary) -> Dictionary:
	var tool: GDScript = load(COMBAT_TOOL) as GDScript
	var level: int = tool.call("auto_level", data, area)
	var session: Object = tool.call("_new_session", data, seed_value + 77)
	var xp_before: int = tool.call("_set_level", session, level)
	var grade: int = tool.call("auto_grade", data, level)
	tool.call("_equip_set", session, grade, StringName(str(opts["setup"])), StringName(str(opts["material"])))
	tool.call("_fill_loadout", session, data)
	var food_id: StringName = tool.call("food_for_grade", data, grade)
	session.bank.add(food_id, 100000000)
	session.equipment.set_food(food_id)
	tool.call("_set_tier", session, tool.call("auto_tier", data, level))
	session.deposit.register_occupant(&"sim:room", func() -> int: return -100000)
	var worn: int = session.armory.instances().size()
	var tally: Dictionary = {"encounters": 0, "minibosses": 0, "stones": 0, "loss": 0.0, "prev": -1}
	session.events.player_hp_changed.connect(func(hp: int, max_hp: int) -> void:
		if int(tally["prev"]) > hp:
			tally["loss"] += float(int(tally["prev"]) - hp) / max_hp * 100.0
		tally["prev"] = hp)
	session.events.encounter_started.connect(func(ids: Array[StringName]) -> void:
		tally["encounters"] += 1
		for id: StringName in ids:
			if str(id).begins_with("miniboss_"):
				tally["minibosses"] += 1
				break)
	session.events.rift_stone_appeared.connect(func(_id: StringName) -> void: tally["stones"] += 1)
	var gold_start: int = session.wallet.get_gold()
	var total_ms: int = int(hours * HOUR_MS)
	var slice_ms: int = maxi(1, int(float(opts["slice"]) * 1000.0))
	var elapsed: int = 0
	while elapsed < total_ms:
		if not session.combat.is_active() and not session.combat.start(area.id).ok:
			break
		session.advance(slice_ms)
		elapsed += slice_ms
		tool.call("_pin_level", session, xp_before)
	var kills: int = 0
	var counts: Dictionary = session.combat.total_kills()
	for monster_id: Variant in counts:
		kills += int(counts[monster_id])
	var h: float = maxf(float(elapsed) / HOUR_MS, 0.001)
	var out: Dictionary = {
		"level": level, "kills_h": kills / h, "encounters_h": tally["encounters"] / h, "miniboss_h": tally["encounters"] / h * float(data.call("balance_value", "miniboss.chance_pct")) / 100.0, "miniboss_seen_h": tally["minibosses"] / h,
		"stones_h": kills / h * float(area.rift_stone_chance_pct) / 100.0, "stones_seen_h": tally["stones"] / h, "loss_enc": float(tally["loss"]) / maxf(float(tally["encounters"]), 1.0), "gold_h": (session.wallet.get_gold() - gold_start) / h,
		"pieces_h": (_rare_count(session.armory.instances().slice(worn)) + _rare_count(session.combat.loot.pieces())) / h,
		"p_miniboss": ticket_chance(data, data.call("monster", area.miniboss_id).drops, data.call("monster", area.miniboss_id).loot_tables),
		"p_stone": _stone_chance(data, area),
	}
	session.free()
	return out


## Ticket drop chance (0..1) of a drop list plus loot tables.
static func ticket_chance(data: Object, drops: Array, tables: Array) -> float:
	var pct: float = 0.0
	for drop: Object in drops:
		pct += float(drop.chance_pct) if drop.item_id == TICKET else 0.0
	for table_id: StringName in tables:
		for drop: Object in data.call("loot_table", table_id).entries:
			pct += float(drop.chance_pct) if drop.item_id == TICKET else 0.0
	return pct / 100.0


## Mean ticket chance of a Monolith of the area (F-139: uniform over the stones of the area).
static func _stone_chance(data: Object, area: Object) -> float:
	var stones: Array = data.call("rift_stones_for_area", area.id)
	var total: float = 0.0
	for stone: Object in stones:
		total += ticket_chance(data, stone.drops, stone.loot_tables)
	return total / maxf(float(stones.size()), 1.0)


## Pieces of rare rarity or better in a list of ItemInstance.
static func _rare_count(pieces: Array) -> int:
	var count: int = 0
	for inst: Object in pieces:
		count += 1 if ["rare", "masterwork", "legendary"].has(str(inst.rarity)) else 0
	return count
