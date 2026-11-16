class_name CombatCycleStub
extends RefCounted
## Test double of what M24-04 adds to the combat (05_INTERFACES_M24.md §5.33), for the UI smoke tests that run before the
## real engine exists: the extra keys of `combat.get_state()` for the travel and node states, and the static
## `color(data, skill_level, action_level)` of `EncounterCycle` (point `NodeColorPreview.cycle_script_path` to this file).
## Not a rule of the game: the numbers here are fixed values for the tests.


## A `combat.get_state()` dictionary in the `travel` state: `left_ms` of `total_ms` left, heading to `skill_id` (a node) or
## to a fight (`skill_id` empty).
static func travel_state(left_ms: int, total_ms: int, skill_id: StringName = &"") -> Dictionary:
	return {
		"state": &"travel", "area": &"", "enemies": [], "travel_ms": left_ms, "travel_total_ms": total_ms,
		"next": {"kind": &"node" if skill_id != &"" else &"fight", "skill": skill_id}, "node": {},
	}


## A state in the `node` state: the resource `action_id` of `skill_id` at `elapsed_ms` of `duration_ms`.
static func node_state(skill_id: StringName, action_id: StringName, elapsed_ms: int, duration_ms: int,
		skipped: bool = false, color: StringName = &"orange", units: int = 0) -> Dictionary:
	return {
		"state": &"node", "area": &"", "enemies": [], "travel_ms": 0, "travel_total_ms": 0, "next": {},
		"node": {"skill": skill_id, "action": action_id, "duration_ms": duration_ms, "elapsed_ms": elapsed_ms,
				"skipped": skipped, "color": color, "units": units},
	}


## The signature of `EncounterCycle.color` (F-154): always orange here.
static func color(_data: GameData, _skill_level: int, _action_level: int) -> Dictionary:
	return {"id": &"orange", "xp_pct": 100.0}
