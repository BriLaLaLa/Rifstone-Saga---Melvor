extends RefCounted
## M12-07 measurements for tools/sim_combat.gd (options `helpers`, `engraver`, `deposit`; docs/05_INTERFACES.md):
## real sessions built from the real data, seeded, nothing is written. Called by sim_combat, never run on its own.
##   helpers=1   three Master helpers vs the player alone on one gathering trade (F-102 invariant), xp per hour
##   engraver=1  Dust, Chips, Stones, Crystals per hour from the combat drops and the expected time for the first
##               Crystal, the first Perfect Stone and a grade V rune (F-104..F-106)
##   deposit=1   drops per hour, bag losses (Q56) and the hours the Deposit takes to fill (F-100)
## The combat drops are collected from the loot bag every `collect` minutes (what a player does between two looks).

const SIM_PATH: String = "res://tools/sim_combat.gd"
const HOUR_MS: int = 3600000
const TRADES: Array[StringName] = [&"forestry", &"quarrying", &"angling"]
const FAMILIES: Array[String] = ["ember", "eye", "shade", "root"]
const CRYSTALS: Array[StringName] = [&"currency_spark", &"currency_flux", &"currency_crown"]
const HELPER_LEVEL: int = 50
const RUNE_V_COPIES: int = 81


static func report(data: Object, opts: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	if str(opts["helpers"]) == "1":
		lines.append_array(helpers_report(data, opts))
	var runs: Dictionary = {}
	if str(opts["engraver"]) == "1" or str(opts["deposit"]) == "1":
		for area: Object in data.call("areas"):
			if str(opts["area"]) == "all" or str(opts["area"]) == str(area.id):
				runs[area.id] = loot_run(data, area, opts)
	if str(opts["deposit"]) == "1":
		lines.append_array(deposit_report(runs))
		lines.append_array(prefix_lines(runs))
	if str(opts["engraver"]) == "1":
		lines.append_array(engraver_report(data, runs, opts))
	return lines


# ---- helpers (F-101, F-102) ----

static func helpers_report(data: Object, opts: Dictionary) -> PackedStringArray:
	var hours: float = float(opts["hours"])
	var lines: PackedStringArray = PackedStringArray(["", "| trade | action | player xp/h | master helper xp/h |", "|---|---|---|---|"])
	var helper_total: float = 0.0
	var best_player: float = 0.0
	for trade: StringName in TRADES:
		var action: Object = best_action(data, trade)
		var player: float = float(_gather_xp(data, opts, trade, action.id, false)) / hours
		var helper: float = float(_gather_xp(data, opts, trade, action.id, true)) / hours
		helper_total += helper
		best_player = maxf(best_player, player)
		lines.append("| %s | %s | %.0f | %.0f |" % [trade, action.id, player, helper])
	var ratio: float = helper_total / maxf(best_player, 0.001)
	lines.append("")
	lines.append("helpers: 3 Master helpers %.0f xp/h vs the player alone on one trade (no tool) %.0f xp/h: ratio %.3f (invariant <= 1)" % [
		helper_total, best_player, ratio])
	return lines


## The unlocked action (at HELPER_LEVEL) with the best xp per second of interval.
static func best_action(data: Object, trade: StringName) -> Object:
	var best: Object = null
	for action: Object in data.call("actions_for_skill", trade):
		if action.level <= HELPER_LEVEL and not action.single:
			if best == null or float(action.xp) / action.interval_ms > float(best.xp) / best.interval_ms:
				best = action
	return best


## Skill xp gained in `hours` by the player (no tool) or by a Master helper on `action_id`, from HELPER_LEVEL.
static func _gather_xp(data: Object, opts: Dictionary, trade: StringName, action_id: StringName, helper: bool) -> int:
	var sim: GDScript = load(SIM_PATH) as GDScript
	var session: Object = sim.call("_new_session", data, int(opts["seed"]))
	session.deposit.register_occupant(&"sim:room", func() -> int: return -10000)
	session.skills.add_xp(trade, int(session.data.call("xp_table").xp_for_level(HELPER_LEVEL)))
	var tally: Array[int] = [0]
	session.events.xp_gained.connect(func(skill: StringName, amount: int) -> void:
		if skill == trade:
			tally[0] += amount)
	if helper:
		var contract: StringName = StringName("contract_%s_master" % trade)
		session.bank.add(contract, 1)
		var hired: Object = session.helpers.hire(contract)
		var set: Object = session.helpers.set_action(trade, action_id)
		if not hired.ok or not set.ok:
			printerr("sim_m12: helper not set (%s / %s)" % [hired.reason, set.reason])
	elif not session.actions.start(trade, action_id).ok:
		printerr("sim_m12: action not started")
	_run(session, int(float(opts["hours"]) * HOUR_MS), 30000, Callable())
	session.free()
	return tally[0]


# ---- combat drops (Q56, F-100, 8.5b) ----

## Fights `area` for `hours` (all packs, weighted), emptying the loot bag every `collect` minutes. Returns the drops
## collected, the drops lost to a full bag, the Deposit use over time and the kills.
static func loot_run(data: Object, area: Object, opts: Dictionary) -> Dictionary:
	var sim: GDScript = load(SIM_PATH) as GDScript
	var level: int = sim.call("auto_level", data, area) if opts["level"] == "auto" else int(opts["level"])
	var grade: int = sim.call("auto_grade", data, level) if opts["grade"] == "auto" else int(opts["grade"])
	var tier: int = sim.call("auto_tier", data, level) if opts["tier"] == "auto" else int(opts["tier"])
	var session: Object = sim.call("_new_session", data, int(opts["seed"]))
	var pinned: int = sim.call("_set_level", session, level)
	sim.call("_equip_set", session, grade, StringName(str(opts["setup"])))
	if opts["loadout"] == "auto":
		sim.call("_fill_loadout", session, data)
	var food: StringName = sim.call("food_for_grade", data, grade)
	session.bank.add(food, int(opts["food"]))
	session.equipment.set_food(food)
	sim.call("_set_tier", session, tier)
	var result: Dictionary = {"drops": {}, "lost": {}, "lost_events": 0, "timeline": [], "full_h": -1.0, "hours": float(opts["hours"])}
	session.events.loot_lost.connect(func(id: StringName, qty: int) -> void:
		result["lost"][id] = int(result["lost"].get(id, 0)) + qty
		result["lost_events"] += 1)
	var collect_ms: int = int(float(opts["collect"]) * 60000.0)
	var state: Dictionary = {"since": 0, "elapsed": 0}
	var total_ms: int = int(float(opts["hours"]) * HOUR_MS)
	var step_ms: int = mini(30000, collect_ms)
	var elapsed: int = 0
	while elapsed < total_ms:
		if not session.combat.is_active() and not session.combat.start(area.id).ok:
			break
		var step: int = mini(step_ms, total_ms - elapsed)
		session.advance(step)
		elapsed += step
		sim.call("_pin_level", session, pinned)
		state["since"] += step
		if state["since"] >= collect_ms:
			state["since"] = 0
			_empty_bag(session, result)
		if result["full_h"] < 0.0 and session.deposit.free_slots() <= 0:
			result["full_h"] = float(elapsed) / HOUR_MS
		if elapsed % HOUR_MS == 0:
			result["timeline"].append(session.deposit.used())
	_empty_bag(session, result, true)
	result["kills"] = 0
	var counts: Dictionary = session.combat.total_kills()
	for monster_id: Variant in counts:
		result["kills"] += int(counts[monster_id])
	result["deaths"] = session.combat.deaths()
	result["capacity"] = session.deposit.capacity()
	session.free()
	return result


static func _empty_bag(session: Object, result: Dictionary, final: bool = false) -> void:
	var before: Dictionary = _bag_counts(session)
	session.combat.loot.collect_all()
	var after: Dictionary = _bag_counts(session)
	for id: Variant in before:
		var counted: int = int(before[id]) - int(after.get(id, 0)) + (int(after.get(id, 0)) if final else 0)
		result["drops"][id] = int(result["drops"].get(id, 0)) + counted


static func _bag_counts(session: Object) -> Dictionary:
	var counts: Dictionary = {}
	for entry: Dictionary in session.combat.loot.items():
		counts[entry["item"]] = int(entry["qty"])
	return counts


static func deposit_report(runs: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray(["", "| area | kills/h | deaths/h | drop types | lost events/h | lost/h (qty) | lost % of drops | deposit used at 1h/2h/4h/8h | hours to full |", "|---|---|---|---|---|---|---|---|---|"])
	for area_id: Variant in runs:
		var run: Dictionary = runs[area_id]
		var hours: float = run["hours"]
		var got: int = _sum(run["drops"])
		var lost: int = _sum(run["lost"])
		var line: Array[String] = []
		for h: int in [1, 2, 4, 8]:
			line.append(str(run["timeline"][h - 1]) if run["timeline"].size() >= h else "-")
		lines.append("| %s | %.0f | %.2f | %d | %.2f | %.1f | %.1f | %s (cap %d) | %s |" % [
			area_id, run["kills"] / hours, run["deaths"] / hours, run["drops"].size(), run["lost_events"] / hours,
			lost / hours, 100.0 * lost / maxf(got + lost, 1.0), "/".join(line), run["capacity"],
			"%.1f" % run["full_h"] if run["full_h"] >= 0.0 else "not full"])
	return lines


# ---- Engraver (F-104..F-107) ----

static func engraver_report(data: Object, runs: Dictionary, opts: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray(["", "| area | dust/h | chips/h (per family) | stones/h (per family) | crystals/h (spark/flux/crown) | h first spark | h first Perfect Stone | h first flux | h first crown |", "|---|---|---|---|---|---|---|---|---|"])
	var best_rate: Dictionary = {}
	for area_id: Variant in runs:
		var run: Dictionary = runs[area_id]
		var rate: Dictionary = {}
		for id: Variant in run["drops"]:
			rate[id] = float(run["drops"][id] + run["lost"].get(id, 0)) / run["hours"]
			best_rate[id] = maxf(float(best_rate.get(id, 0.0)), rate[id])
		for id: Variant in run["lost"]:
			rate[id] = float(run["drops"].get(id, 0) + run["lost"][id]) / run["hours"]
			best_rate[id] = maxf(float(best_rate.get(id, 0.0)), rate[id])
		var chips: float = _family_rate(rate, "chip") / 4.0
		var stones: float = _family_rate(rate, "stone") / 4.0
		var dust: float = float(rate.get(&"rift_dust", 0.0))
		lines.append("| %s | %.1f | %.2f | %.2f | %.2f / %.2f / %.2f | %s | %s | %s | %s |" % [
			area_id, dust, chips, stones, rate.get(CRYSTALS[0], 0.0), rate.get(CRYSTALS[1], 0.0), rate.get(CRYSTALS[2], 0.0),
			_h(crystal_hours(data, rate, &"crystallize_spark")), _h(heart_hours(chips, stones)),
			_h(crystal_hours(data, rate, &"crystallize_flux")), _h(crystal_hours(data, rate, &"crystallize_crown"))])
	lines.append("")
	lines.append_array(rune_lines(data, best_rate))
	return lines


## Hours to the first Perfect Stone of a family: 3 Stones, each 3 Chips or a direct Stone drop (F-105).
static func heart_hours(chips_per_family: float, stones_per_family: float) -> float:
	var stone_flow: float = chips_per_family / 3.0 + stones_per_family
	return 3.0 / stone_flow if stone_flow > 0.0 else INF


## Hours to the first Crystal with the Dust of the action (F-104, Engraver at the action's level) plus the direct drops.
static func crystal_hours(data: Object, rate: Dictionary, action_id: StringName) -> float:
	var action: Object = data.call("action", action_id)
	var qty: int = int(action.inputs[0].qty)
	var chance: float = float((load("res://systems/actions/engraver_resolver.gd") as GDScript).call("crystal_chance_pct", action.level, data)) / 100.0
	var dust_per_crystal: float = qty * (1.0 + (1.0 / chance - 1.0) * float(data.call("balance_value", "engraver.crystal_fail_loss_pct")) / 100.0)
	var item: StringName = StringName(str(action.outputs[0].item_id))
	var flow: float = float(rate.get(&"rift_dust", 0.0)) / dust_per_crystal + float(rate.get(item, 0.0))
	return 1.0 / flow if flow > 0.0 else INF


## Per engraving recipe: hours to farm the materials of 81 grade I runes (a grade V rune, F-106) in the best area.
static func rune_lines(data: Object, best_rate: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray(["| rune | material | best drops/h | hours of farming for 81 runes (grade V) |", "|---|---|---|---|"])
	var worst: float = 0.0
	for action: Object in data.call("actions_for_skill", &"riftbinding"):
		if not str(action.id).begins_with("engrave_"):
			continue
		var material: StringName = StringName(str(action.inputs[1].item_id))
		var need: float = float(RUNE_V_COPIES * int(action.inputs[1].qty))
		var hours: float = need / float(best_rate.get(material, 0.0)) if best_rate.get(material, 0.0) > 0.0 else INF
		worst = maxf(worst, hours)
		lines.append("| %s | %s | %.1f | %s |" % [action.id, material, best_rate.get(material, 0.0), _h(hours)])
	lines.append("grade V rune: slowest material %s h" % _h(worst))
	return lines


# ---- small helpers ----

static func _family_rate(rate: Dictionary, grade: String) -> float:
	var total: float = 0.0
	for family: String in FAMILIES:
		total += float(rate.get(StringName("stone_%s_%s" % [family, grade]), 0.0))
	return total


static func _sum(counts: Dictionary) -> int:
	var total: int = 0
	for id: Variant in counts:
		total += int(counts[id])
	return total


static func _h(hours: float) -> String:
	return "inf" if is_inf(hours) else "%.1f" % hours


static func _run(session: Object, total_ms: int, slice_ms: int, _unused: Callable) -> void:
	var elapsed: int = 0
	while elapsed < total_ms:
		var step: int = mini(slice_ms, total_ms - elapsed)
		session.advance(step)
		elapsed += step


## Drops per hour (collected + lost) of the items whose id starts with each prefix: blueprints, contracts, bags.
static func prefix_lines(runs: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray(["", "| area | blueprints/h | contracts/h (apprentice/journeyman/expert/master) | bags/h |", "|---|---|---|---|"])
	for area_id: Variant in runs:
		var run: Dictionary = runs[area_id]
		var grades: Array[String] = []
		for grade: String in ["apprentice", "journeyman", "expert", "master"]:
			grades.append("%.2f" % (_prefix_qty(run, "contract_", "_" + grade) / run["hours"]))
		lines.append("| %s | %.2f | %s | %.2f |" % [area_id, _prefix_qty(run, "bp_", "") / run["hours"], " / ".join(grades),
			_prefix_qty(run, "bag_", "") / run["hours"]])
	return lines


static func _prefix_qty(run: Dictionary, prefix: String, suffix: String) -> float:
	var total: float = 0.0
	for source: Dictionary in [run["drops"], run["lost"]]:
		for id: Variant in source:
			if str(id).begins_with(prefix) and str(id).ends_with(suffix):
				total += float(source[id])
	return total
