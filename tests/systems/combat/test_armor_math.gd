extends GutTest
## ArmorMath: F-117 (Armour and Barrier) and F-118 (set budget and piece values), docs/02_FORMULAS.md §5e and §8.4.

var _d: GameData = null


func before_all() -> void:
	_d = GameData.load_from_dirs()


func test_armor_reduction() -> void:
	assert_almost_eq(ArmorMath.reduction_pct(100, 20, _d), 35.7143, 0.0001)
	assert_almost_eq(ArmorMath.reduction_pct(724, 92, _d), 54.1916, 0.0001)
	assert_eq(ArmorMath.reduction_pct(2000, 10, _d), 75.0, "limited to cap_pct")
	assert_eq(ArmorMath.reduction_pct(0, 50, _d), 0.0)
	assert_eq(ArmorMath.reduction_pct(-5, 50, _d), 0.0)


func test_barrier_arcane() -> void:
	assert_almost_eq(ArmorMath.reduction_pct(121, 30, _d), 33.5180, 0.0001)


func test_set_budget() -> void:
	assert_eq(ArmorMath.set_budget(11, _d), {"armor": 404, "evasion": 77}, "grade 11 = level 50")
	assert_eq(ArmorMath.set_budget(1, _d), {"armor": 12, "evasion": 4})
	assert_eq(ArmorMath.set_budget(15, _d), {"armor": 724, "evasion": 137})


func test_piece_values_by_material() -> void:
	assert_eq(ArmorMath.piece_values(&"body", &"plate", 11, _d), {"armor": 121, "barrier": 0, "evasion": 5})
	assert_eq(ArmorMath.piece_values(&"body", &"leather", 11, _d), {"armor": 73, "barrier": 48, "evasion": 23})
	assert_eq(ArmorMath.piece_values(&"body", &"cloth", 11, _d), {"armor": 36, "barrier": 121, "evasion": 9})


func test_full_plate_set_with_shield_gives_404_armor() -> void:
	var expected: Dictionary = {&"body": 121, &"legs": 81, &"head": 61, &"offhand": 61, &"hands": 40, &"feet": 40}
	var total: int = 0
	for slot: StringName in expected:
		var armor: int = int(ArmorMath.piece_values(slot, &"plate", 11, _d)["armor"])
		assert_eq(armor, expected[slot], "plate %s" % slot)
		total += armor
	assert_eq(total, 404)


func test_real_plate_pieces_follow_the_table_on_their_current_grade() -> void:
	var checked: int = 0
	for def: ItemDef in _d.items():
		if def.equip == null or def.equip.material != &"plate":
			continue
		var values: Dictionary = ArmorMath.piece_values(def.equip.slot, def.equip.material, def.equip.grade, _d)
		var armor: float = 0.0
		var evasion: float = 0.0
		for m: Modifier in def.equip.modifiers:
			if m.stat == &"armor":
				armor = m.value
			elif m.stat == &"evasion_bonus":
				evasion = m.value
		assert_eq(int(armor), int(values["armor"]), "%s armor" % def.id)
		assert_eq(int(evasion), int(values["evasion"]), "%s evasion" % def.id)
		checked += 1
	assert_gt(checked, 0)


func test_grade_tables() -> void:
	assert_eq(_d.grade_level(1), 1)
	assert_eq(_d.grade_level(11), 50)
	assert_eq(_d.grade_level(15), 90)
	assert_eq(_d.material_grade(1), 1)
	assert_eq(_d.material_grade(11), 6)
	assert_eq(_d.material_grade(15), 8)
