class_name FractureScaler
extends RefCounted
## Scale of a Fracture (docs/02_FORMULAS.md F-110 grade table, F-111 risks). Pure logic, no state.

const EPSILON: float = 1e-9
const RISK_HP: StringName = &"monster_hp_pct"
const RISK_DAMAGE: StringName = &"monster_damage_pct"
const RISK_SPEED: StringName = &"monster_speed_pct"
const RISK_DEFENCE: StringName = &"monster_defence_pct"
const RISK_PACK: StringName = &"pack_bonus"
const RISK_FOOD: StringName = &"food_heal_pct"
const RISK_PULSE: StringName = &"pulse"
const REWARD_QTY: StringName = &"loot_qty_pct"
const REWARD_RARITY: StringName = &"item_rarity_pct"
const REWARD_XP: StringName = &"xp_pct"
const REWARD_GOLD: StringName = &"gold_drop_pct"
const REWARD_BLUEPRINT: StringName = &"blueprint_pct"
const REWARD_DUST: StringName = &"dust_pct"
const REWARD_CARD: StringName = &"card_chance_pct"
const MAX_LEVEL: int = 99


## F-110 then F-111 (the risks); a copy, the data monster does not change. A boss (`BossDef`) takes only the risks: its hp,
## levels, xp and gold are already the values of the data (F-115).
static func scale_monster(def: MonsterDef, grade: int, effects: Array[Dictionary], data: GameData) -> MonsterDef:
	var scaled: ScaledMonsterDef = ScaledMonsterDef.copy_of(def)
	scaled.is_boss = def is BossDef
	if not scaled.is_boss:
		var row: FractureGradeDef = data.fracture_grade(grade)
		scaled.attack_level = mini(MAX_LEVEL, def.attack_level + row.level_bonus)
		scaled.power_level = mini(MAX_LEVEL, def.power_level + row.level_bonus)
		scaled.defence_level = mini(MAX_LEVEL, def.defence_level + row.level_bonus)
		scaled.hp = int(round(float(def.hp) * row.hp_mult))
		scaled.xp = int(round(float(def.xp) * row.reward_mult))
		scaled.gold_min = int(round(float(def.gold_min) * row.reward_mult))
		scaled.gold_max = int(round(float(def.gold_max) * row.reward_mult))
		scaled.damage_mult = row.damage_mult
	scaled.hp = int(round(float(scaled.hp) * (1.0 + total(effects, RISK_HP) / 100.0)))
	scaled.risk_damage_pct = total(effects, RISK_DAMAGE)
	scaled.risk_speed_pct = total(effects, RISK_SPEED)
	scaled.risk_defence_pct = total(effects, RISK_DEFENCE)
	return scaled


## The sum of the values (risk or reward, whichever has that type) of the `effects` of a Card.
static func total(effects: Array[Dictionary], type: StringName) -> float:
	var sum: float = 0.0
	for effect: Dictionary in effects:
		if effect["risk_type"] == type:
			sum += float(effect["risk"])
		if effect["reward_type"] == type:
			sum += float(effect["reward"])
	return sum


## F-111 `pack_bonus`: `base_size` + v, at most `combat.max_pack_size`.
static func pack_size(base_size: int, effects: Array[Dictionary], data: GameData) -> int:
	var extra: int = int(round(total(effects, RISK_PACK)))
	return mini(int(data.balance_value("combat.max_pack_size")), base_size + extra)


## The F-22 numbers of a scaled monster: each of min and max hit x `damage_mult`, then x the damage risk (floor, minimum 1).
static func scaled_hits(base_min: int, base_max: int, def: ScaledMonsterDef) -> Vector2i:
	return Vector2i(_scaled_hit(base_min, def), _scaled_hit(base_max, def))


static func _scaled_hit(hit: int, def: ScaledMonsterDef) -> int:
	var first: int = maxi(1, floori(float(hit) * def.damage_mult + EPSILON))
	return maxi(1, floori(float(first) * (1.0 + def.risk_damage_pct / 100.0) + EPSILON))
