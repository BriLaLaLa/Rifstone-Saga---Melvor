class_name DataValidatorItems
extends RefCounted
## Third part of DataValidator (internal, not API for other modules): the rules of items, actions and shop
## (docs/04_DATA_SCHEMA.md §5, §6, §9), written with the toolkit of DataValidatorRules.

const ACTION_SKILL_CATEGORIES: PackedStringArray = ["gathering", "artisan"]
const ITEM_FIELDS: PackedStringArray = ["id", "name", "description", "category", "icon", "value", "sort_order",
	"equip", "food", "infusion"]
const ITEM_ICON_DIR: String = "res://assets/icons/items/"
## Item file name (without `.json`) -> the category of its items.
const ITEM_FILE_CATEGORIES: Dictionary[String, String] = {
	"materials": "material", "equipment": "equipment", "tools": "tool", "food": "food", "infusions": "infusion",
	"misc": "misc",
}
const EQUIP_CATEGORIES: PackedStringArray = ["equipment", "tool"]
const EQUIP_SLOTS: PackedStringArray = [
	"head", "body", "legs", "feet", "hands", "neck", "ring", "weapon", "offhand", "tool_forestry", "tool_quarrying",
	"tool_angling",
]
const TOOL_SLOT_PREFIX: String = "tool_"
const WEAPON_SLOT: String = "weapon"
const RIFT_SHARD_ID: StringName = &"rift_shard"
const RIFT_SHARD_CATEGORY: String = "misc"
const ACTION_FIELDS: PackedStringArray = ["id", "name", "level", "interval_ms", "xp", "mastery", "inputs",
	"outputs", "icon"]
const SHOP_CATEGORIES: PackedStringArray = ["bank", "combat", "tools", "materials"]  # M8 adds "lanes"
const SHOP_FORMULAS: PackedStringArray = ["bank_slot"]
const SHOP_FIELDS: PackedStringArray = ["id", "name", "description", "category", "cost", "max_purchases",
	"requires", "effect"]


static func validate_items(v: DataValidatorRules, files: Dictionary[String, Dictionary]) -> void:
	var seen: Dictionary[StringName, bool] = {}
	for path: String in files:
		v.at_file(path)
		var stem: String = path.get_file().get_basename()
		if not ITEM_FILE_CATEGORIES.has(stem):
			v.fail("unknown items file '%s' (expected one of %s)" % [stem, ITEM_FILE_CATEGORIES.keys()])
		var list: Array[Dictionary] = DataValidator.entries(v, files[path], "items")
		for index: int in list.size():
			v.entry("item", index, list[index], seen, ITEM_FIELDS)
			_item(v, list[index], ITEM_FILE_CATEGORIES.get(stem, ""))
	v.at_file("section 'items'" if files.is_empty() else (files.keys()[0] as String).get_base_dir())
	if not v.items.has(RIFT_SHARD_ID):
		v.fail("required item '%s' (category %s) is missing" % [RIFT_SHARD_ID, RIFT_SHARD_CATEGORY])
	elif v.items[RIFT_SHARD_ID].get("category") != RIFT_SHARD_CATEGORY:
		v.fail("item '%s' must have category '%s'" % [RIFT_SHARD_ID, RIFT_SHARD_CATEGORY])


static func _item(v: DataValidatorRules, e: Dictionary, file_category: String) -> void:
	DataValidator.icon(v, e, ITEM_ICON_DIR)
	v.integer(e, "value", 0)
	v.integer(e, "sort_order", -DataValidatorRules.NO_LIMIT)
	if not v.one_of(e, "category", ITEM_FILE_CATEGORIES.values()):
		return
	var category: String = e["category"] as String
	if not file_category.is_empty() and category != file_category:
		v.fail("category '%s' does not match its file (expected '%s')" % [category, file_category])
	if _sub_object(v, e, "equip", category in EQUIP_CATEGORIES):
		_equip(v, e["equip"] as Dictionary, category)
	if _sub_object(v, e, "food", category == "food"):
		v.keys(e["food"] as Dictionary, ["heal"], "food")
		v.integer(e["food"] as Dictionary, "heal", 1, DataValidatorRules.NO_LIMIT, "food")
	if _sub_object(v, e, "infusion", category == "infusion"):
		var infusion: Dictionary = e["infusion"] as Dictionary
		v.keys(infusion, ["modifiers", "unique"], "infusion")
		v.modifiers(infusion, "modifiers", "infusion")
		if infusion.get("modifiers") is Array and (infusion["modifiers"] as Array).is_empty():
			v.fail("field 'infusion.modifiers' needs at least 1 entries (an infusion without effect is decorative)")
		if infusion.has("unique"):
			v.flag(infusion, "unique", "infusion")


# A sub-object required by the category (`wanted`) and forbidden otherwise; true if it is there and an object.
static func _sub_object(v: DataValidatorRules, e: Dictionary, key: String, wanted: bool) -> bool:
	if not wanted and e.has(key):
		v.fail("field '%s' is not allowed for category '%s'" % [key, e["category"]])
	if wanted:
		v.object(e, key)
	return wanted and e.get(key) is Dictionary


static func _equip(v: DataValidatorRules, equip: Dictionary, category: String) -> void:
	v.keys(equip, ["slot", "requirements", "modifiers", "weapon"], "equip")
	var slot: String = ""
	if v.one_of(equip, "slot", EQUIP_SLOTS, "equip"):
		slot = equip["slot"] as String
		if slot.begins_with(TOOL_SLOT_PREFIX) and category != "tool":
			v.fail("slot '%s' is only for category 'tool'" % slot)
	v.level_map(equip, "requirements", "equip")
	v.modifiers(equip, "modifiers", "equip")
	if equip.has("weapon") and slot != WEAPON_SLOT:
		v.fail("field 'equip.weapon' is allowed only with slot '%s'" % WEAPON_SLOT)
	if not equip.has("weapon") or slot != WEAPON_SLOT:
		return
	var weapon: Dictionary = v.object(equip, "weapon", "equip")
	if not equip["weapon"] is Dictionary:
		return
	v.keys(weapon, ["style", "attack_interval_ms", "two_handed"], "equip.weapon")
	v.one_of(weapon, "style", DataValidatorRules.STYLES, "equip.weapon")
	v.integer(weapon, "attack_interval_ms", maxf(v.min_attack_interval_ms, 1), DataValidatorRules.NO_LIMIT,
			"equip.weapon")
	v.flag(weapon, "two_handed", "equip.weapon")


static func validate_actions(v: DataValidatorRules, files: Dictionary[String, Dictionary]) -> void:
	var seen: Dictionary[StringName, bool] = {}
	for path: String in files:
		v.at_file(path)
		var skill: String = DataValidator.file_skill(v, files[path], path, ACTION_SKILL_CATEGORIES)
		var category: String = str(v.skills[StringName(skill)].get("category")) if not skill.is_empty() else ""
		var list: Array[Dictionary] = DataValidator.entries(v, files[path], "actions", ["skill"])
		for index: int in list.size():
			var e: Dictionary = list[index]
			v.entry("action", index, e, seen, ACTION_FIELDS)
			v.integer(e, "level", 1, v.max_skill_level)
			v.integer(e, "interval_ms", maxf(v.min_action_interval_ms, 1))
			v.integer(e, "xp", 1)
			v.flag(e, "mastery")
			if e.has("icon"):
				v.text(e, "icon")
			v.item_qty_list(e, "inputs", 1 if category == "artisan" else 0)
			if category == "gathering" and e.get("inputs") is Array and not (e["inputs"] as Array).is_empty():
				v.fail("gathering actions must have no inputs")
			v.item_qty_list(e, "outputs", 1)


static func validate_shop(v: DataValidatorRules, files: Dictionary[String, Dictionary]) -> void:
	var seen: Dictionary[StringName, bool] = {}
	for path: String in files:
		v.at_file(path)
		var list: Array[Dictionary] = DataValidator.entries(v, files[path], "entries")
		for index: int in list.size():
			var e: Dictionary = list[index]
			v.entry("shop entry", index, e, seen, SHOP_FIELDS)
			v.one_of(e, "category", SHOP_CATEGORIES)
			v.integer(e, "max_purchases", 0)
			var cost: Dictionary = _one_of_two(v, e, "cost", "gold", "formula")
			if cost.has("gold"):
				v.integer(cost, "gold", 1, DataValidatorRules.NO_LIMIT, "cost")
			elif cost.has("formula"):
				v.one_of(cost, "formula", SHOP_FORMULAS, "cost")
			var req: Dictionary = v.object(e, "requires")
			v.keys(req, ["entries", "skills", "total_level"], "requires")
			if req.has("entries"):
				v.id_list(req, "entries", v.shop_entries, "shop entry", 0, "requires")
			if req.has("skills"):
				v.level_map(req, "skills", "requires")
			if req.has("total_level"):
				v.integer(req, "total_level", 0, DataValidatorRules.NO_LIMIT, "requires")
			var effect: Dictionary = _one_of_two(v, e, "effect", "modifiers", "item")
			if effect.has("modifiers"):
				v.modifiers(effect, "modifiers", "effect")
				if DataValidatorRules.is_int(e.get("max_purchases")) and int(e["max_purchases"]) == 0:
					v.fail("field 'max_purchases' can be 0 (unlimited) only for item effects")
			elif effect.has("item"):
				var item: Dictionary = v.object(effect, "item", "effect")
				if effect["item"] is Dictionary:
					v.item_qty(item, "effect.item")


# The object under `key` with exactly one of the fields `a` and `b`; {} (after an error) otherwise.
static func _one_of_two(v: DataValidatorRules, e: Dictionary, key: String, a: String, b: String) -> Dictionary:
	var d: Dictionary = v.object(e, key)
	v.keys(d, [a, b], key)
	if e.get(key) is Dictionary and d.has(a) == d.has(b):
		v.fail("field '%s' needs exactly one of '%s' and '%s'" % [key, a, b])
		return {}
	return d
