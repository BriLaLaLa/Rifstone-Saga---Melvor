class_name CardDropMult
extends TraitEffect
## F-120 `card_drop_mult` (`mult`), hook `on_kill`: the probability of the Fracture Cards dropped by monsters and Monoliths
## (F-113) is multiplied by `mult` (at most 100%). Several of them multiply.


func on_kill(ctx: EffectContext) -> void:
	ctx.card_mult *= float(params["mult"])
	ctx.trigger(trait_id)
