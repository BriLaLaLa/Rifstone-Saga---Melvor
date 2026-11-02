class_name ItemTooltipLines
extends RefCounted
## Builds the BBCode lines of an item tooltip from an ItemDef (display only, no game state).
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
	&"equipment": "Equipaggiamento",
	&"tool": "Attrezzo",
	&"food": "Cibo",
	&"infusion": "Infusione",
	&"misc": "Varie",
}
const FORMAT_PCT: String = "pct"
const FORMAT_FLAT: String = "flat"
const FORMAT_FLAG: String = "flag"
## Numbers are shown with at most two decimals.
const HUNDREDTHS: int = 100


## Subtitle under the name: category and, when `count` > 0, the quantity.
static func subtitle(item: ItemDef, count: int) -> String:
	var parts: PackedStringArray = PackedStringArray([category_name(item.category)])
	if count > 0:
		parts.append("Quantità: %s" % format_int(count))
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
			lines.append(_weapon_line(item.equip.weapon, data))
		lines.append_array(modifier_lines(item.equip.modifiers, data))
	if item.is_infusion() and has_data:
		lines.append_array(modifier_lines(item.infusion_modifiers, data))
		if item.infusion_unique:
			lines.append(_muted("Unica: non si incastona in più prese"))
	if item.is_food():
		lines.append("Cura %s punti vita" % _value(format_int(item.food_heal)))
	if item.value > 0:
		lines.append(_muted("Valore: %s oro" % format_int(item.value)))
	else:
		lines.append(_muted("Non vendibile"))
	return lines


## One line per modifier whose stat is registered: "<name> <value>[ (<scope>)]".
static func modifier_lines(mods: Array[Modifier], data: GameData) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	for mod: Modifier in mods:
		if not data.stats.has(mod.stat):
			Log.warn(LOG_CATEGORY, "tooltip: stat '%s' is not registered, no line shown" % mod.stat)
			continue
		var info: Dictionary = data.stats.info(mod.stat)
		var line: String = "%s %s" % [escape(info["name"] as String), _value(format_stat(info["format"] as String,
				mod.value))]
		var scope: String = _scope_name(mod, data)
		if not scope.is_empty():
			line += " " + _muted("(%s)" % scope)
		lines.append(line)
	return lines


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
	return format_number(value)


static func category_name(category: StringName) -> String:
	if not CATEGORY_NAMES.has(category):
		Log.warn(LOG_CATEGORY, "tooltip: unknown item category '%s'" % category)
		return String(category)
	return CATEGORY_NAMES[category]


## Integer with "." as thousands separator (1250 -> "1.250").
static func format_int(value: int) -> String:
	var digits: String = str(absi(value))
	var out: String = ""
	while digits.length() > 3:
		out = "." + digits.right(3) + out
		digits = digits.left(digits.length() - 3)
	return ("-" if value < 0 else "") + digits + out


## Number in Italian notation: thousands with ".", decimals with "," (at most two, no trailing zeros).
@warning_ignore("integer_division")
static func format_number(value: float) -> String:
	var hundredths: int = roundi(absf(value) * HUNDREDTHS)
	var text: String = ("-" if value < 0.0 and hundredths > 0 else "") + format_int(hundredths / HUNDREDTHS)
	var fraction: String = ("%02d" % (hundredths % HUNDREDTHS)).rstrip("0")
	if not fraction.is_empty():
		text += "," + fraction
	return text


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
		lines.append(_muted("Richiede %s livello %d" % [_skill_name(skill_id, data), equip.requirements[skill_id]]))
	return lines


static func _weapon_line(weapon: WeaponInfo, data: GameData) -> String:
	var seconds: String = format_number(weapon.attack_interval_ms / 1000.0)
	var line: String = "Stile %s, un attacco ogni %s s" % [_skill_name(weapon.style, data), _value(seconds)]
	if weapon.two_handed:
		line += ", a due mani"
	return line


## Display name of a modifier scope; empty for global modifiers.
static func _scope_name(mod: Modifier, data: GameData) -> String:
	match mod.scope_kind:
		&"skill":
			return _skill_name(mod.scope_id, data)
		&"action":
			var action: ActionDef = data.action(mod.scope_id)
			return escape(action.name) if action != null else String(mod.scope_id)
	return ""


## Skill name from the data; an unknown id (already logged by GameData) is shown as the id.
static func _skill_name(skill_id: StringName, data: GameData) -> String:
	var skill: SkillDef = data.skill(skill_id)
	return escape(skill.name) if skill != null else String(skill_id)


static func _signed(value: float) -> String:
	return ("+" if value > 0.0 else "") + format_number(value)


static func _value(text: String) -> String:
	return "[color=#%s][b]%s[/b][/color]" % [UiStyle.GOLD_LIGHT.to_html(false), text]


static func _muted(text: String) -> String:
	return "[color=#%s]%s[/color]" % [UiStyle.TEXT_2.to_html(false), text]
