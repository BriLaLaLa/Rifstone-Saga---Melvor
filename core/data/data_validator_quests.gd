class_name DataValidatorQuests
extends RefCounted
## Quest rules of DataValidator (internal, M20; docs/04_DATA_SCHEMA.md §25, docs/02_FORMULAS.md F-134): the `quest`
## section of balance.json and data/quests/quests.json. `quest_for` is the pure F-134 function: the validator compares
## every written quest with it, tools/gen_quests.gd writes them with it and the tests call it.

const TIERS: int = 8
const TYPES: PackedStringArray = ["kill", "gather", "craft"]
const SKILLS_OF: Dictionary = {"gather": ["forestry", "quarrying", "angling"], "craft": ["forging", "hearthcraft", "woodwright"]}
const QUEST_FIELDS: PackedStringArray = ["id", "name", "description", "type", "tier", "skill", "item", "target", "requires", "reward"]
const PARAM_KEYS: PackedStringArray = ["tier_levels", "tier_window", "recent_memory", "gold_by_tier", "xp_unit_by_tier",
	"kill_food_qty", "types"]
const CRAFT_SKILLS: PackedStringArray = ["forging", "hearthcraft", "woodwright"]


## True for the `quest` section of balance.json (its fields are checked by `validate_balance`).
static func is_known_key(path: String) -> bool:
	return path == "quest"


## The lookup used by `quest_for`, from the parsed files of data/items/ and data/actions/ (path -> top-level object):
## `{"names": {item_id: name}, "producers": {item_id: {"skill": String, "level": int}}}` (first producing action wins).
static func lookup_from(items_files: Dictionary, actions_files: Dictionary) -> Dictionary:
	var names: Dictionary = {}
	for path: Variant in items_files:
		for item: Variant in (items_files[path] as Dictionary).get("items", []) as Array:
			if item is Dictionary and (item as Dictionary).get("id") is String and (item as Dictionary).get("name") is String:
				names[(item as Dictionary)["id"]] = (item as Dictionary)["name"]
	var producers: Dictionary = {}
	for path: Variant in actions_files:
		var file: Dictionary = actions_files[path] as Dictionary
		for action: Variant in file.get("actions", []) as Array:
			if not action is Dictionary:
				continue
			for out: Variant in (action as Dictionary).get("outputs", []) as Array:
				var item: String = str((out as Dictionary).get("item")) if out is Dictionary else ""
				if not item.is_empty() and not producers.has(item):
					producers[item] = {"skill": str(file.get("skill")), "level": int(float((action as Dictionary).get("level", 0)))}
	return {"names": names, "producers": producers}


## The item a quest of `skill` asks for at tier `tier` (1..8); "" for an unknown skill.
static func item_for(skill: String, tier: int) -> String:
	var wood: String = DataValidatorVillage.WOODS[tier - 1]
	var metal: String = DataValidatorVillage.METALS[tier - 1]
	var fish: String = DataValidatorVillage.FISH[tier - 1]
	match skill:
		"forestry": return wood + "_log"
		"quarrying": return metal + "_ore"
		"angling": return fish
		"forging": return metal + "_plate"
		"hearthcraft": return "seared_" + fish
		"woodwright": return wood + "_grip"
	return ""


## F-134: the quest of `type` (kill, gather, craft), `skill` ("" for kill) and `tier` (1..8) with the `quest` parameters of
## balance.json and the lookup of `lookup_from`. `{}` if the item has no name or no producing action of that skill.
static func quest_for(type: String, skill: String, tier: int, params: Dictionary, lookup: Dictionary) -> Dictionary:
	var spec: Dictionary = (params["types"] as Dictionary)[type] as Dictionary
	var mult: int = int((spec.get("mult", {}) as Dictionary).get(skill, 1))
	var target: int = (int(spec["base"]) + int(spec["per_tier"]) * (tier - 1)) * mult
	var gold: float = float(int((params["gold_by_tier"] as Array)[tier - 1])) * float(spec["gold_mult"])
	var reward: Dictionary = {"gold": int(floorf(gold / 10.0 + 0.5)) * 10}
	var character: int = int((params["tier_levels"] as Array)[tier - 1])
	if type == "kill":
		var food: String = "seared_" + DataValidatorVillage.FISH[tier - 1]
		if not (lookup["names"] as Dictionary).has(food):
			return {}
		reward["items"] = [{"item": food, "qty": int(params["kill_food_qty"])}]
		return {"id": "kill_any_t%d" % tier, "name": "Caccia di gradino %d" % tier,
				"description": "Sconfiggi %d mostri, in qualunque area." % target, "type": type, "tier": tier,
				"target": target, "requires": {"character": character, "skills": {}}, "reward": reward}
	var item: String = item_for(skill, tier)
	var producer: Dictionary = (lookup["producers"] as Dictionary).get(item, {}) as Dictionary
	if not (lookup["names"] as Dictionary).has(item) or str(producer.get("skill")) != skill:
		return {}
	var item_name: String = str((lookup["names"] as Dictionary)[item])
	reward["xp"] = {"skill": skill, "amount": int(spec["xp_cycles"]) * int((params["xp_unit_by_tier"] as Array)[tier - 1])}
	reward["items"] = []
	var gather: bool = type == "gather"
	return {"id": "%s_%s_t%d" % [type, skill, tier],
			"name": ("Raccolta: " if gather else "Produzione: ") + item_name,
			"description": ("Raccogli %d pezzi di %s." if gather else "Produci %d pezzi di %s.") % [target, item_name],
			"type": type, "tier": tier, "skill": skill, "item": item, "target": target,
			"requires": {"character": character, "skills": {skill: int(producer["level"])}}, "reward": reward}


## Every quest in file order (tier, then kill, gather, craft; skills as in SKILLS_OF): `{"quests": Array[Dictionary],
## "errors": PackedStringArray}`. A quest that cannot be built is reported in `errors`.
static func all_for(params: Dictionary, lookup: Dictionary) -> Dictionary:
	var quests: Array[Dictionary] = []
	var errors: PackedStringArray = []
	for tier: int in range(1, TIERS + 1):
		for type: String in TYPES:
			for skill: String in ([""] if type == "kill" else SKILLS_OF[type] as Array):
				var quest: Dictionary = quest_for(type, skill, tier, params, lookup)
				if quest.is_empty():
					errors.append("%s %s tier %d: its item does not exist or is not produced by an action of that skill" % [type, skill, tier])
				else:
					quests.append(quest)
	return {"quests": quests, "errors": errors}


static func validate_balance(v: DataValidatorRules, balance: Dictionary) -> void:
	var section: Variant = DataValidator.lookup(balance, "quest")
	if not section is Dictionary:
		v.fail("missing key 'quest'")
		return
	var quest: Dictionary = section as Dictionary
	v.keys(quest, PARAM_KEYS, "quest")
	_levels(v, quest)
	v.integer(quest, "tier_window", 1.0, float(TIERS), "quest")
	v.integer(quest, "recent_memory", 0.0, DataValidatorRules.NO_LIMIT, "quest")
	_tier_table(v, quest, "gold_by_tier")
	_tier_table(v, quest, "xp_unit_by_tier")
	v.integer(quest, "kill_food_qty", 1.0, DataValidatorRules.NO_LIMIT, "quest")
	var types: Dictionary = v.object(quest, "types", "quest")
	v.keys(types, TYPES, "quest.types")
	for type: String in TYPES:
		var spec: Dictionary = v.object(types, type, "quest.types")
		var prefix: String = "quest.types.%s" % type
		var allowed: PackedStringArray = ["base", "per_tier", "gold_mult"]
		if type != "kill":
			allowed.append("xp_cycles")
		if type == "craft":
			allowed.append("mult")
		v.keys(spec, allowed, prefix)
		v.integer(spec, "base", 1.0, DataValidatorRules.NO_LIMIT, prefix)
		v.integer(spec, "per_tier", 0.0, DataValidatorRules.NO_LIMIT, prefix)
		v.number(spec, "gold_mult", 0.0, DataValidatorRules.NO_LIMIT, prefix, true)
		if type != "kill":
			v.integer(spec, "xp_cycles", 1.0, DataValidatorRules.NO_LIMIT, prefix)
		if type == "craft":
			var mult: Dictionary = v.object(spec, "mult", prefix)
			v.keys(mult, CRAFT_SKILLS, prefix + ".mult")
			for skill: String in CRAFT_SKILLS:
				v.integer(mult, skill, 1.0, DataValidatorRules.NO_LIMIT, prefix + ".mult")


## data/quests/quests.json. The files of balance, items and actions give the parameters and the lookup of the
## regeneration (skipped when the balance is invalid). An empty list is accepted (test fixtures).
static func validate(v: DataValidatorRules, files: Dictionary[String, Dictionary], balance_files: Dictionary[String, Dictionary],
		items_files: Dictionary[String, Dictionary], actions_files: Dictionary[String, Dictionary]) -> void:
	var params: Dictionary = _valid_params(balance_files)
	var seen: Dictionary[StringName, bool] = {}
	for path: String in files:
		v.at_file(path)
		var list: Array[Dictionary] = DataValidator.entries(v, files[path], "quests")
		var expected: Dictionary = {}
		if not params.is_empty() and not list.is_empty():
			expected = all_for(params, lookup_from(items_files, actions_files))
			for message: String in expected["errors"] as PackedStringArray:
				v.fail("cannot regenerate (F-134): " + message)
			if list.size() != (expected["quests"] as Array).size() and (expected["errors"] as PackedStringArray).is_empty():
				v.fail("expected %d quests (F-134 regeneration), got %d" % [(expected["quests"] as Array).size(), list.size()])
		for index: int in list.size():
			var e: Dictionary = list[index]
			v.entry("quest", index, e, seen, QUEST_FIELDS)
			if expected.is_empty() or index >= (expected["quests"] as Array).size():
				continue
			var diff: String = _first_diff(e, (expected["quests"] as Array)[index], "")
			if not diff.is_empty():
				v.fail("field '%s' differs from the F-134 regeneration (rerun tools/gen_quests.gd)" % diff)


# The path of the first difference between the written value and the regenerated one ("" if equal); numbers compare by value.
static func _first_diff(written: Variant, expected: Variant, path: String) -> String:
	if expected is Dictionary:
		if not written is Dictionary:
			return path
		for key: Variant in expected as Dictionary:
			var at: String = str(key) if path.is_empty() else "%s.%s" % [path, key]
			if not (written as Dictionary).has(key):
				return at
			var inner: String = _first_diff((written as Dictionary)[key], (expected as Dictionary)[key], at)
			if not inner.is_empty():
				return inner
		for key: Variant in written as Dictionary:
			if not (expected as Dictionary).has(key) and str(key) != DataValidatorRules.DOC_KEY:
				return str(key) if path.is_empty() else "%s.%s" % [path, key]
		return ""
	if expected is Array:
		if not written is Array or (written as Array).size() != (expected as Array).size():
			return path
		for index: int in (expected as Array).size():
			var inner: String = _first_diff((written as Array)[index], (expected as Array)[index], "%s[%d]" % [path, index])
			if not inner.is_empty():
				return inner
		return ""
	if DataValidatorRules.is_number(expected):
		return "" if DataValidatorRules.is_number(written) and is_equal_approx(float(written), float(expected)) else path
	return "" if written == expected else path


static func _levels(v: DataValidatorRules, quest: Dictionary) -> void:
	if not quest.get("tier_levels") is Array or (quest["tier_levels"] as Array).size() != TIERS:
		v.fail("key 'quest.tier_levels' must be an array of %d integers" % TIERS)
		return
	var previous: float = 0.0
	for value: Variant in quest["tier_levels"] as Array:
		if not DataValidatorRules.is_int(value) or float(value) < 1.0 or float(value) > 99.0 or float(value) <= previous:
			v.fail("key 'quest.tier_levels' must be strictly increasing integers in 1..99, got %s" % JSON.stringify(quest["tier_levels"]))
			return
		previous = float(value)


static func _tier_table(v: DataValidatorRules, quest: Dictionary, key: String) -> void:
	if not quest.get(key) is Array or (quest[key] as Array).size() != TIERS:
		v.fail("key 'quest.%s' must be an array of %d integers" % [key, TIERS])
		return
	for value: Variant in quest[key] as Array:
		if not DataValidatorRules.is_int(value) or float(value) < 1.0:
			v.fail("key 'quest.%s' must contain integers >= 1, got %s" % [key, JSON.stringify(quest[key])])
			return


# `quest` of balance.json when valid ({} otherwise; the balance errors are reported by validate_balance).
static func _valid_params(balance_files: Dictionary[String, Dictionary]) -> Dictionary:
	for path: String in balance_files:
		var probe := DataValidatorRules.new()
		validate_balance(probe, balance_files[path])
		if probe.errors.is_empty():
			return DataValidator.lookup(balance_files[path], "quest") as Dictionary
	return {}
