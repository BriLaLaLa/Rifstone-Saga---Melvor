class_name ArmorPiercePct
extends TraitEffect
## F-120 `armor_pierce_pct` (`pct`), hook `on_before_attack`: the reduction of the target (F-25, after the triangle) is
## multiplied by (1 - pct/100) in the base attack. Several pierces multiply.


func on_before_attack(ctx: EffectContext) -> void:
	ctx.dr_mult *= 1.0 - float(params["pct"]) / 100.0
	ctx.trigger(trait_id)
