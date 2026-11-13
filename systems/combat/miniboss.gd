class_name Miniboss
extends RefCounted
## The miniboss of an area (docs/02_FORMULAS.md F-139, docs/05_INTERFACES.md §5.29): the chance that one follows a normal
## encounter, and its encounter. The multipliers come only from `balance.json` `miniboss` and are applied here, once, at runtime:
## the monster of the data (`miniboss: true`) has the plain stats of the strongest monster of its area. No state.

const CHANCE_KEY: String = "miniboss.chance_pct"


## F-139: `roll_pct(chance_pct)` after a normal encounter of `area`; false (no roll) for an area without a miniboss.
static func roll(area: AreaDef, rng: RngService, data: GameData) -> bool:
	if area.miniboss_id == &"":
		return false
	return rng.roll_pct(float(data.balance_value(CHANCE_KEY)))


## F-139: the miniboss (scaled) followed by `miniboss.escorts` monsters of the area, each drawn at random among its monsters.
## Empty if the area has no miniboss.
static func pack(area: AreaDef, rng: RngService, data: GameData) -> Array[MonsterDef]:
	var result: Array[MonsterDef] = []
	if area.miniboss_id == &"":
		return result
	result.append(scale(data.monster(area.miniboss_id), data))
	for _i: int in int(data.balance_value("miniboss.escorts")):
		result.append(data.monster(area.monster_ids[rng.randi_range(0, area.monster_ids.size() - 1)]))
	return result


## F-139: a copy of `def` with hp x `hp_mult`, xp x `xp_mult`, gold x `gold_mult` (rounded) and the hits x `power_mult`
## (`ScaledMonsterDef.damage_mult`, floor, minimum 1). A monster already scaled is returned as it is: never twice.
static func scale(def: MonsterDef, data: GameData) -> MonsterDef:
	if def is ScaledMonsterDef:
		return def
	var scaled: ScaledMonsterDef = ScaledMonsterDef.copy_of(def)
	scaled.is_miniboss = true
	scaled.hp = int(round(float(def.hp) * float(data.balance_value("miniboss.hp_mult"))))
	scaled.xp = int(round(float(def.xp) * float(data.balance_value("miniboss.xp_mult"))))
	var gold_mult: float = float(data.balance_value("miniboss.gold_mult"))
	scaled.gold_min = int(round(float(def.gold_min) * gold_mult))
	scaled.gold_max = int(round(float(def.gold_max) * gold_mult))
	scaled.damage_mult = float(data.balance_value("miniboss.power_mult"))
	return scaled
