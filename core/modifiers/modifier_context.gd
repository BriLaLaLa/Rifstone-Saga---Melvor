class_name ModifierContext
extends RefCounted
## The context a stat total is computed in (F-05): which skill and action, if any.
## Empty ids mean "none": the global context has both empty.

const TOOL_SOURCE_PREFIX: String = "equipment:tool_"  # source of the worn tool of a skill (Equipment.SOURCE_PREFIX + slot)

var skill_id: StringName = &""
var action_id: StringName = &""
## M12: sources ignored by `total` and `breakdown` with this context (default none).
var excluded_sources: Array[StringName] = []


static func global_ctx() -> ModifierContext:
	return ModifierContext.new()


static func for_skill(skill_id: StringName) -> ModifierContext:
	var ctx := ModifierContext.new()
	ctx.skill_id = skill_id
	return ctx


static func for_action(skill_id: StringName, action_id: StringName) -> ModifierContext:
	var ctx := ModifierContext.new()
	ctx.skill_id = skill_id
	ctx.action_id = action_id
	return ctx


## F-101 (M12): the context of a helper's action: like `for_action` but ignoring the player's tool of the skill.
static func for_helper(skill_id: StringName, action_id: StringName) -> ModifierContext:
	var ctx := ModifierContext.for_action(skill_id, action_id)
	ctx.excluded_sources = [StringName(TOOL_SOURCE_PREFIX + String(skill_id))]
	return ctx
