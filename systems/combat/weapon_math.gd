class_name WeaponMath
extends RefCounted
## Pure weapon numbers (docs/02_FORMULAS.md F-22, F-119, F-120, F-86): the damage range of a worn or stored weapon and
## its damage per second. No rounding here: the floor happens in the hit formula.


## (dmg_min, dmg_max) of the weapon base x the rarity multiplier (masterwork and legendary, F-119/F-120) x the
## refinement factor `1 + upgrade.mod_pct_per_level x N / 100` (F-86). (0, 0) if `inst` is not a weapon.
static func damage_range(inst: ItemInstance, data: GameData) -> Vector2:
	if inst == null or not data.has_item(inst.base_id):
		return Vector2.ZERO
	var base: ItemDef = data.item(inst.base_id)
	if base.equip == null or base.equip.weapon == null:
		return Vector2.ZERO
	var factor: float = Rarities.base_mult(inst.rarity, data)
	if inst.upgrade > 0:
		factor *= 1.0 + float(data.balance_value("upgrade.mod_pct_per_level")) * float(inst.upgrade) / 100.0
	return Vector2(float(base.equip.weapon.dmg_min) * factor, float(base.equip.weapon.dmg_max) * factor)


## F-22: (dmg_min + dmg_max) / 2 / (interval / 1000), with the interval of F-26 over `attack_interval_pct`.
## 0 if `inst` is not a weapon.
static func dps(inst: ItemInstance, attack_interval_pct: float, data: GameData) -> float:
	var span: Vector2 = damage_range(inst, data)
	if span.y <= 0.0:
		return 0.0
	var base_ms: int = data.item(inst.base_id).equip.weapon.attack_interval_ms
	var interval_ms: int = CombatMath.attack_interval_ms(base_ms, attack_interval_pct, data)
	return (span.x + span.y) / 2.0 / (float(interval_ms) / 1000.0)
