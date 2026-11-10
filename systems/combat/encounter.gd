class_name Encounter
extends RefCounted
## The enemies of one encounter (docs/01_GDD.md §10.1, F-76, F-77) and the roll of one attack. No timers of the
## player and no session: `CombatEngine` owns the flow. Position = index in `enemies`; a dead enemy keeps its slot.

const RULE_FIRST: StringName = &"first"
const RULE_LOWEST_HP: StringName = &"lowest_hp"
const RULE_HIGHEST_HP: StringName = &"highest_hp"


## One enemy. `stats` is recomputed from the monster data (never saved).
class Enemy extends RefCounted:
	var def: MonsterDef
	var stats: CombatantStats
	var hp: int = 0
	var timer_ms: int = 0
	var pulse_damage: int = 0  # > 0: a Rift Stone (F-87); its "attack" is the pulse, `timer_ms` the time to the next one
	var summoned: bool = false  # M13 (F-112): called by a boss; gives no xp, gold or drops

	func _init(monster: MonsterDef, data: GameData, pulse: int = 0) -> void:
		def = monster
		pulse_damage = pulse
		stats = CombatantStats.for_monster(monster, data)
		hp = stats.max_hp
		timer_ms = stats.attack_interval_ms

	func alive() -> bool:
		return hp > 0

	func is_stone() -> bool:
		return pulse_damage > 0

var enemies: Array[Enemy] = []



## F-77: a pack drawn by weight from the area; full hp and timers equal to their own interval.
static func spawn(area: AreaDef, data: GameData, rng: RngService) -> Encounter:
	var weights: Array[int] = []
	for pack: PackDef in area.packs:
		weights.append(pack.weight)
	var result := Encounter.new()
	var picked: int = rng.pick_weighted(weights)
	if picked < 0:
		return result
	for monster_id: StringName in area.packs[picked].monster_ids:
		result.enemies.append(Enemy.new(data.monster(monster_id), data))
	return result


## Rebuilds the enemies of a save (`[{"monster", "hp", "timer_ms"}]`, `"summoned": true` for a summoned one). null if a
## monster is unknown or an entry is malformed (the caller logs and goes idle). hp is clamped to [0, max], the timer to
## [0, interval]. With a `run` (a Fracture) the monsters are scaled like its packs (F-110, F-111) and the boss of its grade
## is known.
static func from_save(entries: Array, data: GameData, run: FractureRun = null) -> Encounter:
	var result := Encounter.new()
	var stone_level: int = _saved_stone_level(entries, data) if run == null else 0  # M15: the summoned of a stone share its level
	for entry: Variant in entries:
		if not (entry is Dictionary):
			return null
		var d: Dictionary = entry
		var monster_id := StringName(str(d.get("monster", "")))
		var def: MonsterDef = _saved_def(monster_id, data, run)
		if def == null and not data.has_rift_stone(monster_id) or not (d.get("hp") is int or d.get("hp") is float):
			return null
		var enemy: Enemy = null
		if def != null:
			if stone_level > 0 and d.get("summoned") == true:
				def = StoneFight.scaled(def, stone_level)
			enemy = Enemy.new(def, data)
		else:
			enemy = RiftStone.enemy(data.rift_stone(monster_id), data)
		enemy.summoned = d.get("summoned") == true
		enemy.hp = clampi(int(d["hp"]), 0, enemy.stats.max_hp)
		enemy.timer_ms = clampi(int(d.get("timer_ms", enemy.timer_ms)), 0, enemy.stats.attack_interval_ms)
		result.enemies.append(enemy)
	return result


# The level of the Rift Stone among the saved `entries` (it keeps its slot, dead or alive), 0 if there is none.
static func _saved_stone_level(entries: Array, data: GameData) -> int:
	for entry: Variant in entries:
		if entry is Dictionary:
			var id := StringName(str((entry as Dictionary).get("monster", "")))
			if not data.has_monster(id) and data.has_rift_stone(id):
				return data.rift_stone(id).level
	return 0


# The monster (scaled inside a Fracture) or the boss of the run; null for a Rift Stone or an unknown id.
static func _saved_def(monster_id: StringName, data: GameData, run: FractureRun) -> MonsterDef:
	if run != null:
		var boss: BossDef = run.boss_def(data)
		if boss != null and boss.id == monster_id:
			return FractureScaler.scale_monster(boss, run.grade, run.effects, data)
		if data.has_monster(monster_id):
			return FractureScaler.scale_monster(data.monster(monster_id), run.grade, run.effects, data)
		return null
	return data.monster(monster_id) if data.has_monster(monster_id) else null


func to_save() -> Array:
	var out: Array = []
	for enemy: Enemy in enemies:
		var saved: Dictionary = {"monster": String(enemy.def.id), "hp": enemy.hp, "timer_ms": enemy.timer_ms}
		if enemy.summoned:
			saved["summoned"] = true
		out.append(saved)
	return out


## The enemies of a Fracture group (already scaled): full hp, timers at their own interval.
static func of_defs(defs: Array[MonsterDef], data: GameData) -> Encounter:
	var result := Encounter.new()
	for def: MonsterDef in defs:
		result.enemies.append(Enemy.new(def, data))
	return result


func monster_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for enemy: Enemy in enemies:
		ids.append(enemy.def.id)
	return ids


## Positions of the living enemies, in order.
func alive_indices() -> Array[int]:
	var result: Array[int] = []
	for i: int in enemies.size():
		if enemies[i].alive():
			result.append(i)
	return result


## True if one of the enemies is a Rift Stone (F-87).
func has_stone() -> bool:
	for enemy: Enemy in enemies:
		if enemy.is_stone():
			return true
	return false


func alive_count() -> int:
	var count: int = 0
	for enemy: Enemy in enemies:
		if enemy.alive():
			count += 1
	return count


## F-76: index of the target for `rule` among the living enemies, -1 if none. Ties go to the lowest position.
func target(rule: StringName) -> int:
	var best: int = -1
	for i: int in enemies.size():
		if not enemies[i].alive():
			continue
		if best < 0:
			best = i
		elif rule == RULE_LOWEST_HP and enemies[i].hp < enemies[best].hp:
			best = i
		elif rule == RULE_HIGHEST_HP and enemies[i].hp > enemies[best].hp:
			best = i
		if rule == RULE_FIRST:
			break
	return best


## The attack of `enemy` against `defender`: a monster rolls F-23, F-75, F-22, F-24, F-25 (`roll_attack`); a Rift Stone
## pulses (`stone_pulse`, F-125: fixed damage, no roll).
static func roll_enemy_attack(enemy: Enemy, defender: CombatantStats, rng: RngService, data: GameData) -> Dictionary:
	if enemy.is_stone():
		return stone_pulse(enemy.pulse_damage)
	return roll_attack(enemy.stats, defender, defender.block_chance, rng, data)


## F-125: the pulse of a Rift Stone: always hits, fixed `damage` that ignores Armour and Barrier (no F-25, F-117, F-118) and
## cannot be blocked (no F-75). No random draw. Same result shape as `roll_attack`.
static func stone_pulse(damage: int) -> Dictionary:
	return {"hit": true, "blocked": false, "damage": damage}


## F-111: the pulse of a Fracture never misses, is reduced by F-25 (neutral relation: the plain
## reduction; F-117: no style, so it counts as `combat.unarmed.style`, i.e. Armour) and can be blocked (F-75, the only
## roll). `attacker_level` is the L_att of F-117 (-1 = the level of the defender). Same result shape as `roll_attack`.
static func roll_pulse(damage: int, defender: CombatantStats, block_chance: float, rng: RngService, data: GameData,
		attacker_level: int = -1) -> Dictionary:
	var result: Dictionary = {"hit": true, "blocked": false, "damage": 0}
	if block_chance > 0.0 and rng.roll_pct(block_chance):
		result["blocked"] = true
		return result
	var style: StringName = StringName(str(data.balance_value("combat.unarmed.style")))
	var level: int = defender.level if attacker_level < 0 else attacker_level
	result["damage"] = CombatMath.damage_after_dr(damage, defender.reduction_against(style, level, data))
	return result


## docs/05_INTERFACES.md §5.10, "Ordine dei tiri di un attacco": hit (F-23), block only if `block_chance` > 0
## (F-75), damage in [min_hit, max_hit] (F-22), then triangle and reduction without rolls (F-24, F-25).
## Returns {"hit", "blocked", "damage"}; a miss or a block does 0 damage and consumes no later roll.
## `damage_mult` (F-81 `low_hp_damage_mult`) multiplies the damage after the triangle, floored, before the reduction.
## `dr_mult` (F-120 `armor_pierce_pct`) multiplies the reduction of the defender (F-25, after the triangle).
static func roll_attack(attacker: CombatantStats, defender: CombatantStats, block_chance: float,
		rng: RngService, data: GameData, damage_mult: float = 1.0, dr_mult: float = 1.0) -> Dictionary:
	var result: Dictionary = {"hit": false, "blocked": false, "damage": 0}
	if rng.randf() >= CombatMath.hit_chance(attacker.accuracy, defender.evasion, data):
		return result
	result["hit"] = true
	if block_chance > 0.0 and rng.roll_pct(block_chance):
		result["blocked"] = true
		return result
	var raw: int = rng.randi_range(attacker.min_hit, attacker.max_hit)
	var relation: StringName = CombatMath.triangle(attacker.style, defender.style, data)
	var base_dr: float = defender.reduction_against(attacker.style, attacker.level, data)
	var dr: float = CombatMath.effective_dr(base_dr, relation, data) * dr_mult
	var damage: int = CombatMath.triangle_damage(raw, relation, data)
	if damage_mult != 1.0:
		damage = int(floor(float(damage) * damage_mult + CombatMath.EPSILON))
	result["damage"] = CombatMath.damage_after_dr(damage, dr)
	return result
