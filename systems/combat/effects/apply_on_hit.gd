class_name ApplyOnHit
extends TraitEffect
## F-192 `apply_on_hit` (`every`, `condition`, `pct`, `ms`): at every `every`-th base hit that lands, the condition is applied to the target
## of that hit (the engine skips it if the target is dead). State: {"count"}.

var _count: int = 0


func has_state() -> bool:
	return true


func on_hit(ctx: EffectContext, _damage: int) -> void:
	if ctx.hit_kind != EffectContext.HIT_BASE:
		return
	_count += 1
	if _count < int(params["every"]):
		return
	_count = 0
	var app := ConditionApply.new()
	app.condition = StringName(str(params["condition"]))
	app.pct = float(params.get("pct", 0.0))
	app.ms = int(params["ms"])
	ctx.applies.append(app)
	ctx.trigger(trait_id)


func to_save() -> Dictionary:
	return {"count": _count} if _count > 0 else {}


func from_save(d: Dictionary) -> void:
	var v: Variant = d.get("count")
	_count = clampi(int(v), 0, int(params["every"]) - 1) if v is int or v is float else 0
