class_name ProductionJob
extends RefCounted
## One job of the production queue (docs/05_INTERFACES_M24.md §5.32): `remaining` cycles of a recipe (or `repeat` until
## the ingredients run out), or a blueprint craft (`blueprint` set; the materials leave the bank when it becomes the head).
## Internal helper of ActionRunner (not an API for other modules).

const KEY_SKILL: String = "skill"
const KEY_ACTION: String = "action"
const KEY_REMAINING: String = "remaining"
const KEY_REPEAT: String = "repeat"
const KEY_BLUEPRINT: String = "blueprint"
const KEY_AFFIX: String = "chosen_affix"
const KEY_DURATION: String = "duration_ms"
const KEY_CONSUMED: String = "consumed"

var action: ActionDef
var remaining: int = 0
var repeat: bool = false
var blueprint: StringName = &""
var chosen_affix: StringName = &""
var duration_ms: int = 0  # blueprint only: F-90 duration, fixed when the job becomes the head
var consumed: bool = false  # blueprint only: the materials are out of the bank


func is_blueprint() -> bool:
	return blueprint != &""


## The public copy of `ActionRunner.jobs()` and the save entry (the same keys, `repeat` => `remaining` 0).
func to_dict() -> Dictionary:
	var d: Dictionary = {KEY_SKILL: String(action.skill_id), KEY_ACTION: String(action.id)}
	if is_blueprint():
		d[KEY_BLUEPRINT] = String(blueprint)
		d[KEY_AFFIX] = String(chosen_affix)
		d[KEY_DURATION] = duration_ms
		d[KEY_CONSUMED] = consumed
	else:
		d[KEY_REMAINING] = 0 if repeat else remaining
		d[KEY_REPEAT] = repeat
	return d
