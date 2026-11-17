extends GutTest
## DataValidatorDisciplines, the slots rules of M25-11 (docs/04_DATA_SCHEMA_M25.md §30.4): `disciplines.max_per_category` against the
## disciplines of each category, and (strict, real data) every gathering and artisan skill a discipline with a real choice.

const V: GDScript = preload("res://tests/core/data/test_data_validator.gd")
const NODES_FILE: String = "res://tests/fixtures/data/encounters/nodes.json"


func _raw() -> Dictionary:
	var raw: Dictionary = V.fixture_raw()
	var errors: PackedStringArray = []
	raw["encounters"] = {NODES_FILE: JsonLoader.load_file(NODES_FILE, errors)}
	return raw


func _disciplines_balance(raw: Dictionary) -> Dictionary:
	return V.file_of(raw, "balance", V.BALANCE)["disciplines"] as Dictionary


func _skill(raw: Dictionary, id: String) -> Dictionary:
	for e: Variant in (V.file_of(raw, "skills", V.SKILLS)["skills"] as Array):
		if (e as Dictionary)["id"] == id:
			return e as Dictionary
	return {}


func _strict_errors(raw: Dictionary) -> PackedStringArray:
	var v := DataValidatorRules.new()
	v.max_skill_level = 99.0
	v.max_character_level = 99.0
	for section: String in ["skills", "items", "actions"]:
		for path: String in raw[section]:
			for e: Variant in ((raw[section][path] as Dictionary)[section] as Array):
				var target: Dictionary[StringName, Dictionary] = v.skills if section == "skills" else v.items if section == "items" else v.actions
				target[StringName((e as Dictionary)["id"] as String)] = e as Dictionary
	DataValidatorDisciplines.validate(v, raw, true)
	return v.errors


func _has_error(errors: PackedStringArray, fragment: String) -> bool:
	for message: String in errors:
		if message.contains(fragment):
			return true
	return false


func test_max_per_category_above_the_disciplines_of_a_category_is_rejected() -> void:
	var raw: Dictionary = _raw()
	_disciplines_balance(raw)["max_per_category"] = 3  # the fixtures have two artisan disciplines
	var errors: PackedStringArray = V.validate(raw)
	assert_true(_has_error(errors, "(3) is above the 2 disciplines of the category 'artisan'"), str(errors))


func test_strict_an_artisan_skill_without_discipline_is_rejected() -> void:
	var raw: Dictionary = _raw()
	_skill(raw, "test_craft").erase("discipline")
	var errors: PackedStringArray = _strict_errors(raw)
	assert_true(_has_error(errors, "skill 'test_craft' (artisan) is not a discipline"), str(errors))


func test_strict_the_choice_must_be_real() -> void:
	var raw: Dictionary = _raw()
	var errors: PackedStringArray = _strict_errors(raw)
	assert_true(_has_error(errors, "must be below the 2 disciplines of the category 'artisan'"), str(errors))


func test_the_real_data_have_four_and_four_and_choose_two() -> void:
	var data: GameData = TestFactory.real_data()
	assert_eq(data.disciplines(&"gathering").size(), 4)
	assert_eq(data.disciplines(&"artisan").size(), 4)
	assert_eq(int(data.balance_value("disciplines.max_per_category")), 2)
	assert_eq(data.errors, PackedStringArray())
