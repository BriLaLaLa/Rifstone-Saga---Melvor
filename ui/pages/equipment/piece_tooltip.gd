class_name PieceTooltip
extends RefCounted
## BBCode of the hover tooltip of a piece, in the order of an ARPG item card (display only, no state): name in the
## rarity color; rarity, slot and item level; requirements (red if unmet); weapon and protection; base stats; affixes
## and sockets with the values in front; legendary effect; comparison with the worn piece; refinement and value at the
## bottom. Every number comes from the session (armory, shop, character) and every stat label from the registry.
## The base stats are the modifiers of the piece minus its affixes and stones, so no formula is written here.

const DIVIDER_TEXT: String = "──────────────────────────────────────"
const RARITY_SLOT_TEXT: String = "%s  ·  %s"
const BASE_TITLE: String = "Statistiche base"
const AFFIXES_TITLE: String = "Affissi"
const SOCKETS_TITLE: String = "Castoni %d/%d"
const FREE_SOCKET_TEXT: String = "Incavo libero"
const REFINE_TEXT: String = "Raffinazione +%d"
const VALUE_TEXT: String = "Valore: %s"
const NOT_SELLABLE_TEXT: String = "Non vendibile"
const GRADE_TEXT: String = "grado %d"
const TITLE_SIZE: int = 20
const SUBTITLE_SIZE: int = 14


## Whole tooltip text of the piece `uid`; empty if it is not in the armory.
static func build(session: GameSession, uid: int) -> String:
	var inst: ItemInstance = session.armory.get_instance(uid)
	var base: ItemDef = session.data.item(inst.base_id) if inst != null else null
	if base == null or base.equip == null:
		return ""
	var data: GameData = session.data
	var mods: Array[Modifier] = session.armory.instance_modifiers(uid)
	var rarity_color: Color = UiStyle.rarity_color(inst.rarity)
	var lines: PackedStringArray = PackedStringArray()
	lines.append("[font_size=%d]%s[/font_size]" % [TITLE_SIZE,
			ItemTooltipLines.colored_title(ArmoryTexts.piece_name(inst, base), rarity_color)])
	lines.append("[font_size=%d]%s[/font_size]" % [SUBTITLE_SIZE, _tag(RARITY_SLOT_TEXT % [
			ArmoryTexts.rarity_name(inst.rarity), EquipmentStatsText.slot_text(base.equip.slot, data)], rarity_color)])
	lines.append(_tag(ArmoryTexts.LEVEL_TEXT % inst.ilvl, UiStyle.TEXT_2))
	var requirements: PackedStringArray = ArmoryTexts.requirement_lines(session, base.equip)
	lines.append_array(requirements)
	var base_block: PackedStringArray = PackedStringArray()
	if base.equip.weapon != null:
		base_block.append_array(ArmoryTexts.weapon_lines(session, inst, base))
	base_block.append_array(ArmoryTexts.armor_lines(session, mods))
	var extras: Array[Modifier] = _extra_modifiers(inst, data)
	base_block.append_array(_stat_lines(ArmoryTexts.diff_modifiers(mods, extras), data))
	_append_block(lines, BASE_TITLE, base_block)
	_append_block(lines, AFFIXES_TITLE, _affix_lines(inst, data))
	_append_sockets(lines, session, uid, inst)
	_append_block(lines, ArmoryTexts.LEGENDARY_TITLE, ArmoryTexts.legendary_lines(session, base))
	var comparison: PackedStringArray = PackedStringArray()
	ArmoryTexts.append_comparison(comparison, session, uid, base, mods)
	if not comparison.is_empty():
		lines.append(_divider())
		lines.append_array(comparison)
	lines.append(_divider())
	if inst.upgrade > 0:
		lines.append(_tag(REFINE_TEXT % inst.upgrade, UiStyle.GOLD_LIGHT))
	var gold: int = session.shop.sell_value(inst.base_id, 1)
	lines.append(_tag(VALUE_TEXT % Money.text(gold, data.currency()) if gold > 0 else NOT_SELLABLE_TEXT, UiStyle.TEXT_2))
	return "\n".join(lines)


## Modifiers of the affixes and of the active stones (what the piece has on top of its base stats).
static func _extra_modifiers(inst: ItemInstance, data: GameData) -> Array[Modifier]:
	var extras: Array[Modifier] = []
	var piece_slot: StringName = data.item(inst.base_id).equip.slot
	var scope_kind: StringName = Modifier.SCOPE_GLOBAL
	var scope_id: StringName = &""
	if String(piece_slot).begins_with(ItemRoller.TOOL_SLOT_PREFIX):
		scope_kind = Modifier.SCOPE_SKILL
		scope_id = StringName(String(piece_slot).trim_prefix(ItemRoller.TOOL_SLOT_PREFIX))
	for roll: AffixRoll in inst.affixes:
		var def: AffixDef = data.affix(roll.affix_id)
		if def != null:
			extras.append(Modifier.make(def.stat, roll.value, scope_kind, scope_id))
	for stone_id: StringName in Sockets.active(inst, data):
		if data.has_item(stone_id):
			extras.append_array(data.item(stone_id).stone_modifiers)
	return extras


## "+12 Name (scope)" with the value first and highlighted.
static func _stat_lines(mods: Array[Modifier], data: GameData) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	for mod: Modifier in mods:
		if not data.stats.has(mod.stat):
			continue
		lines.append(_stat_line(mod.stat, mod.value, ItemTooltipLines.scope_name(mod, data), data, ""))
	return lines


static func _stat_line(stat: StringName, value: float, scope: String, data: GameData, note: String) -> String:
	var info: Dictionary = data.stats.info(stat)
	var text: String = "%s %s" % [_value(ItemTooltipLines.format_stat(info["format"] as String, value)),
			ItemTooltipLines.escape(info["name"] as String)]
	if not scope.is_empty():
		text += " " + _tag("(%s)" % scope, UiStyle.TEXT_2)
	if not note.is_empty():
		text += " " + _tag("(%s)" % note, UiStyle.TEXT_2)
	return text


static func _affix_lines(inst: ItemInstance, data: GameData) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	for roll: AffixRoll in inst.affixes:
		var def: AffixDef = data.affix(roll.affix_id)
		if def == null or not data.stats.has(def.stat):
			Log.warn(ArmoryTexts.LOG_CATEGORY, "tooltip: affix '%s' is not in the data, no line shown" % roll.affix_id)
			continue
		lines.append(_stat_line(def.stat, roll.value, "", data, GRADE_TEXT % roll.tier))
	return lines


## "Castoni n/m": the name of each stone with its modifiers, a muted line for each free socket.
static func _append_sockets(lines: PackedStringArray, session: GameSession, uid: int, inst: ItemInstance) -> void:
	var count: int = session.armory.socket_count(uid)
	if count <= 0 and inst.sockets.is_empty():
		return
	var block: PackedStringArray = PackedStringArray()
	for i: int in maxi(count, inst.sockets.size()):
		if i >= inst.sockets.size():
			block.append(_tag(FREE_SOCKET_TEXT, UiStyle.TEXT_2))
			continue
		var stone: ItemDef = session.data.item(inst.sockets[i])
		if stone == null:
			continue
		var stats: PackedStringArray = _stat_lines(stone.stone_modifiers, session.data)
		block.append("%s  %s" % [ItemTooltipLines.escape(stone.name), "  ".join(stats)])
	_append_block(lines, SOCKETS_TITLE % [mini(inst.sockets.size(), count), count], block)


static func _append_block(lines: PackedStringArray, title: String, body: PackedStringArray) -> void:
	if body.is_empty():
		return
	lines.append(_divider())
	lines.append(_tag(title, UiStyle.GOLD))
	lines.append_array(body)


static func _divider() -> String:
	return _tag(DIVIDER_TEXT, UiStyle.TOOLTIP_DIVIDER)


static func _tag(text: String, color: Color) -> String:
	return ArmoryTexts.COLOR_TAG % [color.to_html(false), text]


static func _value(text: String) -> String:
	return "[color=#%s][b]%s[/b][/color]" % [UiStyle.GOLD_LIGHT.to_html(false), text]
