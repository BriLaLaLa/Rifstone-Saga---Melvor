class_name GuideTables
extends RefCounted
## Tables of the Guide generated from the data (docs/05_INTERFACES.md §5.19): rows of text, the first one is the header.
## Every number is read from GameData at the moment of the call; nothing is copied.
##
## Sources: the fixed `ids()` plus the families `actions:<skill>`, `area_monsters:<area>`, `monster_drops:<monster>`,
## `mastery_milestones:<skill>` (a gathering skill).

const LOG_CATEGORY: String = "guide"
const MS_PER_SEC: float = 1000.0
const FIXED_IDS: Array[String] = ["affix_tiers", "refine_costs", "tool_upgrades", "traits", "abilities", "stats",
	"bags", "helper_grades", "engraver_recipes",
	"infusions"]
const PREFIX_ACTIONS: String = "actions:"
const PREFIX_AREA_MONSTERS: String = "area_monsters:"
const PREFIX_MONSTER_DROPS: String = "monster_drops:"
const PREFIX_MILESTONES: String = "mastery_milestones:"
const ENGRAVER_SKILL: StringName = &"riftbinding"


## Declared fixed sources (the `<family>:<id>` ones are listed in the header comment).
static func ids() -> PackedStringArray:
	return PackedStringArray(FIXED_IDS)


static func build(source: String, data: GameData) -> Array[Array]:
	var rows: Array[Array] = []
	match source:
		"affix_tiers":
			rows = _affix_tiers(data)
		"refine_costs":
			rows = _refine_costs(data)
		"tool_upgrades":
			rows = _tool_upgrades(data)
		"traits":
			rows = _traits(data)
		"abilities":
			rows = _abilities(data)
		"stats":
			rows = _stats(data)
		"infusions":
			rows = _infusions(data)
		"bags":
			rows = _bags(data)
		"helper_grades":
			rows = _helper_grades(data)
		"engraver_recipes":
			rows = _engraver_recipes(data)
		_:
			rows = _family(source, data)
	if rows.is_empty():
		Log.error(LOG_CATEGORY, "guide table: unknown or empty source '%s'" % source)
	return rows


## Every page: the hand-written ones (GameData.guide_pages, M11-02) and one generated page per entity.
static func page_ids(data: GameData) -> Array[StringName]:
	var result: Array[StringName] = []
	if data.has_method("guide_pages"):
		for page: Variant in data.call("guide_pages") as Array:
			result.append(GuideIndex.entry(&"page", StringName((page as RefCounted).get("id"))))
	for item: ItemDef in data.items():
		result.append(GuideIndex.entry(&"item", item.id))
	var seen: Dictionary[StringName, bool] = {}
	for area: AreaDef in data.areas():
		result.append(GuideIndex.entry(&"area", area.id))
		for monster_id: StringName in area.monster_ids:
			if not seen.has(monster_id):
				seen[monster_id] = true
				result.append(GuideIndex.entry(&"monster", monster_id))
	for skill: SkillDef in data.skills():
		result.append(GuideIndex.entry(&"skill", skill.id))
	for stat_id: StringName in data.stats.ids():
		result.append(GuideIndex.entry(&"stat", stat_id))
	for class_def: ClassDef in data.classes():
		for trait_def: TraitDef in class_def.traits:
			result.append(GuideIndex.entry(&"trait", trait_def.id))
		for ability: AbilityDef in class_def.abilities:
			result.append(GuideIndex.entry(&"ability", ability.id))
	return result


static func _family(source: String, data: GameData) -> Array[Array]:
	if source.begins_with(PREFIX_ACTIONS):
		return _actions(StringName(source.trim_prefix(PREFIX_ACTIONS)), data)
	if source.begins_with(PREFIX_AREA_MONSTERS):
		return _area_monsters(StringName(source.trim_prefix(PREFIX_AREA_MONSTERS)), data)
	if source.begins_with(PREFIX_MONSTER_DROPS):
		return _monster_drops(StringName(source.trim_prefix(PREFIX_MONSTER_DROPS)), data)
	if source.begins_with(PREFIX_MILESTONES):
		return _milestones(StringName(source.trim_prefix(PREFIX_MILESTONES)), data)
	return []


static func _n(value: float) -> String:
	return GuideIndex.num(value)


static func _stat_name(stat: StringName, data: GameData) -> String:
	return String(data.stats.info(stat).get("name", stat)) if data.stats.has(stat) else String(stat)


static func _item_name(item_id: StringName, data: GameData) -> String:
	return data.item(item_id).name if data.has_item(item_id) else String(item_id)


static func _qty_list(list: Array[ItemQty], data: GameData) -> String:
	var parts: PackedStringArray = []
	for entry: ItemQty in list:
		parts.append("%d %s" % [entry.qty, _item_name(entry.item_id, data)])
	return ", ".join(parts)


static func _affix_tiers(data: GameData) -> Array[Array]:
	var rows: Array[Array] = [["Affisso", "Statistica", "Grado", "Livello oggetto minimo", "Valore"]]
	var seen: Dictionary[StringName, bool] = {}
	for item: ItemDef in data.items():
		if not item.is_equippable():
			continue
		for affix: AffixDef in data.affixes_for_slot(item.equip.slot):
			if seen.has(affix.id):
				continue
			seen[affix.id] = true
			for index: int in affix.tiers.size():
				var tier: AffixTier = affix.tiers[index]
				rows.append([affix.name, _stat_name(affix.stat, data), str(index + 1), str(tier.min_ilvl),
						"%s - %s" % [_n(tier.min), _n(tier.max)]])
	return rows


static func _refine_costs(data: GameData) -> Array[Array]:
	var rows: Array[Array] = [["Raffinazione", "Successo (%)", "Oro per grado", "Lingotti", "Frammenti del Rift"]]
	var levels: Array = data.balance_value("upgrade.levels") as Array
	for index: int in levels.size():
		var row: Dictionary = levels[index] as Dictionary
		rows.append(["+%d" % (index + 1), _n(float(row["success_pct"])), _n(float(row["gold_per_grade"])),
				_n(float(row["ingots"])), _n(float(row["shards"]))])
	return rows


static func _tool_upgrades(data: GameData) -> Array[Array]:
	var rows: Array[Array] = [["Livello del mestiere", "Grado", "Piastre", "Manici", "Oro"]]
	for row_variant: Variant in data.balance_value("tool_upgrade.levels") as Array:
		var row: Dictionary = row_variant as Dictionary
		rows.append([_n(float(row["min_level"])), _n(float(row["grade"])), _n(float(row["plates"])),
				_n(float(row["handles"])), _n(float(row["gold"]))])
	return rows


static func _traits(data: GameData) -> Array[Array]:
	var rows: Array[Array] = [["Tratto", "Livello", "Descrizione"]]
	for class_def: ClassDef in data.classes():
		for trait_def: TraitDef in class_def.traits:
			rows.append([trait_def.name, str(trait_def.unlock_level), LoadoutDescribe.trait_text(trait_def, data, class_def)])
	return rows


static func _abilities(data: GameData) -> Array[Array]:
	var rows: Array[Array] = [["Abilità", "Livello", "Ricarica (s)", "Descrizione"]]
	for class_def: ClassDef in data.classes():
		for ability: AbilityDef in class_def.abilities:
			rows.append([ability.name, str(ability.unlock_level), _n(ability.cooldown_ms / MS_PER_SEC),
					LoadoutDescribe.ability_text(ability, data, class_def)])
	return rows


static func _stats(data: GameData) -> Array[Array]:
	var rows: Array[Array] = [["Statistica", "Descrizione", "Minimo", "Massimo"]]
	for stat_id: StringName in data.stats.ids():
		var info: Dictionary = data.stats.info(stat_id)
		rows.append([String(info.get("name", stat_id)), String(info.get("description", "")),
				_n(float(info.get("min", 0))), _n(float(info.get("max", 0)))])
	return rows


static func _infusions(data: GameData) -> Array[Array]:
	var rows: Array[Array] = [["Runa", "Effetto"]]
	for item: ItemDef in data.items():
		if item.is_infusion():
			rows.append([item.name, item.description])
	return rows


static func _actions(skill_id: StringName, data: GameData) -> Array[Array]:
	var rows: Array[Array] = []
	if data.skills().filter(func(s: SkillDef) -> bool: return s.id == skill_id).is_empty():
		return rows
	rows.append(["Azione", "Livello", "XP", "Durata (s)", "Ingredienti", "Prodotto"])
	for action: ActionDef in data.actions_for_skill(skill_id):
		rows.append([action.name, str(action.level), _n(action.xp), _n(action.interval_ms / MS_PER_SEC),
				_qty_list(action.inputs, data), _qty_list(action.outputs, data)])
	return rows


static func _area_monsters(area_id: StringName, data: GameData) -> Array[Array]:
	var rows: Array[Array] = []
	if not data.has_area(area_id):
		return rows
	rows.append(["Mostro", "Punti vita", "Stile", "Intervallo (s)"])
	for monster_id: StringName in data.area(area_id).monster_ids:
		var monster: MonsterDef = data.monster(monster_id)
		rows.append([monster.name, str(monster.hp), String(monster.style), _n(monster.attack_interval_ms / MS_PER_SEC)])
	return rows


static func _monster_drops(monster_id: StringName, data: GameData) -> Array[Array]:
	var rows: Array[Array] = []
	if not data.has_monster(monster_id):
		return rows
	rows.append(["Oggetto", "Probabilità (%)", "Quantità"])
	for drop: DropEntry in data.monster(monster_id).drops:
		var qty: String = _n(drop.qty_min) if drop.qty_min == drop.qty_max else "%d - %d" % [drop.qty_min, drop.qty_max]
		rows.append([_item_name(drop.item_id, data), _n(drop.chance_pct), qty])
	return rows


static func _bags(data: GameData) -> Array[Array]:
	var rows: Array[Array] = [["Borsa", "Caselle aggiunte"]]
	for item: ItemDef in data.items():
		if item.is_bag():
			rows.append([item.name, str(item.bag_slots)])
	return rows


## Helper grades in the order of the data: the helper takes `interval_mult` times the player's interval (F-101).
static func _helper_grades(data: GameData) -> Array[Array]:
	var rows: Array[Array] = [["Grado", "Durata rispetto a te"]]
	for grade: HelperGradeDef in data.helper_grades():
		rows.append([HelperGradeNames.name_of(grade.id), "x%s" % _n(grade.interval_mult)])
	return rows


## Recipes of the Engraver. The success chance of a crystallization goes from the minimum (level 1) to the maximum (F-104).
static func _engraver_recipes(data: GameData) -> Array[Array]:
	var rows: Array[Array] = []
	if data.actions_for_skill(ENGRAVER_SKILL).is_empty():
		return rows
	rows.append(["Ricetta", "Livello", "Ingredienti", "Prodotto", "Probabilità (%)"])
	var low: float = float(data.balance_value("engraver.crystal_chance_min_pct"))
	var high: float = float(data.balance_value("engraver.crystal_chance_max_pct"))
	for action: ActionDef in data.actions_for_skill(ENGRAVER_SKILL):
		var chance: String = "%s - %s" % [_n(low), _n(high)] if action.kind == &"crystallize" else "-"
		rows.append([action.name, str(action.level), _qty_list(action.inputs, data), _qty_list(action.outputs, data), chance])
	return rows


## The three milestones of every action of a gathering skill: by-product, resource bonus and trade bonus.
static func _milestones(skill_id: StringName, data: GameData) -> Array[Array]:
	var rows: Array[Array] = []
	var found: bool = false
	for skill: SkillDef in data.skills():
		found = found or (skill.id == skill_id and skill.category == &"gathering")
	if not found:
		return rows
	var at: Dictionary = data.balance_value("mastery.milestones") as Dictionary
	rows.append(["Risorsa", "Maestria %s" % _n(float(at["byproduct_at"])), "Maestria %s" % _n(float(at["resource_at"])),
			"Maestria %s" % _n(float(at["trade_at"]))])
	for action: ActionDef in data.actions_for_skill(skill_id):
		var cells: Array = [action.name, "", "", ""]
		for index: int in action.milestones.size():
			var milestone: MilestoneDef = action.milestones[index]
			if milestone.type == MilestoneDef.TYPE_BYPRODUCT:
				cells[index + 1] = _item_name(milestone.item, data)
			else:
				cells[index + 1] = LoadoutDescribe.modifiers_text(milestone.modifiers, data)
		rows.append(cells)
	return rows
