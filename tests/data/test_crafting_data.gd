extends GutTest
## Artisan recipes, food, equipment, tools, shop and affixes of the real data
## (02_FORMULAS.md §8.2-8.4, §8.6, §8.9; 04_DATA_SCHEMA.md §14-15). The expected values below are the oracle.

const CONTENT_ROOT: String = "res://data"
const METALS: PackedStringArray = [
	"emberbronze", "ashlead", "stormzinc", "duskcobalt", "glimmerite", "palecinnabar", "emberheart", "riftite",
]
const WOODS: PackedStringArray = [
	"redbirch", "ashpine", "thornalder", "duskelm", "shardcedar", "veilcypress", "emberlarch", "riftspruce",
]
const FISH: PackedStringArray = [
	"brookfin", "ashgill", "redscale", "dusk_eel", "shard_gar", "mist_barbel", "ember_sturgeon", "riftmaw",
]
const HEAL: Array[int] = [20, 35, 55, 80, 110, 150, 200, 260]
## 02_FORMULAS.md §8.1, T1..T8: [level, interval_ms, xp, product qty, item value].
const GATHERING_TIERS: Array[Array] = [
	[1, 3000, 10, 1, 1], [10, 3200, 18, 1, 3], [20, 3500, 28, 1, 6], [30, 3800, 40, 1, 10],
	[45, 4200, 58, 1, 18], [60, 4600, 80, 1, 30], [75, 5000, 108, 1, 50], [90, 5500, 145, 1, 85],
]
## Armor rows: [suffix, ingots, slot, evasion per grade, damage reduction kind (0 none, 1 n, 2 ceil(n/2))].
const ARMOR_PIECES: Array[Array] = [
	["cuirass", 5, "body", 6, 1], ["greaves", 4, "legs", 4, 2], ["helm", 3, "head", 3, 2],
	["boots", 2, "feet", 2, 0], ["gauntlets", 2, "hands", 2, 0],
]
## Tools: [suffix, skill, slot].
const TOOL_PIECES: Array[Array] = [
	["hatchet", "forestry", "tool_forestry"], ["pick", "quarrying", "tool_quarrying"],
	["rod", "angling", "tool_angling"],
]
## Weapons: [suffix, kind, interval, two handed, accuracy per grade, power per grade, ingots,
## recipe interval, value per ore value].
const WEAPONS: Array[Array] = [
	["sword", "sword", 2400, false, 8, 6, 3, 3000, 12], ["greatsword", "greatsword", 3200, true, 9, 11, 5, 3500, 20],
]
## 02_FORMULAS.md §8.9: [id, stat, slots, [[min, max] x4], weight].
const AFFIXES: Array[Array] = [
	["keen", "accuracy_bonus", ["weapon", "hands", "ring"], [[2, 4], [5, 8], [9, 14], [15, 22]], 10],
	["heavy", "power_bonus", ["weapon", "hands", "ring"], [[2, 3], [4, 6], [7, 10], [11, 16]], 10],
	["precise", "accuracy_pct", ["weapon", "neck"], [[1, 2], [3, 4], [5, 6], [7, 9]], 6],
	["brutal", "power_pct", ["weapon", "neck"], [[1, 2], [3, 4], [5, 6], [7, 9]], 6],
	["swift", "attack_interval_pct", ["weapon", "hands", "feet"], [[-2, -1], [-3, -2], [-4, -3], [-6, -4]], 4],
	["nimble", "evasion_bonus", ["head", "body", "legs", "feet", "hands", "offhand"],
			[[2, 4], [5, 8], [9, 14], [15, 22]], 10],
	["evasive", "evasion_pct", ["legs", "feet"], [[1, 2], [3, 4], [5, 6], [7, 9]], 6],
	["warded", "damage_reduction", ["head", "body", "legs", "offhand"], [[1, 1], [1, 2], [2, 3], [3, 4]], 6],
	["hale", "max_hp_flat", ["head", "body", "legs", "feet", "neck", "ring", "offhand"],
			[[5, 10], [11, 20], [21, 35], [36, 55]], 10],
	["hearty", "food_healing_pct", ["head", "body", "neck"], [[2, 4], [5, 8], [9, 12], [13, 18]], 4],
	["bulwark", "block_chance", ["offhand"], [[1, 2], [2, 3], [3, 4], [4, 5]], 4],
	["prosperous", "gold_drop_pct", ["neck", "ring"], [[2, 4], [5, 8], [9, 12], [13, 18]], 4],
	["fortunate", "item_rarity_pct", ["neck", "ring"], [[2, 4], [5, 8], [9, 12], [13, 18]], 3],
	["hasty", "skill_interval_pct", ["tool_*"], [[-2, -1], [-3, -2], [-4, -3], [-5, -4]], 10],
	["bountiful", "double_item_chance", ["tool_*"], [[1, 2], [2, 3], [3, 4], [4, 6]], 8],
	["learned", "skill_xp_pct", ["tool_*"], [[1, 2], [2, 3], [3, 5], [5, 7]], 8],
	["devoted", "mastery_xp_pct", ["tool_*"], [[1, 2], [2, 4], [4, 6], [6, 8]], 6],
	["riftsense", "rift_shard_chance", ["tool_*"], [[0.05, 0.10], [0.10, 0.15], [0.15, 0.25], [0.25, 0.35]], 4],
]
const AFFIX_MIN_ILVLS: Array[int] = [1, 20, 45, 75]
const EQUIPMENT_SLOTS: PackedStringArray = [
	"head", "body", "legs", "feet", "hands", "neck", "ring", "weapon", "offhand",
	"tool_forestry", "tool_quarrying", "tool_angling",
]

var _raw: Dictionary = {}
var _load_errors: PackedStringArray = []


func before_all() -> void:
	_raw = {
		"shop": _read([CONTENT_ROOT.path_join(GameData.CONTENT_FILES["shop"])]),
		"affixes": _read([CONTENT_ROOT.path_join(GameData.CONTENT_FILES["affixes"])]),
	}
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


func _by_id(section: String, key: String) -> Dictionary:
	var result: Dictionary = {}
	for path: Variant in _raw[section]:
		for e: Variant in (_raw[section][path] as Dictionary).get(key, []):
			result[(e as Dictionary)["id"]] = e
	return result


# The action producing `output` in `skill`, or an empty Dictionary.
func _recipe(skill: String, output: String) -> Dictionary:
	for path: Variant in _raw["actions"]:
		var content: Dictionary = _raw["actions"][path] as Dictionary
		if content["skill"] != skill:
			continue
		for a: Variant in content["actions"]:
			if ((a as Dictionary)["outputs"] as Array)[0]["item"] == output:
				return a as Dictionary
	return {}


func _assert_recipe(skill: String, output: String, n: int, inputs: Array, interval: int, xp: int, value: int) -> void:
	var items: Dictionary = _by_id("items", "items")
	var a: Dictionary = _recipe(skill, output)
	assert_false(a.is_empty(), "recipe of %s in %s" % [output, skill])
	if a.is_empty():
		return
	assert_eq(a["level"], float(GATHERING_TIERS[n - 1][0]), "%s level" % output)
	assert_eq(a["interval_ms"], float(interval), "%s interval" % output)
	assert_eq(a["xp"], float(xp), "%s xp" % output)
	assert_eq((a["inputs"] as Array).size(), inputs.size(), "%s inputs" % output)
	for index: int in mini((a["inputs"] as Array).size(), inputs.size()):
		assert_eq(a["inputs"][index]["item"], inputs[index][0], "%s input %d" % [output, index])
		assert_eq(a["inputs"][index]["qty"], float(inputs[index][1]), "%s input %d qty" % [output, index])
	assert_eq(a["outputs"][0]["qty"], 1.0, "%s qty" % output)
	assert_eq(items[output]["value"], float(value), "%s value" % output)


func _ingot_xp(n: int) -> int:
	return int(floor(0.8 * int(GATHERING_TIERS[n - 1][2])))


func _ore_value(n: int) -> int:
	return int(GATHERING_TIERS[n - 1][4])


func test_forging_recipes_follow_8_2() -> void:
	for n: int in range(1, 9):
		var m: String = METALS[n - 1]
		var ore: int = _ore_value(n)
		var ixp: int = _ingot_xp(n)
		var grip: String = WOODS[n - 1] + "_grip"
		var grip_value: int = 2 * _ore_value(n)
		_assert_recipe("forging", m + "_ingot", n, [[m + "_ore", 2]], 2000, ixp, 3 * ore)
		for w: Array in WEAPONS:
			var ing: int = w[6]
			_assert_recipe("forging", "%s_%s" % [m, w[0]], n, [[m + "_ingot", ing], [grip, 1]], w[7],
					int(floor(ing * ixp * 1.2)), int(w[8]) * ore + grip_value)
		_assert_recipe("forging", m + "_shield", n, [[m + "_ingot", 4], [WOODS[n - 1] + "_shieldcore", 1]], 3000,
				int(floor(4 * ixp * 1.2)), 16 * ore + 4 * _ore_value(n))
		for p: Array in ARMOR_PIECES:
			var ing: int = p[1]
			_assert_recipe("forging", "%s_%s" % [m, p[0]], n, [[m + "_ingot", ing]], 3000,
					int(floor(ing * ixp * 1.2)), ing * 4 * ore)
		for t: Array in TOOL_PIECES:
			_assert_recipe("forging", "%s_%s" % [m, t[0]], n, [[m + "_ingot", 2], [WOODS[n - 1] + "_handle", 1]], 3000,
					int(floor(2 * ixp * 1.3)), 10 * ore)


func test_hearthcraft_recipes_and_food_follow_8_2_and_8_3() -> void:
	var items: Dictionary = _by_id("items", "items")
	for n: int in range(1, 9):
		var xp: int = int(floor(0.9 * int(GATHERING_TIERS[n - 1][2])))
		var out: String = "seared_" + FISH[n - 1]
		_assert_recipe("hearthcraft", out, n, [[FISH[n - 1], 1]], 2500, xp, 2 * _ore_value(n))
		assert_eq(items[out]["category"], "food", out)
		assert_eq(items[out]["food"]["heal"], float(HEAL[n - 1]), "%s heal" % out)


func test_woodwright_recipes_follow_8_2() -> void:
	for n: int in range(1, 9):
		var w: String = WOODS[n - 1]
		var wood_xp: int = int(GATHERING_TIERS[n - 1][2])
		var wood_value: int = _ore_value(n)
		_assert_recipe("woodwright", w + "_grip", n, [[w + "_log", 1]], 1600, int(floor(wood_xp * 0.8)), 2 * wood_value)
		_assert_recipe("woodwright", w + "_handle", n, [[w + "_log", 1]], 1600, int(floor(wood_xp * 0.8)),
				2 * wood_value)
		_assert_recipe("woodwright", w + "_shieldcore", n, [[w + "_log", 2]], 2000, int(floor(2 * wood_xp * 0.9)),
				4 * wood_value)


# The modifiers of `item` as {stat: value}.
func _mods_of(item: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for m: Variant in item["equip"]["modifiers"]:
		result[(m as Dictionary)["stat"]] = (m as Dictionary)["value"]
	return result


func test_weapons_follow_8_4() -> void:
	var items: Dictionary = _by_id("items", "items")
	for n: int in range(1, 9):
		var level: float = float(GATHERING_TIERS[n - 1][0])
		for wp: Array in WEAPONS:
			var id: String = "%s_%s" % [METALS[n - 1], wp[0]]
			var e: Dictionary = items[id]["equip"] as Dictionary
			assert_eq(items[id]["category"], "equipment", id)
			assert_eq(e["slot"], "weapon", id)
			assert_eq(e["kind"], wp[1], "%s kind" % id)
			assert_eq(e["grade"], float(n), "%s grade" % id)
			assert_eq(e["requirements"], {"character": level}, "%s requirements" % id)
			assert_eq(_mods_of(items[id]), {"accuracy_bonus": float(wp[4] * n), "power_bonus": float(wp[5] * n)},
					"%s modifiers" % id)
			assert_eq(e["weapon"], {"style": "blade", "attack_interval_ms": float(wp[2]), "two_handed": wp[3]},
					"%s weapon" % id)


func test_armor_and_shields_follow_8_4() -> void:
	var items: Dictionary = _by_id("items", "items")
	for n: int in range(1, 9):
		var level: float = float(GATHERING_TIERS[n - 1][0])
		for p: Array in ARMOR_PIECES:
			var id: String = "%s_%s" % [METALS[n - 1], p[0]]
			var want: Dictionary = {"evasion_bonus": float(p[3] * n)}
			if p[4] == 1:
				want["damage_reduction"] = float(n)
			elif p[4] == 2:
				want["damage_reduction"] = float(ceili(n / 2.0))
			assert_eq(items[id]["equip"]["slot"], p[2], "%s slot" % id)
			assert_eq(items[id]["equip"]["grade"], float(n), "%s grade" % id)
			assert_eq(items[id]["equip"]["requirements"], {"character": level}, "%s requirements" % id)
			assert_eq(_mods_of(items[id]), want, "%s modifiers" % id)
			assert_false((items[id]["equip"] as Dictionary).has("weapon"), "%s weapon" % id)
			assert_false((items[id]["equip"] as Dictionary).has("kind"), "%s kind" % id)
		var shield: String = METALS[n - 1] + "_shield"
		assert_eq(items[shield]["equip"]["slot"], "offhand", shield)
		assert_eq(items[shield]["equip"]["kind"], "shield", shield)
		assert_eq(items[shield]["equip"]["grade"], float(n), "%s grade" % shield)
		assert_eq(items[shield]["equip"]["requirements"], {"character": level}, "%s requirements" % shield)
		assert_eq(_mods_of(items[shield]), {"evasion_bonus": float(4 * n), "damage_reduction": float(n),
				"block_chance": float(5 + floori(10.0 * (n - 1) / 7.0))}, "%s modifiers" % shield)


func test_full_t8_set_with_shield_follows_the_8_4_example() -> void:
	var items: Dictionary = _by_id("items", "items")
	var reduction: float = 0.0
	for suffix: String in ["cuirass", "greaves", "helm", "boots", "gauntlets", "shield"]:
		reduction += _mods_of(items["riftite_" + suffix]).get("damage_reduction", 0.0)
	assert_eq(reduction, 24.0)
	assert_eq(_mods_of(items["riftite_shield"])["block_chance"], 15.0)


func test_tools_follow_8_4() -> void:
	var items: Dictionary = _by_id("items", "items")
	for n: int in range(1, 9):
		var level: float = float(GATHERING_TIERS[n - 1][0])
		for t: Array in TOOL_PIECES:
			var id: String = "%s_%s" % [METALS[n - 1], t[0]]
			var m: Dictionary = items[id]["equip"]["modifiers"][0] as Dictionary
			assert_eq(items[id]["category"], "tool", id)
			assert_eq(items[id]["equip"]["slot"], t[2], "%s slot" % id)
			assert_eq(items[id]["equip"]["grade"], float(n), "%s grade" % id)
			assert_eq(items[id]["equip"]["requirements"], {t[1]: level}, "%s requirements" % id)
			assert_eq(items[id]["equip"]["modifiers"].size(), 1, "%s modifiers" % id)
			assert_eq([m["stat"], m["value"], m["scope"]],
					["skill_interval_pct", float(-(3 + 2 * n)), "skill:" + t[1]], id)


func test_novice_tools_are_grade_one_tools() -> void:
	var items: Dictionary = _by_id("items", "items")
	for t: Array in TOOL_PIECES:
		var id: String = "novice_" + (t[0] as String)
		assert_eq(items[id]["category"], "tool", id)
		assert_eq(items[id]["equip"]["slot"], t[2], id)
		assert_eq(items[id]["equip"]["grade"], 1.0, id)
		assert_eq(items[id]["equip"]["requirements"], {t[1]: 1.0}, id)
		assert_eq(items[id]["equip"]["modifiers"],
				[{"stat": "skill_interval_pct", "value": -5.0, "scope": "skill:" + t[1]}], id)


func test_shop_follows_8_6() -> void:
	var shop: Dictionary = _by_id("shop", "entries")
	assert_eq(shop.size(), 10)
	assert_false(shop.has("second_thought"))
	assert_eq(shop["bank_slot"]["cost"], {"formula": "bank_slot"})
	assert_eq(shop["bank_slot"]["max_purchases"], 150.0)
	assert_eq(shop["bank_slot"]["effect"]["modifiers"], [{"stat": "bank_slots", "value": 1.0}])
	assert_eq(shop["armory_slot"]["cost"], {"formula": "armory_slot"})
	assert_eq(shop["armory_slot"]["max_purchases"], 60.0)
	assert_eq(shop["armory_slot"]["requires"], {})
	assert_eq(shop["armory_slot"]["effect"]["modifiers"], [{"stat": "armory_slots", "value": 1.0}])
	var gold: Array[Array] = [
		["auto_eat_1", 2000, 1, "auto_eat_tier", 1], ["auto_eat_2", 25000, 1, "auto_eat_tier", 1],
		["auto_eat_3", 250000, 1, "auto_eat_tier", 1], ["auto_loot", 50000, 1, "auto_loot", 1],
		["loot_pocket", 5000, 3, "loot_bag_slots", 4],
	]
	for g: Array in gold:
		assert_eq(shop[g[0]]["cost"], {"gold": float(g[1])}, "%s cost" % g[0])
		assert_eq(shop[g[0]]["max_purchases"], float(g[2]), "%s max" % g[0])
		assert_eq(shop[g[0]]["effect"]["modifiers"], [{"stat": g[3], "value": float(g[4])}], "%s effect" % g[0])
	assert_eq(shop["auto_eat_2"]["requires"], {"entries": ["auto_eat_1"], "character": 25.0})
	assert_eq(shop["auto_eat_3"]["requires"], {"entries": ["auto_eat_2"], "character": 50.0})
	for t: Array in TOOL_PIECES:
		var id: String = "novice_" + (t[0] as String)
		assert_eq(shop[id]["cost"], {"gold": 150.0}, id)
		assert_eq(shop[id]["max_purchases"], 0.0, id)
		assert_eq(shop[id]["effect"]["item"], {"item": id, "qty": 1.0}, id)


func test_rift_blade_class_has_the_four_setups() -> void:
	var classes: Dictionary = {}
	for path: Variant in _raw["classes"]:
		classes[(_raw["classes"][path] as Dictionary)["id"]] = _raw["classes"][path]
	assert_true(classes.has("rift_blade"))
	var c: Dictionary = classes.get("rift_blade", {}) as Dictionary
	assert_eq(c.get("weapon_kinds"), ["greatsword", "sword"])
	assert_eq(c.get("offhand_kinds"), ["shield", "sword"])
	var pairs: Array = []
	for s: Variant in c.get("setups", []):
		pairs.append([s["id"], s["weapon"], s["offhand"]])
	assert_eq(pairs, [["greatsword", "greatsword", ""], ["sword_shield", "sword", "shield"],
			["dual_swords", "sword", "sword"], ["sword", "sword", ""]])
	assert_eq(c.get("traits"), [])
	assert_eq(c.get("abilities"), [])


func test_affixes_follow_8_9() -> void:
	var affixes: Dictionary = _by_id("affixes", "affixes")
	assert_eq(affixes.size(), AFFIXES.size())
	for row: Array in AFFIXES:
		var a: Dictionary = affixes.get(row[0], {}) as Dictionary
		assert_false(a.is_empty(), "affix %s" % row[0])
		if a.is_empty():
			continue
		assert_eq(a["stat"], row[1], "%s stat" % row[0])
		assert_eq(a["weight"], float(row[4]), "%s weight" % row[0])
		var slots: Array = row[2]
		if slots == ["tool_*"]:
			slots = ["tool_forestry", "tool_quarrying", "tool_angling"]
		assert_eq(a["slots"], slots, "%s slots" % row[0])
		assert_eq((a["tiers"] as Array).size(), 4, "%s tiers" % row[0])
		for index: int in mini((a["tiers"] as Array).size(), 4):
			var t: Dictionary = a["tiers"][index] as Dictionary
			assert_eq(t["min_ilvl"], float(AFFIX_MIN_ILVLS[index]), "%s tier %d min_ilvl" % [row[0], index])
			assert_almost_eq(float(t["min"]), float(row[3][index][0]), 0.0001, "%s tier %d min" % [row[0], index])
			assert_almost_eq(float(t["max"]), float(row[3][index][1]), 0.0001, "%s tier %d max" % [row[0], index])
	assert_eq(affixes["riftsense"]["tiers"][0]["step"], 0.05)


func test_every_slot_has_at_least_four_affixes() -> void:
	for slot: String in EQUIPMENT_SLOTS:
		var count: int = 0
		for a: Variant in _by_id("affixes", "affixes").values():
			if (a["slots"] as Array).has(slot):
				count += 1
		assert_gte(count, 4, "affixes for slot %s" % slot)


func test_affixed_rare_sword_example_of_8_9() -> void:
	# Rare T3 sword with four tier-2 affixes: at most +8 accuracy, +6 power, +4 accuracy %, +4 power % over the base.
	var affixes: Dictionary = _by_id("affixes", "affixes")
	for pair: Array in [["keen", 8.0], ["heavy", 6.0], ["precise", 4.0], ["brutal", 4.0]]:
		assert_eq(affixes[pair[0]]["tiers"][1]["max"], pair[1], pair[0])
