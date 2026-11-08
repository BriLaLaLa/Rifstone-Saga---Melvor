class_name ItemTooltipLines
extends RefCounted
## Builds the BBCode lines of an item tooltip from an ItemDef (display only, no game state).
##
## Numbers use NumberFormat (ui/theme/number_format.gd).
##
## Ported from the item part of the previous game's tooltip: there it read loose item dictionaries with rarity,
## upgrade levels and a hard-coded list of stat names. Here every modifier line takes its label and format from
## `StatRegistry.info()` (docs/04_DATA_SCHEMA.md §2): `pct` is shown with "%", `flat` as a signed number, `flag` as
## Sì/No. A stat that is not in the registry gets no line (and a warning): the tooltip never invents stats.
## Skill and action names (requirements, weapon style, modifier scopes) come from the same GameData.

const LOG_CATEGORY: String = "ui"
## Italian name of each item category (docs/04_DATA_SCHEMA.md §5).
const CATEGORY_NAMES: Dictionary[StringName, String] = {
	&"material": "Materiale",
	&"stone": "Pietra",
	&"currency": "Valuta",
	&"equipment": "Equipaggiamento",
	&"tool": "Attrezzo",
	&"food": "Cibo",
	&"infusion": "Infusione",
	&"misc": "Varie",
}
## Italian name of each weapon style (docs/OPEN_QUESTIONS.md Q42): styles are not skills any more.
const STYLE_NAMES: Dictionary[StringName, String] = {
	&"blade": "Lama", &"marksmanship": "Mira", &"arcana": "Arcano",
}
## Requirement on the character level (reserved key `character` of the requirements).
const CHARACTER_REQUIREMENT_TEXT: String = "Richiede il livello %d del personaggio"
## Fixed words of the class setup (docs/04_DATA_SCHEMA.md §14): the label and the modifier source "Assetto: <name>".
const SETUP_LABEL: String = "Assetto"
const SETUP_SOURCE_TEXT: String = "Assetto: %s"
## Name of the combat section (sidebar row) and of the `combat` shop category: one definition for both.
const COMBAT_TEXT: String = "Combattimento"
const FORMAT_PCT: String = "pct"
const FORMAT_FLAT: String = "flat"
const FORMAT_FLAG: String = "flag"
## Last lines of an item tooltip (docs/01_GDD.md §27).
const GUIDE_MAX_ENTRIES: int = 3
const SOURCES_TEXT: String = "Si ottiene da: %s"
const USES_TEXT: String = "Serve a: %s"

static var _index: GuideIndex = null
static var _index_data: GameData = null


## Subtitle under the name: category and, when `count` > 0, the quantity.
static func subtitle(item: ItemDef, count: int) -> String:
	var parts: PackedStringArray = PackedStringArray([category_name(item.category)])
	if count > 0:
		parts.append("Quantità: %s" % NumberFormat.format_int(count))
	return "  ·  ".join(parts)


## Body lines, in order: requirements, weapon, modifiers (equipment, then infusion), food, value.
## `data` gives the stat registry and the skill/action names; with a null or invalid `data` the lines that need it
## are left out (with a warning) instead of being shown with made-up labels.
static func body(item: ItemDef, data: GameData) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var has_data: bool = data != null and data.is_valid() and data.stats != null
	var needs_data: bool = item.equip != null or item.is_infusion()
	if needs_data and not has_data:
		Log.warn(LOG_CATEGORY, "tooltip of '%s' without valid game data: requirements and modifiers hidden" % item.id)
	if item.equip != null and has_data:
		lines.append_array(_requirement_lines(item.equip, data))
		if item.equip.weapon != null:
			lines.append(weapon_line(item.equip.weapon))
		lines.append_array(modifier_lines(item.equip.modifiers, data))
	if item.is_infusion() and has_data:
		lines.append_array(modifier_lines(item.infusion_modifiers, data))
		if item.infusion_unique:
			lines.append(_muted("Unica: non si incastona in più prese"))
	if item.is_food():
		lines.append("Cura %s punti vita" % _value(NumberFormat.format_int(item.food_heal)))
	if item.value > 0:
		lines.append(_muted("Valore: %s oro" % NumberFormat.format_int(item.value)))
	else:
		lines.append(_muted("Non vendibile"))
	return lines


## "Si ottiene da: ..." and "Serve a: ..." (at most GUIDE_MAX_ENTRIES entries then "e altro", from the Guide index);
## a line with no entries is left out. Nothing for data that is not valid or has no such item. Appended by the tooltip
## (`CustomTooltip.setup_item`), not by `body`.
static func guide_lines(item: ItemDef, data: GameData) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	if data == null or not data.is_valid() or not data.has_item(item.id):
		return lines
	var index: GuideIndex = _guide_index(data)
	var sources: String = index.summary_line(index.sources_of(item.id), GUIDE_MAX_ENTRIES)
	if not sources.is_empty():
		lines.append(_muted(SOURCES_TEXT % escape(sources)))
	var uses: String = index.summary_line(index.uses_of(item.id), GUIDE_MAX_ENTRIES)
	if not uses.is_empty():
		lines.append(_muted(USES_TEXT % escape(uses)))
	return lines


## The Guide index of `data`, built once per GameData (read-only derived data, never saved).
static func _guide_index(data: GameData) -> GuideIndex:
	if _index == null or _index_data != data:
		_index = GuideIndex.new(data)
		_index_data = data
	return _index


## One line per (stat, scope) whose stat is registered: "<name> <value>[ (<scope>)]". Modifiers of the same stat and
## scope are summed into one line (first-appearance order).
static func modifier_lines(mods: Array[Modifier], data: GameData) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var sums: Dictionary[String, Modifier] = {}
	var order: Array[String] = []
	for mod: Modifier in mods:
		if not data.stats.has(mod.stat):
			Log.warn(LOG_CATEGORY, "tooltip: stat '%s' is not registered, no line shown" % mod.stat)
			continue
		var key: String = "%s|%s|%s" % [mod.stat, mod.scope_kind, mod.scope_id]
		if not sums.has(key):
			sums[key] = Modifier.make(mod.stat, 0.0, mod.scope_kind, mod.scope_id)
			order.append(key)
		sums[key].value += mod.value
	for key: String in order:
		var sum: Modifier = sums[key]
		var info: Dictionary = data.stats.info(sum.stat)
		var line: String = "%s %s" % [escape(info["name"] as String), _value(format_stat(info["format"] as String,
				sum.value))]
		var scope: String = _scope_name(sum, data)
		if not scope.is_empty():
			line += " " + _muted("(%s)" % scope)
		lines.append(line)
	return lines


## A bold name in `color` (a piece shows its name in the color of its rarity).
static func colored_title(text: String, color: Color) -> String:
	return "[color=#%s][b]%s[/b][/color]" % [color.to_html(false), escape(text)]


## A stat value in its registry format: pct "+5%" / "-3%", flat "+8", flag "Sì" / "No".
static func format_stat(format: String, value: float) -> String:
	match format:
		FORMAT_PCT:
			return _signed(value) + "%"
		FORMAT_FLAT:
			return _signed(value)
		FORMAT_FLAG:
			return "Sì" if value != 0.0 else "No"
	Log.warn(LOG_CATEGORY, "tooltip: unknown stat format '%s'" % format)
	return NumberFormat.format_number(value)


static func category_name(category: StringName) -> String:
	if not CATEGORY_NAMES.has(category):
		Log.warn(LOG_CATEGORY, "tooltip: unknown item category '%s'" % category)
		return String(category)
	return CATEGORY_NAMES[category]


## Escapes BBCode in data texts.
static func escape(text: String) -> String:
	return text.replace("[", "[lb]")


static func _requirement_lines(equip: EquipInfo, data: GameData) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var skill_ids: Array[StringName] = []
	for skill_id: StringName in equip.requirements:
		skill_ids.append(skill_id)
	skill_ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	for skill_id: StringName in skill_ids:
		lines.append(_muted(requirement_text(skill_id, equip.requirements[skill_id], data)))
	return lines


static func weapon_line(weapon: WeaponInfo) -> String:
	var seconds: String = NumberFormat.format_number(weapon.attack_interval_ms / 1000.0)
	var line: String = "Stile %s, un attacco ogni %s s" % [style_name(weapon.style), _value(seconds)]
	if weapon.two_handed:
		line += ", a due mani"
	return line


## Display name of the scope of `mod` (a skill or an action); empty for global modifiers.
static func scope_name(mod: Modifier, data: GameData) -> String:
	return _scope_name(mod, data)


## Display name of a modifier scope; empty for global modifiers.
static func _scope_name(mod: Modifier, data: GameData) -> String:
	match mod.scope_kind:
		Modifier.SCOPE_SKILL:
			return _skill_name(mod.scope_id, data)
		Modifier.SCOPE_ACTION:
			var action: ActionDef = data.action(mod.scope_id)
			return escape(action.name) if action != null else String(mod.scope_id)
	return ""


## Skill name from the data; an unknown id (already logged by GameData) is shown as the id.
static func _skill_name(skill_id: StringName, data: GameData) -> String:
	var skill: SkillDef = data.skill(skill_id)
	return escape(skill.name) if skill != null else String(skill_id)


static func _signed(value: float) -> String:
	return ("+" if value > 0.0 else "") + NumberFormat.format_number(value)


static func _value(text: String) -> String:
	return "[color=#%s][b]%s[/b][/color]" % [UiStyle.GOLD_LIGHT.to_html(false), text]


static func _muted(text: String) -> String:
	return "[color=#%s]%s[/color]" % [UiStyle.TEXT_2.to_html(false), text]


## Display name of a weapon style (Q42); an unknown style is shown as its id (and logged).
static func style_name(style: StringName) -> String:
	if not STYLE_NAMES.has(style):
		Log.warn(LOG_CATEGORY, "tooltip: unknown weapon style '%s'" % style)
		return String(style)
	return STYLE_NAMES[style]


## Plain text of one requirement: the reserved key `character` is the character level, the others skill levels.
static func requirement_text(key: StringName, needed: int, data: GameData) -> String:
	if key == CharacterSystem.REQUIREMENT_KEY:
		return CHARACTER_REQUIREMENT_TEXT % needed
	return "Richiede %s livello %d" % [_skill_name(key, data), needed]
