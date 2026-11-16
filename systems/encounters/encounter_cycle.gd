class_name EncounterCycle
extends RefCounted
## The cycle of the encounters of an area (docs/01_GDD_M24.md §35.1, §35.2; F-153, F-154, F-155, F-156): pure functions,
## no state. Every number comes from `balance.json` (`encounters.*`) and `data/encounters/nodes.json`; randomness from `session.rng`.

const FIGHT: StringName = &"fight"
const NODE: StringName = &"node"
const INTERVAL_STAT: StringName = &"skill_interval_pct"


## F-153: the kind of the next encounter of an area, decided now. `forced_fight` (a Rift Stone or a miniboss waits): `fight` with
## no roll. An area without nodes: `fight` with no roll. Else the roll `node_chance_pct`, then the discipline by weight (file order).
## Returns {"kind": `fight`|`node`, "skill": the discipline or `&""`}.
static func next_kind(session: GameSession, area_id: StringName, forced_fight: bool) -> Dictionary:
	var fight: Dictionary = {"kind": FIGHT, "skill": &""}
	if forced_fight:
		return fight
	var nodes: AreaNodesDef = session.data.area_nodes(area_id)
	if nodes == null or nodes.entries.is_empty():
		return fight
	if not session.rng.roll_pct(float(session.data.balance_value("encounters.node_chance_pct"))):
		return fight
	var weights: Array[int] = []
	for entry: NodeEntryDef in nodes.entries:
		weights.append(entry.weight)
	return {"kind": NODE, "skill": nodes.entries[session.rng.pick_weighted(weights)].skill}


## F-154: the resource of a node, the action of `skill_id` with the highest `level` <= min(`skill_level`, `max_level`) (the first
## in the file on a tie). Null only if the skill has no such action (data error: the first step has level 1).
static func worked_action(data: GameData, skill_id: StringName, skill_level: int, max_level: int) -> ActionDef:
	var limit: int = mini(skill_level, max_level)
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


## F-156: the closed form of the cycle (a reference for the simulation, not used by the game).
## `p` = {travel_ms, node_chance_pct, fight_ms, skip_ms, node_units, weights: {skill: int}, learned: [skill], node_ms: {skill: int}}.
## Returns {"cycle_ms", "per_hour", "fights_per_hour", "nodes_per_hour": {skill: float}, "units_per_hour": {skill: float}}.
static func expected(p: Dictionary) -> Dictionary:
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
			learned_ms += float(weights[skill]) * float(node_ms.get(skill, 0))
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
			units_per_hour[skill] = nodes * float(p["node_units"])
	return {"cycle_ms": cycle, "per_hour": per_hour, "fights_per_hour": (1.0 - q) * per_hour,
		"nodes_per_hour": nodes_per_hour, "units_per_hour": units_per_hour}
