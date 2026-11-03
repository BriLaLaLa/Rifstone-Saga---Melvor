extends GutTest
## PackDef and the packs of AreaDef (docs/04_DATA_SCHEMA.md §8).


func _parse(text: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(text)
	assert_true(parsed is Dictionary, "test JSON must be an object")
	return parsed as Dictionary


func test_pack_example() -> void:
	var pack: PackDef = PackDef.from_dict(_parse("""{"weight": 2, "monsters": ["ember_rat", "plains_boar"]}"""))
	assert_not_null(pack)
	assert_eq(pack.weight, 2)
	assert_eq(typeof(pack.weight), TYPE_INT)
	assert_eq(pack.monster_ids, [&"ember_rat", &"plains_boar"] as Array[StringName])


func test_pack_keeps_repeats_and_order() -> void:
	var pack: PackDef = PackDef.from_dict(_parse("""{"weight": 1, "monsters": ["a", "b", "a"]}"""))
	assert_eq(pack.monster_ids, [&"a", &"b", &"a"] as Array[StringName])


func test_pack_missing_weight_is_null() -> void:
	assert_null(PackDef.from_dict(_parse("""{"monsters": ["a"]}""")))
	assert_push_error(1)


func test_pack_fractional_weight_is_null() -> void:
	assert_null(PackDef.from_dict(_parse("""{"weight": 1.5, "monsters": ["a"]}""")))
	assert_push_error(1)


func test_area_monster_ids_are_distinct_in_order_of_first_appearance() -> void:
	var area: AreaDef = AreaDef.from_dict(_parse("""
		{"id": "a", "name": "A", "order": 1, "description": "", "requirements": {},
		 "packs": [{"weight": 1, "monsters": ["b", "a", "b"]}, {"weight": 3, "monsters": ["c", "a"]}]}"""))
	assert_eq(area.monster_ids, [&"b", &"a", &"c"] as Array[StringName])
	assert_eq(area.packs.size(), 2)
	assert_eq(area.packs[1].weight, 3)


func test_area_with_a_bad_pack_is_null() -> void:
	var area: AreaDef = AreaDef.from_dict(_parse("""
		{"id": "a", "name": "A", "order": 1, "description": "", "requirements": {},
		 "packs": [{"weight": 1, "monsters": ["b"]}, {"monsters": ["c"]}]}"""))
	assert_null(area)
	assert_push_error(1)
