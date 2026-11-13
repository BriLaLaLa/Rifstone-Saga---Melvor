extends "res://tests/data/engraver_data_base.gd"
## Rune grades (docs/04_DATA_SCHEMA.md §5, F-107): `infusion.grade` / `infusion.family`, the effect of the grade
## (value = grade I x rune.grade_mult[grade-1]) checked by the validator, five grades per family, the id of each grade.
## Fixture family `inf_test` (skill_interval_pct -3, -6, -9, -12, -15).

const FAMILY: String = "inf_test"


func _rune(raw_data: Dictionary, grade: int) -> Dictionary:
	for item: Variant in V.file_of(raw_data, "items", ITEMS_RUNES)["items"] as Array:
		if (item as Dictionary)["id"] == (FAMILY if grade == 1 else "%s_%d" % [FAMILY, grade]):
			return item as Dictionary
	return {}


func _first_modifier(rune: Dictionary) -> Dictionary:
	return ((rune["infusion"] as Dictionary)["modifiers"] as Array)[0] as Dictionary


func test_grades_are_parsed() -> void:
	var data: GameData = TestFactory.fixture_data()
	assert_eq(data.item(&"inf_test").infusion_grade, 1)
	assert_eq(data.item(&"inf_test_3").infusion_grade, 3)
	assert_eq(data.item(&"inf_test_3").infusion_family, &"inf_test")
	assert_eq(data.item(&"test_infusion").infusion_grade, 1, "default grade")
	assert_eq(data.item(&"test_infusion").infusion_family, &"test_infusion", "default family: its own id")
	assert_true(data.item(&"inf_test_5").is_infusion())


func test_f107_examples_with_the_fixture_family() -> void:
	var data: GameData = TestFactory.fixture_data()
	var mult: Array = data.balance_value("rune.grade_mult")
	var base: float = data.item(&"inf_test").infusion_modifiers[0].value
	assert_eq(base, -3.0)
	assert_eq(data.item(&"inf_test_3").infusion_modifiers[0].value, -9.0, "grade III: -3 x 3")
	assert_eq(data.item(&"inf_test_5").infusion_modifiers[0].value, -15.0)
	for grade: int in range(2, 6):
		var rune: ItemDef = data.item(StringName("inf_test_%d" % grade))
		assert_eq(rune.infusion_modifiers[0].value, base * float(mult[grade - 1]), "grade %d" % grade)


func test_f107_examples_of_the_game_runes() -> void:
	var data: GameData = TestFactory.real_data()
	assert_eq(data.item(&"inf_swift_hands").infusion_modifiers[0].value, -3.0, "grade I is the same as before")
	assert_eq(data.item(&"inf_swift_hands").infusion_grade, 1)
	assert_eq(data.item(&"inf_swift_hands_3").infusion_modifiers[0].value, -9.0, "Rapidità III")
	assert_eq(data.item(&"inf_bulwark_5").infusion_modifiers[0].value, 300.0, "Baluardo V")
	assert_eq(data.item(&"inf_riftsense_2").infusion_modifiers[0].value, 1.0, "Senso del Rift II")
	var runes: int = 0
	var families: Dictionary = {}
	for item: ItemDef in data.items():
		if item.is_infusion() and not String(item.id).begins_with("inf_minor_"):  # M18-01: minor runes have one grade
			runes += 1
			families[item.infusion_family] = int(families.get(item.infusion_family, 0)) + 1
	assert_eq(runes, 45, "9 families x 5 grades")
	assert_eq(families.size(), 9)
	for family: Variant in families:
		assert_eq(families[family], 5, str(family))


func test_fixtures_are_valid() -> void:
	assert_eq(V.validate(raw()), PackedStringArray())


func test_value_must_follow_the_grade() -> void:
	var r: Dictionary = raw()
	_first_modifier(_rune(r, 3))["value"] = -8
	expect(r, [ITEMS_RUNES, "inf_test_3", "rune.grade_mult[2]"])
	r = raw()
	balance(r, "rune")["grade_mult"] = [1, 2, 3, 4, 6]
	expect(r, [ITEMS_RUNES, "inf_test_5", "rune.grade_mult[4]"])


func test_the_stat_must_be_the_one_of_grade_one() -> void:
	var r: Dictionary = raw()
	_first_modifier(_rune(r, 2))["stat"] = "skill_xp_pct"
	expect(r, [ITEMS_RUNES, "inf_test_2", "rune.grade_mult[1]"])


func test_modifier_count_must_match() -> void:
	var r: Dictionary = raw()
	((_rune(r, 4)["infusion"] as Dictionary)["modifiers"] as Array).append({"stat": "skill_xp_pct", "value": 1})
	expect(r, [ITEMS_RUNES, "inf_test_4", "2 modifiers, grade I has 1"])


func test_no_grade_may_be_missing() -> void:
	var r: Dictionary = raw()
	var items: Array = V.file_of(r, "items", ITEMS_RUNES)["items"] as Array
	items.erase(_rune(r, 4))
	expect(r, [ITEMS_RUNES, "rune family 'inf_test'", "grade 4 is missing"])


func test_the_id_of_a_grade_is_family_and_number() -> void:
	var r: Dictionary = raw()
	_rune(r, 2)["id"] = "inf_test_second"
	expect(r, [ITEMS_RUNES, "inf_test_second", "the id must be 'inf_test_2'"])


func test_a_family_needs_its_grade_one() -> void:
	var r: Dictionary = raw()
	var items: Array = V.file_of(r, "items", ITEMS_RUNES)["items"] as Array
	items.erase(_rune(r, 1))
	expect(r, [ITEMS_RUNES, "rune family 'inf_test'", "grade I rune must exist"])


func test_grade_and_family_shape() -> void:
	var r: Dictionary = raw()
	(_rune(r, 2)["infusion"] as Dictionary)["grade"] = 6
	expect(r, [ITEMS_RUNES, "inf_test_2", "infusion.grade"])
	r = raw()
	(_rune(r, 2)["infusion"] as Dictionary)["grade"] = "II"
	expect(r, [ITEMS_RUNES, "inf_test_2", "infusion.grade"])
	r = raw()
	(_rune(r, 2)["infusion"] as Dictionary)["family"] = 3
	expect(r, [ITEMS_RUNES, "inf_test_2", "infusion.family"])
