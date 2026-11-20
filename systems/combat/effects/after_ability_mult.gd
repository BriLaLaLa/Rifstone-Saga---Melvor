class_name AfterAbilityMult
extends TraitEffect
## F-192 `after_ability_mult` (`mult`): after any ability is used the next base attack is "charged": its hits (all targets) have the factor
## `mult` in `M`; the charge ends with that attack, even if it misses. State: {"armed"}.

var _armed: bool = false
var _firing: bool = false  # the base attack being rolled now is the charged one (never saved: an attack is atomic)


func has_state() -> bool:
	return true


func on_ability(_ctx: EffectContext) -> void:
	_armed = true


func on_before_attack(ctx: EffectContext) -> void:
	_firing = _armed
	if _armed:
		_armed = false
		ctx.trigger(trait_id)


func hit_mult(ctx: EffectContext) -> float:
	return float(params["mult"]) if _firing and ctx.hit_kind == EffectContext.HIT_BASE else 1.0


func to_save() -> Dictionary:
	return {"armed": true} if _armed else {}


func from_save(d: Dictionary) -> void:
	_armed = d.get("armed") is bool and d["armed"] as bool
