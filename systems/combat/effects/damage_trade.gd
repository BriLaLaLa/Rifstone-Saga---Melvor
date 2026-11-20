class_name DamageTrade
extends TraitEffect
## F-192 `damage_trade` (`dealt_pct`, `taken_pct`): factor `1 + dealt_pct/100` in `M` (B, A, C) and `1 + taken_pct/100` on the damage
## taken (F-193).


func hit_mult(ctx: EffectContext) -> float:
	if not StackBase.counts(ctx.hit_kind):
		return 1.0
	return 1.0 + float(params["dealt_pct"]) / 100.0


func incoming_mult(_ctx: EffectContext) -> float:
	return 1.0 + float(params["taken_pct"]) / 100.0
