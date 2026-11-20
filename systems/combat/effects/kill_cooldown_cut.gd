class_name KillCooldownCut
extends TraitEffect
## F-192 `kill_cooldown_cut` (`ms`): at every kill each active cooldown of the abilities loses `ms` (sum over the effects).


func on_kill(ctx: EffectContext) -> void:
	ctx.cooldown_cut_ms += int(params["ms"])
	ctx.trigger(trait_id)
