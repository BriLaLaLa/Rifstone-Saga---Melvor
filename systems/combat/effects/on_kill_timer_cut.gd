class_name OnKillTimerCut
extends TraitEffect
## F-81 `on_kill_timer_cut` (`pct`): a kill cuts the remaining base-attack timer: floor(timer x (1 - pct/100)).


func on_kill(ctx: EffectContext) -> void:
	var cut: int = int(floor(float(ctx.player_timer_ms) * (1.0 - float(params["pct"]) / 100.0) + CombatMath.EPSILON))
	if cut < ctx.player_timer_ms:
		ctx.player_timer_ms = cut
		ctx.trigger(trait_id)
