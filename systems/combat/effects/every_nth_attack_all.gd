class_name EveryNthAttackAll
extends TraitEffect
## F-81 `every_nth_attack_all` (`n`): every n-th base attack of the combat hits every living enemy.

var _count: int = 0


func on_before_attack(ctx: EffectContext) -> void:
	_count += 1
	if _count >= int(params["n"]):
		_count = 0
		ctx.attack_all = true
		ctx.trigger(trait_id)


func to_save() -> Dictionary:
	return {"count": _count} if _count > 0 else {}


func from_save(d: Dictionary) -> void:
	var v: Variant = d.get("count")
	_count = clampi(int(v), 0, int(params["n"]) - 1) if v is int or v is float else 0
