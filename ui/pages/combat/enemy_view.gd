class_name EnemyView
extends RefCounted
## Presentation of one enemy of the encounter (docs/UI_GDR.md §2): a monster or, in the `riftstone` state, a Rift Stone.
## The state of `combat.get_state()` keeps the id of the Stone in `enemies[i]["monster"]`; the name and the icon are
## resolved here with `GameData.rift_stone` (05 §5.10). Pure functions over the data, no state.

const STONE_TAG_TEXT: String = "Monolito del Rift"
const STONE_INFO_TEXT: String = "Impulso ogni %s s · %s danni a impulso"


## True when `id` is a Rift Stone and not a monster.
static func is_stone(data: GameData, id: StringName) -> bool:
	return not data.has_monster(id) and data.has_rift_stone(id)


static func name_of(data: GameData, id: StringName) -> String:
	if data.has_monster(id):
		return data.monster(id).name
	if data.has_rift_stone(id):
		return data.rift_stone(id).name
	return String(id)


static func icon_of(data: GameData, id: StringName) -> String:
	if data.has_monster(id):
		return data.monster(id).icon
	if data.has_rift_stone(id):
		return data.rift_stone(id).icon
	return ""


## Second line of the card: the style and the triangle relation of a monster, the fixed tag of a Stone.
static func tag_text(data: GameData, id: StringName, player_style: StringName) -> String:
	if is_stone(data, id):
		return STONE_TAG_TEXT
	if not data.has_monster(id):
		return ""
	var def: MonsterDef = data.monster(id)
	var relation: StringName = CombatMath.triangle(player_style, def.style, data)
	return CombatTexts.TAG_TEXT % [ItemTooltipLines.STYLE_NAMES.get(def.style, String(def.style)),
			CombatTexts.RELATION_TEXTS.get(relation, "")]


## Info line of the big card (attack interval and damage reduction; pulse interval and damage for a Stone).
static func info_text(data: GameData, id: StringName) -> String:
	if is_stone(data, id):
		var stone: RiftStoneDef = data.rift_stone(id)
		return STONE_INFO_TEXT % [CombatTexts.seconds_text(stone.pulse_ms), NumberFormat.format_int(stone.pulse_damage)]
	if not data.has_monster(id):
		return ""
	var def: MonsterDef = data.monster(id)
	return CombatTexts.ENEMY_INFO_TEXT % [CombatTexts.seconds_text(def.attack_interval_ms),
			NumberFormat.format_int(roundi(def.damage_reduction))]
