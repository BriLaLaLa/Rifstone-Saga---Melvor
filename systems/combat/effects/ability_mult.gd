class_name AbilityMult
extends TraitEffect
## F-192 `ability_mult` (`kinds`, `pct`): factor `1 + pct/100` on the abilities of the listed kinds: in `M` for the hits of `strike` and
## `cleave`, on the amount of a `heal` (F-191) or of a `ward` (F-189).


func hit_mult(ctx: EffectContext) -> float:
	if ctx.hit_kind == EffectContext.HIT_ABILITY and _listed(ctx.ability_kind):
		return 1.0 + float(params["pct"]) / 100.0
	return 1.0


func amount_mult(ctx: EffectContext) -> float:
	if _listed(ctx.ability_kind):
		return 1.0 + float(params["pct"]) / 100.0
	return 1.0


func _listed(kind: StringName) -> bool:
	return (params["kinds"] as Array).has(String(kind))
