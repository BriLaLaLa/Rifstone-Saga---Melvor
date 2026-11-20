class_name WardOn
extends TraitEffect
## F-192 `ward_on` (`on`, `pct`, `ms`): a Ward of `pct` of the maximum hp for `ms` (F-189) at a kill, a block or the start of an
## encounter. The engine grants it; with several effects on the same event the largest one wins.


func on_kill(ctx: EffectContext) -> void:
	if params["on"] == "kill":
		_ask(ctx)


func on_block(ctx: EffectContext) -> void:
	if params["on"] == "block":
		_ask(ctx)


func on_encounter_start(ctx: EffectContext) -> void:
	if params["on"] == "encounter_start":
		_ask(ctx)


func _ask(ctx: EffectContext) -> void:
	var pct: float = float(params["pct"])
	if pct > ctx.ward_pct:
		ctx.ward_pct = pct
		ctx.ward_ms = int(params["ms"])
	ctx.trigger(trait_id)
