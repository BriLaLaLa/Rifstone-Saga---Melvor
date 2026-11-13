extends RefCounted
## Kill xp for the balance tools: F-28 with F-130 (docs/02_FORMULAS.md §5g), one rounding, F-71 ignored.
## floor(xp x combat.kill_xp_mult x xp_level_mult(monster level - character level)).

const MATH_PATH: String = "res://systems/combat/combat_math.gd"
const POOL_PATH: String = "res://core/data/equipment_pool.gd"


static func kill_xp(data: Object, xp: int, monster_level: int, character_level: int) -> int:
	var mult: float = float(data.call("balance_value", "combat.kill_xp_mult"))
	mult *= float((load(MATH_PATH) as GDScript).call("xp_level_mult", monster_level - character_level, data))
	return floori(float(xp) * mult + 1e-9)


## Xp of one kill of the monster `def` (level = highest of its three levels, as `EquipmentPool.monster_level`).
static func monster_kill_xp(data: Object, def: Object, character_level: int) -> int:
	return kill_xp(data, int(def.xp), int((load(POOL_PATH) as GDScript).call("monster_level", def)), character_level)


## Xp of one Rift Stone kill (the level of the stone is its own `level`).
static func stone_kill_xp(data: Object, stone: Object, character_level: int) -> int:
	return kill_xp(data, int(stone.xp), int(stone.level), character_level)
