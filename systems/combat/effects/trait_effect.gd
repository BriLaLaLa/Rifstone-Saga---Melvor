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


## F-120 `on_block`: the player blocked an attack (F-75): may set `heal`.
func on_block(_ctx: EffectContext) -> void:
	pass


## F-120 `on_monolith`: a Rift Monolith was killed: may multiply `loot_mult`.
func on_monolith(_ctx: EffectContext) -> void:
	pass


## F-120 `on_gather`: a gathering cycle of the player succeeded: fills the outputs of `ctx`.
func on_gather(_ctx: GatherContext) -> void:
	pass


## F-120 `on_damaged` before the damage is taken: the damage the player really takes (`damage` > 0, after F-25).
func cap_damage(_ctx: EffectContext, damage: int) -> int:
	return damage


## F-120 `on_before_attack` for one target: the factor of the damage of the base attack against a target with these hp.
func damage_mult_against(_ctx: EffectContext, _target_hp: int, _target_max_hp: int) -> float:
	return 1.0


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


# --- M28 (docs/05_INTERFACES_M28.md §5.10c): the hooks of the conditions and of the new types, all neutral here ---------------------

## F-192 `on_evade`: an enemy attack missed the player (F-23); never for a pulse or a Monolith.
func on_evade(_ctx: EffectContext) -> void:
	pass


## F-192 `on_ability`: the player used an ability (`ctx.ability_kind`), after its hits and its heal or Ward.
func on_ability(_ctx: EffectContext) -> void:
	pass


## F-190: this effect's factor of `M` for a hit of the player (`ctx.hit_kind`, `ctx.target_*`, `ctx.alive_count`).
func hit_mult(_ctx: EffectContext) -> float:
	return 1.0


## F-193: the factor of the damage the player takes (`damage_trade`).
func incoming_mult(_ctx: EffectContext) -> float:
	return 1.0


## F-191, F-192 `ability_mult`: the factor of the amount of a heal or a Ward of an ability (`ctx.ability_kind`).
func amount_mult(_ctx: EffectContext) -> float:
	return 1.0


## F-192 `stack_haste`: the factor of the timer of the next base attack.
func base_timer_mult(_ctx: EffectContext) -> float:
	return 1.0


## True for the types that keep a state in `to_save` (at most one effect per trait).
func has_state() -> bool:
	return false
