class_name CombatTutorial
extends RefCounted
## The forced pack and the guard of the tutorial (docs/M33_TUTORIAL_FORZATO.md §3.2, §4): armed only by `TutorialSystem` through the
## engine, derived from the current step, never saved, no roll on `session.rng`. Held by `CycleState` (next to `force_node`).

var _session: GameSession
var _cy: CycleState
var _area: StringName = &""
var _monsters: Array[StringName] = []


func _init(session: GameSession, cy: CycleState) -> void:
	_session = session
	_cy = cy


## Arms (or, with no monsters, disarms) the pack of `area_id`. `travelling` and `current_area`: the journey in progress to a node
## (not forced) becomes a fight, so that the meal does not wait for a node.
func set_pack(area_id: StringName, monster_ids: Array[StringName], travelling: bool, current_area: StringName) -> void:
	_area = area_id if not monster_ids.is_empty() else &""
	_monsters = monster_ids.duplicate() if not monster_ids.is_empty() else ([] as Array[StringName])
	if travelling and armed(current_area) and not _cy.force_node and _cy.next.get("kind") == EncounterCycle.NODE:
		_cy.next = {"kind": EncounterCycle.FIGHT, "skill": &""}


func pack() -> Array[StringName]:
	return _monsters.duplicate()


func armed(area_id: StringName) -> bool:
	return not _monsters.is_empty() and _area == area_id


## A forced pack for this area is armed, or `force_node` is on.
func guarded(area_id: StringName) -> bool:
	return armed(area_id) or _cy.force_node


## The forced encounter of the area (full hp, full timers), or null if none is armed for it. No roll.
func encounter(area_id: StringName) -> Encounter:
	if not armed(area_id):
		return null
	var defs: Array[MonsterDef] = []
	for monster_id: StringName in _monsters:
		defs.append(_session.data.monster(monster_id))
	return Encounter.of_defs(defs, _session.data)


## `force_node` just went on: a journey in progress to a fight, or to a node that would be skipped, becomes the forced node (no roll).
func retarget_node(area_id: StringName, travelling: bool) -> void:
	if not travelling or not _cy.force_node or _cy.next.is_empty():
		return
	if _cy.next["kind"] == EncounterCycle.NODE and EncounterCycle.is_workable(_session, area_id, _cy.next["skill"]):
		return
	var forced: Dictionary = EncounterCycle.forced_node(_session, area_id)
	if not forced.is_empty():
		_cy.next = forced


func reset() -> void:
	_area = &""
	_monsters = []
