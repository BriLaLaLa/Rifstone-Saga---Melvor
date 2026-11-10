class_name StoneFight
extends RefCounted
## The Rift Stone as a wave encounter (M15, docs/02_FORMULAS.md §5f, docs/01_GDD.md §24b). Pure functions: the hp of a stone
## (F-125), its fixed pulse, the thresholds that fire a wave (F-126) and the monsters of a wave. The state of the fight
## (the thresholds already fired) lives in `RiftStone`, the flow in `CombatFight`. Every number from `balance.json` (`metin.*`).

const FIRST_HIT: int = 100  # the "threshold" of the first hit received (docs/05_INTERFACES.md §5.25)
const MAX_LEVEL: int = 99


## F-125: `round(metin.hp_base x (1 + metin.hp_per_level x L))`, at least 1.
static func max_hp(level: int, data: GameData) -> int:
	var base: float = float(data.balance_value("metin.hp_base"))
	var per_level: float = float(data.balance_value("metin.hp_per_level"))
	return maxi(1, int(round(base * (1.0 + per_level * float(level)))))


## F-125: the fixed damage of the pulse (it ignores Armour and Barrier and cannot be blocked).
static func pulse_damage(data: GameData) -> int:
	return int(data.balance_value("metin.pulse_damage"))


## F-126: the thresholds in order (`FIRST_HIT`, then `metin.wave_thresholds`, strictly decreasing).
static func thresholds(data: GameData) -> Array[int]:
	var result: Array[int] = [FIRST_HIT]
	for value: Variant in (data.balance_value("metin.wave_thresholds") as Array):
		result.append(int(round(float(value))))
	return result


## F-126: the thresholds of `thresholds` (descending) that a hit leaving `hp_after` of `hp_max` fires and that are not in
## `fired` yet: `hp_after x 100 < s x hp_max` (strict; the first hit, 100, fires at any damage). A hit that crosses two
## fires both, in descending order.
static func waves_crossed(hp_after: int, hp_max: int, fired: Array[int], thresholds_list: Array[int]) -> Array[int]:
	var result: Array[int] = []
	for s: int in thresholds_list:
		if not fired.has(s) and hp_after * 100 < s * hp_max:
			result.append(s)
	return result


## F-126: the monsters of one wave: packs drawn by weight (F-77) among `def.wave_packs` (empty = every pack of the area)
## until `metin.wave_size` is reached, the last pack truncated. Levels (attack, power, defence) become `min(99, L)`.
static func wave_defs(def: RiftStoneDef, data: GameData, rng: RngService) -> Array[MonsterDef]:
	var area: AreaDef = data.area(def.area_id)
	var candidates: Array[int] = def.wave_packs.duplicate()
	if candidates.is_empty():
		for i: int in area.packs.size():
			candidates.append(i)
	var result: Array[MonsterDef] = []
	if candidates.is_empty():
		return result
	var weights: Array[int] = []
	for index: int in candidates:
		weights.append(area.packs[index].weight)
	var size: int = int(data.balance_value("metin.wave_size"))
	while result.size() < size:
		var picked: int = rng.pick_weighted(weights)
		if picked < 0:
			break
		for monster_id: StringName in area.packs[candidates[picked]].monster_ids:
			if result.size() < size:
				result.append(scaled(data.monster(monster_id), def.level))
	return result


## A copy of `monster` with the three combat levels at `min(99, level)` (hp, damage and rewards unchanged, Q79).
static func scaled(monster: MonsterDef, level: int) -> MonsterDef:
	var copy: ScaledMonsterDef = ScaledMonsterDef.copy_of(monster)
	var capped: int = mini(MAX_LEVEL, level)
	copy.attack_level = capped
	copy.power_level = capped
	copy.defence_level = capped
	return copy
