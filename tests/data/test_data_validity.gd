extends GutTest
## Validity of the real game data under res://data (04_DATA_SCHEMA.md, 00_VISION.md, 02_FORMULAS.md §8.1, F-11).
## The checks that the validator leaves to this file live here: the 12 skill ids of 00_VISION.md, `mastery: true`
## on every action of the MVP, the gathering tiers of §8.1. The expected values below are the oracle.
##
## Until M3-04 (shop.json) and M4-04 (areas.json, monsters.json) the real data cannot be fully valid: the
## single-file sections that do not exist yet are replaced in memory by empty lists, so that every other section is
## validated with the real DataValidator; the full `GameData.load_from_dirs()` test stays pending until then.

const CONTENT_ROOT: String = "res://data"
const CONFIG_ROOT: String = "res://data/config"
## Single-file sections that arrive after M1: content file -> list key of the empty stand-in, and the task.
const LATER_SECTIONS: Dictionary[String, Array] = {
	"areas": ["areas", "M4-04"], "monsters": ["monsters", "M4-04"], "shop": ["entries", "M3-04"],
}
## 00_VISION.md, in sidebar order: [id, name, category].
const SKILLS: Array[Array] = [
	["forestry", "Selvicoltura", "gathering"], ["quarrying", "Cavatura", "gathering"],
	["angling", "Lenza", "gathering"], ["forging", "Forgiatura", "artisan"], ["hearthcraft", "Focolare", "artisan"],
	["woodwright", "Intaglio", "artisan"], ["blade", "Lama", "combat"], ["marksmanship", "Mira", "combat"],
	["arcana", "Arcano", "combat"], ["vitality", "Vitalità", "combat"], ["guard", "Guardia", "combat"],
	["riftbinding", "Legatura del Rift", "artisan"],
]
## F-11 rules as [every_levels or at_level key, level, stat, value].
const GATHERING_BONUSES: Array[Array] = [
	["every_levels", 10, "double_item_chance", 1.0], ["at_level", 99, "double_item_chance", 5.0],
]
const ARTISAN_BONUSES: Array[Array] = [
	["every_levels", 10, "preservation_chance", 1.5], ["at_level", 99, "skill_interval_pct", -5.0],
]
## 02_FORMULAS.md §8.1, T1..T8: [level, interval_ms, xp, product qty, item value].
const GATHERING_TIERS: Array[Array] = [
	[1, 3000, 10, 1, 1], [10, 3200, 18, 1, 3], [20, 3500, 28, 1, 6], [30, 3800, 40, 1, 10],
	[45, 4200, 58, 1, 18], [60, 4600, 80, 1, 30], [75, 5000, 108, 1, 50], [90, 5500, 145, 1, 85],
]
## Gathering skills whose actions exist in M1 (quarrying and angling arrive with M2).
const GATHERING_WITH_ACTIONS: PackedStringArray = ["forestry"]

var _raw: Dictionary = {}
var _load_errors: PackedStringArray = []


func before_all() -> void:
	_raw = {
		"balance": _read([CONFIG_ROOT.path_join(GameData.BALANCE_FILE)]),
		"stats": _read([CONFIG_ROOT.path_join(GameData.STATS_FILE)]),
	}
	for section: String in GameData.CONTENT_FILES:
		var path: String = CONTENT_ROOT.path_join(GameData.CONTENT_FILES[section])
		if LATER_SECTIONS.has(section) and not FileAccess.file_exists(path):
			_raw[section] = {"<empty stand-in>/%s.json" % section: {LATER_SECTIONS[section][0]: []}}
		else:
			_raw[section] = _read([path])
	for section: String in GameData.CONTENT_DIRS:
		_raw[section] = _read(JsonLoader.list_json_files(CONTENT_ROOT.path_join(GameData.CONTENT_DIRS[section]),
				_load_errors))


func _read(paths: PackedStringArray) -> Dictionary:
	var files: Dictionary = {}
	for path: String in paths:
		var content: Variant = JsonLoader.load_file(path, _load_errors)
		if content is Dictionary:
			files[path] = content
	return files


# Every entry of the list `key` of every file of a section.
func _entries(section: String, key: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for path: Variant in _raw[section]:
		for e: Variant in (_raw[section][path] as Dictionary).get(key, []):
			result.append(e as Dictionary)
	return result


func _by_id(section: String, key: String) -> Dictionary:
	var result: Dictionary = {}
	for e: Dictionary in _entries(section, key):
		result[e["id"]] = e
	return result


func test_real_files_load() -> void:
	assert_eq(_load_errors, PackedStringArray())


func test_m1_sections_pass_the_validator() -> void:
	var errors: PackedStringArray = []
	DataValidator.validate(_raw, errors)
	assert_eq(errors, PackedStringArray())


func test_real_data_errors_are_only_later_sections() -> void:
	var data: GameData = GameData.load_from_dirs(CONTENT_ROOT, CONFIG_ROOT)
	for message: String in data.errors:
		var later: bool = false
		for section: String in LATER_SECTIONS:
			later = later or message.contains("/%s.json:" % section) or message.contains("section '%s'" % section)
		assert_true(later, "unexpected data error: %s" % message)


func test_real_data_is_valid() -> void:
	var missing: PackedStringArray = []
	for section: String in LATER_SECTIONS:
		if not FileAccess.file_exists(CONTENT_ROOT.path_join(GameData.CONTENT_FILES[section])):
			missing.append("%s (task %s)" % [GameData.CONTENT_FILES[section], LATER_SECTIONS[section][1]])
	if not missing.is_empty():
		pending("full GameData.load_from_dirs() needs files that do not exist yet: %s" % ", ".join(missing))
		return
	var data: GameData = GameData.load_from_dirs(CONTENT_ROOT, CONFIG_ROOT)
	assert_true(data.is_valid())
	assert_eq(data.errors, PackedStringArray())


func test_twelve_skills_of_the_vision_in_order() -> void:
	var skills: Array[Dictionary] = _entries("skills", "skills")
	skills.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["order"] < b["order"])
	assert_eq(skills.size(), SKILLS.size())
	for index: int in mini(skills.size(), SKILLS.size()):
		assert_eq(skills[index]["id"], SKILLS[index][0], "skill at order position %d" % index)
		assert_eq(skills[index]["name"], SKILLS[index][1], "name of %s" % SKILLS[index][0])
		assert_eq(skills[index]["category"], SKILLS[index][2], "category of %s" % SKILLS[index][0])


func test_skill_colors_are_unique() -> void:
	var colors: Dictionary = {}
	for e: Dictionary in _entries("skills", "skills"):
		assert_false(colors.has(e["color"]), "color %s of %s is already used" % [e["color"], e["id"]])
		colors[e["color"]] = true


func test_balance_combat_skills_are_combat_skills() -> void:
	var skills: Dictionary = _by_id("skills", "skills")
	var balance: Dictionary = _raw["balance"].values()[0] as Dictionary
	for key: String in ["combat.hp_skill", "combat.defence_skill"]:
		var id: Variant = DataValidator.lookup(balance, key)
		assert_true(skills.has(id), "%s = %s" % [key, id])
		if skills.has(id):
			assert_eq(skills[id]["category"], "combat", key)


func test_mastery_only_outside_combat() -> void:
	for e: Dictionary in _entries("skills", "skills"):
		assert_eq(e["has_mastery"], e["category"] != "combat", "has_mastery of %s" % e["id"])


func test_mastery_bonuses_follow_f11() -> void:
	for e: Dictionary in _entries("skills", "skills"):
		if e["category"] == "combat":
			assert_false(e.has("mastery_bonuses"), "combat skill %s" % e["id"])
			continue
		var expected: Array[Array] = GATHERING_BONUSES if e["category"] == "gathering" else ARTISAN_BONUSES
		var rules: Array = e.get("mastery_bonuses", [])
		assert_eq(rules.size(), expected.size(), "rules of %s" % e["id"])
		for index: int in mini(rules.size(), expected.size()):
			var rule: Dictionary = rules[index] as Dictionary
			var want: Array = expected[index]
			assert_eq(rule.get(want[0]), float(want[1]), "%s rule %d level" % [e["id"], index])
			assert_eq((rule["modifiers"] as Array).size(), 1, "%s rule %d modifiers" % [e["id"], index])
			var m: Dictionary = rule["modifiers"][0] as Dictionary
			assert_eq(m["stat"], want[2], "%s rule %d stat" % [e["id"], index])
			assert_almost_eq(float(m["value"]), float(want[3]), 0.0001, "%s rule %d value" % [e["id"], index])


func test_every_action_has_mastery() -> void:
	for path: Variant in _raw["actions"]:
		for e: Variant in (_raw["actions"][path] as Dictionary)["actions"]:
			assert_eq((e as Dictionary)["mastery"], true, "action %s of %s" % [(e as Dictionary)["id"], path])


func test_gathering_actions_follow_the_tiers() -> void:
	var items: Dictionary = _by_id("items", "items")
	var seen_skills: Array[String] = []
	for path: Variant in _raw["actions"]:
		var content: Dictionary = _raw["actions"][path] as Dictionary
		var skill: String = content["skill"] as String
		if not SKILLS.any(func(s: Array) -> bool: return s[0] == skill and s[2] == "gathering"):
			continue
		seen_skills.append(skill)
		var actions: Array = (content["actions"] as Array).duplicate()
		actions.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["level"] < b["level"])
		assert_eq(actions.size(), GATHERING_TIERS.size(), "actions of %s" % skill)
		for index: int in mini(actions.size(), GATHERING_TIERS.size()):
			_assert_tier(actions[index] as Dictionary, GATHERING_TIERS[index], index + 1, items)
	for skill: String in GATHERING_WITH_ACTIONS:
		assert_true(seen_skills.has(skill), "actions file of %s" % skill)


func _assert_tier(action: Dictionary, tier: Array, n: int, items: Dictionary) -> void:
	var at: String = "%s (T%d)" % [action["id"], n]
	assert_eq(action["level"], float(tier[0]), "%s level" % at)
	assert_eq(action["interval_ms"], float(tier[1]), "%s interval_ms" % at)
	assert_eq(action["xp"], float(tier[2]), "%s xp" % at)
	assert_eq((action["inputs"] as Array).size(), 0, "%s inputs" % at)
	var outputs: Array = action["outputs"] as Array
	assert_eq(outputs.size(), 1, "%s outputs" % at)
	if outputs.size() != 1:
		return
	var output: Dictionary = outputs[0] as Dictionary
	assert_eq(output["qty"], float(tier[3]), "%s qty" % at)
	assert_true(items.has(output["item"]), "%s item %s" % [at, output["item"]])
	if items.has(output["item"]):
		assert_eq(items[output["item"]]["value"], float(tier[4]), "%s value of %s" % [at, output["item"]])
		assert_eq(items[output["item"]]["category"], "material", "%s category of %s" % [at, output["item"]])


func test_rift_shard_is_misc() -> void:
	var items: Dictionary = _by_id("items", "items")
	assert_true(items.has("rift_shard"))
	if items.has("rift_shard"):
		assert_eq(items["rift_shard"]["category"], "misc")


func test_icons_exist() -> void:
	var entries: Array[Dictionary] = _entries("skills", "skills")
	entries.append_array(_entries("items", "items"))
	for e: Dictionary in entries:
		assert_true(FileAccess.file_exists(e["icon"] as String), "icon of %s: %s" % [e["id"], e["icon"]])


func test_names_are_unique_per_kind() -> void:
	for kind: Array in [["skills", "skills"], ["items", "items"], ["actions", "actions"]]:
		var names: Dictionary = {}
		for e: Dictionary in _entries(kind[0], kind[1]):
			assert_false(names.has(e["name"]), "%s name '%s' of %s is already used" % [kind[0], e["name"], e["id"]])
			names[e["name"]] = true
