class_name GameData
extends RefCounted
## The read-only game data (docs/05_INTERFACES.md §4, docs/03_ARCHITECTURE.md §10): loads the JSON files, validates
## them with DataValidator and builds the typed Defs.
##
## Loading problems (JsonLoader) and validation problems all go to `errors`; with any error the Defs are not built,
## `is_valid()` is false and every lookup fails (null + error): there is no partial or fallback data. A Def whose
## `from_dict` still returns null (it logs its own error) adds an entry with file and id to `errors`.
## Lists are returned as copies; the Defs are shared and read-only by convention.

const LOG_CATEGORY: String = "data"
const BALANCE_FILE: String = "balance.json"
const STATS_FILE: String = "stats.json"
## Content section -> file (single-file sections) or folder (every `.json` inside), relative to the content root.
const CONTENT_FILES: Dictionary[String, String] = {
	"skills": "skills/skills.json", "areas": "combat/areas.json", "monsters": "combat/monsters.json",
	"shop": "shop/shop.json", "affixes": "affixes/affixes.json",
	"rift_stones": "combat/rift_stones.json",
	"hints": "hints/hints.json", "loot_tables": LootIndex.FILE,  # M12: mandatory
	"map_mods": MapIndex.MODS_FILE, "bosses": MapIndex.BOSSES_FILE,  # M13: mandatory (may be empty)
	"village": VillageIndex.FILE,  # M19: mandatory (may be empty)
}
const CONTENT_DIRS: Dictionary[String, String] = {
	"items": "items", "actions": "actions", "mastery": "mastery", "classes": "classes",
}

var errors: PackedStringArray = []
var stats: StatRegistry = StatRegistry.new()

var _balance: Dictionary = {}
var _xp_table: XpTable = null
var _mastery_table: XpTable = null
var _items: Dictionary[StringName, ItemDef] = {}
var _item_list: Array[ItemDef] = []
var _skills: Dictionary[StringName, SkillDef] = {}
var _skill_list: Array[SkillDef] = []
var _actions: Dictionary[StringName, ActionDef] = {}
var _action_list: Array[ActionDef] = []
var _nodes: Dictionary[StringName, MasteryNodeDef] = {}
var _node_list: Array[MasteryNodeDef] = []
var _areas: Dictionary[StringName, AreaDef] = {}
var _area_list: Array[AreaDef] = []
var _monsters: Dictionary[StringName, MonsterDef] = {}
var _stones: Dictionary[StringName, RiftStoneDef] = {}
var _stones_by_area: Dictionary[StringName, Array] = {}  # area id -> Array[RiftStoneDef], by level
var _shop: Dictionary[StringName, ShopEntryDef] = {}
var _shop_list: Array[ShopEntryDef] = []
var _character_table: XpTable = null
var _classes: Dictionary[StringName, ClassDef] = {}
var _class_list: Array[ClassDef] = []
var _affixes: Dictionary[StringName, AffixDef] = {}
var _affix_list: Array[AffixDef] = []
var _hints: Dictionary[StringName, HintDef] = {}
var _hint_list: Array[HintDef] = []
var _guide: GuideBook = GuideBook.new()  # M11
var _helper: HelperIndex = HelperIndex.new()  # M12
var _loot: LootIndex = LootIndex.new()  # M12
var _maps: MapIndex = MapIndex.new()  # M13
var _village: VillageIndex = VillageIndex.new()  # M19
var _blueprint_list: Array[ItemDef] = []
var _blueprint_by_base: Dictionary[StringName, ItemDef] = {}
var _unique_tools: Dictionary[StringName, ItemDef] = {}  # slot -> unique tool (M10)

static func load_from_dirs(content_root: String = "res://data", config_root: String = "res://data/config") -> GameData:
	var data := GameData.new()
	var raw: Dictionary = {
		"balance": DataBuildUtil.read_files([config_root.path_join(BALANCE_FILE)], data.errors),
		"stats": DataBuildUtil.read_files([config_root.path_join(STATS_FILE)], data.errors),
	}
	for section: String in CONTENT_FILES:
		raw[section] = DataBuildUtil.read_files([content_root.path_join(CONTENT_FILES[section])], data.errors)
	for section: String in CONTENT_DIRS:
		raw[section] = DataBuildUtil.read_files(JsonLoader.list_json_files(content_root.path_join(CONTENT_DIRS[section]),
				data.errors), data.errors)
	raw["guide"] = DataBuildUtil.read_files(DataValidatorGuide.list_files(content_root, data.errors), data.errors)  # M11, optional
	DataValidator.validate(raw, data.errors)
	if data.errors.is_empty():
		data._build(raw)
	return data

func is_valid() -> bool: return errors.is_empty()

## The value at a dotted path of balance.json (e.g. "combat.respawn_ms"), as parsed from JSON: numbers are float,
## so integer parameters need `int()`. Objects and arrays are copies. A missing key logs an error and gives null.
func balance_value(path: String) -> Variant:
	var value: Variant = DataValidator.lookup(_balance, path)
	if value == null:
		Log.error(LOG_CATEGORY, "balance key '%s' not found" % path)
		return null
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	if value is Array:
		return (value as Array).duplicate(true)
	return value

## F-118: material grade (1..8) of a piece grade (1..15), `equipment.grade_material[g - 1]`; out of range: error, 0.
func material_grade(piece_grade: int) -> int: return EquipmentGrades.entry(self, "equipment.grade_material", piece_grade)

## F-118: character level of a piece grade (1..15), `equipment.grade_levels[g - 1]`; out of range: error, 0.
func grade_level(piece_grade: int) -> int: return EquipmentGrades.entry(self, "equipment.grade_levels", piece_grade)

## F-01 table from `xp_curve` (null when the data is not valid).
func xp_table() -> XpTable: return _xp_table

## F-09 table from `mastery_curve` (null when the data is not valid).
func mastery_table() -> XpTable: return _mastery_table

## F-71 table from `character_curve` (null when the data is not valid).
func character_xp_table() -> XpTable: return _character_table

func character_class(id: StringName) -> ClassDef: return _find(_classes, id, "class") as ClassDef

## Every class, by `order`.
func classes() -> Array[ClassDef]: return _class_list.duplicate()

func affix(id: StringName) -> AffixDef: return _find(_affixes, id, "affix") as AffixDef

## The affixes that can roll on an equipment slot (`head`, `weapon`, `tool_forestry`…), in file order.
func affixes_for_slot(slot: StringName) -> Array[AffixDef]:
	var result: Array[AffixDef] = []
	for def: AffixDef in _affix_list:
		if def.slots.has(slot):
			result.append(def)
	return result

func item(id: StringName) -> ItemDef: return _find(_items, id, "item") as ItemDef

func has_item(id: StringName) -> bool: return _items.has(id)

## Every item, in load order (files in alphabetical order, then file order).
func items() -> Array[ItemDef]: return _item_list.duplicate()

## Every blueprint item (M10), by grade then `sort_order`.
func blueprints() -> Array[ItemDef]: return _blueprint_list.duplicate()

## The blueprint of an equipment base (one per base). Null, without error, when there is none (rings, amulets, tools).
func blueprint_for_base(base_id: StringName) -> ItemDef: return _blueprint_by_base.get(base_id) as ItemDef

## M14: every legendary base (`equip.legendary`), in the order of the data.
func legendaries() -> Array[ItemDef]: return LegendaryIndex.all(_item_list)

## M14: the legendaries whose source is the boss or the Monolith `source_id` (`source_type` &"boss" / &"monolith").
func legendaries_from(source_type: StringName, source_id: StringName) -> Array[ItemDef]:
	return LegendaryIndex.from_source(_item_list, source_type, source_id)

## M14 (F-121): a base the drop pool can give: equipment that is neither a Masterwork nor a legendary.
func is_equipment_pool_base(base_id: StringName) -> bool:
	var equip: EquipInfo = _items[base_id].equip if _items.has(base_id) and _items[base_id].category == &"equipment" else null
	return equip != null and not equip.masterwork and equip.legendary == null

## The unique tool of a `tool_*` slot (M10); null and an error when the slot has none.
func unique_tool(slot: StringName) -> ItemDef: return _find(_unique_tools, slot, "unique tool slot") as ItemDef

func skill(id: StringName) -> SkillDef: return _find(_skills, id, "skill") as SkillDef

## Every skill, by `order`.
func skills() -> Array[SkillDef]: return _skill_list.duplicate()

## The skills of a category (`gathering`, `artisan`), by `order`; an unknown category is an error.
func skills_by_category(category: StringName) -> Array[SkillDef]:
	var result: Array[SkillDef] = []
	if not DataValidator.SKILL_CATEGORIES.has(String(category)):
		Log.error(LOG_CATEGORY, "unknown skill category '%s'" % category)
		return result
	for def: SkillDef in _skill_list:
		if def.category == category:
			result.append(def)
	return result

func action(id: StringName) -> ActionDef: return _find(_actions, id, "action") as ActionDef

## The actions of a skill, by `level` then id; an unknown skill is an error.
func actions_for_skill(skill_id: StringName) -> Array[ActionDef]:
	var result: Array[ActionDef] = []
	if _find(_skills, skill_id, "skill") == null:
		return result
	for def: ActionDef in _action_list:
		if def.skill_id == skill_id:
			result.append(def)
	return result

## The actions of a skill that give mastery (`mastery == true`), same order as `actions_for_skill`.
func mastery_actions_for_skill(skill_id: StringName) -> Array[ActionDef]:
	var result: Array[ActionDef] = []
	for def: ActionDef in actions_for_skill(skill_id):
		if def.mastery:
			result.append(def)
	return result

func mastery_node(id: StringName) -> MasteryNodeDef: return _find(_nodes, id, "mastery node") as MasteryNodeDef

## The mastery nodes of a skill, in file order; an unknown skill is an error.
func mastery_nodes(skill_id: StringName) -> Array[MasteryNodeDef]:
	var result: Array[MasteryNodeDef] = []
	if _find(_skills, skill_id, "skill") == null:
		return result
	for def: MasteryNodeDef in _node_list:
		if def.skill_id == skill_id:
			result.append(def)
	return result

func area(id: StringName) -> AreaDef: return _find(_areas, id, "area") as AreaDef

## Every area, by `order`.
func areas() -> Array[AreaDef]: return _area_list.duplicate()

func monster(id: StringName) -> MonsterDef: return _find(_monsters, id, "monster") as MonsterDef

## Existence checks without `push_error` (docs/05_INTERFACES.md §4).
func has_area(id: StringName) -> bool: return _areas.has(id)
func has_monster(id: StringName) -> bool: return _monsters.has(id)
func has_action(id: StringName) -> bool: return _actions.has(id)  # M14
func has_balance(path: String) -> bool: return DataValidator.lookup(_balance, path) != null  # M14: no error when absent

func has_rift_stone(id: StringName) -> bool: return _stones.has(id)
func rift_stone(id: StringName) -> RiftStoneDef: return _find(_stones, id, "rift stone") as RiftStoneDef

## The Rift Stones of an area (F-87, M15), ordered by `level`; empty (no error) when the area has none.
func rift_stones_for_area(area_id: StringName) -> Array[RiftStoneDef]:
	return Array(_stones_by_area.get(area_id, []) as Array, TYPE_OBJECT, &"RefCounted", RiftStoneDef)

func shop_entry(id: StringName) -> ShopEntryDef: return _find(_shop, id, "shop entry") as ShopEntryDef

## Every shop entry, in file order.
func shop_entries() -> Array[ShopEntryDef]: return _shop_list.duplicate()

## M19 (docs/04_DATA_SCHEMA.md §24): a Village building by id (null and an error if unknown); all of them, by `order`.
func village_building(id: StringName) -> VillageBuildingDef: return _find(_village.by_id, id, "village building") as VillageBuildingDef
func village_buildings() -> Array[VillageBuildingDef]: return _village.list.duplicate()

func hint(id: StringName) -> HintDef: return _find(_hints, id, "hint") as HintDef

## Every hint, in file order.
func hints() -> Array[HintDef]: return _hint_list.duplicate()

## M12: the helper grades of `helper.grades`, in order of grade (apprentice first).
func helper_grades() -> Array[HelperGradeDef]: return _helper.grades.duplicate()

## M12: a helper grade by id; null and an error if unknown.
func helper_grade(id: StringName) -> HelperGradeDef: return _find(_helper.by_id, id, "helper grade") as HelperGradeDef

## M12: the contract item of a gathering skill and a grade; null (no error) when there is none.
func contract_for(skill_id: StringName, grade_id: StringName) -> ItemDef: return _helper.contract_for(skill_id, grade_id)

## M12: a loot table by id; null and an error if unknown.
func loot_table(id: StringName) -> LootTableDef: return _find(_loot.by_id, id, "loot table") as LootTableDef

## M12: every loot table, in file order (empty without data/combat/loot_tables.json).
func loot_tables() -> Array[LootTableDef]: return _loot.list.duplicate()

## M11: the hand-written Guide pages by section, order and id.
func guide_pages() -> Array[GuidePageDef]: return _guide.list.duplicate()

func guide_page(id: StringName) -> GuidePageDef: return _find(_guide.by_id, id, "guide page") as GuidePageDef

## {"no_source": Array[StringName], "no_use": Array[StringName]} (empty lists without data/guide/exceptions.json).
func guide_exceptions() -> Dictionary: return _guide.exceptions.duplicate(true)

## M13 (docs/04_DATA_SCHEMA.md §11): the Card base of a grade 1..10 (null and an error if there is none); the modifiers
## in file order; a modifier by id; the boss of a grade and a boss by id (null and an error if unknown); a row of
## `fracture.grades` (F-110, grade 1..10).
func map_base(grade: int) -> ItemDef: return _find(_maps.bases, grade, "map base") as ItemDef
func map_mods() -> Array[MapModDef]: return _maps.mods.duplicate()
func map_mod(id: StringName) -> MapModDef: return _maps.mods_by_id.get(id) as MapModDef
func boss_for_grade(grade: int) -> BossDef: return _find(_maps.boss_by_grade, grade, "boss of grade") as BossDef
func boss(id: StringName) -> BossDef: return _find(_maps.bosses_by_id, id, "boss") as BossDef
func fracture_grade(grade: int) -> FractureGradeDef: return _find(_maps.grade_by_number, grade, "fracture grade") as FractureGradeDef

func _find(table: Dictionary, id: Variant, kind: String) -> RefCounted:
	if table.has(id):
		return table[id] as RefCounted
	Log.error(LOG_CATEGORY, "unknown %s '%s'" % [kind, id])
	return null

func _build(raw: Dictionary) -> void:
	_balance = (raw["balance"] as Dictionary).values()[0] as Dictionary
	stats = StatRegistry.from_array((raw["stats"] as Dictionary).values()[0]["stats"] as Array, errors)
	_xp_table = DataBuildUtil.curve(_balance, "xp_curve")
	_mastery_table = DataBuildUtil.curve(_balance, "mastery_curve")
	_character_table = DataBuildUtil.curve(_balance, "character_curve")
	for path: String in raw["skills"]:
		for d: Dictionary in DataBuildUtil.list(raw["skills"][path], "skills"):
			_add(SkillDef.from_dict(d), _skills, _skill_list, path, "skill", d)
	for path: String in raw["items"]:
		for d: Dictionary in DataBuildUtil.list(raw["items"][path], "items"):
			_add(ItemDef.from_dict(d), _items, _item_list, path, "item", d)
	for path: String in raw["actions"]:
		var skill_id := StringName(raw["actions"][path]["skill"] as String)
		for d: Dictionary in DataBuildUtil.list(raw["actions"][path], "actions"):
			_add(ActionDef.from_dict(d, skill_id), _actions, _action_list, path, "action", d)
	for path: String in raw["mastery"]:
		var skill_id := StringName(raw["mastery"][path]["skill"] as String)
		for d: Dictionary in DataBuildUtil.list(raw["mastery"][path], "nodes"):
			_add(MasteryNodeDef.from_dict(d, skill_id), _nodes, _node_list, path, "mastery node", d)
	for path: String in raw["areas"]:
		for d: Dictionary in DataBuildUtil.list(raw["areas"][path], "areas"):
			_add(AreaDef.from_dict(d), _areas, _area_list, path, "area", d)
	for path: String in raw["classes"]:
		_add(ClassDef.from_dict(raw["classes"][path] as Dictionary), _classes, _class_list, path, "class",
				raw["classes"][path] as Dictionary)
	for path: String in raw["affixes"]:
		for d: Dictionary in DataBuildUtil.list(raw["affixes"][path], "affixes"):
			_add(AffixDef.from_dict(d), _affixes, _affix_list, path, "affix", d)
	for path: String in raw["monsters"]:
		for d: Dictionary in DataBuildUtil.list(raw["monsters"][path], "monsters"):
			_add(MonsterDef.from_dict(d), _monsters, [], path, "monster", d)
	for path: String in raw["rift_stones"]:
		for d: Dictionary in DataBuildUtil.list(raw["rift_stones"][path], "rift_stones"):
			_add(RiftStoneDef.from_dict(d), _stones, [], path, "rift stone", d)
			if _stones.has(StringName(d["id"] as String)):
				var stone: RiftStoneDef = _stones[StringName(d["id"] as String)]
				(_stones_by_area.get_or_add(stone.area_id, []) as Array).append(stone)
	for list: Array in _stones_by_area.values():
		list.sort_custom(func(a: RiftStoneDef, b: RiftStoneDef) -> bool: return a.level < b.level)
	for path: String in raw["shop"]:
		for d: Dictionary in DataBuildUtil.list(raw["shop"][path], "entries"):
			_add(ShopEntryDef.from_dict(d), _shop, _shop_list, path, "shop entry", d)
	for path: String in raw["hints"]:
		for d: Dictionary in DataBuildUtil.list(raw["hints"][path], "hints"):
			_add(HintDef.from_dict(d), _hints, _hint_list, path, "hint", d)
	ItemIndexM10.build(_item_list, _blueprint_list, _blueprint_by_base, _unique_tools)
	_helper.build(_balance, _item_list)
	_loot.build(raw["loot_tables"] as Dictionary, errors)
	_maps.build(_item_list, raw["map_mods"] as Dictionary, raw["bosses"] as Dictionary, _balance, errors)
	_village.build(raw["village"] as Dictionary, errors)
	_skill_list.sort_custom(func(a: SkillDef, b: SkillDef) -> bool: return a.order < b.order)
	_area_list.sort_custom(func(a: AreaDef, b: AreaDef) -> bool: return a.order < b.order)
	_class_list.sort_custom(func(a: ClassDef, b: ClassDef) -> bool: return a.order < b.order)
	_action_list.sort_custom(DataBuildUtil.action_before)
	for def: ActionDef in _action_list:
		if def.icon.is_empty() and not def.outputs.is_empty():
			def.icon = _items[def.outputs[0].item_id].icon
	_guide.build(raw.get("guide", {}) as Dictionary, self)
	if not errors.is_empty():
		_clear()

# Registers a built Def by id; a null Def (from_dict already logged why) becomes an error with file and id.
func _add(def: RefCounted, table: Dictionary, list: Array, path: String, kind: String, d: Dictionary) -> void:
	if def == null:
		errors.append("%s: %s '%s': cannot be built (see the log)" % [path, kind, d.get("id")])
		return
	table[StringName(d["id"] as String)] = def
	list.append(def)

# With a Def that could not be built the data is not valid: nothing stays half-loaded.
func _clear() -> void:
	for table: Dictionary in [_items, _skills, _actions, _nodes, _areas, _monsters, _stones, _stones_by_area, _shop, _classes,
			_blueprint_by_base, _unique_tools, _affixes, _hints]:
		table.clear()
	_guide.clear()
	_helper.clear()
	_loot.clear()
	_maps.clear()
	_village.clear()
	for list: Array in [_item_list, _skill_list, _action_list, _node_list, _area_list, _shop_list, _class_list,
			_affix_list, _hint_list, _blueprint_list]:
		list.clear()
	_xp_table = null
	_mastery_table = null
	_character_table = null
	_balance = {}
	stats = StatRegistry.new()
