class_name NodeColorPreview
extends RefCounted
## The colour a node of a gathering resource would have at the player's current level (F-154), read from the model:
## `EncounterCycle.color(data, skill_level, action_level)` -> `{"id", "xp_pct"}` (05_INTERFACES_M24.md §5.33). The UI
## computes nothing. The class of the cycle (M24-04) is loaded by path so that this page works before and after it
## lands; `{}` (nothing to show) when it does not exist yet.

## Path of the script of `EncounterCycle`; a test may point it to a double with the same static signature.
static var cycle_script_path: String = "res://systems/encounters/encounter_cycle.gd"


## `{"id": StringName, "xp_pct": float}` of `action` at the level of the player in `action.skill_id`, or `{}`.
static func of(session: GameSession, action: ActionDef) -> Dictionary:
	if not ResourceLoader.exists(cycle_script_path):
		return {}
	var cycle: Script = load(cycle_script_path) as Script
	if cycle == null:
		return {}
	var result: Variant = cycle.call("color", session.data, session.skills.get_level(action.skill_id), action.level)
	return result as Dictionary if result is Dictionary else {}
