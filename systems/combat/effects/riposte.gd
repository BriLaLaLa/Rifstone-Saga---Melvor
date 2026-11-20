class_name Riposte
extends TraitEffect
## F-192 `riposte` (`on`, `mult`): after a block or an evade (`on`) the engine strikes the source back (counter-attack C); the strongest
## `mult` among the effects wins (`ctx.counter_mult`).


func on_block(ctx: EffectContext) -> void:
	if params["on"] == "block":
		_ask(ctx)


func on_evade(ctx: EffectContext) -> void:
	if params["on"] == "evade":
		_ask(ctx)


func _ask(ctx: EffectContext) -> void:
	ctx.counter_mult = maxf(ctx.counter_mult, float(params["mult"]))
	ctx.trigger(trait_id)
