class_name MasteryMilestones
extends RefCounted
## Mastery milestones of the gathering actions (F-103, F-108): thresholds from `mastery.milestones.*` and the modifier
## sources `mastery_item:<action_id>` (milestone `resource`) and `mastery_trade:<skill_id>` (milestones `trade`).
## Helper of MasterySystem, which owns the levels; this class only reads the data and builds modifier lists.

const BYPRODUCT_AT_KEY: String = "mastery.milestones.byproduct_at"
const RESOURCE_AT_KEY: String = "mastery.milestones.resource_at"
const TRADE_AT_KEY: String = "mastery.milestones.trade_at"
const BYPRODUCT_CHANCE_KEY: String = "mastery.milestones.byproduct_chance_pct"
const GATHERING: StringName = &"gathering"

var byproduct_at: int = 0
var resource_at: int = 0
var trade_at: int = 0

var _data: GameData


func _init(data: GameData) -> void:
	_data = data
	byproduct_at = int(data.balance_value(BYPRODUCT_AT_KEY))
	resource_at = int(data.balance_value(RESOURCE_AT_KEY))
	trade_at = int(data.balance_value(TRADE_AT_KEY))


func is_gathering(skill_id: StringName) -> bool:
	return _data.skill(skill_id).category == GATHERING


## True when a level change from `old_level` to `new_level` crosses one of the thresholds that change a modifier source.
func changes_sources(old_level: int, new_level: int) -> bool:
	return _crossed(resource_at, old_level, new_level) or _crossed(trade_at, old_level, new_level)


## Thresholds (in ascending order) crossed going from `old_level` to `new_level` (upwards).
func crossed(old_level: int, new_level: int) -> Array[int]:
	var result: Array[int] = []
	for at: int in [byproduct_at, resource_at, trade_at]:
		if _crossed(at, old_level, new_level):
			result.append(at)
	return result


## Thresholds of the three milestones that `level` has reached, in order.
func reached(level: int) -> Array[int]:
	var result: Array[int] = []
	for at: int in [byproduct_at, resource_at, trade_at]:
		if level >= at:
			result.append(at)
	return result


## Modifiers of the action's `resource` milestone when `level` reached it (scope `action:<id>` from the data); else [].
func resource_modifiers(action: ActionDef, level: int) -> Array[Modifier]:
	return _modifiers_of(action, MilestoneDef.TYPE_RESOURCE, resource_at, level)


## Modifiers of the action's `trade` milestone when `level` reached it (scope `skill:<id>` from the data); else [].
func trade_modifiers(action: ActionDef, level: int) -> Array[Modifier]:
	return _modifiers_of(action, MilestoneDef.TYPE_TRADE, trade_at, level)


func _modifiers_of(action: ActionDef, type: StringName, at: int, level: int) -> Array[Modifier]:
	var milestone: MilestoneDef = action.milestone_of(type)
	if milestone == null or level < at:
		return []
	return milestone.modifiers


static func _crossed(at: int, old_level: int, new_level: int) -> bool:
	return old_level < at and new_level >= at
