class_name LeechPct
extends TraitEffect
## F-81 `leech_pct` (`pct`): heals floor(damage dealt x pct/100) on every hit.


func on_hit(ctx: EffectContext, damage: int) -> void:
	var healed: int = int(floor(float(damage) * float(params["pct"]) / 100.0 + CombatMath.EPSILON))
	if healed > 0:
		ctx.heal += healed
		ctx.trigger(trait_id)
