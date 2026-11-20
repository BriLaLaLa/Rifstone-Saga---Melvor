class_name StatusDamageMult
extends TraitEffect
## F-192 `status_damage_mult` (`condition`, `pct`): factor `1 + pct/100` in `M` (B, A, C) if the target has the condition now.


func hit_mult(ctx: EffectContext) -> float:
	if ctx.target_conditions == null or not StackBase.counts(ctx.hit_kind):
		return 1.0
	if not ctx.target_conditions.has(StringName(str(params["condition"]))):
		return 1.0
	return 1.0 + float(params["pct"]) / 100.0
