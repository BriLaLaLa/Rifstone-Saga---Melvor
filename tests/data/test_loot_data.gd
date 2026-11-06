extends GutTest
## Rings, amulets, Warding Seal and Rift Stones of the real data (02_FORMULAS.md §8.4 and F-87; 04_DATA_SCHEMA §16).

const TIERS: Array[String] = ["emberbronze", "ashlead", "stormzinc", "duskcobalt", "glimmerite", "palecinnabar",
	"emberheart", "riftite"]
const REQUIREMENTS: Array[int] = [1, 10, 20, 30, 45, 60, 75, 90]

var _items: Dictionary = {}
var _areas: Dictionary = {}
var _monsters: Dictionary = {}
var _stones: Array = []


func before_all() -> void:
	for file: String in ["equipment", "materials"]:
		for item: Dictionary in _read("res://data/items/%s.json" % file)["items"]:
			_items[item["id"]] = item
	for a: Dictionary in _read("res://data/combat/areas.json")["areas"]:
		_areas[a["id"]] = a
	for m: Dictionary in _read("res://data/combat/monsters.json")["monsters"]:
		_monsters[m["id"]] = m
	_stones = _read("res://data/combat/rift_stones.json")["rift_stones"]


func _read(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path)) as Dictionary


func test_rings_and_amulets_follow_table_8_4() -> void:
	for i: int in TIERS.size():
		var n: int = i + 1
		var ring: Dictionary = _items["%s_ring" % TIERS[i]]["equip"]
		assert_eq(ring["slot"], "ring")
		assert_eq(int(ring["grade"]), n)
		_check_mods(ring, REQUIREMENTS[i], "accuracy_bonus", 3 * n)
		var amulet: Dictionary = _items["%s_amulet" % TIERS[i]]["equip"]
		assert_eq(amulet["slot"], "neck")
		assert_eq(int(amulet["grade"]), n)
		_check_mods(amulet, REQUIREMENTS[i], "max_hp_flat", 10 * n)


func _check_mods(equip: Dictionary, level: int, stat: String, value: int) -> void:
	assert_eq((equip["requirements"] as Dictionary).size(), 1)
	assert_eq(int(equip["requirements"]["character"]), level)
	var mods: Array = equip["modifiers"]
	assert_eq(mods.size(), 1)
	assert_eq(mods[0]["stat"], stat)
	assert_eq(int(mods[0]["value"]), value)


func test_warding_seal_is_the_balance_seal() -> void:
	var balance: Dictionary = _read("res://data/config/balance.json")
	var seal: String = str(balance["upgrade"]["seal_item"])
	assert_eq(seal, "warding_seal")
	assert_eq(_items[seal]["category"], "material")


func test_one_stone_per_area_with_explicit_summon() -> void:
	assert_eq(_stones.size(), _areas.size())
	var seen: Dictionary = {}
	for s: Dictionary in _stones:
		assert_true(_areas.has(s["area"]), "%s area" % s["id"])
		assert_false(seen.has(s["area"]), "two stones in %s" % s["area"])
		seen[s["area"]] = true
		assert_true(s.has("summon_pack"), "%s summon_pack is explicit" % s["id"])
		if s["summon_pack"] != null:
			assert_between(int(s["summon_pack"]), 0, (_areas[s["area"]]["packs"] as Array).size() - 1)


func test_stone_numbers() -> void:
	var balance: Dictionary = _read("res://data/config/balance.json")
	var min_interval: int = int(balance["combat"]["min_attack_interval_ms"])
	for s: Dictionary in _stones:
		assert_gte(int(s["pulse_ms"]), min_interval, "%s pulse_ms" % s["id"])
		assert_gte(int(s["pulse_damage"]), 1, "%s pulse_damage" % s["id"])
		assert_gte(int(s["hp"]), 1)
		assert_true(FileAccess.file_exists(s["icon"]), "icon %s" % s["icon"])
		assert_between((s["drops"] as Array).size(), 1, 4)
		for d: Dictionary in s["drops"]:
			assert_true(_items.has(d["item"]), "%s drops unknown %s" % [s["id"], d["item"]])
			assert_between(float(d["chance_pct"]), 1.0, 40.0)


func test_every_equipment_drop_is_reachable_by_level() -> void:
	# a monster drops pieces whose requirement is within its own level (ilvl, F-85): no unusable drops
	for m: Dictionary in _monsters.values():
		var level: int = maxi(int(m["attack_level"]), maxi(int(m["power_level"]), int(m["defence_level"])))
		for d: Dictionary in m["drops"]:
			var item: Dictionary = _items[d["item"]]
			if item["category"] == "equipment":
				assert_lte(int(item["equip"]["requirements"]["character"]), level, "%s drops %s" % [m["id"], d["item"]])


func test_every_slot_with_drops_exists() -> void:
	var slots: Dictionary = {}
	for m: Dictionary in _monsters.values():
		for d: Dictionary in m["drops"]:
			if _items[d["item"]]["category"] == "equipment":
				slots[_items[d["item"]]["equip"]["slot"]] = true
	assert_true(slots.has("ring") and slots.has("neck"))
