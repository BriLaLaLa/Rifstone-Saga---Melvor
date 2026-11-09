class_name ArmorMath
extends RefCounted
## Pure armour formulas: F-117 (Armour and Barrier reduction) and F-118 (set budget and piece values, docs/02_FORMULAS.md
## §5e and §8.4). Every parameter comes from balance.json (`combat.armor.*`, `equipment.*`) through GameData.


## F-117: min(cap_pct, 100 x X / (X + k x (L_att + level_offset))); 0 for X <= 0. `x` is the floored Armour or Barrier
## total, `attacker_level` the `power_level` of the attacking monster.
static func reduction_pct(x: int, attacker_level: int, data: GameData) -> float:
	if x <= 0:
		return 0.0
	var k: float = float(data.balance_value("combat.armor.k"))
	var offset: float = float(data.balance_value("combat.armor.level_offset"))
	var cap: float = float(data.balance_value("combat.armor.cap_pct"))
	var raw: float = 100.0 * float(x) / (float(x) + k * (float(attacker_level) + offset))
	return minf(cap, raw)


## F-118: `A_set(g) = armor_base + armor_per_level x lvl(g)` and `E_set(g) = round(evasion_base + evasion_per_level x
## lvl(g))`; `lvl(g)` is `equipment.grade_levels[g - 1]`. Returns {"armor": int, "evasion": int}.
static func set_budget(piece_grade: int, data: GameData) -> Dictionary:
	var budget: Dictionary = data.balance_value("equipment.set_budget") as Dictionary
	var level: float = float(data.grade_level(piece_grade))
	var armor: Array = budget["armor"] as Array
	var evasion: Array = budget["evasion"] as Array
	return {
		"armor": roundi(float(armor[0]) + float(armor[1]) * level),
		"evasion": roundi(float(evasion[0]) + float(evasion[1]) * level),
	}


## F-118: the base values of an armour piece or shield: {"armor", "barrier", "evasion"} = round(budget x slot weight x
## material multiplier). `slot` is the weight key (`body`, `legs`, `head`, `offhand`, `hands`, `feet`).
static func piece_values(slot: StringName, material: StringName, piece_grade: int, data: GameData) -> Dictionary:
	var budget: Dictionary = set_budget(piece_grade, data)
	var weights: Dictionary = data.balance_value("equipment.slot_weights") as Dictionary
	var materials: Dictionary = data.balance_value("combat.armor.materials") as Dictionary
	var weight: float = float(weights.get(String(slot), 0.0))
	var mult: Dictionary = materials.get(String(material), {}) as Dictionary
	return {
		"armor": roundi(float(budget["armor"]) * weight * float(mult.get("armor", 0.0))),
		"barrier": roundi(float(budget["armor"]) * weight * float(mult.get("barrier", 0.0))),
		"evasion": roundi(float(budget["evasion"]) * weight * float(mult.get("evasion", 0.0))),
	}
