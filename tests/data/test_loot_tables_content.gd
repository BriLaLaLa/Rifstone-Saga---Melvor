extends GutTest
## The real loot tables (02_FORMULAS.md §8.5b, docs/04_DATA_SCHEMA.md §8b): one table per area, one per Monolito,
## the starting values of the formulas. Starting values: M12-07 may retune them in the data.

const AREAS: Array[String] = ["redrock_plains", "whisper_wood", "cracked_mines", "rift_threshold"]
const MONOLITHS: Dictionary = {"redrock_stone": "loot_monolith_redrock", "whisper_stone": "loot_monolith_whisper",
		"mine_stone": "loot_monolith_mine", "threshold_stone": "loot_monolith_threshold"}
const FAMILIES: Array[String] = ["ember", "eye", "shade", "root"]
const TRADES: Array[String] = ["forestry", "quarrying", "angling"]
## The contract grade of each area: the highest one dropped there and the grade of its Monolito.
const MAX_GRADE: Array[String] = ["apprentice", "journeyman", "expert", "master"]

var _data: GameData


func before_all() -> void:
	_data = TestFactory.real_data()


func _chance(table: String, item: String) -> float:
	for entry: DropEntry in _data.loot_table(StringName(table)).entries:
		if entry.item_id == StringName(item):
			return entry.chance_pct
	return -1.0


func _qty(table: String, item: String) -> Array[int]:
	for entry: DropEntry in _data.loot_table(StringName(table)).entries:
		if entry.item_id == StringName(item):
			return [entry.qty_min, entry.qty_max]
	return []


func test_every_area_and_monolith_has_its_table() -> void:
	assert_eq(_data.loot_tables().size(), 8)
	for area_id: String in AREAS:
		assert_eq(_data.area(StringName(area_id)).loot_tables, [StringName("loot_area_" + area_id)] as Array[StringName], area_id)
	for stone_id: String in MONOLITHS:
		assert_eq(_data.rift_stone(StringName(stone_id)).loot_tables, [StringName(MONOLITHS[stone_id])] as Array[StringName], stone_id)


func test_area_tables_follow_8_5b() -> void:
	for area_id: String in AREAS:
		var table: String = "loot_area_" + area_id
		assert_eq(_chance(table, "rift_dust"), 8.0, table)  # M14, Q71
		assert_eq(_qty(table, "rift_dust"), [1, 1] as Array[int], table)
		for family: String in FAMILIES:
			assert_eq(_chance(table, "stone_%s_chip" % family), 1.0, table)
			assert_eq(_chance(table, "stone_%s_heart" % family), -1.0, "no perfect stone from the monsters")
	for table: String in ["loot_area_whisper_wood", "loot_area_cracked_mines", "loot_area_rift_threshold"]:
		for family: String in FAMILIES:
			assert_eq(_chance(table, "stone_%s_stone" % family), 0.05, table)
		assert_eq([_chance(table, "currency_spark"), _chance(table, "currency_flux"), _chance(table, "currency_crown")],
				[0.05, 0.03, 0.02], table)
	assert_eq(_chance("loot_area_redrock_plains", "stone_ember_stone"), -1.0, "stones and Crystals not in the Pianure")
	assert_eq(_chance("loot_area_redrock_plains", "currency_spark"), -1.0)


func test_bags_of_the_areas() -> void:
	assert_eq(_chance("loot_area_redrock_plains", "bag_leather"), 0.05)
	assert_eq(_chance("loot_area_whisper_wood", "bag_leather"), 0.05)
	assert_eq(_chance("loot_area_cracked_mines", "bag_wayfarer"), 0.02)
	assert_eq(_chance("loot_area_cracked_mines", "bag_leather"), -1.0)
	assert_eq(_chance("loot_area_rift_threshold", "bag_runic"), -1.0, "the runic bag falls only from the Monoliti")


func test_contract_grades_by_area() -> void:
	# [apprentice, journeyman, expert, master] chance per trade, in each area (0.005% is under the 0.01% minimum: 0.01)
	var want: Dictionary = {
		"loot_area_redrock_plains": [0.02, -1.0, -1.0, -1.0], "loot_area_whisper_wood": [0.02, 0.015, -1.0, -1.0],
		"loot_area_cracked_mines": [-1.0, 0.015, 0.01, -1.0], "loot_area_rift_threshold": [-1.0, -1.0, 0.01, 0.01]}
	for table: String in want:
		for trade: String in TRADES:
			for index: int in 4:
				assert_eq(_chance(table, "contract_%s_%s" % [trade, MAX_GRADE[index]]), (want[table] as Array)[index], "%s %s %d" % [table, trade, index])


func test_monolith_tables_follow_8_5b() -> void:
	for index: int in 4:
		var table: String = MONOLITHS.values()[index]
		assert_eq([_chance(table, "rift_dust"), _qty(table, "rift_dust")], [100.0, [20, 40] as Array[int]], table)
		for family: String in FAMILIES:
			assert_eq([_chance(table, "stone_%s_chip" % family), _qty(table, "stone_%s_chip" % family)], [100.0, [2, 4] as Array[int]], table)
			assert_eq(_chance(table, "stone_%s_stone" % family), 20.0, table)
		assert_eq([_chance(table, "currency_spark"), _chance(table, "currency_flux"), _chance(table, "currency_crown")], [15.0, 10.0, 5.0], table)
		for trade: String in TRADES:
			assert_eq(_chance(table, "contract_%s_%s" % [trade, MAX_GRADE[index]]), 2.0, table)
		assert_eq(_chance(table, "bag_runic"), 5.0 if index == 3 else -1.0, "only the Monolito della Soglia drops the runic bag")


func test_every_new_drop_item_has_a_source_in_the_tables() -> void:
	var dropped: Dictionary = {}
	for table: LootTableDef in _data.loot_tables():
		for entry: DropEntry in table.entries:
			dropped[entry.item_id] = true
	for id: String in ["rift_dust", "bag_leather", "bag_wayfarer", "bag_runic"]:
		assert_true(dropped.has(StringName(id)), id)
	for family: String in FAMILIES:
		assert_true(dropped.has(StringName("stone_%s_chip" % family)), family)
	for trade: String in TRADES:
		for grade: String in MAX_GRADE:
			assert_true(dropped.has(StringName("contract_%s_%s" % [trade, grade])), "%s %s" % [trade, grade])
