class_name MonolithLootMult
extends TraitEffect
## F-120 `monolith_loot_mult` (`mult`), hook `on_monolith`: the quantity of every stack of the loot of a Rift Monolith is
## multiplied by `mult` (round). Several of them multiply.


func on_monolith(ctx: EffectContext) -> void:
	ctx.loot_mult *= float(params["mult"])
	ctx.trigger(trait_id)
