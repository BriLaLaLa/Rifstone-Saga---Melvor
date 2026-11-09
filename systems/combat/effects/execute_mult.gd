class_name ExecuteMult
extends TraitEffect
## F-120 `execute_mult` (`hp_pct`, `mult`), hook `on_before_attack` (asked for each target): the damage after F-24 of the
## base attack is multiplied by `mult` (floor) when the target has hp <= hp_pct% of its maximum.


func damage_mult_against(ctx: EffectContext, target_hp: int, target_max_hp: int) -> float:
	if target_hp <= int(floor(float(target_max_hp) * float(params["hp_pct"]) / 100.0 + CombatMath.EPSILON)):
		ctx.trigger(trait_id)
		return float(params["mult"])
	return 1.0
