class_name EncounterCycle
extends RefCounted
## The cycle of the encounters of an area (docs/01_GDD_M24.md §35.1, §35.2; F-153, F-154, F-155, F-156): pure functions,
## no state. Every number comes from `balance.json` (`encounters.*`) and `data/encounters/nodes.json`; randomness from `session.rng`.

const FIGHT: StringName = &"fight"
const NODE: StringName = &"node"
const INTERVAL_STAT: StringName = &"skill_interval_pct"
const UNITS_STAT: StringName = &"node_units_pct"  # M35 (F-198)
const RICH_STAT: StringName = &"node_rich_pct"  # M35 (F-199)


## F-153: the kind of the next encounter of an area, decided now. `forced_fight` (a Rift Stone or a miniboss waits): `fight` with
## no roll. An area without nodes: `fight` with no roll. Else the roll `node_chance_pct`, then the discipline by weight (file order).
## M31: `force_node` (tutorial, no `forced_fight`): a node of the first discipline of the area, in file order, that is learned and
## not too hard, with no roll; none: the normal rule.
## Returns {"kind": `fight`|`node`, "skill": the discipline or `&""`}.
static func next_kind(session: GameSession, area_id: StringName, forced_fight: bool, force_node: bool = false) -> Dictionary:
	var fight: Dictionary = {"kind": FIGHT, "skill": &""}
	if forced_fight:
		return fight
	var nodes: AreaNodesDef = session.data.area_nodes(area_id)
	if nodes == null or nodes.entries.is_empty():
		return fight
	if force_node:  # M31 (§4): no roll at all; no discipline that can be worked here: the normal rule
		var forced: StringName = _forced_skill(session, nodes)
		if forced != &"":
			return {"kind": NODE, "skill": forced}
	if not session.rng.roll_pct(float(session.data.balance_value("encounters.node_chance_pct"))):
		return fight
	var weights: Array[int] = []
	for entry: NodeEntryDef in nodes.entries:
		weights.append(entry.weight)
	return {"kind": NODE, "skill": nodes.entries[session.rng.pick_weighted(weights)].skill}


## F-154 / F-195: the resource of a node. `focus` (the chosen resource, `&""` = Automatico) if it is of `skill_id` and its `level` is <= min(`skill_level`,
## `max_level`); else the action of `skill_id` with the highest such `level` (the first in the file on a tie). Never skips the node. Null only if
## the skill has no such action (data error: the first step has level 1).
static func worked_action(data: GameData, skill_id: StringName, skill_level: int, max_level: int, focus: StringName = &""
) -> ActionDef:
	var limit: int = mini(skill_level, max_level)
	if focus != &"" and data.has_action(focus) and data.action(focus).skill_id == skill_id and data.action(focus).level <= limit:
		return data.action(focus)
	var best: ActionDef = null
	for action: ActionDef in data.actions_for_skill(skill_id):
		if action.level <= limit and (best == null or action.level > best.level):
			best = action
	return best


## F-154: the color of a node worked at the end, from d = `skill_level` - `action_level` (>= 0): the first entry of
## `encounters.colors` with d < `below`. Returns {"id": StringName, "xp_pct": float}.
static func color(data: GameData, skill_level: int, action_level: int) -> Dictionary:
	var d: int = maxi(0, skill_level - action_level)
	var last: Dictionary = {"id": &"grey", "xp_pct": 0.0}
	for entry: Variant in data.balance_value("encounters.colors") as Array:
		var row: Dictionary = entry
		last = {"id": StringName(str(row["id"])), "xp_pct": float(row["xp_pct"])}
		if d < int(row["below"]):
			return last
	return last


## F-155: the duration of a worked node, max(`node_min_ms`, round(`node_ms` x (1 + T(skill_interval_pct)/100))).
static func node_duration_ms(session: GameSession, skill_id: StringName, action: ActionDef) -> int:
	var ctx: ModifierContext = ModifierContext.for_action(skill_id, action.id)
	var pct: float = session.modifiers.total(INTERVAL_STAT, ctx)
	var base: float = float(session.data.balance_value("encounters.node_ms"))
	return maxi(int(session.data.balance_value("encounters.node_min_ms")), roundi(base * (1.0 + pct / 100.0)))


## F-161: the difficulty `D` of the node of `skill_id` in the area (the cap of the area if the data has no value); 0 without such a node.
static func difficulty(session: GameSession, area_id: StringName, skill_id: StringName) -> int:
	var nodes: AreaNodesDef = session.data.area_nodes(area_id)
	return nodes.difficulty_of(skill_id) if nodes != null else 0


## F-162: the yield in percent of an attempt, from the skill level and the difficulty of the node.
static func yield_pct(session: GameSession, level: int, difficulty_level: int) -> int:
	var free: int = int(session.data.balance_value("encounters.yield_free_levels"))
	var gap: int = difficulty_level - level
	if gap <= free:
		return 100
	var loss: int = int(session.data.balance_value("encounters.yield_loss_pct"))
	return maxi(int(session.data.balance_value("encounters.yield_min_pct")), 100 - (gap - free) * loss)


## F-199: the chance in percent that a node is rich, `min(100, encounters.rich_chance_pct + T(node_rich_pct))`.
static func rich_chance(session: GameSession, skill_id: StringName, action: ActionDef) -> float:
	var ctx: ModifierContext = ModifierContext.for_action(skill_id, action.id)
	return minf(100.0, float(session.data.balance_value("encounters.rich_chance_pct")) + GatheringResolver.optional_total(session, RICH_STAT, ctx))


## F-198: `u` = `T(node_units_pct)`, the extra units in percent of a node of `skill_id` (0 while the stat is not in the data).
static func units_bonus_pct(session: GameSession, skill_id: StringName, action: ActionDef) -> int:
	return int(GatheringResolver.optional_total(session, UNITS_STAT, ModifierContext.for_action(skill_id, action.id)))


## F-161: the number of attempts of a node, `encounters.attempts` (+ `rich_extra_attempts` if rich).
static func attempts_for(session: GameSession, rich: bool) -> int:
	var count: int = int(session.data.balance_value("encounters.attempts"))
	return count + int(session.data.balance_value("encounters.rich_extra_attempts")) if rich else count


## F-198: the units a node plans, `Ne`: `floor(N x (100 + u) / 100)`, for a rich node `floor(N x (100 + u) x rich_units_pct / 10000)`.
static func planned_units(data: GameData, rich: bool, u: int = 0) -> int:
	var planned: int = int(data.balance_value("encounters.node_units")) * (100 + u)
	if rich:
		return planned * int(data.balance_value("encounters.rich_units_pct")) / 10000
	return planned / 100


## F-162: the units of the attempt `k` (1-based) of `attempts`, at least 1: the cumulative integer share of `Ne x yield / 100`.
## `ne` = the `Ne` fixed at the start of the node (F-198); -1: the one without `node_units_pct`.
static func attempt_units(session: GameSession, k: int, attempts: int, rich: bool, yield_percent: int, ne: int = -1) -> int:
	var planned: int = ne if ne >= 0 else planned_units(session.data, rich)
	var upto: int = k * planned * yield_percent / (100 * attempts)
	var before: int = (k - 1) * planned * yield_percent / (100 * attempts)
	return maxi(1, upto - before)


## F-161: the instant (ms from the start of the node) of the attempt `k` (1-based): `round(k x duration / attempts)`.
static func attempt_time_ms(duration_ms: int, attempts: int, k: int) -> int:
	return (2 * k * duration_ms + attempts) / (2 * attempts)


## F-161: the duration of a rich node, `round(duration x rich_ms_pct / 100)`.
static func rich_duration_ms(session: GameSession, duration_ms: int) -> int:
	return (2 * duration_ms * int(session.data.balance_value("encounters.rich_ms_pct")) + 100) / 200


## F-156 with F-165: the closed form of the cycle (a reference for the simulation, not used by the game).
## `p` = {travel_ms, node_chance_pct, fight_ms, skip_ms, node_units, weights: {skill: int}, learned: [skill], node_ms: {skill: int},
## rich_chance_pct, rich_ms_pct, rich_units_pct, yield: {skill: int}, unit_bonus_pct: {skill: int}, rich_by_skill: {skill: p}} (the last six are optional: without
## them, no rich nodes, yield 100, no unit bonus; M35: `rich_chance_pct` is the `p` of F-199). `learned` = the disciplines that are worked (learned and `level >= min_level`).
## Returns {"cycle_ms", "per_hour", "fights_per_hour", "nodes_per_hour": {skill: float}, "units_per_hour": {skill: float}}.
static func expected(p: Dictionary) -> Dictionary:
	var yields: Dictionary = p.get("yield", {}) as Dictionary
	var bonus: Dictionary = p.get("unit_bonus_pct", {}) as Dictionary  # M35 (F-198): u = T(node_units_pct) per skill
	var q: float = float(p["node_chance_pct"]) / 100.0
	var weights: Dictionary = p["weights"]
	var learned: Array = p["learned"]
	var node_ms: Dictionary = p["node_ms"]
	var total: float = 0.0
	var learned_weight: float = 0.0
	var learned_ms: float = 0.0
	for skill: Variant in weights:
		total += float(weights[skill])
		if learned.has(skill):
			learned_weight += float(weights[skill])
			learned_ms += float(weights[skill]) * float(node_ms.get(skill, 0)) * _rich_mult(p, skill, "rich_ms_pct")
	var p_learned: float = learned_weight / total if total > 0.0 else 0.0
	var mean_node: float = learned_ms / learned_weight if learned_weight > 0.0 else 0.0
	var cycle: float = float(p["travel_ms"]) + (1.0 - q) * float(p["fight_ms"]) \
			+ q * (p_learned * mean_node + (1.0 - p_learned) * float(p["skip_ms"]))
	var per_hour: float = 3600000.0 / cycle if cycle > 0.0 else 0.0
	var nodes_per_hour: Dictionary = {}
	var units_per_hour: Dictionary = {}
	for skill: Variant in learned:
		if weights.has(skill) and total > 0.0:
			var nodes: float = q * float(weights[skill]) / total * per_hour
			nodes_per_hour[skill] = nodes
			units_per_hour[skill] = nodes * float(p["node_units"]) * (100.0 + float(bonus.get(skill, 0))) / 100.0 * _rich_mult(p, skill, "rich_units_pct") * float(yields.get(skill, 100)) / 100.0
	return {"cycle_ms": cycle, "per_hour": per_hour, "fights_per_hour": (1.0 - q) * per_hour,
		"nodes_per_hour": nodes_per_hour, "units_per_hour": units_per_hour}


## F-165 / F-199: `1 + (p / 100) x (key / 100 - 1)` with the `p` of `skill` (`rich_by_skill[skill]` or `rich_chance_pct`) and `key` = `rich_ms_pct` or `rich_units_pct`.
static func _rich_mult(p: Dictionary, skill: Variant, key: String) -> float:
	var chance: float = float((p.get("rich_by_skill", {}) as Dictionary).get(skill, p.get("rich_chance_pct", 0))) / 100.0
	return 1.0 + chance * (float(p.get(key, 100)) / 100.0 - 1.0)

## M33 (docs/M33_TUTORIAL_FORZATO.md §4): the forced node of the area, no roll: `{"kind": NODE, "skill": ...}`, or `{}` if no discipline can be worked.
static func forced_node(session: GameSession, area_id: StringName) -> Dictionary:
	var nodes: AreaNodesDef = session.data.area_nodes(area_id)
	if nodes == null:
		return {}
	var skill: StringName = _forced_skill(session, nodes)
	return {} if skill == &"" else {"kind": NODE, "skill": skill}


## M33: the node of `skill_id` in the area would be worked (the discipline is learned and its `min_level` reached), not skipped.
static func is_workable(session: GameSession, area_id: StringName, skill_id: StringName) -> bool:
	var nodes: AreaNodesDef = session.data.area_nodes(area_id)
	return nodes != null and nodes.min_level_of(skill_id) > 0 and session.disciplines.is_learned(skill_id) \
			and maxi(1, session.skills.get_level(skill_id)) >= nodes.min_level_of(skill_id)


# M31: the first entry of the area (file order) whose discipline is learned and whose `min_level` is reached; `&""` if none.
static func _forced_skill(session: GameSession, nodes: AreaNodesDef) -> StringName:
	for entry: NodeEntryDef in nodes.entries:
		if is_workable(session, nodes.area, entry.skill):
			return entry.skill
	return &""
