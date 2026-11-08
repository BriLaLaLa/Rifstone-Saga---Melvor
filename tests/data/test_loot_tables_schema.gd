extends "res://tests/data/engraver_data_base.gd"
## Validator rules of data/combat/loot_tables.json and of the `loot_tables` references (docs/04_DATA_SCHEMA.md §8b):
## entries, item categories (no equipment), orphan tables, unknown references, the mandatory file. Fixture tables:
## test_area_loot (area), test_monster_loot (monster), test_stone_loot (stone).

const FILE: String = "loot_tables.json"


func _file(raw_data: Dictionary) -> Dictionary:
	return (raw_data["loot_tables"] as Dictionary).values()[0] as Dictionary


func _table(raw_data: Dictionary, index: int) -> Dictionary:
	return (_file(raw_data)["tables"] as Array)[index] as Dictionary


func _entry(raw_data: Dictionary, table: int, index: int) -> Dictionary:
	return (_table(raw_data, table)["entries"] as Array)[index] as Dictionary


func test_fixtures_are_valid() -> void:
	assert_eq(V.validate(raw()), PackedStringArray())


func test_real_data_has_the_tables() -> void:
	var data: GameData = TestFactory.real_data()
	assert_true(data.is_valid())
	assert_eq(data.loot_tables().size(), 8, "4 areas and 4 Monoliti (test_loot_tables_content.gd)")


func test_the_file_is_mandatory() -> void:
	var r: Dictionary = raw()
	r["loot_tables"] = {}
	expect(r, ["section 'loot_tables'", "expected one file, got 0"])


func test_an_item_must_exist() -> void:
	var r: Dictionary = raw()
	_entry(r, 0, 0)["item"] = "ghost"
	expect(r, [FILE, "loot table 'test_area_loot'", "entries[0].item", "unknown item 'ghost'"])


func test_equipment_and_tools_are_not_allowed() -> void:
	var r: Dictionary = raw()
	_entry(r, 0, 0)["item"] = "test_blade"
	expect(r, [FILE, "entries[0].item", "a loot table holds only"])


func test_chance_and_quantity_ranges() -> void:
	var r: Dictionary = raw()
	_entry(r, 0, 0)["chance_pct"] = 0
	expect(r, [FILE, "entries[0].chance_pct"])
	r = raw()
	_entry(r, 0, 0)["chance_pct"] = 100.5
	expect(r, [FILE, "entries[0].chance_pct"])
	r = raw()
	_entry(r, 0, 0)["qty"] = [3, 2]
	expect(r, [FILE, "entries[0].qty"])
	r = raw()
	_entry(r, 0, 0)["qty"] = [0, 1]
	expect(r, [FILE, "entries[0].qty"])
	r = raw()
	_entry(r, 0, 0)["chance_pct"] = 0.01
	assert_eq(V.validate(r), PackedStringArray(), "0.01 is the smallest chance")


func test_entry_count_limits() -> void:
	var r: Dictionary = raw()
	_table(r, 0)["entries"] = []
	expect(r, [FILE, "test_area_loot", "entries"])
	var many: Array = []
	for i: int in 25:
		many.append({"item": "rift_dust", "chance_pct": 1, "qty": [1, 1]})
	r = raw()
	_table(r, 0)["entries"] = many.duplicate(true)
	expect(r, [FILE, "test_area_loot", "at most 24"])
	r = raw()
	many.resize(24)
	_table(r, 0)["entries"] = many
	assert_eq(V.validate(r), PackedStringArray())


func test_unknown_fields_and_duplicate_ids() -> void:
	var r: Dictionary = raw()
	_entry(r, 0, 0)["weight"] = 1
	expect(r, [FILE, "entries[0]", "unknown field 'entries[0].weight'"])
	r = raw()
	_table(r, 1)["id"] = "test_area_loot"
	expect(r, [FILE, "duplicate loot table 'test_area_loot'"])


func test_an_empty_file_is_refused() -> void:
	var r: Dictionary = raw()
	_file(r)["tables"] = []
	expect(r, [FILE, "at least 1 table"])


func test_an_orphan_table_is_refused() -> void:
	var r: Dictionary = raw()
	(_file(r)["tables"] as Array).append({"id": "lonely", "entries": [{"item": "rift_dust", "chance_pct": 5, "qty": [1, 1]}]})
	expect(r, [FILE, "loot table 'lonely'", "not used by any area, monster or Rift Stone"])


func test_a_table_used_only_by_a_stone_is_not_an_orphan() -> void:
	assert_eq(V.validate(raw()), PackedStringArray(), "test_stone_loot is used by the stone only")


func test_unknown_references() -> void:
	var r: Dictionary = raw()
	V.entry_of(r, "areas", "areas.json", "areas", 2)["loot_tables"] = ["nope"]
	expect(r, ["areas.json", "area 'test_loot_area'", "unknown loot table 'nope'"])
	r = raw()
	V.entry_of(r, "monsters", "monsters.json", "monsters", 2)["loot_tables"] = ["nope"]
	expect(r, ["monsters.json", "monster 'test_loot_monster'", "unknown loot table 'nope'"])
	r = raw()
	V.entry_of(r, "rift_stones", "rift_stones.json", "rift_stones", 1)["loot_tables"] = ["nope"]
	expect(r, ["rift_stones.json", "rift stone 'test_loot_stone'", "unknown loot table 'nope'"])


func test_references_without_the_file_are_unknown() -> void:
	var r: Dictionary = raw()
	r["loot_tables"] = {}
	expect(r, ["areas.json", "test_loot_area", "unknown loot table 'test_area_loot'"])
