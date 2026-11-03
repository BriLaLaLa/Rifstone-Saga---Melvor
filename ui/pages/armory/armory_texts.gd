class_name ArmoryTexts
extends RefCounted
## Texts of the Armory page and of its piece panel (docs/01_GDD.md §21-22), without state: everything is built from
## what the caller read from the session (an `ItemInstance` copy, modifier lists) and from the game data.
##
## Modifier lines take name and format from `StatRegistry.info()` through `ItemTooltipLines`; rarity names and
## affix grades are presentation texts (docs/OPEN_QUESTIONS.md Q42 for the same rule on styles).

const LOG_CATEGORY: String = "ui"
const RARITY_NAMES: Dictionary[StringName, String] = {
	&"common": "Comune", &"magic": "Magico", &"rare": "Raro",
}
const UPGRADE_TEXT: String = "+%d"
const AFFIX_GRADE_TEXT: String = "grado %d"
const LEVEL_TEXT: String = "Livello oggetto %d"
const KIND_NAMES: Dictionary[StringName, String] = {
	&"sword": "Spada", &"greatsword": "Spadone", &"shield": "Scudo",
}


static func rarity_name(rarity: StringName) -> String:
	if not RARITY_NAMES.has(rarity):
		Log.warn(LOG_CATEGORY, "armory: unknown rarity '%s'" % rarity)
		return String(rarity)
	return RARITY_NAMES[rarity]


static func kind_name(kind: StringName) -> String:
	return KIND_NAMES.get(kind, String(kind))


## "Name +N" for an upgraded piece, "Name" otherwise.
static func piece_name(inst: ItemInstance, base: ItemDef) -> String:
	if inst.upgrade > 0:
		return "%s %s" % [base.name, UPGRADE_TEXT % inst.upgrade]
	return base.name


## One BBCode line per rolled affix: "<affix name> <value> (grado N)". An affix missing from the data is skipped
## (and logged): the panel never invents names.
static func affix_lines(inst: ItemInstance, data: GameData) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	for roll: AffixRoll in inst.affixes:
		var def: AffixDef = data.affix(roll.affix_id)
		if def == null or not data.stats.has(def.stat):
			Log.warn(LOG_CATEGORY, "armory: affix '%s' is not in the data, no line shown" % roll.affix_id)
			continue
		var info: Dictionary = data.stats.info(def.stat)
		var value: String = ItemTooltipLines.format_stat(info["format"] as String, roll.value)
		lines.append("%s [color=#%s][b]%s[/b][/color] [color=#%s](%s)[/color]" % [
			ItemTooltipLines.escape(def.name), UiStyle.GOLD_LIGHT.to_html(false), value,
			UiStyle.TEXT_2.to_html(false), AFFIX_GRADE_TEXT % roll.tier])
	return lines


## Lines of the difference "candidate minus worn" for every (stat, scope) whose totals differ; same format as the
## modifier lines. Modifiers of the same stat and scope are summed first.
static func comparison_lines(candidate: Array[Modifier], worn: Array[Modifier], data: GameData) -> PackedStringArray:
	var diff: Dictionary[String, Modifier] = {}
	_accumulate(diff, candidate, 1.0)
	_accumulate(diff, worn, -1.0)
	var changed: Array[Modifier] = []
	var keys: Array = diff.keys()
	keys.sort()
	for key: String in keys:
		if not is_zero_approx(diff[key].value):
			changed.append(diff[key])
	return ItemTooltipLines.modifier_lines(changed, data)


static func _accumulate(into: Dictionary[String, Modifier], mods: Array[Modifier], sign_factor: float) -> void:
	for mod: Modifier in mods:
		var key: String = "%s|%s|%s" % [mod.stat, mod.scope_kind, mod.scope_id]
		if not into.has(key):
			into[key] = Modifier.make(mod.stat, 0.0, mod.scope_kind, mod.scope_id)
		into[key].value += mod.value * sign_factor
