class_name StackBase
extends TraitEffect
## Shared part of `stack_damage` and `stack_haste` (F-192): `s` stacks, +1 (up to `max`) at every `gain` event, back to 0 at `lose`.
## The subclasses only say what a stack is worth. State: {"stacks"} (the only effect state of the trait).

var _stacks: int = 0


func has_state() -> bool:
	return true


func on_kill(ctx: EffectContext) -> void:
	if params["gain"] == "kill":
		_add(ctx)


## `hit` = a hit of the player of kind B, A or C that lands (the extra hit of `double_hit_pct` does not count).
func on_hit(ctx: EffectContext, _damage: int) -> void:
	if params["gain"] == "hit" and counts(ctx.hit_kind):
		_add(ctx)


func on_block(ctx: EffectContext) -> void:
	if params["gain"] == "block":
		_add(ctx)


func on_evade(ctx: EffectContext) -> void:
	if params["gain"] == "evade":
		_add(ctx)


func on_damaged(_ctx: EffectContext, _damage: int) -> void:
	if params["lose"] == "damaged":
		_stacks = 0


func on_encounter_start(_ctx: EffectContext) -> void:
	if params["lose"] == "encounter":
		_stacks = 0


func to_save() -> Dictionary:
	return {"stacks": _stacks} if _stacks > 0 else {}


func from_save(d: Dictionary) -> void:
	var v: Variant = d.get("stacks")
	_stacks = clampi(int(v), 0, int(params["max"])) if v is int or v is float else 0


## The hit kinds that the rules of M28 count (B, A, C): not the extra hit of F-120.
static func counts(kind: StringName) -> bool:
	return kind == EffectContext.HIT_BASE or kind == EffectContext.HIT_ABILITY or kind == EffectContext.HIT_COUNTER


func _add(ctx: EffectContext) -> void:
	var next: int = mini(int(params["max"]), _stacks + 1)
	if next != _stacks:
		_stacks = next
		ctx.trigger(trait_id)
