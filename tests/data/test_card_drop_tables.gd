extends GutTest
## The Card entries of the real loot tables (M13-04; 02_FORMULAS.md F-113, Q64): grades per area as in F-113, grades 1-4
## drop from at least one table, about one Card every 2-4 hours of combat in the right area, only `map` entries with qty 1.

## Measured defaults (see test_rune_farming_hours.gd): kills per hour of each area.
const KILLS_PER_HOUR: Dictionary = {&"redrock_plains": 206.0, &"whisper_wood": 108.0, &"cracked_mines": 82.0, &"rift_threshold": 60.0}
## F-113: the grades of the Cards in the tables of each area and Monolito.
const AREA_GRADES: Dictionary = {&"redrock_plains": [1], &"whisper_wood": [1, 2], &"cracked_mines": [1, 2, 3], &"rift_threshold": [2, 3]}
const MONOLITH_GRADES: Dictionary = {&"redrock_plains": [1], &"whisper_wood": [1, 2], &"cracked_mines": [2, 3], &"rift_threshold": [3, 4]}  # M15: by area
const HOURS_MIN: float = 2.0
const HOURS_MAX: float = 4.0

var _data: GameData


func before_all() -> void:
	_data = TestFactory.real_data()


func _card_grades(table_ids: Array[StringName]) -> Array[int]:
	var grades: Array[int] = []
	for table_id: StringName in table_ids:
		for entry: DropEntry in _data.loot_table(table_id).entries:
			var item: ItemDef = _data.item(entry.item_id)
			if item.is_map():
				grades.append(item.map_grade)
	grades.sort()
	return grades


func _card_chance(table_ids: Array[StringName]) -> float:
	var total: float = 0.0
	for table_id: StringName in table_ids:
		for entry: DropEntry in _data.loot_table(table_id).entries:
			if _data.item(entry.item_id).is_map():
				total += entry.chance_pct
	return total


func test_areas_drop_the_cards_of_their_grades() -> void:
	for area_id: StringName in AREA_GRADES:
		assert_eq(_card_grades(_data.area(area_id).loot_tables), AREA_GRADES[area_id] as Array, String(area_id))


func test_monoliths_drop_the_cards_of_their_grades() -> void:
	for area_id: StringName in MONOLITH_GRADES:
		for stone: RiftStoneDef in _data.rift_stones_for_area(area_id):
			assert_eq(_card_grades(stone.loot_tables), MONOLITH_GRADES[area_id] as Array, String(stone.id))


func test_cards_of_grades_one_to_four_drop_somewhere() -> void:
	var seen: Dictionary = {}
	for table: LootTableDef in _data.loot_tables():
		for entry: DropEntry in table.entries:
			var item: ItemDef = _data.item(entry.item_id)
			if item.is_map():
				seen[item.map_grade] = true
	for grade: int in range(1, 5):
		assert_true(seen.has(grade), "grade %d" % grade)


func test_one_card_every_two_to_four_hours_in_the_right_area() -> void:
	for area_id: StringName in KILLS_PER_HOUR:
		var per_hour: float = float(KILLS_PER_HOUR[area_id]) * _card_chance(_data.area(area_id).loot_tables) / 100.0
		assert_gt(per_hour, 0.0, String(area_id))
		var hours: float = 1.0 / per_hour
		assert_between(hours, HOURS_MIN, HOURS_MAX, "%s: %.2f h per Card" % [area_id, hours])


func test_card_entries_are_single_copies() -> void:
	for table: LootTableDef in _data.loot_tables():
		for entry: DropEntry in table.entries:
			if _data.item(entry.item_id).is_map():
				assert_eq([entry.qty_min, entry.qty_max], [1, 1], "%s %s" % [table.id, entry.item_id])
				assert_lte(table.entries.size(), 24)
