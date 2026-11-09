class_name EquipmentStatsText
extends RefCounted
## Texts of the equipment page that read the registry and the modifier breakdown (docs/05_INTERFACES.md §5.2): the
## stat summary and the label of a slot. Stateless; everything is read from the session at every call.
##
## The summary has a global block (stats with at least one source in the global context) and, below it, one block
## per skill that has sources of its own (`ModifierContext.for_skill`, minus the sources already in the global
## block), e.g. the tools. Only the stats of the registry are shown; scopes per action are left out.

const STATS_EMPTY_TEXT: String = "Nessun bonus attivo."
const TOOL_SLOT_PREFIX: String = "tool_"
const TOOL_SLOT_TEXT: String = "Attrezzo: %s"
const TOOL_SLOT_DEFAULT_TEXT: String = "Attrezzo"
const SLOT_TEXTS: Dictionary[StringName, String] = {
	&"head": "Testa", &"body": "Corpo", &"legs": "Gambe", &"feet": "Piedi", &"hands": "Mani", &"neck": "Collo",
	&"ring": "Anello", &"weapon": "In mano", &"offhand": "Seconda mano",
}
const SOURCE_EQUIPMENT_PREFIX: String = "equipment:"
const SOURCE_SETUP_PREFIX: String = "setup:"
const SOURCE_SHOP_PREFIX: String = "shop:"
const SOURCE_TEXTS: Dictionary[String, String] = {
	"mastery_item:": "Maestria (oggetto)",
	"mastery_node:": "Maestria (nodo)",
	"mastery_step:": "Maestria (bonus di livello)",
	"rift_socket:": "Altare del Rift",
}
const COLOR_TAG: String = "[color=#%s]%s[/color]"
const SOURCE_INDENT: String = "    "


## Label of `slot`; a tool slot `tool_<skill id>` takes the skill name from the data ("Attrezzo" if there is none).
static func slot_text(slot: StringName, data: GameData) -> String:
	if SLOT_TEXTS.has(slot):
		return SLOT_TEXTS[slot]
	var text: String = String(slot)
	if text.begins_with(TOOL_SLOT_PREFIX):
		var skill: SkillDef = _skill_named(StringName(text.trim_prefix(TOOL_SLOT_PREFIX)), data)
		return TOOL_SLOT_TEXT % skill.name if skill != null else TOOL_SLOT_DEFAULT_TEXT
	return text


## Short label under a slot of the doll: a tool slot shows only the skill name (the icon says it is a tool), so the
## text fits the small slot; the other slots use `slot_text`.
static func doll_text(slot: StringName, data: GameData) -> String:
	var text: String = String(slot)
	if text.begins_with(TOOL_SLOT_PREFIX):
		var skill: SkillDef = _skill_named(StringName(text.trim_prefix(TOOL_SLOT_PREFIX)), data)
		return skill.name if skill != null else TOOL_SLOT_DEFAULT_TEXT
	return slot_text(slot, data)


## Stats shown on the character page, not in the equipment totals.
const TOTALS_HIDDEN_STATS: Array[StringName] = [&"auto_eat_tier", &"upgrade_success_pct"]


## BBCode of the final values: the combat values of the character (the same lines as the character page,
## `CombatTexts.final_stat_lines`), then one line "name  total" for every stat with at least one source in the global
## context.
static func totals(session: GameSession) -> String:
	var lines: PackedStringArray = PackedStringArray()
	for text: String in CombatTexts.final_stat_lines(session):
		lines.append(ItemTooltipLines.escape(text))
	var bonuses: PackedStringArray = PackedStringArray()
	for stat: StringName in session.data.stats.ids():
		if TOTALS_HIDDEN_STATS.has(stat) or session.modifiers.breakdown(stat).is_empty():
			continue
		var info: Dictionary = session.data.stats.info(stat)
		var total: String = ItemTooltipLines.format_stat(info["format"] as String, session.modifiers.total(stat))
		bonuses.append("%s  %s" % [ItemTooltipLines.escape(info["name"] as String),
				COLOR_TAG % [UiStyle.GOLD_LIGHT.to_html(false), total]])
	lines.append("")
	if bonuses.is_empty():
		lines.append(COLOR_TAG % [UiStyle.TEXT_2.to_html(false), STATS_EMPTY_TEXT])
	else:
		lines.append_array(bonuses)
	return "\n".join(lines)


## BBCode of the whole summary, with the sources of every stat.
static func summary(session: GameSession) -> String:
	var lines: PackedStringArray = PackedStringArray()
	var global_sources: Dictionary[StringName, Array] = {}
	for stat: StringName in session.data.stats.ids():
		var sources: Array[Dictionary] = session.modifiers.breakdown(stat)
		global_sources[stat] = _source_ids(sources)
		_append_stat(lines, session, stat, sources, ModifierContext.global_ctx())
	for skill: SkillDef in session.data.skills():
		var ctx: ModifierContext = ModifierContext.for_skill(skill.id)
		var skill_lines: PackedStringArray = PackedStringArray()
		for stat: StringName in session.data.stats.ids():
			var own: Array[Dictionary] = []
			for source: Dictionary in session.modifiers.breakdown(stat, ctx):
				if not (global_sources[stat] as Array).has(source["source"]):
					own.append(source)
			_append_stat(skill_lines, session, stat, own, ctx)
		if not skill_lines.is_empty():
			lines.append("")
			lines.append(COLOR_TAG % [UiStyle.GOLD.to_html(false), ItemTooltipLines.escape(skill.name)])
			lines.append_array(skill_lines)
	if lines.is_empty():
		return COLOR_TAG % [UiStyle.TEXT_2.to_html(false), STATS_EMPTY_TEXT]
	return "\n".join(lines)


static func _append_stat(lines: PackedStringArray, session: GameSession, stat: StringName,
		sources: Array[Dictionary], ctx: ModifierContext) -> void:
	if sources.is_empty():
		return
	var info: Dictionary = session.data.stats.info(stat)
	var format: String = info["format"] as String
	var total: String = ItemTooltipLines.format_stat(format, session.modifiers.total(stat, ctx))
	lines.append("%s  %s" % [ItemTooltipLines.escape(info["name"] as String),
			COLOR_TAG % [UiStyle.GOLD_LIGHT.to_html(false), total]])
	var description: String = str(info.get("description", ""))
	if not description.is_empty():
		lines.append(COLOR_TAG % [UiStyle.TEXT_2.to_html(false), SOURCE_INDENT + ItemTooltipLines.escape(description)])
	for source: Dictionary in sources:
		var line: String = "%s%s  %s" % [SOURCE_INDENT,
				ItemTooltipLines.escape(source_name(source["source"], session)),
				ItemTooltipLines.format_stat(format, source["value"])]
		lines.append(COLOR_TAG % [UiStyle.TEXT_2.to_html(false), line])


static func _source_ids(sources: Array[Dictionary]) -> Array:
	var ids: Array = []
	for source: Dictionary in sources:
		ids.append(source["source"])
	return ids


## Readable name of a modifier source id (05 §5.2): the worn piece, the shop entry, or a generic text.
static func source_name(source_id: StringName, session: GameSession) -> String:
	var text: String = String(source_id)
	if text.begins_with(SOURCE_EQUIPMENT_PREFIX):
		var slot: StringName = StringName(text.trim_prefix(SOURCE_EQUIPMENT_PREFIX))
		var item_id: StringName = session.equipment.get_item(slot)
		var item: ItemDef = session.data.item(item_id) if item_id != &"" else null
		var label: String = slot_text(slot, session.data)
		return "%s (%s)" % [item.name, label] if item != null else label
	if text.begins_with(SOURCE_SETUP_PREFIX):
		return ItemTooltipLines.SETUP_SOURCE_TEXT % _setup_name(
				StringName(text.trim_prefix(SOURCE_SETUP_PREFIX)), session)
	if text.begins_with(SOURCE_SHOP_PREFIX):
		var entry: ShopEntryDef = session.data.shop_entry(StringName(text.trim_prefix(SOURCE_SHOP_PREFIX)))
		return entry.name if entry != null else text
	for prefix: String in SOURCE_TEXTS:
		if text.begins_with(prefix):
			return SOURCE_TEXTS[prefix]
	return text


## Setup name from the class data; the id if the setup is not in the class.
static func _setup_name(setup_id: StringName, session: GameSession) -> String:
	var class_def: ClassDef = session.character.class_def()
	if class_def != null:
		for setup: SetupDef in class_def.setups:
			if setup.id == setup_id:
				return setup.name
	return String(setup_id)


## The skill with this id, searched in the list without logging (the data logs an error for unknown ids).
static func _skill_named(skill_id: StringName, data: GameData) -> SkillDef:
	for skill: SkillDef in data.skills():
		if skill.id == skill_id:
			return skill
	return null
