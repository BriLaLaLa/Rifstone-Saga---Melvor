class_name StackDamage
extends StackBase
## F-192 `stack_damage` (`gain`, `pct`, `max`, `lose`): factor `1 + s x pct/100` in `M` for the hits B, A and C (F-190).


func hit_mult(ctx: EffectContext) -> float:
	if _stacks <= 0 or not StackBase.counts(ctx.hit_kind):
		return 1.0
	return 1.0 + float(_stacks) * float(params["pct"]) / 100.0
