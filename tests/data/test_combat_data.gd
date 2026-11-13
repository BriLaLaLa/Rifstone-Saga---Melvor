extends GutTest
## Areas, monsters and packs of the real data (02_FORMULAS.md §8.5; 04_DATA_SCHEMA.md §8). The table below is the oracle.
## M14-10: hp, gold and xp of the three upper areas are retuned by the sim (kills per hour close across the areas, STATUS.md); the rest follows §8.5.

## [id, area, L, hp, style, interval, acc, pot, eva, dr, gold min, gold max, shard %, xp].
const MONSTERS: Array[Array] = [
	["plains_boar", "redrock_plains", 1, 20, "blade", 2800, 0, 0, 0, 0, 1, 4, 0.5, 80],
	["ember_rat", "redrock_plains", 4, 32, "arcana", 2400, 5, 4, 5, 0, 2, 6, 0.5, 128],
	["redrock_raider", "redrock_plains", 8, 50, "marksmanship", 2600, 10, 8, 8, 2, 4, 10, 0.75, 200],
	["whisper_wolf", "whisper_wood", 16, 81, "blade", 2600, 20, 15, 18, 4, 6, 13, 1.0, 324],
	["moss_troll", "whisper_wood", 22, 118, "arcana", 3000, 25, 22, 30, 8, 9, 18, 1.0, 472],
	["hollow_archer", "whisper_wood", 30, 155, "marksmanship", 2400, 30, 18, 20, 5, 11, 22, 1.0, 620],
	["crack_golem", "cracked_mines", 38, 198, "blade", 3200, 45, 35, 50, 12, 16, 31, 1.5, 633],
	["deep_crawler", "cracked_mines", 46, 248, "marksmanship", 2200, 50, 30, 35, 8, 19, 37, 1.5, 793],
	["vein_witch", "cracked_mines", 55, 322, "arcana", 2800, 55, 40, 40, 10, 25, 50, 1.5, 1030],
	["shard_wraith", "rift_threshold", 65, 287, "arcana", 2600, 70, 55, 60, 15, 25, 49, 2.0, 1148],
	["rift_knight", "rift_threshold", 78, 390, "blade", 2400, 85, 65, 80, 20, 37, 70, 2.5, 1560],
	["riftborn_colossus", "rift_threshold", 92, 533, "marksmanship", 3400, 100, 80, 110, 25, 61, 123, 3.0, 2132],
]
## [area id, requirement, max pack size].
const AREAS: Array[Array] = [
	["redrock_plains", 1, 2], ["whisper_wood", 16, 3], ["cracked_mines", 38, 4], ["rift_threshold", 65, 6],
]

var _areas: Array = []
var _monsters: Dictionary = {}
var _items: Dictionary = {}


func before_all() -> void:
	_areas = _read("res://data/combat/areas.json")["areas"]
	for m: Dictionary in _read("res://data/combat/monsters.json")["monsters"]:
		_monsters[m["id"]] = m
	for file: String in DirAccess.get_files_at("res://data/items"):  # the item files are split by kind (M14)
		if file.ends_with(".json"):
			for m: Dictionary in _read("res://data/items/%s" % file)["items"]:
				_items[m["id"]] = m


func _read(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed as Dictionary


func test_four_areas_and_twelve_monsters() -> void:
	assert_eq(_areas.size(), 4)
	assert_eq(_monsters.size(), 12)


func test_monsters_follow_table_8_5() -> void:
	for row: Array in MONSTERS:
		var m: Dictionary = _monsters.get(row[0], {})
		assert_false(m.is_empty(), "missing %s" % row[0])
		if m.is_empty():
			continue
		for key: String in ["attack_level", "power_level", "defence_level"]:
			assert_eq(int(m[key]), row[2], "%s %s" % [row[0], key])
		assert_eq(int(m["hp"]), row[3], "%s hp" % row[0])
		assert_eq(m["style"], row[4], "%s style" % row[0])
		assert_eq(int(m["attack_interval_ms"]), row[5], "%s interval" % row[0])
		assert_eq(int(m["accuracy_bonus"]), row[6], "%s acc" % row[0])
		assert_eq(int(m["power_bonus"]), row[7], "%s pot" % row[0])
		assert_eq(int(m["evasion_bonus"]), row[8], "%s eva" % row[0])
		assert_eq(float(m["damage_reduction"]), float(row[9]), "%s dr" % row[0])
		assert_eq([int(m["gold"][0]), int(m["gold"][1])], [row[10], row[11]], "%s gold" % row[0])
		assert_eq(float(m["rift_shard_chance"]), row[12], "%s shard" % row[0])




func test_areas_order_and_requirements() -> void:
	for i: int in AREAS.size():
		var a: Dictionary = _areas[i]
		assert_eq(a["id"], AREAS[i][0])
		assert_eq(int(a["order"]), i + 1)
		assert_eq(int(a["requirements"]["character"]), AREAS[i][1])
		assert_eq(a["requirements"].size(), 1)
		var first_level: int = 0
		for row: Array in MONSTERS:
			if row[1] == a["id"]:
				first_level = row[2]
				break
		assert_eq(AREAS[i][1], first_level, "requirement = level of the first monster")


func test_packs_follow_8_5_rules() -> void:
	for i: int in AREAS.size():
		var a: Dictionary = _areas[i]
		var packs: Array = a["packs"]
		assert_between(packs.size(), 3, 6, "%s pack count" % a["id"])
		var largest: int = 0
		var has_solo_weakest: bool = false
		var weakest: String = ""
		for row: Array in MONSTERS:
			if row[1] == a["id"]:
				weakest = row[0]
				break
		for p: Dictionary in packs:
			assert_gte(int(p["weight"]), 1)
			var ms: Array = p["monsters"]
			assert_between(ms.size(), 1, 6)
			largest = maxi(largest, ms.size())
			if ms == [weakest]:
				has_solo_weakest = true
			for id: String in ms:
				assert_true(_monsters.has(id), "unknown monster %s" % id)
				assert_eq(_monster_area(id), a["id"], "%s belongs to %s" % [id, a["id"]])
		assert_eq(largest, AREAS[i][2], "%s max pack size" % a["id"])
		assert_true(has_solo_weakest, "%s has a solo pack of the weakest monster" % a["id"])


func test_every_monster_is_in_some_pack() -> void:
	var seen: Dictionary = {}
	for a: Dictionary in _areas:
		for p: Dictionary in a["packs"]:
			for id: String in p["monsters"]:
				seen[id] = true
	assert_eq(seen.size(), 12)


func test_drops_use_existing_items() -> void:
	for m: Dictionary in _monsters.values():
		var drops: Array = m["drops"]
		assert_between(drops.size(), 1, 8, "%s drop count" % m["id"])
		for d: Dictionary in drops:
			assert_true(_items.has(d["item"]), "%s drops unknown %s" % [m["id"], d["item"]])
			# Blueprints are rare on purpose (about one per hour in the whole area, Q49): below the 1% of the other drops.
			var low: float = 0.05 if str(d["item"]).begins_with("bp_") else 1.0
			assert_between(float(d["chance_pct"]), low, 40.0, "%s %s" % [m["id"], d["item"]])


func test_icons_exist() -> void:
	for m: Dictionary in _monsters.values():
		assert_true(FileAccess.file_exists(m["icon"]), "icon %s" % m["icon"])
	for item: Dictionary in _items.values():
		assert_true(FileAccess.file_exists(item["icon"]), "icon %s" % item["icon"])


func test_names_are_unique() -> void:
	var names: Dictionary = {}
	for m: Dictionary in _monsters.values():
		assert_false(names.has(m["name"]), "duplicate name %s" % m["name"])
		names[m["name"]] = true
	for a: Dictionary in _areas:
		assert_false(names.has(a["name"]), "duplicate name %s" % a["name"])
		names[a["name"]] = true


func _monster_area(id: String) -> String:
	for row: Array in MONSTERS:
		if row[0] == id:
			return row[1]
	return ""


func test_slot_and_class_icons_exist() -> void:
	for slot: String in DataValidatorItems.EQUIP_SLOTS:
		assert_true(FileAccess.file_exists("res://assets/icons/slots/%s.svg" % slot), "slot icon %s" % slot)
	var cls: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/classes/rift_blade.json"))
	assert_true(FileAccess.file_exists(cls["icon"]), "class icon %s" % cls["icon"])


func test_xp_follows_f130_generator() -> void:
	# M17-03: xp = round(monster_xp.base x monster_xp.growth^(L - 1)), written by tools/gen_monster_xp.gd.
	var spec: Dictionary = _read("res://data/config/balance.json")["combat"]["monster_xp"]
	for m: Dictionary in _monsters.values():
		var level: int = maxi(int(m["attack_level"]), maxi(int(m["power_level"]), int(m["defence_level"])))
		var expected: int = int(round(float(spec["base"]) * pow(float(spec["growth"]), float(level - 1))))
		assert_eq(int(m["xp"]), expected, "%s xp" % m["id"])

