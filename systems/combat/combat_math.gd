class_name CombatMath
extends RefCounted
## Pure combat formulas F-20..F-27, F-73, F-75 (docs/02_FORMULAS.md section 5). Every parameter comes from
## balance.json (`combat.*`) through GameData; the stat limit of block_chance comes from stats.json.
## Player and monsters use the same functions (decisions D3, D5).

const ADVANTAGE: StringName = &"advantage"
const NEUTRAL: StringName = &"neutral"
const DISADVANTAGE: StringName = &"disadvantage"
## Absorbs binary float noise (e.g. 32.99999999999999 for an exact 33) before a floor.
const EPSILON: float = 1e-9


## F-20: AR = floor((L + acc_level_offset) x (accuracy_bonus + acc_bonus_offset) x (1 + accuracy_pct / 100)).
static func accuracy_rating(level: int, bonus: float, pct: float, data: GameData) -> int:
	return _rating(level, bonus, pct, data)


## F-21: same shape as F-20 with the evasion values.
static func evasion_rating(level: int, bonus: float, pct: float, data: GameData) -> int:
	return _rating(level, bonus, pct, data)


## F-22: max_hit = floor((L + maxhit_level_offset) x (W_max + power_bonus + maxhit_bonus_offset) / maxhit_bonus_offset x (1 + power_pct / 100)).
## `bonus` is `W_max + power_bonus` for the player (W_max = dmg_max of the striking weapon, 0 without one), the data
## `power_bonus` for monsters.
static func max_hit(level: int, bonus: float, pct: float, data: GameData) -> int:
	var level_offset: float = _num(data, "combat.maxhit_level_offset")
	var bonus_offset: float = _num(data, "combat.maxhit_bonus_offset")
	var raw: float = (float(level) + level_offset) * (bonus + bonus_offset) / bonus_offset * (1.0 + pct / 100.0)
	return int(floor(raw + EPSILON))


## F-22: min_hit = max(1, floor(max_hit x min_hit_ratio)).
static func min_hit(max_hit: int, data: GameData) -> int:
	return maxi(1, int(floor(float(max_hit) * _num(data, "combat.min_hit_ratio") + EPSILON)))


## F-22: with a weapon the ratio is the one of its own range: max(1, floor(max_hit x dmg_min / dmg_max)); without one
## (`weapon_max` <= 0) and for monsters it is `min_hit_ratio`.
static func min_hit_for(max_hit: int, weapon_min: float, weapon_max: float, data: GameData) -> int:
	if weapon_max <= 0.0:
		return min_hit(max_hit, data)
	return maxi(1, int(floor(float(max_hit) * weapon_min / weapon_max + EPSILON)))


## F-23: clamp(AR / (AR + ER), hit_chance_min, hit_chance_max).
static func hit_chance(accuracy: int, evasion: int, data: GameData) -> float:
	var total: int = accuracy + evasion
	var raw: float = 1.0 if total <= 0 else float(accuracy) / float(total)
	return clampf(raw, _num(data, "combat.hit_chance_min"), _num(data, "combat.hit_chance_max"))


## F-129: the hit chance as a whole percent for the UI: floor(100 x hit + 0.5). The roll uses the unrounded F-23 value.
static func hit_pct(accuracy: int, evasion: int, data: GameData) -> int:
	return int(floor(100.0 * hit_chance(accuracy, evasion, data) + 0.5 + EPSILON))


## F-130: xp multiplier of the level difference `diff` = monster level - character level (`combat.xp_level`): 0 at
## `-zero_gap` or lower, linear below 0, then 1 + diff x up_per_level capped at up_cap.
static func xp_level_mult(diff: int, data: GameData) -> float:
	var zero_gap: float = _num(data, "combat.xp_level.zero_gap")
	if float(diff) <= -zero_gap:
		return 0.0
	if diff < 0:
		return 1.0 - float(-diff) / zero_gap
	return minf(1.0 + float(diff) * _num(data, "combat.xp_level.up_per_level"), _num(data, "combat.xp_level.up_cap"))


## F-130: base xp of a monster of level `level`: round(base x growth^(level - 1)).
static func monster_xp(level: int, data: GameData) -> int:
	return int(round(_num(data, "combat.monster_xp.base") * pow(_num(data, "combat.monster_xp.growth"), float(level - 1))))


## F-24: relation from the attacker point of view (`combat.triangle.beats`: key beats value).
static func triangle(attacker_style: StringName, defender_style: StringName, data: GameData) -> StringName:
	var beats: Dictionary = data.balance_value("combat.triangle.beats") as Dictionary
	if str(beats.get(str(attacker_style), "")) == str(defender_style):
		return ADVANTAGE
	if str(beats.get(str(defender_style), "")) == str(attacker_style):
		return DISADVANTAGE
	return NEUTRAL


## F-24: damage x advantage/disadvantage multiplier, truncated before the reduction.
static func triangle_damage(damage: int, relation: StringName, data: GameData) -> int:
	if relation == ADVANTAGE:
		return int(floor(float(damage) * _num(data, "combat.triangle.advantage_damage_mult") + EPSILON))
	if relation == DISADVANTAGE:
		return int(floor(float(damage) * _num(data, "combat.triangle.disadvantage_damage_mult") + EPSILON))
	return damage


## F-25: the defender reduction (already limited 0..80 by the stat) x defender_dr_mult when the attacker has advantage.
## `relation` is the attacker relation (the defender is at a disadvantage when it is ADVANTAGE).
static func effective_dr(defender_dr: float, relation: StringName, data: GameData) -> float:
	if relation == ADVANTAGE:
		return defender_dr * _num(data, "combat.triangle.defender_dr_mult")
	return defender_dr


## F-25: max(1, floor(damage x (1 - dr_eff / 100))).
static func damage_after_dr(damage: int, dr_eff: float) -> int:
	return maxi(1, int(floor(float(damage) * (1.0 - dr_eff / 100.0) + EPSILON)))


## F-26: max(min_attack_interval_ms, round(base_ms x (1 + pct / 100))).
static func attack_interval_ms(base_ms: int, pct: float, data: GameData) -> int:
	var scaled: int = int(round(float(base_ms) * (1.0 + pct / 100.0)))
	return maxi(int(_num(data, "combat.min_attack_interval_ms")), scaled)


## F-73: round((weapon_ms + offhand_ms) / 2 x dual_wield.interval_mult), before F-26.
static func dual_wield_base_ms(weapon_ms: int, offhand_ms: int, data: GameData) -> int:
	return int(round(float(weapon_ms + offhand_ms) / 2.0 * _num(data, "combat.dual_wield.interval_mult")))


## F-27: hp_base + hp_per_level x L_char + floor(max_hp_flat).
static func max_hp(character_level: int, flat: float, data: GameData) -> int:
	var base: int = int(_num(data, "combat.hp_base"))
	var per_level: int = int(_num(data, "combat.hp_per_level"))
	return base + per_level * character_level + int(floor(flat + EPSILON))


## F-75: the total block chance limited by the stat range in stats.json.
static func block_chance(total: float, data: GameData) -> float:
	return data.stats.clamp_total(&"block_chance", total)


static func _rating(level: int, bonus: float, pct: float, data: GameData) -> int:
	var level_offset: float = _num(data, "combat.acc_level_offset")
	var bonus_offset: float = _num(data, "combat.acc_bonus_offset")
	var raw: float = (float(level) + level_offset) * (bonus + bonus_offset) * (1.0 + pct / 100.0)
	return int(floor(raw + EPSILON))


static func _num(data: GameData, path: String) -> float:
	return float(data.balance_value(path))
