class_name GatherEffects
extends RefCounted
## The `on_gather` effects of the legendary tools worn (F-120) for one cycle of a gathering action of the player (never of a
## helper). No state: `roll` draws on `session.rng` in the order of the effects, and only if some effect is worn.

const TYPES: Array[StringName] = [&"gather_bonus_item", &"gather_grade_up_pct", &"byproduct_mult"]


## The rolls of the cycle; null when no legendary tool effect applies (no draw is made).
static func roll(session: GameSession, action: ActionDef) -> GatherContext:
	var effects: Array[TraitEffect] = []
	for def: ItemEffectDef in session.equipment.item_effects():
		if TYPES.has(def.type):
			effects.append(EffectSet.create_typed(def.source, def.type, def.params))
	if effects.is_empty():
		return null
	var ctx := GatherContext.new()
	ctx.rng = session.rng
	ctx.action = action
	ctx.upgraded_action = next_resource(action, session.data)
	for effect: TraitEffect in effects:
		effect.on_gather(ctx)
	return ctx


## The action of the next resource of the skill of `action` (the first with a higher level); null for the last one.
static func next_resource(action: ActionDef, data: GameData) -> ActionDef:
	for candidate: ActionDef in data.actions_for_skill(action.skill_id):
		if candidate.level > action.level:
			return candidate
	return null
