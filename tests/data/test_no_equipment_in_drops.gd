extends GutTest
## M14-05: pieces and blueprints do not drop from the lists any more (F-121 replaces them with the pool of the code):
## no `drops` of a monster, a boss or a Monolith contains equipment, tools or blueprints; the loot tables too; every loot
## table is used; Rift Dust 8% x 1 (Q71); the `loot.*` keys of the pool (F-121).

var _data: GameData = null


func before_all() -> void:
	_data = GameData.load_from_dirs()


func _raw(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path)) as Dictionary


func _assert_clean(owner_id: String, drops: Array) -> void:
	for entry: Variant in drops:
		var item: ItemDef = _data.item(StringName((entry as Dictionary)["item"] as String))
		assert_not_null(item, "%s drops a known item" % owner_id)
		if item != null:
			assert_false([&"equipment", &"tool", &"blueprint"].has(item.category), "%s drops %s" % [owner_id, item.id])


func test_monsters_drop_no_pieces_and_no_blueprints() -> void:
	for m: Dictionary in _raw("res://data/combat/monsters.json")["monsters"]:
		_assert_clean(m["id"] as String, m["drops"] as Array)
		assert_lte((m["drops"] as Array).size(), 8)


func test_bosses_and_monoliths_drop_no_pieces_and_no_blueprints() -> void:
	for b: Dictionary in _raw("res://data/maps/bosses.json")["bosses"]:
		_assert_clean(b["id"] as String, b["drops"] as Array)
	for s: Dictionary in _raw("res://data/combat/rift_stones.json")["rift_stones"]:
		_assert_clean(s["id"] as String, s["drops"] as Array)


func test_loot_tables_hold_no_pieces_and_no_blueprints() -> void:
	for table: LootTableDef in _data.loot_tables():
		for entry: DropEntry in table.entries:
			assert_false([&"equipment", &"tool", &"blueprint"].has(_data.item(entry.item_id).category),
					"%s: %s" % [table.id, entry.item_id])


func test_every_loot_table_is_used() -> void:
	var used: Dictionary = {}
	for a: Dictionary in _raw("res://data/combat/areas.json")["areas"]:
		for id: Variant in a.get("loot_tables", []):
			used[id] = true
	for m: Dictionary in _raw("res://data/combat/monsters.json")["monsters"]:
		for id: Variant in m.get("loot_tables", []):
			used[id] = true
	for s: Dictionary in _raw("res://data/combat/rift_stones.json")["rift_stones"]:
		for id: Variant in s.get("loot_tables", []):
			used[id] = true
	for table: LootTableDef in _data.loot_tables():
		assert_true(used.has(String(table.id)), "table %s is used" % table.id)


func test_rift_dust_is_8_percent_times_one_in_the_area_tables() -> void:
	for area: AreaDef in _data.areas():
		for table_id: StringName in area.loot_tables:
			var found: bool = false
			for entry: DropEntry in _data.loot_table(table_id).entries:
				if entry.item_id == &"rift_dust":
					found = true
					assert_eq([entry.chance_pct, entry.qty_min, entry.qty_max], [8.0, 1, 1], table_id)
			assert_true(found, "%s drops Rift Dust" % table_id)


func test_loot_pool_keys_of_f121() -> void:
	assert_eq(float(_data.balance_value("loot.equipment.chance_pct")), 2.9)
	assert_eq(int(_data.balance_value("loot.equipment.level_ahead")), 5)
	assert_eq(int(_data.balance_value("loot.equipment.level_window")), 15)
	var kinds: Dictionary = _data.balance_value("loot.equipment.kind_weights") as Dictionary
	assert_eq(kinds.size(), 10, "the 10 types of piece")
	for kind: String in ["sword", "greatsword", "shield", "head", "body", "legs", "feet", "hands", "ring", "neck"]:
		assert_eq(float(kinds[kind]), 1.0, kind)
	assert_eq(float(_data.balance_value("loot.blueprint.chance_pct")), 0.4)
	assert_eq(float(_data.balance_value("rarity.drop.magic_pct")), 25.0)
	assert_eq(float(_data.balance_value("rarity.drop.rare_pct")), 5.0)
