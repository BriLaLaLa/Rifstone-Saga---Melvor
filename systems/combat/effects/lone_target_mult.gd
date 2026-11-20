class_name LoneTargetMult
extends TraitEffect
## F-192 `lone_target_mult` (`pct`): factor `1 + pct/100` in `M` (B, A, C) when exactly one enemy is alive as the hit is rolled.


func hit_mult(ctx: EffectContext) -> float:
	if ctx.alive_count == 1 and StackBase.counts(ctx.hit_kind):
		return 1.0 + float(params["pct"]) / 100.0
	return 1.0
