class_name ReflectPct
extends TraitEffect
## F-81 `reflect_pct` (`pct`): the attacker loses floor(damage taken x pct/100); no roll, no reduction.


func on_damaged(ctx: EffectContext, damage: int) -> void:
	var back: int = int(floor(float(damage) * float(params["pct"]) / 100.0 + CombatMath.EPSILON))
	if back > 0:
		ctx.reflect_damage += back
		ctx.trigger(trait_id)
