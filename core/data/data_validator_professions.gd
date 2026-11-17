class_name DataValidatorProfessions
extends RefCounted
## Profession rules of DataValidator (internal, M26-02; docs/04_DATA_SCHEMA_M26.md §31.1-§31.5, §31.8): the `colors` of actions, the
## `reagent` items, the `profession` shop entries and the `vendor` of the Trainers. The Recipe rule (drop or shop) is in
## DataValidatorDisciplines. The "real data" rules are on only when some action has `colors` (M26-04 writes them): until then the
## real data keep their structure checks and nothing more.

const COLOR_KEYS: PackedStringArray = ["yellow", "green", "grey"]
const COLORS_MAX_LEVEL: int = 200  # level < yellow < green < grey <= 200
const PROFESSION_CATEGORY: String = "profession"
const REAGENT_PREFIX: String = "reagent_"
## Real data: the artisan skills that have colors and the shop stall of their Trainer (§31.5, §31.1).
const REAL_VENDORS: Dictionary[String, String] = {"forging": "fabbro", "woodwright": "falegname", "hearthcraft": "cuoco"}


## `colors` of an action entry (the caller started the entry): artisan actions that are not `single`, three increasing levels above `level`.
static func action(v: DataValidatorRules, e: Dictionary, category: String, single: bool) -> void:
	if not e.has("colors"):
		return
	if category != "artisan" or single:
		v.fail("field 'colors' is allowed only for artisan actions that are not 'single'")
	var colors: Dictionary = v.object(e, "colors")
	v.keys(colors, COLOR_KEYS, "colors")
	var low: int = int(e["level"]) if DataValidatorRules.is_int(e.get("level")) else 0
	for key: String in COLOR_KEYS:
		if v.integer(colors, key, low + 1, COLORS_MAX_LEVEL, "colors"):
			low = int(colors[key])


## `vendor` of a Trainer (the caller started the entry; `seen` collects the vendors of the file): an artisan discipline, a known stall, unique.
static func trainer(v: DataValidatorRules, t: Dictionary, skill: StringName, seen: Dictionary[StringName, bool]) -> void:
	if not t.has("vendor"):
		return
	if v.skills.has(skill) and v.skills[skill].get("category") != "artisan":
		v.fail("field 'vendor' is allowed only on an artisan discipline")
	if v.one_of(t, "vendor", DataValidatorItems.SHOP_VENDORS):
		var vendor: StringName = StringName(t["vendor"] as String)
		if seen.has(vendor):
			v.fail("field 'vendor': '%s' is already the vendor of another Trainer" % vendor)
		seen[vendor] = true


## The cross-checks over the whole raw data (`strict` = real data): reagents, profession shop entries, real-data rules.
static func validate(v: DataValidatorRules, raw: Dictionary, strict: bool) -> void:
	var skill_of: Dictionary[StringName, StringName] = {}
	var colored: bool = false
	var actions: Dictionary = raw.get("actions", {}) as Dictionary
	for path: Variant in actions:
		var skill: StringName = StringName(str((actions[path] as Dictionary).get("skill", "")))
		v.at_file(str(path))
		for a: Variant in ((actions[path] as Dictionary).get("actions", []) as Array):
			if a is Dictionary and (a as Dictionary).get("id") is String:
				skill_of[StringName((a as Dictionary)["id"] as String)] = skill
				colored = colored or (a as Dictionary).has("colors")
				_reagent_use(v, a as Dictionary, skill)
	var vendors: Dictionary[StringName, StringName] = _vendors(raw)
	_shop(v, raw, skill_of, vendors, strict and colored)
	if strict and colored:
		_real_data(v, actions, vendors)


# The reagent items an action uses: never an output; an input only of a `discover` action of its own skill.
static func _reagent_use(v: DataValidatorRules, a: Dictionary, skill: StringName) -> void:
	v.at_entry("action", 0, a)
	for entry: Variant in (a.get("outputs", []) as Array if a.get("outputs") is Array else []):
		if entry is Dictionary and _is_reagent(v, (entry as Dictionary).get("item")):
			v.fail("reagent '%s' cannot be the output of an action" % (entry as Dictionary)["item"])
	for entry: Variant in (a.get("inputs", []) as Array if a.get("inputs") is Array else []):
		if not entry is Dictionary or not _is_reagent(v, (entry as Dictionary).get("item")):
			continue
		var item_id: String = (entry as Dictionary)["item"] as String
		if not (a.get("discover") is bool and a["discover"]):
			v.fail("reagent '%s' is an input of an action without 'discover: true'" % item_id)
		elif reagent_skill(item_id) != skill:
			v.fail("reagent '%s' is an input of an action of another skill" % item_id)


## The skill id a reagent belongs to: `reagent_<skill>_<n>` -> `<skill>`; &"" for any other shape.
static func reagent_skill(item_id: String) -> StringName:
	var cut: int = item_id.rfind("_")
	if not item_id.begins_with(REAGENT_PREFIX) or cut <= REAGENT_PREFIX.length() or not item_id.substr(cut + 1).is_valid_int():
		return &""
	return StringName(item_id.substr(REAGENT_PREFIX.length(), cut - REAGENT_PREFIX.length()))


static func _is_reagent(v: DataValidatorRules, item_id: Variant) -> bool:
	return item_id is String and v.items.has(StringName(item_id as String)) \
			and v.items[StringName(item_id as String)].get("category") == "reagent"


# Trainer skill -> its `vendor` (only the Trainers that have one).
static func _vendors(raw: Dictionary) -> Dictionary[StringName, StringName]:
	var result: Dictionary[StringName, StringName] = {}
	var files: Dictionary = raw.get("disciplines", {}) as Dictionary
	for path: Variant in files:
		for t: Variant in ((files[path] as Dictionary).get("trainers", []) as Array):
			if t is Dictionary and (t as Dictionary).get("skill") is String and (t as Dictionary).get("vendor") is String:
				result[StringName((t as Dictionary)["skill"] as String)] = StringName((t as Dictionary)["vendor"] as String)
	return result


# Every shop entry that sells an item pays more than the item is worth (F-171); the `profession` entries sell a Recipe or a reagent.
static func _shop(v: DataValidatorRules, raw: Dictionary, skill_of: Dictionary[StringName, StringName],
		vendors: Dictionary[StringName, StringName], real: bool) -> void:
	var files: Dictionary = raw.get("shop", {}) as Dictionary
	for path: Variant in files:
		v.at_file(str(path))
		var list: Array = (files[path] as Dictionary).get("entries", []) as Array
		for index: int in list.size():
			if not list[index] is Dictionary:
				continue
			var e: Dictionary = list[index] as Dictionary
			v.at_entry("shop entry", index, e)
			var effect: Dictionary = e["effect"] as Dictionary if e.get("effect") is Dictionary else {}
			var sold: Dictionary = effect["item"] as Dictionary if effect.get("item") is Dictionary else {}
			var item: Dictionary = v.items.get(StringName(str(sold.get("item", ""))), {})
			if not item.is_empty():
				_cost(v, e, item, sold)
			if str(e.get("category")) == PROFESSION_CATEGORY:
				_profession_entry(v, e, item, skill_of, vendors, real)


static func _cost(v: DataValidatorRules, e: Dictionary, item: Dictionary, sold: Dictionary) -> void:
	var cost: Variant = (e["cost"] as Dictionary).get("gold") if e.get("cost") is Dictionary else null
	if not DataValidatorRules.is_int(cost) or not DataValidatorRules.is_int(item.get("value")) or not DataValidatorRules.is_int(sold.get("qty")):
		return
	var worth: int = int(item["value"]) * int(sold["qty"])
	if int(cost) <= worth:
		v.fail("field 'cost.gold' (%d) must be above the value of the item sold (%d)" % [int(cost), worth])


static func _profession_entry(v: DataValidatorRules, e: Dictionary, item: Dictionary, skill_of: Dictionary[StringName, StringName],
		vendors: Dictionary[StringName, StringName], real: bool) -> void:
	var category: String = str(item.get("category"))
	var skill: StringName = &""
	var action_level: int = 0
	var want_max: int = 0
	if category == "recipe" and item.get("recipe") is Dictionary:
		var action_id: StringName = StringName(str((item["recipe"] as Dictionary).get("action", "")))
		skill = skill_of.get(action_id, &"")
		want_max = 1
		var action_def: Dictionary = v.actions.get(action_id, {})
		action_level = int(action_def["level"]) if DataValidatorRules.is_int(action_def.get("level")) else 0
	elif category == "reagent":
		skill = reagent_skill(str(item.get("id", "")))
	else:
		v.fail("a 'profession' entry must sell a Recipe or a reagent (field 'effect.item')")
		return
	if skill == &"":
		v.fail("the skill of the item sold cannot be found (an action of the Recipe or the id of the reagent)")
		return
	if DataValidatorRules.is_int(e.get("max_purchases")) and int(e["max_purchases"]) != want_max:
		v.fail("field 'max_purchases' must be %d for a %s" % [want_max, category])
	var req: Dictionary = e["requires"] as Dictionary if e.get("requires") is Dictionary else {}
	var skills: Dictionary = req["skills"] as Dictionary if req.get("skills") is Dictionary else {}
	var names: Array = skills.keys().filter(func(k: Variant) -> bool: return str(k) != DataValidatorRules.DOC_KEY)
	if names.size() != 1 or StringName(str(names[0])) != skill:
		v.fail("field 'requires.skills' must name only the skill '%s'" % skill)
	elif real and category == "recipe" and DataValidatorRules.is_int(skills[names[0]]) and int(skills[names[0]]) != action_level:
		v.fail("field 'requires.skills.%s' must be the level of the action (%d)" % [skill, action_level])
	if vendors.get(skill, &"") == &"" or str(e.get("vendor")) != String(vendors[skill]):
		v.fail("field 'vendor' must be the vendor of the Trainer of '%s' (%s)" % [skill, vendors.get(skill, &"none")])


# Real data (strict and with colors): the three crafting skills have colors on every non-single action, Riftbinding on none,
# and each of the three Trainers has its vendor.
static func _real_data(v: DataValidatorRules, actions: Dictionary, vendors: Dictionary[StringName, StringName]) -> void:
	for path: Variant in actions:
		var skill: String = str((actions[path] as Dictionary).get("skill", ""))
		v.at_file(str(path))
		for a: Variant in ((actions[path] as Dictionary).get("actions", []) as Array):
			if not a is Dictionary:
				continue
			v.at_entry("action", 0, a as Dictionary)
			var single: bool = (a as Dictionary).get("single") is bool and (a as Dictionary)["single"]
			if REAL_VENDORS.has(skill) and not single and not (a as Dictionary).has("colors"):
				v.fail("an action of '%s' needs 'colors'" % skill)
			elif skill == "riftbinding" and (a as Dictionary).has("colors"):
				v.fail("an action of 'riftbinding' must not have 'colors'")
	v.at_file("section 'disciplines'")
	for skill: String in REAL_VENDORS:
		if str(vendors.get(StringName(skill), "")) != REAL_VENDORS[skill]:
			v.fail("the Trainer of '%s' must have vendor '%s'" % [skill, REAL_VENDORS[skill]])
