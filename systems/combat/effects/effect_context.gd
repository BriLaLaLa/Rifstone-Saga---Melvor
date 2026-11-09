class_name EffectContext
extends RefCounted
## What the engine hands to a trait effect at a hook (docs/01_GDD.md §20.3) and reads back afterwards. The engine fills
## the inputs before the call; the effect changes only the outputs. Effects never touch the engine or the session.

# Inputs.
var player_hp: int = 0
var player_max_hp: int = 0

# Input and output: the base-attack timer in ms (`opening_strike`, `on_kill_timer_cut`).
var player_timer_ms: int = 0

# Outputs of `on_before_attack`: hit every living enemy; product of the damage multipliers.
var attack_all: bool = false
var damage_mult: float = 1.0

# Outputs of `on_hit` (hp to restore) and `on_damaged` (damage returned to the attacker).
var heal: int = 0
var reflect_damage: int = 0

# M14 (F-120). Inputs: the random source (`double_hit_pct`) and whether the hook belongs to the base attack.
var rng: RngService = null
var base_attack: bool = false
# Outputs: `armor_pierce_pct` (product of the factors on the reduction of the target), `double_hit_pct` (a second base hit),
# `monolith_loot_mult` (on_monolith) and `card_drop_mult` (on_kill): products of the multipliers.
var dr_mult: float = 1.0
var extra_hit: bool = false
var loot_mult: float = 1.0
var card_mult: float = 1.0

# Trait ids whose effect fired during the hook: the engine emits `trait_triggered` for each.
var triggered: Array[StringName] = []


func trigger(trait_id: StringName) -> void:
	if not triggered.has(trait_id):
		triggered.append(trait_id)
