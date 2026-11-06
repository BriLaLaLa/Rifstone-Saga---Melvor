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
var _shop: Dictionary[StringName, ShopEntryDef] = {}
var _shop_list: Array[ShopEntryDef] = []
var _character_table: XpTable = null
var _classes: Dictionary[StringName, ClassDef] = {}
var _class_list: Array[ClassDef] = []
var _affixes: Dictionary[StringName, AffixDef] = {}
var _affix_list: Array[AffixDef] = []


static func load_from_dirs(content_root: String = "res://data", config_root: String = "res://data/config") -> GameData:
	var data := GameData.new()
	var raw: Dictionary = {
		"balance": data._read_files([config_root.path_join(BALANCE_FILE)]),
		"stats": data._read_files([config_root.path_join(STATS_FILE)]),
	}
	for section: String in CONTENT_FILES:
		raw[section] = data._read_files([content_root.path_join(CONTENT_FILES[section])])
	for section: String in CONTENT_DIRS:
		raw[section] = data._read_files(JsonLoader.list_json_files(content_root.path_join(CONTENT_DIRS[section]),
				data.errors))
	DataValidator.validate(raw, data.errors)
	if data.errors.is_empty():
		data._build(raw)
	return data


func is_valid() -> bool:
	return errors.is_empty()


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


## F-01 table from `xp_curve` (null when the data is not valid).
func xp_table() -> XpTable:
	return _xp_table


## F-09 table from `mastery_curve` (null when the data is not valid).
func mastery_table() -> XpTable:
	return _mastery_table


## F-71 table from `character_curve` (null when the data is not valid).
func character_xp_table() -> XpTable:
	return _character_table


func character_class(id: StringName) -> ClassDef:
	return _find(_classes, id, "class") as ClassDef


## Every class, by `order`.
func classes() -> Array[ClassDef]:
	return _class_list.duplicate()


func affix(id: StringName) -> AffixDef:
	return _find(_affixes, id, "affix") as AffixDef


## The affixes that can roll on an equipment slot (`head`, `weapon`, `tool_forestry`…), in file order.
func affixes_for_slot(slot: StringName) -> Array[AffixDef]:
	var result: Array[AffixDef] = []
	for def: AffixDef in _affix_list:
		if def.slots.has(slot):
			result.append(def)
	return result


func item(id: StringName) -> ItemDef:
	return _find(_items, id, "item") as ItemDef


func has_item(id: StringName) -> bool:
	return _items.has(id)


## Every item, in load order (files in alphabetical order, then file order).
func items() -> Array[ItemDef]:
	return _item_list.duplicate()


func skill(id: StringName) -> SkillDef:
	return _find(_skills, id, "skill") as SkillDef


## Every skill, by `order`.
func skills() -> Array[SkillDef]:
	return _skill_list.duplicate()


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


func action(id: StringName) -> ActionDef:
	return _find(_actions, id, "action") as ActionDef


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


func mastery_node(id: StringName) -> MasteryNodeDef:
	return _find(_nodes, id, "mastery node") as MasteryNodeDef


## The mastery nodes of a skill, in file order; an unknown skill is an error.
func mastery_nodes(skill_id: StringName) -> Array[MasteryNodeDef]:
	var result: Array[MasteryNodeDef] = []
	if _find(_skills, skill_id, "skill") == null:
		return result
	for def: MasteryNodeDef in _node_list:
		if def.skill_id == skill_id:
			result.append(def)
	return result


func area(id: StringName) -> AreaDef:
	return _find(_areas, id, "area") as AreaDef


## Every area, by `order`.
func areas() -> Array[AreaDef]:
	return _area_list.duplicate()


func monster(id: StringName) -> MonsterDef:
	return _find(_monsters, id, "monster") as MonsterDef


## Existence checks without `push_error` (docs/05_INTERFACES.md §4).
func has_area(id: StringName) -> bool:
	return _areas.has(id)


func has_monster(id: StringName) -> bool:
	return _monsters.has(id)


func shop_entry(id: StringName) -> ShopEntryDef:
	return _find(_shop, id, "shop entry") as ShopEntryDef


## Every shop entry, in file order.
func shop_entries() -> Array[ShopEntryDef]:
	return _shop_list.duplicate()


# {path: top-level object} of the files that load as objects; the others are reported in `errors`.
func _read_files(paths: PackedStringArray) -> Dictionary:
	var files: Dictionary = {}
	for path: String in paths:
		var content: Variant = JsonLoader.load_file(path, errors)
		if content is Dictionary:
			files[path] = content
		elif content != null:
			errors.append("%s: the top level is not an object" % path)
	return files


func _find(table: Dictionary, id: StringName, kind: String) -> RefCounted:
	if table.has(id):
		return table[id] as RefCounted
	Log.error(LOG_CATEGORY, "unknown %s '%s'" % [kind, id])
	return null


func _build(raw: Dictionary) -> void:
	_balance = (raw["balance"] as Dictionary).values()[0] as Dictionary
	stats = StatRegistry.from_array((raw["stats"] as Dictionary).values()[0]["stats"] as Array, errors)
	_xp_table = _curve("xp_curve")
	_mastery_table = _curve("mastery_curve")
	_character_table = _curve("character_curve")
	for path: String in raw["skills"]:
		for d: Dictionary in _list(raw["skills"][path], "skills"):
			_add(SkillDef.from_dict(d), _skills, _skill_list, path, "skill", d)
	for path: String in raw["items"]:
		for d: Dictionary in _list(raw["items"][path], "items"):
			_add(ItemDef.from_dict(d), _items, _item_list, path, "item", d)
	for path: String in raw["actions"]:
		var skill_id := StringName(raw["actions"][path]["skill"] as String)
		for d: Dictionary in _list(raw["actions"][path], "actions"):
			_add(ActionDef.from_dict(d, skill_id), _actions, _action_list, path, "action", d)
	for path: String in raw["mastery"]:
		var skill_id := StringName(raw["mastery"][path]["skill"] as String)
		for d: Dictionary in _list(raw["mastery"][path], "nodes"):
			_add(MasteryNodeDef.from_dict(d, skill_id), _nodes, _node_list, path, "mastery node", d)
	for path: String in raw["areas"]:
		for d: Dictionary in _list(raw["areas"][path], "areas"):
			_add(AreaDef.from_dict(d), _areas, _area_list, path, "area", d)
	for path: String in raw["classes"]:
		_add(ClassDef.from_dict(raw["classes"][path] as Dictionary), _classes, _class_list, path, "class",
				raw["classes"][path] as Dictionary)
	for path: String in raw["affixes"]:
		for d: Dictionary in _list(raw["affixes"][path], "affixes"):
			_add(AffixDef.from_dict(d), _affixes, _affix_list, path, "affix", d)
	for path: String in raw["monsters"]:
		for d: Dictionary in _list(raw["monsters"][path], "monsters"):
			_add(MonsterDef.from_dict(d), _monsters, [], path, "monster", d)
	for path: String in raw["shop"]:
		for d: Dictionary in _list(raw["shop"][path], "entries"):
			_add(ShopEntryDef.from_dict(d), _shop, _shop_list, path, "shop entry", d)
	_skill_list.sort_custom(func(a: SkillDef, b: SkillDef) -> bool: return a.order < b.order)
	_area_list.sort_custom(func(a: AreaDef, b: AreaDef) -> bool: return a.order < b.order)
	_class_list.sort_custom(func(a: ClassDef, b: ClassDef) -> bool: return a.order < b.order)
	_action_list.sort_custom(_action_before)
	for def: ActionDef in _action_list:
		if def.icon.is_empty() and not def.outputs.is_empty():
			def.icon = _items[def.outputs[0].item_id].icon
	if not errors.is_empty():
		_clear()


func _curve(key: String) -> XpTable:
	var c: Dictionary = _balance[key] as Dictionary
	return XpTable.from_params(float(c["base"]), float(c["growth"]), float(c["linear"]), int(c["max_level"]))


static func _list(content: Variant, key: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	result.assign((content as Dictionary)[key] as Array)
	return result


# Registers a built Def by id; a null Def (from_dict already logged why) becomes an error with file and id.
func _add(def: RefCounted, table: Dictionary, list: Array, path: String, kind: String, d: Dictionary) -> void:
	if def == null:
		errors.append("%s: %s '%s': cannot be built (see the log)" % [path, kind, d.get("id")])
		return
	table[StringName(d["id"] as String)] = def
	list.append(def)


static func _action_before(a: ActionDef, b: ActionDef) -> bool:
	if a.level != b.level:
		return a.level < b.level
	return String(a.id) < String(b.id)


# With a Def that could not be built the data is not valid: nothing stays half-loaded.
func _clear() -> void:
	for table: Dictionary in [_items, _skills, _actions, _nodes, _areas, _monsters, _shop, _classes, _affixes]:
		table.clear()
	for list: Array in [_item_list, _skill_list, _action_list, _node_list, _area_list, _shop_list, _class_list,
			_affix_list]:
		list.clear()
	_xp_table = null
	_mastery_table = null
	_character_table = null
