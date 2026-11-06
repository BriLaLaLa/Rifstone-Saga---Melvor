class_name TraitEffect
extends RefCounted
## Base class of the trait effect types (F-81, docs/01_GDD.md §20.3): one subclass per type, each reacting to one or
## more hooks with the parameters of the data. Every hook is a no-op here. A new type = a new subclass, a line
## in `EffectSet.create` and its test; a new trait = data only.
## Effects hold at most a small counter (`to_save`/`from_save`); stats are always recomputed.

var trait_id: StringName = &""
var params: Dictionary = {}


func _init(owner_trait: StringName = &"", effect_params: Dictionary = {}) -> void:
	trait_id = owner_trait
	params = effect_params


## A new encounter begins (after the pack is drawn and the base timer is set).
func on_encounter_start(_ctx: EffectContext) -> void:
	pass


## Before the player's base attack: may set `attack_all` and multiply `damage_mult`.
func on_before_attack(_ctx: EffectContext) -> void:
	pass


## The player's attack did `damage` (> 0) to an enemy: may set `heal`.
func on_hit(_ctx: EffectContext, _damage: int) -> void:
	pass


## An enemy died: may change `player_timer_ms`.
func on_kill(_ctx: EffectContext) -> void:
	pass


## An enemy hurt the player for `damage` (> 0) and the player is alive: may set `reflect_damage`.
func on_damaged(_ctx: EffectContext, _damage: int) -> void:
	pass


## `on_low_hp`: true if the player is in a state where F-30 (auto-eat) must not run.
func blocks_auto_eat(_ctx: EffectContext) -> bool:
	return false


## `choose_target`: the F-76 rule this effect asks for, &"" for none.
func target_rule() -> StringName:
	return &""


## `modify_stats`: changes the player's stats after the calculation (limits of stats.json included).
func modify_stats(_stats: CombatantStats, _data: GameData) -> void:
	pass


## Counter state for the save (`combat.effects.<trait_id>`); empty = nothing to save.
func to_save() -> Dictionary:
	return {}


func from_save(_d: Dictionary) -> void:
	pass
