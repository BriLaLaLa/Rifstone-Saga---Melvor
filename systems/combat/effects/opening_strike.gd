class_name OpeningStrike
extends TraitEffect
## F-81 `opening_strike`: at the start of every encounter the base-attack timer goes to 0 (the first attack is immediate).


func on_encounter_start(ctx: EffectContext) -> void:
	if ctx.player_timer_ms > 0:
		ctx.player_timer_ms = 0
		ctx.trigger(trait_id)
