class_name BossAbility
extends RefCounted
## The three abilities of a Fracture boss (docs/02_FORMULAS.md F-112): the numbers, no state. `FractureCombat` keeps the
## timers and the shield; `CombatFight` calls it right after the base attack of the boss (F-76).

const EPSILON: float = 1e-9


## `heavy_strike`: no accuracy roll; the only roll is the block (F-75). Damage `floor(max_hit x mult)`, then F-25 with the
## relation of the boss (no F-24 multiplier). Same result shape as `Encounter.roll_attack`.
static func heavy_strike(boss: CombatantStats, defender: CombatantStats, ability: BossAbilityDef, rng: RngService,
		data: GameData) -> Dictionary:
	var result: Dictionary = {"hit": true, "blocked": false, "damage": 0}
	if defender.block_chance > 0.0 and rng.roll_pct(defender.block_chance):
		result["blocked"] = true
		return result
	var raw: int = floori(float(boss.max_hit) * ability.mult + EPSILON)
	var relation: StringName = CombatMath.triangle(boss.style, defender.style, data)
	var base_dr: float = defender.reduction_against(boss.style, boss.level, data)
	result["damage"] = CombatMath.damage_after_dr(raw, CombatMath.effective_dr(base_dr, relation, data))
	return result


## `shield`: `floor(max hp x shield_pct / 100)`.
static func shield_amount(max_hp: int, ability: BossAbilityDef) -> int:
	return floori(float(max_hp) * float(ability.shield_pct) / 100.0 + EPSILON)


## `summon`: the monsters to call now (scaled like the monsters of the grade, F-110/F-111), in the order of
## `ability.monsters` repeated from the first at every use. `alive` = summoned enemies alive, `used` = slots in use
## (living enemies); at most `max_alive` summoned and `max_pack` enemies in all.
static func summon_defs(ability: BossAbilityDef, alive: int, used: int, max_pack: int, grade: int,
		effects: Array[Dictionary], data: GameData) -> Array[MonsterDef]:
	var result: Array[MonsterDef] = []
	var room: int = mini(mini(ability.count, ability.max_alive - alive), max_pack - used)
	for i: int in maxi(0, room):
		var id: StringName = ability.monsters[i % ability.monsters.size()]
		result.append(FractureScaler.scale_monster(data.monster(id), grade, effects, data))
	return result
