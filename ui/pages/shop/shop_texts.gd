class_name ShopTexts
extends RefCounted
## Effect line of a shop entry with the numbers read from the data (docs/01_GDD.md §29): the modifiers of the entry
## through the stat registry, the thresholds of the auto-eat tier from `combat.auto_eat_tiers`, the item of an item
## effect. No number is written here. Pure functions over the data.

const AUTO_EAT_STAT: StringName = &"auto_eat_tier"
const AUTO_EAT_KEY: String = "combat.auto_eat_tiers"
const AUTO_EAT_TEXT: String = "Mangia da solo sotto il %s%% dei punti vita, fino al %s%%."
const MODIFIER_TEXT: String = "%s: %s"
const ITEM_TEXT: String = "Ottieni: %s x%s"
const LINE_SEPARATOR: String = " · "


## The effect of `entry` as one line: "Caselle della borsa del bottino: +4".
static func describe(entry: ShopEntryDef, data: GameData) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for mod: Modifier in entry.effect_modifiers:
		var part: String = _modifier_text(mod, entry, data)
		if not part.is_empty():
			parts.append(part)
	if entry.effect_item != null:
		var item: ItemDef = data.item(entry.effect_item.item_id) if data.has_item(entry.effect_item.item_id) else null
		parts.append(ITEM_TEXT % [item.name if item != null else String(entry.effect_item.item_id),
				NumberFormat.format_int(entry.effect_item.qty)])
	return LINE_SEPARATOR.join(parts)


static func _modifier_text(mod: Modifier, entry: ShopEntryDef, data: GameData) -> String:
	if mod.stat == AUTO_EAT_STAT:
		var tier: Dictionary = _auto_eat_tier(entry, data)
		if not tier.is_empty():
			return AUTO_EAT_TEXT % [NumberFormat.format_number(float(tier["threshold_pct"])),
					NumberFormat.format_number(float(tier["target_pct"]))]
	if not data.stats.has(mod.stat):
		return ""
	var info: Dictionary = data.stats.info(mod.stat)
	return MODIFIER_TEXT % [str(info["name"]), ItemTooltipLines.format_stat(str(info["format"]), mod.value)]


## The tier an auto-eat entry reaches: the number of entries required in a chain, plus this one (tier 1 = the first).
static func _auto_eat_tier(entry: ShopEntryDef, data: GameData) -> Dictionary:
	var tiers: Variant = data.balance_value(AUTO_EAT_KEY)
	if not tiers is Array:
		return {}
	var index: int = 1
	var current: ShopEntryDef = entry
	while not current.req_entries.is_empty():
		var parent: ShopEntryDef = data.shop_entry(current.req_entries[0])
		if parent == null:
			break
		index += 1
		current = parent
	var list: Array = tiers
	if index >= list.size() or not list[index] is Dictionary:
		return {}
	return list[index]
