class_name GatherFocus
extends RefCounted
## M35 (docs/01_GDD_M35.md §42.3, F-195): the helpers of `Disciplines.focus_of/set_focus`. The choice itself (skill id -> action id, only
## gathering disciplines that are learned) is a Dictionary held by `Disciplines`; nothing is kept here.

const SAVE_KEY: String = "focus"


## F-195: unknown_id (not an action of that skill, or a skill that is not a gathering discipline), not_learned, level_too_low (the level of the
## action is above the level of the discipline).
static func check(session: GameSession, skill_id: StringName, action_id: StringName) -> CommandResult:
	var data: GameData = session.data
	if not data.has_action(action_id) or data.action(action_id).skill_id != skill_id or not _is_gathering(session, skill_id):
		return CommandResult.fail(Reasons.UNKNOWN_ID)
	if not session.disciplines.is_learned(skill_id):
		return CommandResult.fail(Reasons.NOT_LEARNED)
	if data.action(action_id).level > session.skills.get_level(skill_id):
		return CommandResult.fail(Reasons.LEVEL_TOO_LOW)
	return CommandResult.success()


## Sets (`action_id` given) or removes (`&""`, always ok) the choice of `skill_id` in `focus`; `gather_focus_changed` only when it changed.
static func set_choice(focus: Dictionary[StringName, StringName], session: GameSession, skill_id: StringName, action_id: StringName) -> CommandResult:
	if action_id == &"":
		clear(focus, session, skill_id)
		return CommandResult.success()
	var checked: CommandResult = check(session, skill_id, action_id)
	if checked.ok and focus.get(skill_id, &"") != action_id:
		focus[skill_id] = action_id
		session.events.gather_focus_changed.emit(skill_id, action_id)
	return checked


## Removes the choice of `skill_id` (unlearn, reset, `set_choice` with `&""`); the signal follows only if there was one.
static func clear(focus: Dictionary[StringName, StringName], session: GameSession, skill_id: StringName) -> void:
	if focus.erase(skill_id):
		session.events.gather_focus_changed.emit(skill_id, &"")


## `{skill: action}` of `focus` for the save (docs/05_INTERFACES_M35.md §6h).
static func to_save(focus: Dictionary[StringName, StringName]) -> Dictionary:
	var result: Dictionary = {}
	for skill_id: StringName in focus:
		result[String(skill_id)] = String(focus[skill_id])
	return result


## Tolerant: an entry that is not a gathering discipline that is learned, or whose action is not of that skill, is ignored (no error, no
## level check: the level of the skill can only have gone down by a reset, which clears the choice).
static func from_save(raw: Variant, session: GameSession) -> Dictionary[StringName, StringName]:
	var result: Dictionary[StringName, StringName] = {}
	if not raw is Dictionary:
		return result
	for key: Variant in raw as Dictionary:
		var skill_id := StringName(str(key))
		var action_id := StringName(str((raw as Dictionary)[key]))
		if session.data.has_action(action_id) and session.data.action(action_id).skill_id == skill_id and _is_gathering(session, skill_id) \
				and session.disciplines.is_learned(skill_id):
			result[skill_id] = action_id
	return result


static func _is_gathering(session: GameSession, skill_id: StringName) -> bool:
	return session.disciplines.category_of(skill_id) == &"gathering"
