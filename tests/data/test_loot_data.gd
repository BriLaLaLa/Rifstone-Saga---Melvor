extends GutTest
## Warding Seal and Rift Stones of the real data (F-87; 04_DATA_SCHEMA §16). M14-05: rings, amulets and the drops of pieces moved
## to test_equipment_table.gd and test_no_equipment_in_drops.gd.

var _items: Dictionary = {}
var _areas: Dictionary = {}
var _monsters: Dictionary = {}
var _stones: Array = []


func before_all() -> void:
	for file: String in DirAccess.get_files_at("res://data/items"):
		if not file.ends_with(".json"):
			continue
		for item: Dictionary in _read("res://data/items/%s" % file)["items"]:
			_items[item["id"]] = item
	for a: Dictionary in _read("res://data/combat/areas.json")["areas"]:
		_areas[a["id"]] = a
	for m: Dictionary in _read("res://data/combat/monsters.json")["monsters"]:
		_monsters[m["id"]] = m
	_stones = _read("res://data/combat/rift_stones.json")["rift_stones"]


func _read(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path)) as Dictionary


func test_warding_seal_is_the_balance_seal() -> void:
	var balance: Dictionary = _read("res://data/config/balance.json")
	var seal: String = str(balance["upgrade"]["seal_item"])
	assert_eq(seal, "warding_seal")
	assert_eq(_items[seal]["category"], "material")


func test_stones_belong_to_areas_with_explicit_wave_packs() -> void:
	var seen: Dictionary = {}
	for s: Dictionary in _stones:
		assert_true(_areas.has(s["area"]), "%s area" % s["id"])
		assert_false(seen.has([s["area"], s["level"]]), "two stones of the same level in %s" % s["area"])
		seen[[s["area"], s["level"]]] = true
		assert_true(s.has("wave_packs"), "%s wave_packs is explicit" % s["id"])
		if s["wave_packs"] != null:
			for index: Variant in (s["wave_packs"] as Array):
				assert_between(int(index), 0, (_areas[s["area"]]["packs"] as Array).size() - 1)


func test_stone_numbers() -> void:
	var balance: Dictionary = _read("res://data/config/balance.json")
	var min_interval: int = int(balance["combat"]["min_attack_interval_ms"])
	for s: Dictionary in _stones:
		assert_gte(int(s["pulse_ms"]), min_interval, "%s pulse_ms" % s["id"])
		assert_true(FileAccess.file_exists(s["icon"]), "icon %s" % s["icon"])
		assert_between((s["drops"] as Array).size(), 1, 4)
		for d: Dictionary in s["drops"]:
			assert_true(_items.has(d["item"]), "%s drops unknown %s" % [s["id"], d["item"]])
			assert_between(float(d["chance_pct"]), 1.0, 40.0)

