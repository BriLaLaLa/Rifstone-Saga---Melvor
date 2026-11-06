class_name DataValidator
extends RefCounted
## Schema and cross-reference checks of the game data (docs/04_DATA_SCHEMA.md, docs/03_ARCHITECTURE.md §10).
## `raw` has one key per section ("balance", "stats", "skills", "items", "actions", "mastery", "areas", "monsters",
## "shop", "classes", "affixes"); each value maps the path of every loaded file of that section to its top-level object
## (single-file sections have one entry). The paths appear in the messages and give the file name that the schema
## compares with (`skill` of actions and mastery files, `category` of items, `id` of classes). Every problem is
## appended to `errors` as `<file>: <kind> '<id>': <message>`, never pushed to the debugger. Toolkit, mastery:
## DataValidatorRules; items, actions, shop: DataValidatorItems; areas, monsters, classes, affixes:
## DataValidatorClasses.

## Every key of 02_FORMULAS.md §9 of the MVP, as dotted paths. Values that are objects in the table are listed
## by their fields; arrays are leaves. M7 adds `fractures.*`, M8 `parallel.*`.
const REQUIRED_BALANCE_KEYS: PackedStringArray = [
	"tick_ms", "max_catchup_ms", "autosave_interval_ms", "slots.count", "player_name.min_length",
	"player_name.max_length", "start.gold", "start.items",
	"xp_curve.base", "xp_curve.growth", "xp_curve.linear", "xp_curve.max_level", "xp_curve.xp_cap",
	"mastery_curve.base", "mastery_curve.growth", "mastery_curve.linear", "mastery_curve.max_level",
	"mastery.base_factor", "mastery.per_level", "mastery.ratio_weight", "mastery.pool_share_pct",
	"mastery.pool_cap_per_item", "mastery.pool_warning_pct", "action.min_interval_ms",
	"gathering.rift_shard_base_chance_pct",
	"bank.base_slots", "bank.slot_cost_base", "bank.slot_cost_growth", "bank.slot_cost_cap",
	"combat.acc_level_offset", "combat.acc_bonus_offset", "combat.maxhit_level_offset", "combat.maxhit_bonus_offset",
	"combat.min_hit_ratio", "combat.hit_chance_min", "combat.hit_chance_max",
	"combat.triangle.advantage_damage_mult", "combat.triangle.disadvantage_damage_mult",
	"combat.triangle.defender_dr_mult", "combat.triangle.beats.blade", "combat.triangle.beats.arcana",
	"combat.triangle.beats.marksmanship", "combat.min_attack_interval_ms", "combat.unarmed.style",
	"combat.unarmed.attack_interval_ms", "combat.hp_base", "combat.hp_per_level", "combat.dual_wield.interval_mult",
	"combat.max_pack_size", "combat.auto_eat_tiers",
	"combat.respawn_ms", "combat.loot_bag_base_slots",
	"character_curve.base", "character_curve.growth", "character_curve.linear", "character_curve.max_level",
	"character_curve.xp_cap", "character.start_class",
	"armory.base_slots", "armory.slot_cost_base", "armory.slot_cost_growth", "armory.slot_cost_cap",
	"rarity.craft.magic_base_pct", "rarity.craft.magic_per_mastery_level", "rarity.craft.rare_base_pct",
	"rarity.craft.rare_per_mastery_level", "rarity.affix_count.magic", "rarity.affix_count.rare",
	"rarity.drop.magic_pct", "rarity.drop.rare_pct", "rarity.rift_stone.magic_pct", "rarity.rift_stone.rare_pct",
	"rift.sockets", "offline.cap_ms", "offline.min_ms",
	"offline.chunk_ms", "traits.slot_levels", "abilities.slot_levels",
	"upgrade.levels", "upgrade.downgrade_from", "upgrade.mod_pct_per_level", "upgrade.seal_item", "upgrade.ingot_items",
	"salvage.ingot_ratio", "salvage.shards_by_rarity", "rift_stone.chance_pct", "rift_stone.pity_kills",
]
## Balance keys holding an array, a combat style or a class id; every other required key holds a number.
const BALANCE_LIST_KEYS: PackedStringArray = [
	"start.items", "combat.auto_eat_tiers", "rift.sockets", "traits.slot_levels", "abilities.slot_levels", "rarity.affix_count.magic", "rarity.affix_count.rare",
	"upgrade.levels", "upgrade.ingot_items",
]
const BALANCE_STYLE_KEYS: PackedStringArray = [
	"combat.triangle.beats.blade", "combat.triangle.beats.arcana", "combat.triangle.beats.marksmanship",
	"combat.unarmed.style",
]
const BALANCE_CLASS_KEYS: PackedStringArray = ["character.start_class"]
const BALANCE_TEXT_KEYS: PackedStringArray = ["upgrade.seal_item"]  # M7: an item id (checked by DataValidatorLoot)
const BALANCE_OBJECT_KEYS: PackedStringArray = ["salvage.shards_by_rarity"]
const AFFIX_COUNT_KEYS: PackedStringArray = ["rarity.affix_count.magic", "rarity.affix_count.rare"]
const AFFIX_COUNT_MAX: int = 6
const PACK_SIZE_MAX: int = 6  # format limit of combat.max_pack_size
const START_ITEM_FORBIDDEN_CATEGORIES: PackedStringArray = ["equipment", "tool"]  # they live in the Armory only
## Sections made of one file (the others are folders, possibly empty).
const SINGLE_FILE_SECTIONS: PackedStringArray = ["balance", "stats", "skills", "areas", "monsters", "shop", "affixes",
	"rift_stones"]
const SKILL_CATEGORIES: PackedStringArray = ["gathering", "artisan"]
const STAT_FIELDS: PackedStringArray = ["id", "name", "format", "min", "max", "description", "formula", "test"]
const STAT_FORMULA_PATTERN: String = "^(F-[0-9]{2}|[0-9]+(\\.[0-9]+)*)$"
const STAT_TEST_PATTERN: String = "^[^:]+\\.gd::[A-Za-z_][A-Za-z0-9_]*$"
const STAT_NAME_MAX_LENGTH: int = 40
const SKILL_FIELDS: PackedStringArray = ["id", "name", "description", "category", "order", "icon", "color",
	"has_mastery", "mastery_bonuses"]
const COLOR_PATTERN: String = "^#[0-9a-fA-F]{6}$"
const SKILL_ICON_DIR: String = "res://assets/icons/skills/"


static func validate(raw: Dictionary, errors: PackedStringArray) -> void:
	var v := DataValidatorRules.new()
	for section: String in SINGLE_FILE_SECTIONS:
		if _files(raw, section).size() != 1:
			v.at_file("section '%s'" % section)
			v.fail("expected one file, got %d" % _files(raw, section).size())
	_validate_balance(v, _files(raw, "balance"))
	_validate_stats(v, _files(raw, "stats"))
	_collect(v.skills, _files(raw, "skills"), "skills")
	_collect(v.items, _files(raw, "items"), "items")
	_collect(v.actions, _files(raw, "actions"), "actions")
	_collect(v.monsters, _files(raw, "monsters"), "monsters")
	_collect(v.shop_entries, _files(raw, "shop"), "entries")
	_collect_classes(v, _files(raw, "classes"))
	_validate_skills(v, _files(raw, "skills"))
	DataValidatorItems.validate_items(v, _files(raw, "items"))
	_validate_balance_refs(v, _files(raw, "balance"))
	DataValidatorItems.validate_actions(v, _files(raw, "actions"))
	v.validate_mastery(_files(raw, "mastery"))
	DataValidatorClasses.validate_areas(v, _files(raw, "areas"))
	DataValidatorClasses.validate_monsters(v, _files(raw, "monsters"))
	DataValidatorClasses.validate_classes(v, _files(raw, "classes"))
	DataValidatorClasses.validate_affixes(v, _files(raw, "affixes"))
	DataValidatorStones.validate(v, _files(raw, "rift_stones"), _files(raw, "areas"))
	DataValidatorItems.validate_shop(v, _files(raw, "shop"))
	errors.append_array(v.errors)


## The value at a dotted path of nested objects, or null if a segment is missing.
static func lookup(d: Dictionary, path: String) -> Variant:
	var node: Variant = d
	for part: String in path.split("."):
		if not node is Dictionary or not (node as Dictionary).has(part):
			return null
		node = (node as Dictionary)[part]
	return node


## The entries of the list `list_key` of a file, after checking the file's top-level fields.
static func entries(v: DataValidatorRules, content: Dictionary, list_key: String, extra: PackedStringArray = []
) -> Array[Dictionary]:
	var allowed: PackedStringArray = extra.duplicate()
	allowed.append(list_key)
	v.keys(content, allowed)
	return v.object_list(content, list_key)


## A required icon path under `dir`.
static func icon(v: DataValidatorRules, e: Dictionary, dir: String) -> void:
	if v.text(e, "icon") and not (e["icon"] as String).begins_with(dir):
		v.fail("field 'icon' must be a path under %s, got '%s'" % [dir, e["icon"]])


## Checks the file-level `skill` of an actions or mastery file: an existing skill, equal to the file name, whose
## category is in `categories` (any if empty). Returns the skill id ("" if not valid).
static func file_skill(v: DataValidatorRules, content: Dictionary, path: String, categories: PackedStringArray
) -> String:
	if content.get("skill") is String and content["skill"] != path.get_file().get_basename():
		v.fail("skill '%s' must be equal to the file name" % content["skill"])
	if not v.ref(content, "skill", v.skills, "skill"):
		return ""
	var skill: String = content["skill"] as String
	var category: String = str(v.skills[StringName(skill)].get("category", ""))
	if not categories.is_empty() and not categories.has(category):
		v.fail("skill '%s' has category '%s', expected one of %s" % [skill, category, categories])
		return ""
	return skill


# The `{path: top-level object}` of a section; non-object values are left out (the loader reports them).
static func _files(raw: Dictionary, section: String) -> Dictionary[String, Dictionary]:
	var result: Dictionary[String, Dictionary] = {}
	var files: Variant = raw.get(section)
	for path: Variant in (files as Dictionary if files is Dictionary else {}):
		if (files as Dictionary)[path] is Dictionary:
			result[str(path)] = (files as Dictionary)[path] as Dictionary
	return result


# Every entry with a string id, before the rules run, so that references can point forward.
static func _collect(into: Dictionary[StringName, Dictionary], files: Dictionary[String, Dictionary], key: String
) -> void:
	for path: String in files:
		var list: Variant = files[path].get(key)
		for e: Variant in (list as Array if list is Array else []):
			if e is Dictionary and (e as Dictionary).get("id") is String:
				into[StringName((e as Dictionary)["id"] as String)] = e as Dictionary


# Classes are one object per file (`id` = file name): their ids are collected for the references.
static func _collect_classes(v: DataValidatorRules, files: Dictionary[String, Dictionary]) -> void:
	for path: String in files:
		if files[path].get("id") is String:
			v.classes[StringName(files[path]["id"] as String)] = files[path]


# --- balance.json ------------------------------------------------------------------------------------------------

static func _validate_balance(v: DataValidatorRules, files: Dictionary[String, Dictionary]) -> void:
	for path: String in files:
		var balance: Dictionary = files[path]
		v.at_file(path)
		for key: String in REQUIRED_BALANCE_KEYS:
			var parent: Variant = balance if not key.contains(".") else lookup(balance, key.get_slice(".", 0)) \
					if key.get_slice_count(".") == 2 else lookup(balance, key.substr(0, key.rfind(".")))
			var leaf: String = key.substr(key.rfind(".") + 1)
			if not parent is Dictionary or not (parent as Dictionary).has(leaf):
				v.fail("missing key '%s'" % key)
				continue
			_balance_value(v, key, (parent as Dictionary)[leaf])
		_unknown_balance_keys(v, balance, "")
		v.max_skill_level = _curve_max_level(v, balance, "xp_curve")
		v.max_mastery_level = _curve_max_level(v, balance, "mastery_curve")
		_name_length_limits(v, balance)
		_pool_warning_pct(v, balance)
		v.min_action_interval_ms = _limit(balance, "action.min_interval_ms")
		v.min_attack_interval_ms = _limit(balance, "combat.min_attack_interval_ms")
		v.max_character_level = _curve_max_level(v, balance, "character_curve")
		v.max_pack_size = _limit(balance, "combat.max_pack_size")
		if v.max_pack_size < 1.0:
			v.max_pack_size = DataValidatorRules.NO_LIMIT
		DataValidatorClasses.validate_balance(v, balance)
		DataValidatorLoot.validate_balance(v, balance)


static func _balance_value(v: DataValidatorRules, key: String, value: Variant) -> void:
	if key in BALANCE_LIST_KEYS:
		if not value is Array:
			v.fail("key '%s' must be an array, got %s" % [key, JSON.stringify(value)])
	elif key in BALANCE_STYLE_KEYS:
		if not value is String or not DataValidatorRules.STYLES.has(value as String):
			v.fail("key '%s' must be one of %s, got %s" % [key, DataValidatorRules.STYLES, JSON.stringify(value)])
	elif key in BALANCE_TEXT_KEYS:
		if not value is String or (value as String).is_empty():
			v.fail("key '%s' must be a non-empty id, got %s" % [key, JSON.stringify(value)])
	elif key in BALANCE_OBJECT_KEYS:
		if not value is Dictionary:
			v.fail("key '%s' must be an object, got %s" % [key, JSON.stringify(value)])
	elif key in BALANCE_CLASS_KEYS:
		if not value is String:
			v.fail("key '%s' must be a class id, got %s" % [key, JSON.stringify(value)])
	elif not DataValidatorRules.is_number(value):
		v.fail("key '%s' must be a number, got %s" % [key, JSON.stringify(value)])


static func _unknown_balance_keys(v: DataValidatorRules, node: Dictionary, prefix: String) -> void:
	for key: Variant in node:
		var path: String = str(key) if prefix.is_empty() else "%s.%s" % [prefix, key]
		if str(key) == DataValidatorRules.DOC_KEY or path in REQUIRED_BALANCE_KEYS:
			continue
		var is_prefix: bool = false
		for required: String in REQUIRED_BALANCE_KEYS:
			is_prefix = is_prefix or required.begins_with(path + ".")
		if not is_prefix:
			v.fail("unknown key '%s'" % path)
		elif node[key] is Dictionary:
			_unknown_balance_keys(v, node[key] as Dictionary, path)


# max_level of an XpTable curve (NO_LIMIT if malformed); base and growth must be > 0 (XpTable asserts it).
static func _curve_max_level(v: DataValidatorRules, balance: Dictionary, curve: String) -> float:
	for field: String in ["base", "growth"]:
		var value: Variant = lookup(balance, "%s.%s" % [curve, field])
		if DataValidatorRules.is_number(value) and float(value) <= 0.0:
			v.fail("key '%s.%s' must be > 0" % [curve, field])
	var max_level: Variant = lookup(balance, curve + ".max_level")
	if not DataValidatorRules.is_number(max_level):
		return DataValidatorRules.NO_LIMIT
	if not DataValidatorRules.is_int(max_level) or float(max_level) < 1.0:
		v.fail("key '%s.max_level' must be an integer >= 1" % curve)
		return DataValidatorRules.NO_LIMIT
	return float(max_level)


# player_name.min_length and max_length: integers >= 1 with min <= max (a missing or non-number value is already
# reported by the key checks).
static func _name_length_limits(v: DataValidatorRules, balance: Dictionary) -> void:
	var valid: bool = true
	for key: String in ["player_name.min_length", "player_name.max_length"]:
		var value: Variant = lookup(balance, key)
		if not DataValidatorRules.is_number(value):
			valid = false
		elif not DataValidatorRules.is_int(value) or float(value) < 1.0:
			v.fail("key '%s' must be an integer >= 1" % key)
			valid = false
	if valid and float(lookup(balance, "player_name.min_length")) > float(lookup(balance, "player_name.max_length")):
		v.fail("key 'player_name.min_length' must be <= 'player_name.max_length'")


# mastery.pool_warning_pct: share of the pool cap (> 0, <= 100) from which the UI warns that the pool is almost full
# (a missing or non-number value is already reported by the key checks).
static func _pool_warning_pct(v: DataValidatorRules, balance: Dictionary) -> void:
	var value: Variant = lookup(balance, "mastery.pool_warning_pct")
	if DataValidatorRules.is_number(value) and (float(value) <= 0.0 or float(value) > 100.0):
		v.fail("key 'mastery.pool_warning_pct' must be > 0 and <= 100")


static func _limit(balance: Dictionary, key: String) -> float:
	var value: Variant = lookup(balance, key)
	return float(value) if DataValidatorRules.is_number(value) else 0.0


# References of balance.json, checked once items and classes are known: start.items and the start class.
static func _validate_balance_refs(v: DataValidatorRules, files: Dictionary[String, Dictionary]) -> void:
	for path: String in files:
		v.at_file(path)
		var start: Variant = lookup(files[path], "start")
		if start is Dictionary and (start as Dictionary).get("items") is Array:
			v.item_qty_list(start as Dictionary, "items", 0, "start")
			_start_items_are_stackable(v, (start as Dictionary)["items"] as Array)
		DataValidatorLoot.validate_refs(v, files[path])
		var character: Variant = lookup(files[path], "character")
		for key: String in BALANCE_CLASS_KEYS:
			if character is Dictionary and (character as Dictionary).get(key.get_slice(".", 1)) is String:
				v.ref(character as Dictionary, key.get_slice(".", 1), v.classes, "class", "character")


# Equipment and tools exist only as Armory instances: they cannot be start items.
static func _start_items_are_stackable(v: DataValidatorRules, list: Array) -> void:
	for e: Variant in list:
		if not e is Dictionary or not (e as Dictionary).get("item") is String:
			continue
		var item: StringName = StringName((e as Dictionary)["item"] as String)
		if v.items.has(item) and START_ITEM_FORBIDDEN_CATEGORIES.has(str(v.items[item].get("category"))):
			v.fail("field 'start.items': '%s' is %s, pieces live in the Armory" % [item, v.items[item].get("category")])


# --- stats.json (the entry checks of StatRegistry.from_array are reused, with the file in front) ----------------

static func _validate_stats(v: DataValidatorRules, files: Dictionary[String, Dictionary]) -> void:
	var formula := RegEx.create_from_string(STAT_FORMULA_PATTERN)
	var test := RegEx.create_from_string(STAT_TEST_PATTERN)
	var id := RegEx.create_from_string(DataValidatorRules.ID_PATTERN)
	for path: String in files:
		v.at_file(path)
		var list: Array[Dictionary] = entries(v, files[path], "stats")
		for index: int in list.size():
			var e: Dictionary = list[index]
			v.at_entry("stat", index, e)
			v.keys(e, STAT_FIELDS)
			if e.get("id") is String and id.search(e["id"] as String) == null:
				v.fail("id '%s' does not match %s" % [e["id"], DataValidatorRules.ID_PATTERN])
			if e.get("name") is String and (e["name"] as String).length() > STAT_NAME_MAX_LENGTH:
				v.fail("field 'name' must be 1-%d characters" % STAT_NAME_MAX_LENGTH)
			if e.get("formula") is String and formula.search(e["formula"] as String) == null:
				v.fail("field 'formula' must be F-xx or a section number, got '%s'" % e["formula"])
			if e.get("test") is String and test.search(e["test"] as String) == null:
				v.fail("field 'test' must be <path>.gd::<function>, got '%s'" % e["test"])
		v.at_file(path)
		var registry_errors: PackedStringArray = []
		if files[path].get("stats") is Array:
			v.stats = StatRegistry.from_array(files[path]["stats"] as Array, registry_errors)
		for message: String in registry_errors:
			v.fail(message)


# --- skills.json ---------------------------------------------------------------------------------------------------

static func _validate_skills(v: DataValidatorRules, files: Dictionary[String, Dictionary]) -> void:
	var color := RegEx.create_from_string(COLOR_PATTERN)
	var seen: Dictionary[StringName, bool] = {}
	var orders: Dictionary[int, bool] = {}
	for path: String in files:
		v.at_file(path)
		var list: Array[Dictionary] = entries(v, files[path], "skills")
		for index: int in list.size():
			var e: Dictionary = list[index]
			v.entry("skill", index, e, seen, SKILL_FIELDS, orders)
			if e.get("id") == DataValidatorRules.CHARACTER_KEY:
				v.fail("id '%s' is reserved (the character level in requirements)" % DataValidatorRules.CHARACTER_KEY)
			v.one_of(e, "category", SKILL_CATEGORIES)
			icon(v, e, SKILL_ICON_DIR)
			if v.text(e, "color") and color.search(e["color"] as String) == null:
				v.fail("field 'color' must be #rrggbb, got '%s'" % e["color"])
			if v.flag(e, "has_mastery"):
				_skill_mastery(v, e, e["has_mastery"] as bool)


static func _skill_mastery(v: DataValidatorRules, e: Dictionary, has_mastery: bool) -> void:
	if e.has("mastery_bonuses") and not has_mastery:
		v.fail("field 'mastery_bonuses' is allowed only with 'has_mastery': true")
	if not e.has("mastery_bonuses") or not has_mastery:
		return
	var rules: Array[Dictionary] = v.object_list(e, "mastery_bonuses")
	for index: int in rules.size():
		var rule: Dictionary = rules[index]
		var prefix: String = "mastery_bonuses[%d]" % index
		v.keys(rule, ["every_levels", "at_level", "modifiers"], prefix)
		if rule.has("every_levels") == rule.has("at_level"):
			v.fail("field '%s' needs exactly one of 'every_levels' and 'at_level'" % prefix)
		for key: String in ["every_levels", "at_level"]:
			if rule.has(key):
				v.integer(rule, key, 1, v.max_mastery_level, prefix)
		v.modifiers(rule, "modifiers", prefix, false)
