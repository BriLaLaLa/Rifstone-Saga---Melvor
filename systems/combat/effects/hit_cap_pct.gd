class_name HitCapPct
extends TraitEffect
## F-120 `hit_cap_pct` (`pct`), hook `on_damaged` (before the damage is taken): a hit that reaches the player (after
## F-25) never exceeds max(1, floor(max_hp x pct/100)).


func cap_damage(ctx: EffectContext, damage: int) -> int:
	var cap: int = maxi(1, int(floor(float(ctx.player_max_hp) * float(params["pct"]) / 100.0 + CombatMath.EPSILON)))
	if damage > cap:
		ctx.trigger(trait_id)
		return cap
	return damage
