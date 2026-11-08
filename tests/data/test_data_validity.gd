extends GutTest
## Validity of the real game data under res://data (04_DATA_SCHEMA.md, 00_VISION.md, 02_FORMULAS.md §8.1, F-11).
## The checks that the validator leaves to this file live here: the 7 skill ids of 00_VISION.md, `mastery: true`
## on every action of the MVP, the gathering tiers of §8.1. The expected values below are the oracle.

const CONTENT_ROOT: String = "res://data"
const CONFIG_ROOT: String = "res://data/config"
## 00_VISION.md, in sidebar order: [id, name, category].
const SKILLS: Array[Array] = [
	["forestry", "Boscaiolo", "gathering"], ["quarrying", "Minatore", "gathering"],
	["angling", "Pescatore", "gathering"], ["forging", "Fabbro", "artisan"], ["hearthcraft", "Cuoco", "artisan"],
	["woodwright", "Falegname", "artisan"], ["riftbinding", "Incisore", "artisan"],
]
## Ids that the reform removed (D3, Q37): combat skills, bows and staves.
const REMOVED_SKILLS: PackedStringArray = ["blade", "marksmanship", "arcana", "vitality", "guard"]
const REMOVED_ITEM_SUFFIXES: PackedStringArray = ["_blade", "_bow", "_staff"]
## F-11 rules as [every_levels or at_level key, level, stat, value] (artisan only: the gathering trades use the milestones).
const ARTISAN_BONUSES: Array[Array] = [
	["every_levels", 10, "preservation_chance", 1.5], ["at_level", 99, "skill_interval_pct", -5.0],
]
## 02_FORMULAS.md §8.1, T1..T8: [level, interval_ms, xp, product qty, item value].
const GATHERING_TIERS: Array[Array] = [
	[1, 3000, 10, 1, 1], [10, 3200, 18, 1, 3], [20, 3500, 28, 1, 6], [30, 3800, 40, 1, 10],
	[45, 4200, 58, 1, 18], [60, 4600, 80, 1, 30], [75, 5000, 108, 1, 50], [90, 5500, 145, 1, 85],
]
## Gathering skills whose actions exist (M1: forestry; M2: quarrying and angling).
const GATHERING_WITH_ACTIONS: PackedStringArray = ["forestry", "quarrying", "angling"]
## 02_FORMULAS.md §8.8, forestry nodes: [id, cost_pct, requires, [[stat, value], ...]] (scope skill:forestry).
const FORESTRY_NODES: Array[Array] = [
	["forestry_n1_quick_axe", 5.0, [], [["skill_interval_pct", -3.0]]],
	["forestry_n2_keen_eye", 7.5, ["forestry_n1_quick_axe"], [["double_item_chance", 3.0]]],
	["forestry_n3_lore", 7.5, ["forestry_n1_quick_axe"], [["skill_xp_pct", 4.0]]],
	["forestry_n4_rift_bark", 10.0, ["forestry_n2_keen_eye"], [["rift_shard_chance", 0.25]]],
	["forestry_n5_patience", 10.0, ["forestry_n3_lore"], [["mastery_xp_pct", 5.0]]],
	["forestry_n6_master", 20.0, ["forestry_n4_rift_bark", "forestry_n5_patience"],
			[["skill_interval_pct", -5.0], ["double_item_chance", 5.0]]],
]
## 02_FORMULAS.md §8.8b, the modifiers of the nodes n1..n6 of the other gathering trades (costs and requires as forestry).
const TRADE_NODE_MODS: Dictionary = {
	"quarrying": [[["double_item_chance", 2.0]], [["rift_shard_chance", 0.25]], [["mastery_xp_pct", 4.0]],
		[["double_item_chance", 4.0]], [["skill_xp_pct", 5.0]], [["double_item_chance", 6.0], ["rift_shard_chance", 0.25]]],
	"angling": [[["skill_xp_pct", 3.0]], [["skill_interval_pct", -3.0]], [["rift_shard_chance", 0.25]],
		[["skill_xp_pct", 5.0]], [["double_item_chance", 3.0]], [["skill_interval_pct", -5.0], ["rift_shard_chance", 0.5]]],
}
## §8.8: "the other skills with mastery follow the same schema (6 nodes, total 55-65%)".
const NODE_TOTAL_MIN_PCT: float = 55.0
const NODE_TOTAL_MAX_PCT: float = 65.0

var _raw: Dictionary = {}
var _load_errors: PackedStringArray = []


func before_all() -> void:
	_raw = {
		"balance": _read([CONFIG_ROOT.path_join(GameData.BALANCE_FILE)]),
		"stats": _read([CONFIG_ROOT.path_join(GameData.STATS_FILE)]),
	}
	for section: String in GameData.CONTENT_FILES:
		var path: String = CONTENT_ROOT.path_join(GameData.CONTENT_FILES[section])
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


func test_real_data_is_valid() -> void:
	var data: GameData = GameData.load_from_dirs(CONTENT_ROOT, CONFIG_ROOT)
	assert_true(data.is_valid())
	assert_eq(data.errors, PackedStringArray())


func test_seven_skills_of_the_vision_in_order() -> void:
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


func test_no_combat_skills_left() -> void:
	var skills: Dictionary = _by_id("skills", "skills")
	for id: String in REMOVED_SKILLS:
		assert_false(skills.has(id), "skill %s was removed by the reform" % id)
	for e: Dictionary in skills.values():
		assert_ne(e["id"], "character", "'character' is reserved for requirements")
		assert_ne(e["category"], "combat", "category of %s" % e["id"])


func test_every_skill_has_mastery() -> void:
	for e: Dictionary in _entries("skills", "skills"):
		assert_true(e["has_mastery"], "has_mastery of %s" % e["id"])


func test_no_removed_ids_in_items_and_actions() -> void:
	for e: Dictionary in _entries("items", "items") + _entries("actions", "actions"):
		for suffix: String in REMOVED_ITEM_SUFFIXES:
			assert_false((e["id"] as String).ends_with(suffix), "%s ends with %s" % [e["id"], suffix])
		for key: String in (e.get("equip", {}) as Dictionary).get("requirements", {}):
			assert_false(REMOVED_SKILLS.has(key), "requirement %s of %s" % [key, e["id"]])


func test_mastery_bonuses_follow_f11() -> void:
	for e: Dictionary in _entries("skills", "skills"):
		var expected: Array[Array] = []
		if e["category"] != "gathering":
			expected = ARTISAN_BONUSES
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
			# M10: the single-cycle blueprint action has no mastery (04 §6)
			assert_eq((e as Dictionary)["mastery"], not (e as Dictionary).get("single", false), "action %s of %s" % [(e as Dictionary)["id"], path])


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
	for kind: Array in [["skills", "skills"], ["items", "items"], ["actions", "actions"], ["mastery", "nodes"]]:
		var names: Dictionary = {}
		for e: Dictionary in _entries(kind[0], kind[1]):
			assert_false(names.has(e["name"]), "%s name '%s' of %s is already used" % [kind[0], e["name"], e["id"]])
			names[e["name"]] = true


# Mastery nodes of every mastery file, by skill, sorted by id (`<skill>_n<k>_…` sorts as n1..n6).
func _nodes_by_skill() -> Dictionary:
	var result: Dictionary = {}
	for path: Variant in _raw["mastery"]:
		var content: Dictionary = _raw["mastery"][path] as Dictionary
		var nodes: Array = (content["nodes"] as Array).duplicate()
		nodes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["id"] < b["id"])
		result[content["skill"]] = nodes
	return result


func test_every_gathering_skill_has_mastery_nodes() -> void:
	var by_skill: Dictionary = _nodes_by_skill()
	for skill: String in GATHERING_WITH_ACTIONS:
		assert_true(by_skill.has(skill), "mastery file of %s" % skill)
		if by_skill.has(skill):
			assert_eq((by_skill[skill] as Array).size(), FORESTRY_NODES.size(), "nodes of %s" % skill)


func test_forestry_nodes_follow_8_8() -> void:
	var nodes: Array = _nodes_by_skill().get("forestry", [])
	assert_eq(nodes.size(), FORESTRY_NODES.size())
	for index: int in mini(nodes.size(), FORESTRY_NODES.size()):
		assert_eq(nodes[index]["id"], FORESTRY_NODES[index][0], "forestry node %d" % (index + 1))
		_assert_node_like(nodes[index] as Dictionary, FORESTRY_NODES[index], "forestry", nodes)


func test_quarrying_and_angling_nodes_follow_8_8b() -> void:
	var by_skill: Dictionary = _nodes_by_skill()
	for skill: String in ["quarrying", "angling"]:
		var nodes: Array = by_skill.get(skill, [])
		assert_eq(nodes.size(), FORESTRY_NODES.size(), "nodes of %s" % skill)
		for index: int in mini(nodes.size(), FORESTRY_NODES.size()):
			var prefix: String = "%s_n%d_" % [skill, index + 1]
			assert_true((nodes[index]["id"] as String).begins_with(prefix), "%s starts with %s" % [nodes[index]["id"], prefix])
			var want: Array = FORESTRY_NODES[index].duplicate()
			want[3] = (TRADE_NODE_MODS[skill] as Array)[index]
			_assert_node_like(nodes[index] as Dictionary, want, skill, nodes)


# `node` has the cost, the requires (same positions in the n1..n6 order) and the modifiers of the row `want`,
# every modifier scoped to `skill:<skill>`.
func _assert_node_like(node: Dictionary, want: Array, skill: String, nodes: Array) -> void:
	var at: String = node["id"] as String
	assert_almost_eq(float(node["cost_pct"]), float(want[1]), 0.0001, "%s cost_pct" % at)
	var expected_requires: Array = []
	for required: Variant in want[2]:
		var row: int = FORESTRY_NODES.find_custom(func(r: Array) -> bool: return r[0] == required)
		expected_requires.append(nodes[row]["id"] if row < nodes.size() else "")
	assert_eq(node["requires"], expected_requires, "%s requires" % at)
	var modifiers: Array = node["modifiers"] as Array
	var expected: Array = want[3] as Array
	assert_eq(modifiers.size(), expected.size(), "%s modifiers" % at)
	for index: int in mini(modifiers.size(), expected.size()):
		var m: Dictionary = modifiers[index] as Dictionary
		assert_eq(m["stat"], expected[index][0], "%s modifier %d stat" % [at, index])
		assert_almost_eq(float(m["value"]), float(expected[index][1]), 0.0001, "%s modifier %d value" % [at, index])
		assert_eq(m.get("scope", "skill:%s" % skill), "skill:%s" % skill, "%s modifier %d scope" % [at, index])


func test_mastery_node_costs_total_55_to_65_pct() -> void:
	var by_skill: Dictionary = _nodes_by_skill()
	assert_false(by_skill.is_empty())
	for skill: Variant in by_skill:
		var total: float = 0.0
		for node: Variant in by_skill[skill]:
			total += float((node as Dictionary)["cost_pct"])
		assert_between(total, NODE_TOTAL_MIN_PCT, NODE_TOTAL_MAX_PCT, "total cost_pct of %s" % skill)


const ARTISAN_NODE_SKILLS: PackedStringArray = ["forging", "hearthcraft", "woodwright", "riftbinding"]
## Artisan trees: forestry shape with `preservation_chance` in place of `double_item_chance` / `rift_shard_chance`.
const ARTISAN_NODES: Array[Array] = [
	[5.0, [], [1, 0], [["skill_interval_pct", -3.0]]],
	[7.5, [0], [0, 1], [["preservation_chance", 3.0]]],
	[7.5, [0], [2, 1], [["skill_xp_pct", 4.0]]],
	[10.0, [1], [0, 2], [["preservation_chance", 2.0]]],
	[10.0, [2], [2, 2], [["mastery_xp_pct", 5.0]]],
	[20.0, [3, 4], [1, 3], [["skill_interval_pct", -5.0], ["preservation_chance", 5.0]]],
]


func test_riftbinding_actions_all_produce_infusions_stones_or_currencies() -> void:
	var items: Dictionary = _by_id("items", "items")
	for path: Variant in _raw["actions"]:
		var content: Dictionary = _raw["actions"][path] as Dictionary
		if content["skill"] == "riftbinding":
			for e: Dictionary in content["actions"]:
				assert_true(
						["infusion", "stone", "currency", "material"].has(items[e["outputs"][0]["item"]]["category"]), "output of %s" % e["id"])


func test_artisan_mastery_nodes_follow_the_artisan_schema() -> void:
	var by_skill: Dictionary = _nodes_by_skill()
	var actions: Array[Dictionary] = _entries("actions", "actions")
	for skill: String in ARTISAN_NODE_SKILLS:
		var nodes: Array = by_skill.get(skill, [])
		assert_eq(nodes.size(), ARTISAN_NODES.size(), "nodes of %s" % skill)
		for index: int in mini(nodes.size(), ARTISAN_NODES.size()):
			var node: Dictionary = nodes[index] as Dictionary
			var want: Array = ARTISAN_NODES[index]
			var at: String = node["id"] as String
			assert_true(at.begins_with("%s_n%d_" % [skill, index + 1]), "%s id prefix" % at)
			assert_almost_eq(float(node["cost_pct"]), float(want[0]), 0.0001, "%s cost" % at)
			var expected_requires: Array = []
			for r: int in want[1]:
				expected_requires.append(nodes[r]["id"])
			assert_eq(node["requires"], expected_requires, "%s requires" % at)
			assert_eq([int(node["pos"][0]), int(node["pos"][1])], want[2], "%s pos" % at)
			assert_eq((node["modifiers"] as Array).size(), (want[3] as Array).size(), "%s modifiers" % at)
			for m_index: int in mini((node["modifiers"] as Array).size(), (want[3] as Array).size()):
				var m: Dictionary = node["modifiers"][m_index] as Dictionary
				assert_eq(m["stat"], want[3][m_index][0], "%s stat" % at)
				assert_almost_eq(float(m["value"]), float(want[3][m_index][1]), 0.0001, "%s value" % at)
				assert_eq(m.get("scope", "skill:%s" % skill), "skill:%s" % skill, "%s scope" % at)
		var own: int = 0
		for a: Dictionary in actions:
			if (a["id"] as String).begins_with(["smelt_", "forge_", "cook_", "carve_", "engrave_"][ARTISAN_NODE_SKILLS.find(skill)]):
				own += 1
		assert_gt(own, 0, "%s has actions with the expected id prefix" % skill)


# M8-04: stones and currencies of the Rift (F-89, 01_GDD.md §26).
const STONE_COUNT: int = 12
const CURRENCY_EFFECTS: Dictionary = {"currency_spark": "to_magic", "currency_flux": "reroll", "currency_crown": "to_rare"}


func test_stones_have_modifiers_and_the_recipes_of_the_engraver() -> void:
	var items: Dictionary = _by_id("items", "items")
	var actions: Array[Dictionary] = _entries("actions", "actions")
	var stones: int = 0
	for id: Variant in items:
		if items[id]["category"] != "stone":
			continue
		stones += 1
		assert_gt((items[id]["stone"]["modifiers"] as Array).size(), 0, "%s modifiers" % id)
		assert_true(FileAccess.file_exists(items[id]["icon"] as String), "icon of %s" % id)
		var recipes: int = 0
		for a: Dictionary in actions:
			if not (a["outputs"] as Array).is_empty() and a["outputs"][0]["item"] == id:
				recipes += 1
		# M12: the chips fall from the monsters, the stones and the perfect stones are fused (F-105)
		assert_eq(recipes, 0 if (id as String).ends_with("_chip") else 1, "recipes of %s" % id)
	assert_eq(stones, STONE_COUNT, "number of stones")


func test_currencies_cover_the_three_effects_with_a_recipe() -> void:
	var items: Dictionary = _by_id("items", "items")
	var actions: Array[Dictionary] = _entries("actions", "actions")
	for id: String in CURRENCY_EFFECTS:
		assert_true(items.has(id), "currency %s" % id)
		if not items.has(id):
			continue
		assert_eq(items[id]["currency"]["effect"], CURRENCY_EFFECTS[id], "effect of %s" % id)
		assert_true(FileAccess.file_exists(items[id]["icon"] as String), "icon of %s" % id)
		var recipes: int = 0
		for a: Dictionary in actions:
			if not (a["outputs"] as Array).is_empty() and a["outputs"][0]["item"] == id:
				recipes += 1
		assert_eq(recipes, 1, "recipes of %s" % id)
