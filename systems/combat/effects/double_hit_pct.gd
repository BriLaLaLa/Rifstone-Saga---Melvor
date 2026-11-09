class_name DoubleHitPct
extends TraitEffect
## F-120 `double_hit_pct` (`pct`), hook `on_hit`: after a base attack that hurt, `roll_pct(pct)` for a second base hit on
## the same target (the engine rolls F-23 and F-22 again). Abilities and the second hit itself never roll it.


func on_hit(ctx: EffectContext, _damage: int) -> void:
	if ctx.base_attack and ctx.rng.roll_pct(float(params["pct"])):
		ctx.extra_hit = true
		ctx.trigger(trait_id)
