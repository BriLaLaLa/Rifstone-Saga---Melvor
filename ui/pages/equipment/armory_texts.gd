class_name ArmoryTexts
extends RefCounted
## Texts of the Equipment page (docs/UI_GDR.md §3) and of the piece tooltip, without state: everything is built from
## what the caller read from the session (an `ItemInstance` copy, modifier lists) and from the game data.
##
## Modifier lines take name and format from `StatRegistry.info()` through `ItemTooltipLines`; rarity names and
## affix grades are presentation texts (docs/OPEN_QUESTIONS.md Q42 for the same rule on styles). The comparison with
## the piece worn in the same slot sums the modifiers of both pieces (`armory.instance_modifiers`) and the weapon
## interval of the data: no formula is written here.

const LOG_CATEGORY: String = "ui"
const RARITY_NAMES: Dictionary[StringName, String] = {
	&"common": "Comune", &"magic": "Magico", &"rare": "Raro", &"masterwork": "Capolavoro", &"legendary": "Leggendario",
}
## Stats where a lower value is the better one (shown green when they go down); the registry has no polarity.
const LOWER_IS_BETTER: Array[StringName] = [&"skill_interval_pct", &"attack_interval_pct"]
## Titles of the tabs of the Forge bench, in tab order: refine, sockets, currencies.
const BENCH_TAB_TITLES: Array[String] = ["Raffina", "Castoni", "Valute"]
const CAPACITY_TEXT: String = "Deposito: %s / %s"
const CAPACITY_WORN_TEXT: String = "Deposito: %s / %s (+%s indossati)"
const UPGRADE_TEXT: String = "+%d"
const AFFIX_GRADE_TEXT: String = "grado %d"
const LEVEL_TEXT: String = "Livello oggetto %d"
const SUBTITLE_TEXT: String = "%s  ·  %s  ·  Slot: %s"
const REQUIREMENTS_TITLE: String = "Requisiti"
const WEAPON_TITLE: String = "Arma"
const ARMOR_TITLE: String = "Protezione"
const LEGENDARY_TITLE: String = "Effetto leggendario"
const LEGENDARY_SOURCE_TEXT: String = "Fonte: %s (%s%%)"
const LEGENDARY_SOURCE_MONOLITH_TEXT: String = "Monolito: %s"
const LEGENDARY_SOURCE_BOSS_TEXT: String = "Boss: %s"
const PHYSICAL_REDUCTION_TEXT: String = "Armatura: riduce il danno fisico del %s%%"
const ARCANE_REDUCTION_TEXT: String = "Barriera: riduce il danno arcano del %s%%"
const REDUCTION_NOTE_TEXT: String = "Contro nemici del tuo livello."
const AFFIXES_TITLE: String = "Affissi"
const MODIFIERS_TITLE: String = "Statistiche"
const COMPARISON_TITLE: String = "Rispetto a %s"
const NO_DIFFERENCE_TEXT: String = "Nessuna differenza."
const INTERVAL_TEXT: String = "intervallo d'attacco (s)"
const UNARMED_TEXT: String = "Mani nude"
const SETUP_CHANGE_TEXT: String = "Assetto: %s → %s"
const NO_SETUP_TEXT: String = "Nessun assetto con questa combinazione di armi."
const COLOR_TAG: String = "[color=#%s]%s[/color]"
const WEAPON_SLOT: StringName = &"weapon"
const OFFHAND_SLOT: StringName = &"offhand"


## "Deposito: used / capacity", plus "(+N indossati)" when some pieces are worn (they do not use the capacity).
static func capacity_text(used: int, capacity: int, worn: int) -> String:
	if worn > 0:
		return CAPACITY_WORN_TEXT % [NumberFormat.format_int(used), NumberFormat.format_int(capacity),
				NumberFormat.format_int(worn)]
	return CAPACITY_TEXT % [NumberFormat.format_int(used), NumberFormat.format_int(capacity)]


static func rarity_name(rarity: StringName) -> String:
	if not RARITY_NAMES.has(rarity):
		Log.warn(LOG_CATEGORY, "armory: unknown rarity '%s'" % rarity)
		return String(rarity)
	return RARITY_NAMES[rarity]


## "Name +N" for an upgraded piece, "Name" otherwise.
static func piece_name(inst: ItemInstance, base: ItemDef) -> String:
	if inst.upgrade > 0:
		return "%s %s" % [base.name, UPGRADE_TEXT % inst.upgrade]
	return base.name


## "Rarity  ·  Livello oggetto N  ·  Slot".
static func subtitle(inst: ItemInstance, base: ItemDef, data: GameData) -> String:
	return SUBTITLE_TEXT % [rarity_name(inst.rarity), LEVEL_TEXT % inst.ilvl,
			EquipmentStatsText.slot_text(base.equip.slot, data)]


## Item card line (docs/UI_GDR.md): "Slot  ·  Livello oggetto N  ·  +N".
static func card_subtitle(inst: ItemInstance, base: ItemDef, data: GameData) -> String:
	var text: String = "%s  ·  %s" % [EquipmentStatsText.slot_text(base.equip.slot, data), LEVEL_TEXT % inst.ilvl]
	return text if inst.upgrade <= 0 else "%s  ·  %s" % [text, UPGRADE_TEXT % inst.upgrade]


## BBCode lines of the top block of the item card: requirements (red if unmet), weapon and stats (no affixes, no
## comparison).
static func card_top_lines(session: GameSession, uid: int) -> PackedStringArray:
	return detail_lines(session, uid, false, false)


## BBCode lines of the affix block of the item card.
static func card_affix_lines(session: GameSession, uid: int) -> PackedStringArray:
	var inst: ItemInstance = session.armory.get_instance(uid)
	var lines: PackedStringArray = PackedStringArray()
	if inst != null:
		_append_section(lines, AFFIXES_TITLE, affix_lines(inst, session.data))
	return lines


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


## BBCode body of the tooltip of the piece `uid`: title in the rarity color, subtitle, then `detail_lines`.
## Empty if the piece is not in the armory.
static func tooltip_text(session: GameSession, uid: int) -> String:
	var inst: ItemInstance = session.armory.get_instance(uid)
	var base: ItemDef = session.data.item(inst.base_id) if inst != null else null
	if base == null or base.equip == null:
		return ""
	var lines: PackedStringArray = PackedStringArray([
		ItemTooltipLines.colored_title(piece_name(inst, base), UiStyle.rarity_color(inst.rarity)),
		COLOR_TAG % [UiStyle.TEXT_2.to_html(false), subtitle(inst, base, session.data)],
	])
	lines.append_array(detail_lines(session, uid))
	return "\n".join(lines)


## Requirements (red if unmet), weapon, affixes, modifiers, and the comparison with the piece worn in the same slot.
static func detail_lines(session: GameSession, uid: int, with_affixes: bool = true,
		with_comparison: bool = true) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var inst: ItemInstance = session.armory.get_instance(uid)
	var base: ItemDef = session.data.item(inst.base_id) if inst != null else null
	if base == null or base.equip == null:
		return lines
	var data: GameData = session.data
	_append_requirements(lines, base.equip, session)
	if base.equip.weapon != null:
		_append_section(lines, WEAPON_TITLE, weapon_lines(session, inst, base))
	if with_affixes:
		_append_section(lines, AFFIXES_TITLE, affix_lines(inst, data))
	var mods: Array[Modifier] = session.armory.instance_modifiers(uid)
	_append_section(lines, MODIFIERS_TITLE, ItemTooltipLines.modifier_lines(mods, data))
	_append_section(lines, ARMOR_TITLE, armor_lines(session, mods))
	_append_section(lines, LEGENDARY_TITLE, legendary_lines(session, base))
	if with_comparison:
		_append_comparison(lines, session, uid, base, mods)
	return lines


## The modifiers whose (stat, scope) total differs between `candidate` and `worn` (candidate minus worn).
static func diff_modifiers(candidate: Array[Modifier], worn: Array[Modifier]) -> Array[Modifier]:
	var diff: Dictionary[String, Modifier] = {}
	_accumulate(diff, candidate, 1.0)
	_accumulate(diff, worn, -1.0)
	var changed: Array[Modifier] = []
	var keys: Array = diff.keys()
	keys.sort()
	for key: String in keys:
		if not is_zero_approx(diff[key].value):
			changed.append(diff[key])
	return changed


## True if the change `value` of `stat` improves the character.
static func is_improvement(stat: StringName, value: float) -> bool:
	return value < 0.0 if LOWER_IS_BETTER.has(stat) else value > 0.0


## "Assetto: A → B" when equipping `base` in its own slot changes the weapon setup (F-72, `ClassDef.setup_for`);
## the warning when the pair of weapons has no setup; empty if nothing changes or the slot is not a hand.
static func setup_change_line(session: GameSession, base: ItemDef) -> String:
	var cls: ClassDef = session.character.class_def()
	var slot: StringName = base.equip.slot
	if cls == null or (slot != WEAPON_SLOT and slot != OFFHAND_SLOT):
		return ""
	var main: ItemDef = _worn_def(session, WEAPON_SLOT)
	var second: ItemDef = _worn_def(session, OFFHAND_SLOT)
	if slot == WEAPON_SLOT:
		main = base
		if base.equip.weapon != null and base.equip.weapon.two_handed:
			second = null
	else:
		second = base
	if main == null:
		return ""
	var after: SetupDef = cls.setup_for(main.equip.kind, second.equip.kind if second != null else &"")
	if after == null:
		return COLOR_TAG % [UiStyle.BAD.to_html(false), NO_SETUP_TEXT]
	var current: SetupDef = session.equipment.setup_def()
	if current != null and current.id == after.id:
		return ""
	return COLOR_TAG % [UiStyle.TEXT_2.to_html(false), SETUP_CHANGE_TEXT % [
			current.name if current != null else UNARMED_TEXT, after.name]]


static func _worn_def(session: GameSession, slot: StringName) -> ItemDef:
	return session.data.item(session.equipment.get_item(slot)) if session.equipment.get_uid(slot) != 0 else null


static func _accumulate(into: Dictionary[String, Modifier], mods: Array[Modifier], sign_factor: float) -> void:
	for mod: Modifier in mods:
		var key: String = "%s|%s|%s" % [mod.stat, mod.scope_kind, mod.scope_id]
		if not into.has(key):
			into[key] = Modifier.make(mod.stat, 0.0, mod.scope_kind, mod.scope_id)
		into[key].value += mod.value * sign_factor


static func _append_requirements(lines: PackedStringArray, equip: EquipInfo, session: GameSession) -> void:
	var keys: Array[StringName] = []
	for key: StringName in equip.requirements:
		keys.append(key)
	keys.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	var req_lines: PackedStringArray = PackedStringArray()
	for key: StringName in keys:
		var needed: int = equip.requirements[key]
		var text: String = ItemTooltipLines.requirement_text(key, needed, session.data)
		var met: bool = session.character.meets_requirements({key: needed})
		req_lines.append(text if met else COLOR_TAG % [UiStyle.BAD.to_html(false), text])
	_append_section(lines, REQUIREMENTS_TITLE, req_lines)


static func _append_section(lines: PackedStringArray, title: String, body: PackedStringArray) -> void:
	if body.is_empty():
		return
	lines.append(COLOR_TAG % [UiStyle.GOLD.to_html(false), title])
	lines.append_array(body)


## Difference with the piece worn in the same slot (nothing if this one is worn or the slot is empty), green for
## what improves and red for what worsens, then the weapon setup that would result.
static func _append_comparison(lines: PackedStringArray, session: GameSession, uid: int, base: ItemDef,
		mods: Array[Modifier]) -> void:
	if session.equipment.slot_of(uid) != &"":
		return
	var data: GameData = session.data
	var worn_uid: int = session.equipment.get_uid(base.equip.slot)
	var worn: ItemInstance = session.armory.get_instance(worn_uid) if worn_uid != 0 else null
	var worn_base: ItemDef = data.item(worn.base_id) if worn != null else null
	if worn_base != null:
		var diff: PackedStringArray = PackedStringArray()
		for mod: Modifier in diff_modifiers(mods, session.armory.instance_modifiers(worn_uid)):
			if data.stats.has(mod.stat):
				diff.append(_diff_line(mod, data))
		_append_interval_diff(diff, base, worn_base)
		if diff.is_empty():
			diff.append(NO_DIFFERENCE_TEXT)
		_append_section(lines, COMPARISON_TITLE % ItemTooltipLines.escape(piece_name(worn, worn_base)), diff)
	var setup_line: String = setup_change_line(session, base)
	if not setup_line.is_empty():
		lines.append(setup_line)


static func _diff_line(mod: Modifier, data: GameData) -> String:
	var info: Dictionary = data.stats.info(mod.stat)
	var line: String = "%s %s" % [ItemTooltipLines.escape(info["name"] as String),
			ItemTooltipLines.format_stat(info["format"] as String, mod.value)]
	var scope: String = ItemTooltipLines.scope_name(mod, data)
	if not scope.is_empty():
		line += " (%s)" % scope
	return _colored(line, is_improvement(mod.stat, mod.value))


static func _append_interval_diff(diff: PackedStringArray, base: ItemDef, worn_base: ItemDef) -> void:
	if base.equip.weapon == null or worn_base.equip.weapon == null:
		return
	var delta_ms: int = base.equip.weapon.attack_interval_ms - worn_base.equip.weapon.attack_interval_ms
	if delta_ms != 0:
		var seconds: String = ItemTooltipLines.format_stat(ItemTooltipLines.FORMAT_FLAT, delta_ms / 1000.0)
		diff.append(_colored("%s %s" % [seconds, INTERVAL_TEXT], delta_ms < 0))


static func _colored(text: String, good: bool) -> String:
	return COLOR_TAG % [(UiStyle.GOOD if good else UiStyle.BAD).to_html(false), text]


## Weapon block (GDD §28.2): style and interval (F-26 over the character's modifiers), minimum-maximum damage of this
## piece (`WeaponMath.damage_range`, rarity and refinement included) and damage per second (`WeaponMath.dps`, F-22).
static func weapon_lines(session: GameSession, inst: ItemInstance, base: ItemDef) -> PackedStringArray:
	var data: GameData = session.data
	var pct: float = session.modifiers.total(&"attack_interval_pct")
	var interval_ms: int = CombatMath.attack_interval_ms(base.equip.weapon.attack_interval_ms, pct, data)
	var span: Vector2 = WeaponMath.damage_range(inst, data)
	return PackedStringArray([ItemTooltipLines.weapon_line(base.equip.weapon, interval_ms),
			ItemTooltipLines.damage_line(span.x, span.y),
			ItemTooltipLines.dps_line(WeaponMath.dps(inst, pct, data))])


## Protection block (GDD §28.3): the % damage reduction of the Armour and Barrier this piece gives (`ArmorMath.reduction_pct`
## on its own `armor` / `barrier` modifiers) against an attacker of the character's level. Empty for a piece without them.
static func armor_lines(session: GameSession, mods: Array[Modifier]) -> PackedStringArray:
	var armor: float = 0.0
	var barrier: float = 0.0
	for mod: Modifier in mods:
		if mod.stat == &"armor":
			armor += mod.value
		elif mod.stat == &"barrier":
			barrier += mod.value
	var lines: PackedStringArray = PackedStringArray()
	var level: int = session.character.get_level()
	if armor > 0.0:
		lines.append(PHYSICAL_REDUCTION_TEXT % NumberFormat.format_number(snappedf(
				ArmorMath.reduction_pct(int(armor), level, session.data), 0.1)))
	if barrier > 0.0:
		lines.append(ARCANE_REDUCTION_TEXT % NumberFormat.format_number(snappedf(
				ArmorMath.reduction_pct(int(barrier), level, session.data), 0.1)))
	if not lines.is_empty():
		lines.append(COLOR_TAG % [UiStyle.TEXT_2.to_html(false), REDUCTION_NOTE_TEXT])
	return lines


## Legendary block (GDD §28.5): the effect in words (the `description` of the base, which the data write with their
## numbers) and, once the piece is discovered, its source (boss or Monolith of the data) and the base chance.
static func legendary_lines(session: GameSession, base: ItemDef) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var info: LegendaryInfo = base.equip.legendary
	if info == null:
		return lines
	lines.append(ItemTooltipLines.escape(base.description))
	if session.discoveries.has(base.id):
		var source_name: String = String(info.source_id)
		if info.source_type == LegendaryInfo.SOURCE_BOSS:
			var boss: BossDef = session.data.boss(info.source_id)
			source_name = LEGENDARY_SOURCE_BOSS_TEXT % (boss.name if boss != null else source_name)
		elif session.data.has_rift_stone(info.source_id):
			source_name = LEGENDARY_SOURCE_MONOLITH_TEXT % session.data.rift_stone(info.source_id).name
		lines.append(COLOR_TAG % [UiStyle.TEXT_2.to_html(false), LEGENDARY_SOURCE_TEXT % [
				ItemTooltipLines.escape(source_name), GuideDrops.pct_text(info.chance_pct)]])
	return lines
