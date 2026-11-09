class_name ByproductMult
extends TraitEffect
## F-120 `byproduct_mult` (`mult`), hook `on_gather`: the probability of the byproduct of the mastery milestone (F-103) is
## multiplied by `mult` (at most 100%). No roll of its own.


func on_gather(ctx: GatherContext) -> void:
	ctx.byproduct_mult *= float(params["mult"])
