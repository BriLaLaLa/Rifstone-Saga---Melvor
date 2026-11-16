class_name CycleState
extends RefCounted
## What the combat engine holds for the cycle of an area (docs/05_INTERFACES_M24.md §5.33, §6b): the journey timer and its meta, the
## node in progress and the counters of nodes (worked, skipped) of the slot. Save, tolerant load and the copy for the UI live here;
## the transitions are in `CombatFight`.

var travel_ms: int = 0
var travel_total_ms: int = 0
var next: Dictionary = {}  # {"kind", "skill"} while travelling
var node: NodeWork = null
var worked: int = 0
var skipped: int = 0

var _session: GameSession


func _init(session: GameSession) -> void:
	_session = session


## A new journey: F-153 decides the next encounter now (rolls on `session.rng`), the timer is `encounters.travel_ms`.
func begin_travel(area_id: StringName, forced_fight: bool) -> void:
	travel_total_ms = int(_session.data.balance_value("encounters.travel_ms"))
	travel_ms = travel_total_ms
	node = null
	next = EncounterCycle.next_kind(_session, area_id, forced_fight)


## Journey and node gone (the counters stay).
func clear() -> void:
	travel_ms = 0
	travel_total_ms = 0
	next = {}
	node = null


func reset() -> void:
	clear()
	worked = 0
	skipped = 0


## The discipline of the node being worked, `&""` for a skipped node or none.
func worked_skill() -> StringName:
	return node.skill_id if node != null and not node.skipped else &""


## The saved part of the engine: only the journey while `travelling`, only the node while `working` (05_INTERFACES_M24 §6b).
func to_save(travelling: bool, working: bool) -> Dictionary:
	return {
		"travel_ms": travel_ms if travelling else 0,
		"next": {"kind": String(next["kind"]), "skill": String(next["skill"])} if travelling and not next.is_empty() else {},
		"node": node.to_save() if working and node != null else {},
		"nodes": {"worked": worked, "skipped": skipped},
	}


## Takes what `CombatSave.read` parsed (`cycle`).
func apply(parsed: Dictionary) -> void:
	travel_ms = parsed["travel_ms"]
	travel_total_ms = int(_session.data.balance_value("encounters.travel_ms")) if parsed["state"] == CombatState.STATE_TRAVEL else 0
	next = parsed["next"]
	node = parsed["node"]
	worked = parsed["worked"]
	skipped = parsed["skipped"]


## Tolerant read of a saved `travel` or `node` state in `area_id` (§6b): a malformed or unknown `next` or `node` gives a full journey
## to a fight. Returns {"state", "travel_ms", "next", "node", "worked", "skipped"}; `state` is `idle` for an idle save (counters only).
static func parse(d: Dictionary, data: GameData, saved_state: StringName, area_id: StringName) -> Dictionary:
	var counts: Variant = d.get("nodes")
	var result: Dictionary = {"state": CombatState.STATE_IDLE, "travel_ms": 0, "next": {}, "node": null, "worked": 0, "skipped": 0}
	if counts is Dictionary:
		result["worked"] = maxi(0, _int(counts as Dictionary, "worked"))
		result["skipped"] = maxi(0, _int(counts as Dictionary, "skipped"))
	if saved_state != CombatState.STATE_TRAVEL and saved_state != CombatState.STATE_NODE and saved_state != CombatState.STATE_BETWEEN:
		return result
	var full: int = int(data.balance_value("encounters.travel_ms"))
	result["state"] = CombatState.STATE_TRAVEL
	result["travel_ms"] = full
	result["next"] = {"kind": EncounterCycle.FIGHT, "skill": &""}
	if saved_state == CombatState.STATE_BETWEEN:
		return result
	if saved_state == CombatState.STATE_NODE:
		var saved_node: Variant = d.get("node")
		var work: NodeWork = NodeWork.from_save(saved_node as Dictionary, data) if saved_node is Dictionary else null
		if work != null and _in_area(data, area_id, work.skill_id):
			result["state"] = CombatState.STATE_NODE
			result["travel_ms"] = 0
			result["next"] = {}
			result["node"] = work
		else:
			Log.warn("combat", "saved node malformed or unknown: a full journey to a fight")
		return result
	var saved_next: Variant = d.get("next")
	if saved_next is Dictionary:
		var kind := StringName(str((saved_next as Dictionary).get("kind", "")))
		var skill := StringName(str((saved_next as Dictionary).get("skill", "")))
		if kind == EncounterCycle.NODE and _in_area(data, area_id, skill):
			result["next"] = {"kind": EncounterCycle.NODE, "skill": skill}
			result["travel_ms"] = clampi(_int(d, "travel_ms"), 0, full)
		elif kind == EncounterCycle.FIGHT:
			result["travel_ms"] = clampi(_int(d, "travel_ms"), 0, full)
		else:
			Log.warn("combat", "saved journey with an unknown destination: a full journey to a fight")
	return result


## The `node` and `next` of `get_state()`: {} outside the state they belong to.
func view(state: StringName) -> Dictionary:
	var result: Dictionary = {"travel_ms": 0, "travel_total_ms": 0, "next": {}, "node": {}}
	if state == CombatState.STATE_TRAVEL:
		result["travel_ms"] = travel_ms
		result["travel_total_ms"] = travel_total_ms
		result["next"] = next.duplicate()
	elif state == CombatState.STATE_NODE and node != null:
		var color: Dictionary = node.color(_session)
		result["node"] = {"skill": node.skill_id, "action": node.action_id, "duration_ms": node.duration_ms,
			"elapsed_ms": node.elapsed_ms, "skipped": node.skipped, "color": color["id"],
			"units": 0 if node.skipped else int(_session.data.balance_value("encounters.node_units"))}
	return result


static func _in_area(data: GameData, area_id: StringName, skill_id: StringName) -> bool:
	var nodes: AreaNodesDef = data.area_nodes(area_id)
	if nodes == null:
		return false
	for entry: NodeEntryDef in nodes.entries:
		if entry.skill == skill_id:
			return true
	return false


static func _int(d: Dictionary, key: String) -> int:
	var v: Variant = d.get(key)
	return int(v) if v is int or v is float else 0
