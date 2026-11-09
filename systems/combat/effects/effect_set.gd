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


## The effect of a trait entry, null (logged) for an unknown type. A new type is one line in `create_typed`.
static func create(trait_id: StringName, def: TraitEffectDef) -> TraitEffect:
	return create_typed(trait_id, def.type, def.params)


## The effect `type` with `p` (a trait effect or, M14, an effect of a legendary; `owner` is the trait id or the source
## `equipment:<slot>`).
static func create_typed(trait_id: StringName, type: StringName, p: Dictionary) -> TraitEffect:
	match type:
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
		&"block_heal_pct":
			return BlockHealPct.new(trait_id, p)
		&"kill_heal_pct":
			return KillHealPct.new(trait_id, p)
		&"armor_pierce_pct":
			return ArmorPiercePct.new(trait_id, p)
		&"hit_cap_pct":
			return HitCapPct.new(trait_id, p)
		&"stat_convert":
			return StatConvert.new(trait_id, p)
		&"double_hit_pct":
			return DoubleHitPct.new(trait_id, p)
		&"execute_mult":
			return ExecuteMult.new(trait_id, p)
		&"monolith_loot_mult":
			return MonolithLootMult.new(trait_id, p)
		&"card_drop_mult":
			return CardDropMult.new(trait_id, p)
		&"gather_bonus_item":
			return GatherBonusItem.new(trait_id, p)
		&"gather_grade_up_pct":
			return GatherGradeUpPct.new(trait_id, p)
		&"byproduct_mult":
			return ByproductMult.new(trait_id, p)
	Log.error(LOG_CATEGORY, "'%s': unknown effect type '%s'" % [trait_id, type])
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


## F-120 `on_block`.
func block(ctx: EffectContext) -> void:
	for effect: TraitEffect in effects():
		effect.on_block(ctx)
	_flush(ctx)


## F-120 `on_monolith`.
func monolith(ctx: EffectContext) -> void:
	for effect: TraitEffect in effects():
		effect.on_monolith(ctx)
	_flush(ctx)


## F-120 `hit_cap_pct`: the damage the player takes after the caps.
func damage_taken(ctx: EffectContext, damage: int) -> int:
	for effect: TraitEffect in effects():
		damage = effect.cap_damage(ctx, damage)
	_flush(ctx)
	return damage


## F-120 `execute_mult`: the product of the factors of the effects against a target with these hp.
func damage_mult_against(ctx: EffectContext, target_hp: int, target_max_hp: int) -> float:
	var mult: float = 1.0
	for effect: TraitEffect in effects():
		mult *= effect.damage_mult_against(ctx, target_hp, target_max_hp)
	_flush(ctx)
	return mult


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
	for item_effect: ItemEffectDef in _session.equipment.item_effects():  # M14: the legendaries worn (F-120)
		var worn_effect: TraitEffect = create_typed(item_effect.source, item_effect.type, item_effect.params)
		if worn_effect != null:
			_effects.append(worn_effect)
	_states = kept
	_dirty = false


func _flush(ctx: EffectContext) -> void:
	for trait_id: StringName in ctx.triggered:
		_session.events.trait_triggered.emit(trait_id)
	ctx.triggered.clear()
