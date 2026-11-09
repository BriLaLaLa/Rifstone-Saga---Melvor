class_name LegendaryKit
extends RefCounted
## Test helpers for the legendary effects (M14-04, F-120): a session on the M14 content (main fixtures + one legendary per
## effect type, tests/helpers/m14_data.gd), wearing a legendary, and the replay of the first base attack of the player.

const M14Data := preload("res://tests/helpers/m14_data.gd")


## A new session on the M14 content (the starting kit is cleared, as on the other fixtures).
static func session(seed_value: int = 7) -> GameSession:
	return TestFactory.session(seed_value, M14Data.data())


## Creates the piece `base_id` (a legendary: its rarity is imposed) and wears it; returns its uid.
static func wear(s: GameSession, base_id: StringName, slot: StringName = &"") -> int:
	var uid: int = TestFactory.give_piece(s, base_id)
	var result: CommandResult = s.equipment.equip(uid, slot)
	assert(result.ok, "LegendaryKit: equip %s failed: %s" % [base_id, result.reason])
	return uid


## A player that kills fast, survives, and has room: +5000 power, +100000 hp.
static func hero(s: GameSession) -> void:
	s.modifiers.set_source(&"test:hero", [Modifier.make(&"power_bonus", 5000.0), Modifier.make(&"max_hp_flat", 100000.0)])


## A player that survives (+100000 hp) without extra power.
static func sturdy(s: GameSession) -> void:
	s.modifiers.set_source(&"test:sturdy", [Modifier.make(&"max_hp_flat", 100000.0)])


## Records the hits of the player (`[target, hit, damage]`) and of the enemies (`[source, hit, damage, blocked]`).
class HitLog extends RefCounted:
	var player: Array[Array] = []
	var enemies: Array[Array] = []

	func _init(events: GameEvents) -> void:
		events.combat_hit.connect(_on_hit)

	func _on_hit(attacker: int, target: int, hit: bool, damage: int, blocked: bool) -> void:
		if attacker == CombatEngine.PLAYER:
			player.append([target, hit, damage])
		else:
			enemies.append([attacker, hit, damage, blocked])


## What the first base attack of the player does against `monster_id` with a fresh `RngService(seed)` (the session rng at the
## start of a fight): `{"hit": bool, "damage": int}` with the damage multiplier `mult` (after F-24) and the factor `dr_mult`
## on the reduction (F-25). The same draws as `Encounter.roll_attack`: hit, then the roll in [min_hit, max_hit].
static func replay_first_attack(s: GameSession, seed_value: int, monster_id: StringName, mult: float = 1.0,
		dr_mult: float = 1.0) -> Dictionary:
	var rng := RngService.new(seed_value)
	var me: CombatantStats = s.combat.player_stats()
	var foe: CombatantStats = CombatantStats.for_monster(s.data.monster(monster_id), s.data)
	var result: Dictionary = {"hit": false, "damage": 0}
	if rng.randf() >= CombatMath.hit_chance(me.accuracy, foe.evasion, s.data):
		return result
	result["hit"] = true
	var raw: int = rng.randi_range(me.min_hit, me.max_hit)
	var relation: StringName = CombatMath.triangle(me.style, foe.style, s.data)
	var dr: float = CombatMath.effective_dr(foe.reduction_against(me.style, me.level, s.data), relation, s.data) * dr_mult
	var damage: int = CombatMath.triangle_damage(raw, relation, s.data)
	if mult != 1.0:
		damage = int(floor(float(damage) * mult + CombatMath.EPSILON))
	result["damage"] = CombatMath.damage_after_dr(damage, dr)
	return result
