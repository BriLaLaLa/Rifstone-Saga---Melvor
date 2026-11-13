class_name EnemyView
extends RefCounted
## Presentation of one enemy of the encounter (docs/UI_GDR.md §2): a monster, a Fracture boss or, in the `riftstone` state,
## a Rift Stone. The state of `combat.get_state()` keeps the id of the Stone or of the boss in `enemies[i]["monster"]`; the
## name and the icon are resolved here with `GameData.rift_stone` / `GameData.boss` (05 §5.10, §5.23). Pure functions over the
## data, no state.

const STONE_TAG_TEXT: String = "Monolito del Rift"
const STONE_INFO_TEXT: String = "Impulso ogni %s s · %s danni a impulso"
const LEVEL_TAG_TEXT: String = "Liv %d · %s"
const BOSS_TAG_TEXT: String = "Boss della Frattura"
const BOSS_INFO_TEXT: String = "%s · %s"


## True when `id` is a Rift Stone and not a monster.
static func is_stone(data: GameData, id: StringName) -> bool:
	return not data.has_monster(id) and data.has_rift_stone(id)


## The boss of the data with this id, null if `id` is not a boss (the grades come from `fracture.grades`).
static func boss_of(data: GameData, id: StringName) -> BossDef:
	if id == &"" or data.has_monster(id) or data.has_rift_stone(id):
		return null
	var grades: Variant = data.balance_value("fracture.grades")
	var count: int = (grades as Array).size() if grades is Array else 0
	for grade: int in count:
		var boss: BossDef = data.boss_for_grade(grade + 1)
		if boss != null and boss.id == id:
			return boss
	return null


## The monster or the boss of `id` (null for a Stone or an unknown id).
static func monster_of(data: GameData, id: StringName) -> MonsterDef:
	if data.has_monster(id):
		return data.monster(id)
	return boss_of(data, id)


## Level of a monster or boss (`EquipmentPool.monster_level`: the highest of its combat levels); 0 for a Stone.
static func level_of(data: GameData, id: StringName) -> int:
	var def: MonsterDef = monster_of(data, id)
	return EquipmentPool.monster_level(def) if def != null else 0


static func name_of(data: GameData, id: StringName) -> String:
	var def: MonsterDef = monster_of(data, id)
	if def != null:
		return def.name
	if data.has_rift_stone(id):
		return data.rift_stone(id).name
	return String(id)


static func icon_of(data: GameData, id: StringName) -> String:
	var def: MonsterDef = monster_of(data, id)
	if def != null:
		return def.icon
	if data.has_rift_stone(id):
		return data.rift_stone(id).icon
	return ""


## Second line of the card: the style and the triangle relation of a monster, the fixed tags of a Stone and of a boss.
static func tag_text(data: GameData, id: StringName, player_style: StringName) -> String:
	if is_stone(data, id):
		return STONE_TAG_TEXT
	var def: MonsterDef = monster_of(data, id)
	if def == null:
		return ""
	var relation: StringName = CombatMath.triangle(player_style, def.style, data)
	var text: String = CombatTexts.TAG_TEXT % [ItemTooltipLines.STYLE_NAMES.get(def.style, String(def.style)),
			CombatTexts.RELATION_TEXTS.get(relation, "")]
	text = LEVEL_TAG_TEXT % [level_of(data, id), text]  # M16-04: the level of the monster is always visible
	return BOSS_TAG_TEXT + " · " + text if def is BossDef else text


## Info line of the big card (attack interval and damage reduction; pulse interval and damage for a Stone; the ability too for a boss).
static func info_text(data: GameData, id: StringName) -> String:
	if is_stone(data, id):
		var stone: RiftStoneDef = data.rift_stone(id)
		return STONE_INFO_TEXT % [CombatTexts.seconds_text(stone.pulse_ms), NumberFormat.format_int(StoneFight.pulse_damage(data))]  # M15: the pulse comes from metin.pulse_damage
	var def: MonsterDef = monster_of(data, id)
	if def == null:
		return ""
	var text: String = CombatTexts.ENEMY_INFO_TEXT % [CombatTexts.seconds_text(def.attack_interval_ms),
			NumberFormat.format_int(roundi(def.damage_reduction))]
	return BOSS_INFO_TEXT % [text, CombatFracture.ability_text(data, id)] if def is BossDef else text
