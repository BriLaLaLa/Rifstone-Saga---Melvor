class_name DungeonStub
extends RefCounted
## Stand-in for `DungeonSystem` (docs/05_INTERFACES.md §5.29) with the same signatures, for the UI smoke test: the test
## sets the phase with `set_phase` and the page reads `state()`. Commands count their calls and answer with `forced_reason`
## when it is set. It knows nothing of maps: the choices are given.

var active: bool = false
var paused: bool = false
var forced_reason: StringName = &""
var ticket_count: int = 1
var pending_data: Dictionary = {}
var calls: Dictionary[StringName, int] = {}
var last_choice: int = -1
var _state: Dictionary = {}


func is_active() -> bool:
	return active


func state() -> Dictionary:
	return _state.duplicate(true)


## `phase`: &"await", &"event", &"fight", &"intro" (or &"" for no run). `directions` = how many exits in the fork.
## `stage_index` (1..3) only matters for the boss (the `stage` fields of M22-09: `count`, `monster`, `acts`).
func set_phase(phase: StringName, directions: int = 3, kind: StringName = &"pack", is_paused: bool = false,
		stage_index: int = 1) -> void:
	active = phase != &""
	paused = is_paused
	if not active:
		_state = {}
		return
	var choices: Array[Dictionary] = []
	if phase == &"await":
		var all: Array[StringName] = [&"left", &"forward", &"right", &"far_right"]
		for i: int in directions:
			choices.append({"id": &"exit", "direction": all[i]})
	elif phase == &"event":
		var ids: Array[StringName] = []
		ids.assign([&"dash", &"detour"] if kind == &"trap" else [&"rest", &"forage"])
		for id: StringName in ids:
			choices.append({"id": id, "direction": &""})
	_state = {"dungeon": &"monkey_den", "phase": phase, "paused": is_paused, "progress": {"done": 2, "total": 7},
		"room": {"layer": 2, "kind": kind, "name": ""}, "choices": choices,
		"bag": {"stacks": 2, "pieces": 1, "cards": 0}, "can_leave": (phase == &"await" or phase == &"event") and not is_paused,
		"wins": 3}
	if kind == &"boss":
		var acts: Array[Dictionary] = [
			{"id": &"right_hand", "monster": &"monkey_gorom", "name": "Gorom"},
			{"id": &"strategist", "monster": &"monkey_ziki", "name": "Ziki"},
			{"id": &"king", "monster": &"monkey_king", "name": "Uuk-Maar"},
		]
		_state["room"]["name"] = "Il Braccio Destro"
		_state["stage"] = {"index": stage_index, "id": acts[stage_index - 1]["id"], "title": "Il Braccio Destro",
			"quote": "Nessuno passa.", "intro_ms": 4000, "intro_left_ms": 2000 if phase == &"intro" else 0,
			"count": acts.size(), "monster": acts[stage_index - 1]["monster"], "acts": acts}


func can_open(_dungeon_id: StringName) -> StringName:
	return &"ok"


func open(dungeon_id: StringName) -> CommandResult:
	return _command(&"open", dungeon_id)


func choose(index: int) -> CommandResult:
	last_choice = index
	return _command(&"choose")


func leave() -> CommandResult:
	return _command(&"leave")


func flee() -> CommandResult:
	return _command(&"flee")


func resume() -> CommandResult:
	return _command(&"resume")


func pending() -> Dictionary:
	return pending_data.duplicate(true)


func has_pending() -> bool:
	return not pending_data.is_empty()


func collect() -> CommandResult:
	return _command(&"collect")


func tickets(_dungeon_id: StringName) -> int:
	return ticket_count


func wins(_dungeon_id: StringName = &"") -> int:
	return 3


func _command(name: StringName, _argument: StringName = &"") -> CommandResult:
	calls[name] = int(calls.get(name, 0)) + 1
	if forced_reason != &"":
		return CommandResult.fail(forced_reason)
	return CommandResult.success()
