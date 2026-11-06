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

	func _init(monster: MonsterDef, data: GameData) -> void:
		def = monster
		stats = CombatantStats.for_monster(monster, data)
		hp = stats.max_hp
		timer_ms = stats.attack_interval_ms

	func alive() -> bool:
		return hp > 0

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


## Rebuilds the enemies of a save (`[{"monster", "hp", "timer_ms"}]`). null if a monster is unknown or an entry
## is malformed (the caller logs and goes idle). hp is clamped to [0, max], the timer to [0, interval].
static func from_save(entries: Array, data: GameData) -> Encounter:
	var result := Encounter.new()
	for entry: Variant in entries:
		if not (entry is Dictionary):
			return null
		var d: Dictionary = entry
		var monster_id := StringName(str(d.get("monster", "")))
		if not data.has_monster(monster_id) or not (d.get("hp") is int or d.get("hp") is float):
			return null
		var monster: MonsterDef = data.monster(monster_id)
		var enemy := Enemy.new(monster, data)
		enemy.hp = clampi(int(d["hp"]), 0, enemy.stats.max_hp)
		enemy.timer_ms = clampi(int(d.get("timer_ms", enemy.timer_ms)), 0, enemy.stats.attack_interval_ms)
		result.enemies.append(enemy)
	return result


func to_save() -> Array:
	var out: Array = []
	for enemy: Enemy in enemies:
		out.append({"monster": String(enemy.def.id), "hp": enemy.hp, "timer_ms": enemy.timer_ms})
	return out


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


## docs/05_INTERFACES.md §5.10, "Ordine dei tiri di un attacco": hit (F-23), block only if `block_chance` > 0
## (F-75), damage in [min_hit, max_hit] (F-22), then triangle and reduction without rolls (F-24, F-25).
## Returns {"hit", "blocked", "damage"}; a miss or a block does 0 damage and consumes no later roll.
## `damage_mult` (F-81 `low_hp_damage_mult`) multiplies the damage after the triangle, floored, before the reduction.
static func roll_attack(attacker: CombatantStats, defender: CombatantStats, block_chance: float,
		rng: RngService, data: GameData, damage_mult: float = 1.0) -> Dictionary:
	var result: Dictionary = {"hit": false, "blocked": false, "damage": 0}
	if rng.randf() >= CombatMath.hit_chance(attacker.accuracy, defender.evasion, data):
		return result
	result["hit"] = true
	if block_chance > 0.0 and rng.roll_pct(block_chance):
		result["blocked"] = true
		return result
	var raw: int = rng.randi_range(attacker.min_hit, attacker.max_hit)
	var relation: StringName = CombatMath.triangle(attacker.style, defender.style, data)
	var dr: float = CombatMath.effective_dr(defender.damage_reduction, relation, data)
	var damage: int = CombatMath.triangle_damage(raw, relation, data)
	if damage_mult != 1.0:
		damage = int(floor(float(damage) * damage_mult + CombatMath.EPSILON))
	result["damage"] = CombatMath.damage_after_dr(damage, dr)
	return result
