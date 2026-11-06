class_name LowHpDamageMult
extends TraitEffect
## F-81 `low_hp_damage_mult` (`hp_pct`, `mult`, `no_auto_eat`): with hp <= floor(max_hp x hp_pct/100) the damage is
## multiplied by `mult` (after F-24, before F-25), and with `no_auto_eat` F-30 does not run.


func on_before_attack(ctx: EffectContext) -> void:
	if _is_low(ctx):
		ctx.damage_mult *= float(params["mult"])
		ctx.trigger(trait_id)


func blocks_auto_eat(ctx: EffectContext) -> bool:
	return bool(params.get("no_auto_eat", false)) and _is_low(ctx)


func _is_low(ctx: EffectContext) -> bool:
	return ctx.player_hp <= int(floor(float(ctx.player_max_hp) * float(params["hp_pct"]) / 100.0 + CombatMath.EPSILON))
