class_name EffectSet
extends RefCounted
## The trait effects of the active traits (Loadout.active_traits, in slot order) and the dispatch of the engine hooks
## (docs/01_GDD.md §20.3). Rebuilt lazily after `invalidate` (traits or equipment changed); the counters of the effects
## survive a rebuild and live until `reset` (new combat) or the end of the combat. Emits `trait_triggered`.
## Dependencies: data, events, loadout.

const LOG_CATEGORY: String = "combat"

var _session: GameSession
var _effects: Array[TraitEffect] = []
var _dirty: bool = true
# trait id -> counter state (`TraitEffect.to_save`), kept across rebuilds.
var _states: Dictionary[StringName, Dictionary] = {}


func _init(session: GameSession) -> void:
	_session = session


## The effect of a trait entry, null (logged) for an unknown type. A new type is one line here.
static func create(trait_id: StringName, def: TraitEffectDef) -> TraitEffect:
	var p: Dictionary = def.params
	match def.type:
		&"every_nth_attack_all":
			return EveryNthAttackAll.new(trait_id, p)
		&"on_kill_timer_cut":
			return OnKillTimerCut.new(trait_id, p)
		&"low_hp_damage_mult":
			return LowHpDamageMult.new(trait_id, p)
		&"stat_trade":
			return StatTrade.new(trait_id, p)
		&"target_rule":
			return TargetRuleEffect.new(trait_id, p)
		&"reflect_pct":
			return ReflectPct.new(trait_id, p)
		&"leech_pct":
			return LeechPct.new(trait_id, p)
		&"opening_strike":
			return OpeningStrike.new(trait_id, p)
	Log.error(LOG_CATEGORY, "trait '%s': unknown effect type '%s'" % [trait_id, def.type])
	return null


func invalidate() -> void:
	_capture_states()
	_dirty = true


## New combat or back to idle: no counters, the effects are rebuilt on next use.
func reset() -> void:
	_states.clear()
	_effects.clear()
	_dirty = true


func effects() -> Array[TraitEffect]:
	if _dirty:
		_rebuild()
	return _effects


## F-76 rule asked by the first trait that has one, `first` otherwise.
func target_rule() -> StringName:
	for effect: TraitEffect in effects():
		var rule: StringName = effect.target_rule()
		if rule != &"":
			return rule
	return Encounter.RULE_FIRST


func modify_stats(stats: CombatantStats) -> void:
	for effect: TraitEffect in effects():
		effect.modify_stats(stats, _session.data)


func encounter_start(ctx: EffectContext) -> void:
	for effect: TraitEffect in effects():
		effect.on_encounter_start(ctx)
	_flush(ctx)


func before_attack(ctx: EffectContext) -> void:
	for effect: TraitEffect in effects():
		effect.on_before_attack(ctx)
	_flush(ctx)


func hit(ctx: EffectContext, damage: int) -> void:
	for effect: TraitEffect in effects():
		effect.on_hit(ctx, damage)
	_flush(ctx)


func kill(ctx: EffectContext) -> void:
	for effect: TraitEffect in effects():
		effect.on_kill(ctx)
	_flush(ctx)


func damaged(ctx: EffectContext, damage: int) -> void:
	for effect: TraitEffect in effects():
		effect.on_damaged(ctx, damage)
	_flush(ctx)


## `on_low_hp`: true if some effect forbids F-30 now (that effect is reported as triggered).
func blocks_auto_eat(ctx: EffectContext) -> bool:
	var blocked: bool = false
	for effect: TraitEffect in effects():
		if effect.blocks_auto_eat(ctx):
			blocked = true
			ctx.trigger(effect.trait_id)
	_flush(ctx)
	return blocked


## `combat.effects`: {trait id: counter state}, only non-empty states.
func to_save() -> Dictionary:
	effects()  # rebuild first: normalizes the states and drops those of inactive traits
	_capture_states()
	var out: Dictionary = {}
	for trait_id: StringName in _states:
		out[String(trait_id)] = _states[trait_id].duplicate()
	return out


## Tolerant: anything that is not {id: Dictionary} is dropped; ids of inactive traits are dropped on the next rebuild.
func from_save(d: Variant) -> void:
	reset()
	if not (d is Dictionary):
		return
	for key: Variant in (d as Dictionary):
		if (d as Dictionary)[key] is Dictionary:
			_states[StringName(str(key))] = ((d as Dictionary)[key] as Dictionary).duplicate()


func _capture_states() -> void:
	if _dirty:
		return
	for effect: TraitEffect in _effects:
		var state: Dictionary = effect.to_save()
		if state.is_empty():
			_states.erase(effect.trait_id)
		else:
			_states[effect.trait_id] = state


func _rebuild() -> void:
	_effects.clear()
	var kept: Dictionary[StringName, Dictionary] = {}
	for def: TraitDef in _session.loadout.active_traits():
		for effect_def: TraitEffectDef in def.effects:
			var effect: TraitEffect = create(def.id, effect_def)
			if effect == null:
				continue
			if _states.has(def.id):
				effect.from_save(_states[def.id])
				kept[def.id] = _states[def.id]
			_effects.append(effect)
	_states = kept
	_dirty = false


func _flush(ctx: EffectContext) -> void:
	for trait_id: StringName in ctx.triggered:
		_session.events.trait_triggered.emit(trait_id)
	ctx.triggered.clear()
