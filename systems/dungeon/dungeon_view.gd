class_name DungeonView
extends RefCounted
## The copy of a run for the UI (`DungeonSystem.state`, docs/05_INTERFACES.md §5.29), split from the system for size. Nothing of
## the hidden map reaches the UI but the kind of the room we are in and, for the exits, only the direction (no hints, M22-09).

const EXIT_CHOICE: StringName = &"exit"
const EVENT_CHOICES: Dictionary[StringName, Array] = {&"trap": [&"dash", &"detour"], &"rest": [&"rest", &"forage"]}


## `engine_state` = the `get_state()` of the combat engine (only `dungeon.intro_left_ms` is read, during an intro).
static func build(run: DungeonRun, def: DungeonDef, data: GameData, engine_state: Dictionary, wins: int) -> Dictionary:
	var room: DungeonRoom = run.map.room(run.layer, run.index)
	var awaits: bool = run.phase == DungeonRun.PHASE_AWAIT or run.phase == DungeonRun.PHASE_EVENT
	var result: Dictionary = {"dungeon": run.dungeon_id, "phase": run.phase, "paused": run.paused,
		"progress": {"done": run.cleared, "total": run.map.layers()},
		"room": {"layer": run.layer, "kind": room.kind, "name": ""}, "choices": _choices(run, room, data),
		"bag": run.bag.counts(), "can_leave": awaits and not run.paused, "wins": wins}
	if run.stage > 0:
		var stage: DungeonStageDef = def.stages[run.stage - 1]
		result["room"]["name"] = stage.title
		var acts: Array[Dictionary] = []
		for act: DungeonStageDef in def.stages:
			acts.append({"id": act.id, "monster": act.monster_id, "name": act.monster.name if act.monster != null else ""})
		result["stage"] = {"index": run.stage, "count": def.stages.size(), "id": stage.id, "monster": stage.monster_id,
			"title": stage.title, "quote": stage.quote, "intro_ms": stage.intro_ms,
			"intro_left_ms": _intro_left_ms(run, engine_state), "acts": acts}
	return result


## L_m of a room for the piece of its prize: the highest monster of its composition (0 without one).
static func room_level(def: DungeonDef, type: DungeonRoomType) -> int:
	if type == null:
		return 0
	var ids: Array[StringName] = type.fixed if not type.fixed.is_empty() else type.pool_monsters
	var level: int = 0
	for id: StringName in ids:
		var monster: MonsterDef = def.monster_def(id)
		level = maxi(level, EquipmentPool.monster_level(monster) if monster != null else 0)
	return level


static func _choices(run: DungeonRun, room: DungeonRoom, data: GameData) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if run.phase == DungeonRun.PHASE_AWAIT:
		for exit: Dictionary in run.map.exits_of(run.layer, run.index, data):
			result.append({"id": EXIT_CHOICE, "direction": exit["direction"]})
	elif run.phase == DungeonRun.PHASE_EVENT:
		for id: StringName in EVENT_CHOICES[room.kind]:
			result.append({"id": id, "direction": &""})
	return result


static func _intro_left_ms(run: DungeonRun, engine_state: Dictionary) -> int:
	if run.phase != DungeonRun.PHASE_INTRO:
		return 0
	var view: Variant = engine_state.get("dungeon")
	return int((view as Dictionary).get("intro_left_ms", 0)) if view is Dictionary else 0
