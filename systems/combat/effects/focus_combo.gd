class_name FocusCombo
extends TraitEffect
## F-192 `focus_combo` (`pct`, `max`): factor `1 + c x pct/100` on the base hit against the main target, with `c` the consecutive base
## hits already landed on that target (at most `max`). Another main target restarts at 0; the extra targets of `every_nth_attack_all`
## neither get the factor nor count. State: {"target", "count"}.

var _target: int = -1
var _count: int = 0


func has_state() -> bool:
	return true


func on_encounter_start(_ctx: EffectContext) -> void:
	_target = -1
	_count = 0


func hit_mult(ctx: EffectContext) -> float:
	if ctx.hit_kind != EffectContext.HIT_BASE or ctx.target_index != ctx.primary_index or ctx.target_index != _target or _count <= 0:
		return 1.0
	return 1.0 + float(mini(_count, int(params["max"]))) * float(params["pct"]) / 100.0


func on_hit(ctx: EffectContext, _damage: int) -> void:
	if ctx.hit_kind != EffectContext.HIT_BASE or ctx.target_index != ctx.primary_index:
		return
	if ctx.target_index == _target:
		_count = mini(int(params["max"]), _count + 1)
	else:
		_target = ctx.target_index
		_count = 1
	ctx.trigger(trait_id)


func to_save() -> Dictionary:
	return {"target": _target, "count": _count} if _count > 0 else {}


func from_save(d: Dictionary) -> void:
	var target: Variant = d.get("target")
	var count: Variant = d.get("count")
	if (target is int or target is float) and (count is int or count is float):
		_target = maxi(-1, int(target))
		_count = clampi(int(count), 0, int(params["max"]))
	else:
		_target = -1
		_count = 0
