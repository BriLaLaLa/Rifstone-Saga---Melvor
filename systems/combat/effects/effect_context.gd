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

# M28 (docs/05_INTERFACES_M28.md §5.10c). Inputs: the kinds of hit of the player (F-190), the target of the hit and the source of an
# incoming attack. Every field is filled by the engine only where the hook needs it; the defaults mean "not known here".
const HIT_BASE: StringName = &"base"
const HIT_ABILITY: StringName = &"ability"
const HIT_COUNTER: StringName = &"counter"
const HIT_EXTRA: StringName = &"extra"  # the second hit of `double_hit_pct` (F-120): none of the M28 rules applies to it

var target_index: int = -1  # the enemy hit (hit_mult, on_hit, on_kill)
var primary_index: int = -1  # the main target of a base attack (the others of `every_nth_attack_all` do not count)
var target_hp: int = 0
var target_max_hp: int = 0
var target_conditions: EnemyConditions = null
var alive_count: int = 0  # the living enemies when the hit is rolled
var source_index: int = -1  # the enemy that attacked (on_block, on_evade, on_damaged); -1 = none (the pulse of a Fracture)
var hit_kind: StringName = &""
var ability_kind: StringName = &""  # the kind of the ability (on_ability, ability_mult)
var damage: int = 0  # the D of the hit (on_hit)

# Outputs (M28): the strongest counter-attack (`riposte`), the strongest Ward (`ward_on`), the cut of the cooldowns (`kill_cooldown_cut`,
# a sum), the conditions to apply to the target (`apply_on_hit`) and the factor of the next base timer (`stack_haste`, a product).
var counter_mult: float = 0.0
var ward_pct: float = 0.0
var ward_ms: int = 0
var cooldown_cut_ms: int = 0
var applies: Array[ConditionApply] = []
var timer_mult: float = 1.0
