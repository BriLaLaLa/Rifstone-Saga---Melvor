class_name ModifierContext
extends RefCounted
## The context a stat total is computed in (F-05): which skill and action, if any.
## Empty ids mean "none": the global context has both empty.

var skill_id: StringName = &""
var action_id: StringName = &""


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
