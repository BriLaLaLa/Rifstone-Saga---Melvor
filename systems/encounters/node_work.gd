class_name NodeWork
extends RefCounted
## A gathering node in progress (docs/01_GDD_M24.md §35.2; F-154, F-155), held by the combat engine. `begin` fixes the resource and the
## duration; `finish` (at the end) takes the color of that moment and puts the units in the bank. A node of a discipline that is not
## learned is `skipped`: it lasts `encounters.skip_ms` and gives nothing.

var skill_id: StringName = &""
var action_id: StringName = &""
var duration_ms: int = 0
var elapsed_ms: int = 0
var skipped: bool = false


## The node of `skill_id` in the area: resource of F-154 (for a skipped node, the one that would have been worked), duration of F-155
## (or `skip_ms`). Null if the area has no nodes or the skill has no resource (data error, logged).
static func begin(session: GameSession, area_id: StringName, skill_id: StringName) -> NodeWork:
	var nodes: AreaNodesDef = session.data.area_nodes(area_id)
	if nodes == null:
		return null
	var level: int = maxi(1, session.skills.get_level(skill_id))
	var action: ActionDef = EncounterCycle.worked_action(session.data, skill_id, level, nodes.max_level)
	if action == null:
		Log.warn("encounters", "no resource for the node of '%s' in area '%s'" % [skill_id, area_id])
		return null
	var work := NodeWork.new()
	work.skill_id = skill_id
	work.action_id = action.id
	work.skipped = not session.disciplines.is_learned(skill_id)
	work.duration_ms = int(session.data.balance_value("encounters.skip_ms")) if work.skipped \
			else EncounterCycle.node_duration_ms(session, skill_id, action)
	return work


## The color of the node if it ended now (F-154); `&""` and 0% for a skipped node.
func color(session: GameSession) -> Dictionary:
	if skipped:
		return {"id": &"", "xp_pct": 0.0}
	var action: ActionDef = session.data.action(action_id)
	return EncounterCycle.color(session.data, session.skills.get_level(skill_id), action.level)


## The end of the node: the units (`encounters.node_units`) with the color of now (F-155). A skipped node: `ok` false, empty.
func finish(session: GameSession) -> ActionOutcome:
	if skipped:
		return ActionOutcome.new()
	var units: int = int(session.data.balance_value("encounters.node_units"))
	return GatheringResolver.resolve_units(session, session.data.action(action_id), units, float(color(session)["xp_pct"]))


func to_save() -> Dictionary:
	return {"skill": String(skill_id), "action": String(action_id), "elapsed_ms": elapsed_ms, "duration_ms": duration_ms,
		"skipped": skipped}


## Tolerant: null if the dictionary is malformed or names an unknown skill or action.
static func from_save(raw: Dictionary, data: GameData) -> NodeWork:
	var action_key := StringName(str(raw.get("action", "")))
	if not data.has_action(action_key):
		return null
	var action: ActionDef = data.action(action_key)
	if String(action.skill_id) != str(raw.get("skill", "")):
		return null
	for key: String in ["elapsed_ms", "duration_ms"]:
		if not (raw.get(key) is int or raw.get(key) is float):
			return null
	if not (raw.get("skipped") is bool):
		return null
	var work := NodeWork.new()
	work.skill_id = action.skill_id
	work.action_id = action.id
	work.skipped = raw["skipped"]
	work.duration_ms = maxi(1, int(raw["duration_ms"]))
	work.elapsed_ms = clampi(int(raw["elapsed_ms"]), 0, work.duration_ms)
	return work
