class_name KillHealPct
extends TraitEffect
## F-120 `kill_heal_pct` (`pct`), hook `on_kill`: a kill heals floor(max_hp x pct/100).


func on_kill(ctx: EffectContext) -> void:
	var healed: int = int(floor(float(ctx.player_max_hp) * float(params["pct"]) / 100.0 + CombatMath.EPSILON))
	if healed > 0:
		ctx.heal += healed
		ctx.trigger(trait_id)
