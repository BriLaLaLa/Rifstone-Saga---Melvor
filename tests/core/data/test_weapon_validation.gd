extends GutTest
## DataValidator, M14: weapons (`dmg_min`/`dmg_max`), armour `material`, grades 1..15 and the balance keys of F-117/F-118
## (docs/04_DATA_SCHEMA.md §21). One test per rule, on a broken copy of the fixture data.

const V: GDScript = preload("res://tests/core/data/test_data_validator.gd")


func _expect(raw: Dictionary, fragments: Array[String]) -> void:
	for message: String in V.validate(raw):
		var matched: bool = true
		for fragment: String in fragments:
			matched = matched and message.contains(fragment)
		if matched:
			assert_true(true)
			return
	fail_test("no error with %s" % [fragments])


func _equip(raw: Dictionary, index: int) -> Dictionary:
	return V.entry_of(raw, "items", "equipment.json", "items", index)["equip"] as Dictionary


func _balance(raw: Dictionary) -> Dictionary:
	var files: Dictionary = raw["balance"]
	return files[files.keys()[0]] as Dictionary


func test_fixture_data_is_valid() -> void:
	assert_eq(V.validate(V.fixture_raw()), PackedStringArray())


func test_weapon_without_damage_is_rejected() -> void:
	var raw: Dictionary = V.fixture_raw()
	(_equip(raw, 0)["weapon"] as Dictionary).erase("dmg_min")
	(_equip(raw, 0)["weapon"] as Dictionary).erase("dmg_max")
	_expect(raw, ["equipment.json", "item 'test_blade'", "missing field 'equip.weapon.dmg_min'"])
	_expect(raw, ["equipment.json", "item 'test_blade'", "missing field 'equip.weapon.dmg_max'"])


func test_weapon_min_above_max_is_rejected() -> void:
	var raw: Dictionary = V.fixture_raw()
	var weapon: Dictionary = _equip(raw, 0)["weapon"] as Dictionary
	weapon["dmg_min"] = 7
	weapon["dmg_max"] = 6
	_expect(raw, ["item 'test_blade'", "'equip.weapon.dmg_min' must be <= 'equip.weapon.dmg_max'"])


func test_weapon_damage_must_be_positive_integers() -> void:
	var raw: Dictionary = V.fixture_raw()
	var weapon: Dictionary = _equip(raw, 0)["weapon"] as Dictionary
	weapon["dmg_min"] = 0
	weapon["dmg_max"] = 5.5
	_expect(raw, ["item 'test_blade'", "field 'equip.weapon.dmg_min' must be >= 1"])
	_expect(raw, ["item 'test_blade'", "field 'equip.weapon.dmg_max' must be an integer"])


func test_grade_goes_up_to_15() -> void:
	var raw: Dictionary = V.fixture_raw()
	_equip(raw, 0)["grade"] = 15
	assert_eq(V.validate(raw), PackedStringArray(), "grade 15 is valid")
	_equip(raw, 0)["grade"] = 16
	_expect(raw, ["item 'test_blade'", "field 'equip.grade' must be >= 1 and <= 15"])


func test_armour_needs_a_material() -> void:
	var raw: Dictionary = V.fixture_raw()
	(_equip(raw, 3) as Dictionary).erase("material")  # test_helm
	_expect(raw, ["item 'test_helm'", "missing field 'equip.material'"])
	_equip(raw, 3)["material"] = "silk"
	_expect(raw, ["item 'test_helm'", "field 'equip.material' must be one of"])


func test_shield_needs_a_material_and_a_weapon_cannot_have_one() -> void:
	var raw: Dictionary = V.fixture_raw()
	(_equip(raw, 2) as Dictionary).erase("material")  # test_shield
	_expect(raw, ["item 'test_shield'", "missing field 'equip.material'"])
	_equip(raw, 0)["material"] = "plate"
	_expect(raw, ["item 'test_blade'", "'equip.material' is allowed only for armour slots and shields"])


func test_the_player_stat_damage_reduction_is_gone() -> void:
	var raw: Dictionary = V.fixture_raw()
	_equip(raw, 3)["modifiers"] = [{"stat": "damage_reduction", "value": 2}]
	_expect(raw, ["item 'test_helm'", "damage_reduction"])


func test_balance_equipment_keys_are_checked() -> void:
	var raw: Dictionary = V.fixture_raw()
	var equipment: Dictionary = _balance(raw)["equipment"] as Dictionary
	equipment["grade_levels"] = [1, 5, 10]
	equipment["grade_material"] = [1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 9]
	(equipment["slot_weights"] as Dictionary)["body"] = 0.5
	_expect(raw, ["key 'equipment.grade_levels' needs exactly 15 integers"])
	_expect(raw, ["key 'equipment.grade_material' must be integers in 1..8"])
	_expect(raw, ["key 'equipment.slot_weights' must sum to 1"])


func test_balance_armor_keys_are_checked() -> void:
	var raw: Dictionary = V.fixture_raw()
	var armor: Dictionary = (_balance(raw)["combat"] as Dictionary)["armor"] as Dictionary
	armor["cap_pct"] = 100
	armor["k"] = 0
	((armor["materials"] as Dictionary)["plate"] as Dictionary).erase("barrier")
	_expect(raw, ["field 'combat.armor.cap_pct' must be > 0 and <= 95"])
	_expect(raw, ["field 'combat.armor.k' must be > 0"])
	_expect(raw, ["missing field 'combat.armor.materials.plate.barrier'"])


func test_unarmed_damage_keys_are_checked() -> void:
	var raw: Dictionary = V.fixture_raw()
	var unarmed: Dictionary = ((_balance(raw)["combat"] as Dictionary)["unarmed"]) as Dictionary
	unarmed["dmg_min"] = 3
	unarmed["dmg_max"] = 1
	_expect(raw, ["'combat.unarmed.dmg_min' must be <= 'combat.unarmed.dmg_max'"])
	unarmed.erase("dmg_max")
	_expect(raw, ["missing field 'combat.unarmed.dmg_max'"])


func test_monster_damage_reduction_stays_a_percentage_up_to_80() -> void:
	var raw: Dictionary = V.fixture_raw()
	V.entry_of(raw, "monsters", "monsters.json", "monsters", 0)["damage_reduction"] = 81
	_expect(raw, ["field 'damage_reduction' must be >= 0 and <= 80"])
