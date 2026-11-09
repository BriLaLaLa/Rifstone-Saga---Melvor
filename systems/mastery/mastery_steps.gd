class_name MasterySteps
extends RefCounted
## F-122 (M14) for one action with mastery: the bonus every `mastery.step.every_levels` levels, scoped to the action, and
## the data the UI shows (level, bonuses reached, next bonus with its text). Pure functions over `GameData`.

const NEXT_TEXT: String = "Al livello %d: %s"


## The bonus of an action at `level` with the scope action:<id> (a gathering skill uses `mastery.step.gathering`, an
## artisan skill `mastery.step.crafting`).
static func scoped(level: int, category: StringName, action_id: StringName, data: GameData) -> Array[Modifier]:
	var mods: Array[Modifier] = []
	for mod: Modifier in MasteryMath.step_bonus(level, MasteryMath.step_kind(category), data):
		mods.append(Modifier.make(mod.stat, mod.value, Modifier.SCOPE_ACTION, action_id))
	return mods


## `{"level", "n" (steps reached), "current": the modifiers reached, "next": {"level", "modifiers", "text"} or {}}`.
static func info(level: int, category: StringName, data: GameData) -> Dictionary:
	var kind: StringName = MasteryMath.step_kind(category)
	var next: Dictionary = MasteryMath.next_step(level, kind, data)
	if not next.is_empty():
		next["text"] = NEXT_TEXT % [next["level"], LoadoutDescribe.modifiers_text(next["modifiers"], data)]
	return {"level": level, "n": MasteryMath.step_count(level, data), "current": MasteryMath.step_bonus(level, kind, data),
			"next": next}
