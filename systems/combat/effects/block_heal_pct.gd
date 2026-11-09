class_name BlockHealPct
extends TraitEffect
## F-120 `block_heal_pct` (`pct`), hook `on_block`: a successful block (F-75) heals floor(max_hp x pct/100); the engine
## keeps the hp at the maximum.


func on_block(ctx: EffectContext) -> void:
	var healed: int = int(floor(float(ctx.player_max_hp) * float(params["pct"]) / 100.0 + CombatMath.EPSILON))
	if healed > 0:
		ctx.heal += healed
		ctx.trigger(trait_id)
