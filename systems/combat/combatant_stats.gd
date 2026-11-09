class_name CombatantStats
extends RefCounted
## The numbers of one combatant for the combat engine (docs/05_INTERFACES.md §5.10). Always recomputed from the
## character level, the worn equipment and the modifiers (F-70, F-74): nothing here is saved.

## The attack stats that depend on the hand that strikes (F-74).
const HAND_STATS: Array[StringName] = [&"accuracy_bonus", &"accuracy_pct", &"power_bonus", &"power_pct"]
const OFFHAND_SLOT: StringName = &"offhand"
const MAIN_SLOT: StringName = &"weapon"
const WEAPON_SOURCE: StringName = &"equipment:weapon"
const OFFHAND_SOURCE: StringName = &"equipment:offhand"
const SHIELD_KIND: StringName = &"shield"
const ARCANE_STYLE: StringName = &"arcana"

var style: StringName = &""
var accuracy: int = 0
var evasion: int = 0
var max_hit: int = 0
var min_hit: int = 0
var attack_interval_ms: int = 0
var damage_reduction: float = 0.0  # monsters only (F-25): a flat percentage
var armor: int = 0  # player only (F-117)
var barrier: int = 0  # player only (F-117)
var level: int = 0  # player: character level; monster: power_level (the L_att of F-117)
var is_player: bool = false
var weapon_min: float = 0.0  # F-22: range of the striking weapon, 0 without one and for monsters
var weapon_max: float = 0.0
var max_hp: int = 0
var block_chance: float = 0.0


## F-70 for the player. `hand` 1 = the offhand sword of a dual-wield setup (F-74); anywhere else it is the main hand.
static func for_player(session: GameSession, hand: int = 0) -> CombatantStats:
	var data: GameData = session.data
	var mods: ModifierService = session.modifiers
	var equipment: Equipment = session.equipment
	var level: int = session.character.get_level()
	var setup: SetupDef = equipment.setup_def()
	var second: ItemDef = equipment.offhand_weapon()
	var dual: bool = setup != null and setup.alternate and second != null
	var off_hand: bool = hand == 1 and dual
	var values: Dictionary[StringName, float] = {}
	for stat: StringName in HAND_STATS:
		if dual:
			var other: Array[StringName] = [WEAPON_SOURCE if off_hand else OFFHAND_SOURCE]
			values[stat] = mods.total_without(stat, null, other)
		else:
			values[stat] = mods.total(stat)
	var result := CombatantStats.new()
	result.accuracy = CombatMath.accuracy_rating(level, values[&"accuracy_bonus"], values[&"accuracy_pct"], data)
	result.evasion = CombatMath.evasion_rating(level, mods.total(&"evasion_bonus"), mods.total(&"evasion_pct"), data)
	var span: Vector2 = _weapon_range(session, off_hand)
	result.weapon_min = span.x
	result.weapon_max = span.y
	result.max_hit = CombatMath.max_hit(level, span.y + values[&"power_bonus"], values[&"power_pct"], data)
	result.min_hit = CombatMath.min_hit_for(result.max_hit, span.x, span.y, data)
	result.attack_interval_ms = CombatMath.attack_interval_ms(
		equipment.base_attack_interval_ms(), mods.total(&"attack_interval_pct"), data)
	result.armor = int(floor(mods.total(&"armor") + CombatMath.EPSILON))
	result.barrier = int(floor(mods.total(&"barrier") + CombatMath.EPSILON))
	result.level = level
	result.is_player = true
	result.max_hp = CombatMath.max_hp(level, mods.total(&"max_hp_flat"), data)
	result.style = second.equip.weapon.style if off_hand else equipment.style()
	if _wears_shield(session):
		result.block_chance = CombatMath.block_chance(mods.total(&"block_chance"), data)
	return result


## Monsters use the same formulas with the levels and bonuses of their data (D5); no block, no modifiers.
static func for_monster(monster: MonsterDef, data: GameData) -> CombatantStats:
	var result := CombatantStats.new()
	result.style = monster.style
	result.level = monster.power_level
	result.accuracy = CombatMath.accuracy_rating(monster.attack_level, monster.accuracy_bonus, 0.0, data)
	result.evasion = CombatMath.evasion_rating(monster.defence_level, monster.evasion_bonus, 0.0, data)
	result.max_hit = CombatMath.max_hit(monster.power_level, monster.power_bonus, 0.0, data)
	result.min_hit = CombatMath.min_hit(result.max_hit, data)
	result.attack_interval_ms = CombatMath.attack_interval_ms(monster.attack_interval_ms, 0.0, data)
	result.damage_reduction = monster.damage_reduction
	result.max_hp = monster.hp
	if monster is ScaledMonsterDef:  # M13: a monster of a Fracture (F-110, F-111)
		_apply_fracture_scale(result, monster as ScaledMonsterDef, data)
	return result


# F-110 damage, then the F-111 risks on damage, speed (F-26 with pct = -v) and evasion.
static func _apply_fracture_scale(stats: CombatantStats, monster: ScaledMonsterDef, data: GameData) -> void:
	var hits: Vector2i = FractureScaler.scaled_hits(stats.min_hit, stats.max_hit, monster)
	stats.min_hit = hits.x
	stats.max_hit = hits.y
	stats.attack_interval_ms = CombatMath.attack_interval_ms(monster.attack_interval_ms, -monster.risk_speed_pct, data)
	stats.evasion = int(round(float(stats.evasion) * (1.0 + monster.risk_defence_pct / 100.0)))


## `modify_stats` of `stat_trade` (F-81): multiplies the derived number a stat of stats.json feeds by `factor` (0 =
## zeroed), floored, then limits it where stats.json has limits. Mapping: accuracy_bonus/accuracy_pct -> accuracy;
## evasion_bonus/evasion_pct -> evasion; power_bonus/power_pct -> max_hit (min_hit follows, F-22); armor; barrier;
## block_chance; max_hp_flat -> max_hp. Any other stat feeds nothing here: logged and ignored.
func scale_stat(stat: StringName, factor: float, data: GameData) -> void:
	match stat:
		&"accuracy_bonus", &"accuracy_pct":
			accuracy = _scaled(accuracy, factor)
		&"evasion_bonus", &"evasion_pct":
			evasion = _scaled(evasion, factor)
		&"power_bonus", &"power_pct":
			max_hit = maxi(1, _scaled(max_hit, factor))
			min_hit = CombatMath.min_hit_for(max_hit, weapon_min, weapon_max, data)
		&"max_hp_flat":
			max_hp = maxi(1, _scaled(max_hp, factor))
		&"armor":
			armor = int(floor(data.stats.clamp_total(stat, float(armor) * factor) + CombatMath.EPSILON))
		&"barrier":
			barrier = int(floor(data.stats.clamp_total(stat, float(barrier) * factor) + CombatMath.EPSILON))
		&"block_chance":
			block_chance = data.stats.clamp_total(stat, block_chance * factor)
		_:
			Log.warn("combat", "stat_trade: '%s' does not feed any combat number" % stat)


## F-25 + F-117: the base reduction (before the triangle) this combatant applies to an attack of the given style and
## level: a monster uses its flat `damage_reduction`; the player uses Armour against `blade`/`marksmanship` and Barrier
## against `arcana` (diminishing returns, capped).
func reduction_against(attacker_style: StringName, attacker_level: int, data: GameData) -> float:
	if not is_player:
		return damage_reduction
	return ArmorMath.reduction_pct(barrier if attacker_style == ARCANE_STYLE else armor, attacker_level, data)


static func _scaled(value: int, factor: float) -> int:
	return int(floor(float(value) * factor + CombatMath.EPSILON))


static func _wears_shield(session: GameSession) -> bool:
	if session.equipment.get_uid(&"offhand") <= 0:
		return false
	var worn: ItemDef = session.data.item(session.equipment.get_item(&"offhand"))
	return worn != null and worn.equip != null and worn.equip.kind == SHIELD_KIND


# F-22: the (dmg_min, dmg_max) of the weapon that strikes: the worn weapon, the offhand sword for hand 1 of a dual-wield
# setup, `combat.unarmed` without one.
static func _weapon_range(session: GameSession, off_hand: bool) -> Vector2:
	var uid: int = session.equipment.get_uid(OFFHAND_SLOT if off_hand else MAIN_SLOT)
	var inst: ItemInstance = session.armory.get_instance(uid) if uid > 0 else null
	if inst != null:
		return WeaponMath.damage_range(inst, session.data)
	return Vector2(float(session.data.balance_value("combat.unarmed.dmg_min")),
			float(session.data.balance_value("combat.unarmed.dmg_max")))
