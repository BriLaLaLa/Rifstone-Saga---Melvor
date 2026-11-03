extends GutTest
## Artisan recipes, food, equipment, tools and shop of the real data (02_FORMULAS.md §8.2-8.4, §8.6; M3-04).
## Split from test_data_validity.gd to stay under the 400-line limit.

const CONTENT_ROOT: String = "res://data"
## 02_FORMULAS.md §8.1, T1..T8: [level, interval_ms, xp, product qty, item value].
const GATHERING_TIERS: Array[Array] = [
	[1, 3000, 10, 1, 1], [10, 3200, 18, 1, 3], [20, 3500, 28, 1, 6], [30, 3800, 40, 1, 10],
	[45, 4200, 58, 1, 18], [60, 4600, 80, 1, 30], [75, 5000, 108, 1, 50], [90, 5500, 145, 1, 85],
]

var _raw: Dictionary = {}
var _load_errors: PackedStringArray = []


func before_all() -> void:
	_raw = {"shop": _read([CONTENT_ROOT.path_join(GameData.CONTENT_FILES["shop"])])}
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

const METALS: PackedStringArray = ["emberbronze", "ashlead", "stormzinc", "duskcobalt", "glimmerite", "palecinnabar", "emberheart", "riftite"]
const WOODS: PackedStringArray = ["redbirch", "ashpine", "thornalder", "duskelm", "shardcedar", "veilcypress", "emberlarch", "riftspruce"]
const FISH: PackedStringArray = ["brookfin", "ashgill", "redscale", "dusk_eel", "shard_gar", "mist_barbel", "ember_sturgeon", "riftmaw"]
const HEAL: Array[int] = [20, 35, 55, 80, 110, 150, 200, 260]
## Armor rows: [suffix, ingots, slot, evasion per grade, damage reduction kind (0 none, 1 n, 2 ceil(n/2))].
const ARMOR_PIECES: Array[Array] = [
	["cuirass", 5, "body", 6, 1], ["greaves", 4, "legs", 4, 2], ["helm", 3, "head", 3, 2],
	["boots", 2, "feet", 2, 0], ["gauntlets", 2, "hands", 2, 0], ["shield", 4, "offhand", 4, 1],
]
## Tools: [suffix, skill, slot].
const TOOL_PIECES: Array[Array] = [
	["hatchet", "forestry", "tool_forestry"], ["pick", "quarrying", "tool_quarrying"], ["rod", "angling", "tool_angling"],
]
## Weapons: [suffix, material list, skill, style, interval, two handed, accuracy per grade, power per grade].
const WEAPONS: Array[Array] = [
	["blade", "metal", "blade", "blade", 2400, false, 8, 6], ["bow", "wood", "marksmanship", "marksmanship", 2800, true, 10, 7],
	["staff", "wood", "arcana", "arcana", 3000, true, 9, 8],
]


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


func test_forging_recipes_follow_8_2() -> void:
	for n: int in range(1, 9):
		var m: String = METALS[n - 1]
		var ore_value: int = int(GATHERING_TIERS[n - 1][4])
		var ixp: int = _ingot_xp(n)
		_assert_recipe("forging", m + "_ingot", n, [[m + "_ore", 2]], 2000, ixp, 3 * ore_value)
		_assert_recipe("forging", m + "_blade", n, [[m + "_ingot", 3]], 3000, int(floor(3 * ixp * 1.2)), 12 * ore_value)
		for p: Array in ARMOR_PIECES:
			var ing: int = p[1]
			_assert_recipe("forging", "%s_%s" % [m, p[0]], n, [[m + "_ingot", ing]], 3000, int(floor(ing * ixp * 1.2)), ing * 4 * ore_value)
		for t: Array in TOOL_PIECES:
			_assert_recipe("forging", "%s_%s" % [m, t[0]], n, [[m + "_ingot", 2], [WOODS[n - 1] + "_log", 1]], 3000,
					int(floor(2 * ixp * 1.3)), 10 * ore_value)


func test_hearthcraft_recipes_and_food_follow_8_2_and_8_3() -> void:
	var items: Dictionary = _by_id("items", "items")
	for n: int in range(1, 9):
		var xp: int = int(floor(0.9 * int(GATHERING_TIERS[n - 1][2])))
		var out: String = "seared_" + FISH[n - 1]
		_assert_recipe("hearthcraft", out, n, [[FISH[n - 1], 1]], 2500, xp, 2 * int(GATHERING_TIERS[n - 1][4]))
		assert_eq(items[out]["category"], "food", out)
		assert_eq(items[out]["food"]["heal"], float(HEAL[n - 1]), "%s heal" % out)


func test_woodwright_recipes_follow_8_2() -> void:
	for n: int in range(1, 9):
		var w: String = WOODS[n - 1]
		var wood_xp: int = int(GATHERING_TIERS[n - 1][2])
		var wood_value: int = int(GATHERING_TIERS[n - 1][4])
		for kind: String in ["bow", "staff"]:
			_assert_recipe("woodwright", "%s_%s" % [w, kind], n, [[w + "_log", 3]], 2400, int(floor(3 * wood_xp * 1.1)), 10 * wood_value)
		_assert_recipe("woodwright", w + "_grip", n, [[w + "_log", 1]], 1600, int(floor(wood_xp * 0.8)), 2 * wood_value)


# The modifiers of `item` as {stat: value}.
func _mods_of(item: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for m: Variant in item["equip"]["modifiers"]:
		result[(m as Dictionary)["stat"]] = (m as Dictionary)["value"]
	return result


func test_equipment_follows_8_4() -> void:
	var items: Dictionary = _by_id("items", "items")
	for n: int in range(1, 9):
		var level: float = float(GATHERING_TIERS[n - 1][0])
		for wp: Array in WEAPONS:
			var id: String = "%s_%s" % [(METALS if wp[1] == "metal" else WOODS)[n - 1], wp[0]]
			var e: Dictionary = items[id]["equip"] as Dictionary
			assert_eq(items[id]["category"], "equipment", id)
			assert_eq(e["slot"], "weapon", id)
			assert_eq(e["requirements"], {wp[2]: level}, "%s requirements" % id)
			assert_eq(_mods_of(items[id]), {"accuracy_bonus": float(wp[6] * n), "power_bonus": float(wp[7] * n)}, "%s modifiers" % id)
			assert_eq(e["weapon"], {"style": wp[3], "attack_interval_ms": float(wp[4]), "two_handed": wp[5]}, "%s weapon" % id)
		for p: Array in ARMOR_PIECES:
			var id: String = "%s_%s" % [METALS[n - 1], p[0]]
			var want: Dictionary = {"evasion_bonus": float(p[3] * n)}
			if p[4] == 1:
				want["damage_reduction"] = float(n)
			elif p[4] == 2:
				want["damage_reduction"] = float(ceili(n / 2.0))
			assert_eq(items[id]["equip"]["slot"], p[2], "%s slot" % id)
			assert_eq(items[id]["equip"]["requirements"], {"guard": level}, "%s requirements" % id)
			assert_eq(_mods_of(items[id]), want, "%s modifiers" % id)
			assert_false((items[id]["equip"] as Dictionary).has("weapon"), "%s weapon" % id)
		for t: Array in TOOL_PIECES:
			var id: String = "%s_%s" % [METALS[n - 1], t[0]]
			var m: Dictionary = items[id]["equip"]["modifiers"][0] as Dictionary
			assert_eq(items[id]["category"], "tool", id)
			assert_eq(items[id]["equip"]["slot"], t[2], "%s slot" % id)
			assert_eq(items[id]["equip"]["requirements"], {t[1]: level}, "%s requirements" % id)
			assert_eq(items[id]["equip"]["modifiers"].size(), 1, "%s modifiers" % id)
			assert_eq([m["stat"], m["value"], m["scope"]], ["skill_interval_pct", float(-(3 + 2 * n)), "skill:" + t[1]], id)


func test_novice_tools_are_grade_one_tools() -> void:
	var items: Dictionary = _by_id("items", "items")
	for t: Array in TOOL_PIECES:
		var id: String = "novice_" + (t[0] as String)
		assert_eq(items[id]["category"], "tool", id)
		assert_eq(items[id]["equip"]["slot"], t[2], id)
		assert_eq(items[id]["equip"]["requirements"], {t[1]: 1.0}, id)
		assert_eq(items[id]["equip"]["modifiers"], [{"stat": "skill_interval_pct", "value": -5.0, "scope": "skill:" + t[1]}], id)


func test_shop_follows_8_6() -> void:
	var shop: Dictionary = _by_id("shop", "entries")
	assert_eq(shop.size(), 9)
	assert_false(shop.has("second_thought"))
	assert_eq(shop["bank_slot"]["cost"], {"formula": "bank_slot"})
	assert_eq(shop["bank_slot"]["max_purchases"], 150.0)
	assert_eq(shop["bank_slot"]["effect"]["modifiers"], [{"stat": "bank_slots", "value": 1.0}])
	var gold: Array[Array] = [
		["auto_eat_1", 2000, 1, "auto_eat_tier", 1], ["auto_eat_2", 25000, 1, "auto_eat_tier", 1],
		["auto_eat_3", 250000, 1, "auto_eat_tier", 1], ["auto_loot", 50000, 1, "auto_loot", 1],
		["loot_pocket", 5000, 3, "loot_bag_slots", 4],
	]
	for g: Array in gold:
		assert_eq(shop[g[0]]["cost"], {"gold": float(g[1])}, "%s cost" % g[0])
		assert_eq(shop[g[0]]["max_purchases"], float(g[2]), "%s max" % g[0])
		assert_eq(shop[g[0]]["effect"]["modifiers"], [{"stat": g[3], "value": float(g[4])}], "%s effect" % g[0])
	assert_eq(shop["auto_eat_2"]["requires"], {"entries": ["auto_eat_1"], "skills": {"vitality": 25.0}})
	assert_eq(shop["auto_eat_3"]["requires"], {"entries": ["auto_eat_2"], "skills": {"vitality": 50.0}})
	for t: Array in TOOL_PIECES:
		var id: String = "novice_" + (t[0] as String)
		assert_eq(shop[id]["cost"], {"gold": 150.0}, id)
		assert_eq(shop[id]["max_purchases"], 0.0, id)
		assert_eq(shop[id]["effect"]["item"], {"item": id, "qty": 1.0}, id)
