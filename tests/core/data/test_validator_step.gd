extends GutTest
## DataValidator: `mastery.step` (F-122), `fracture.risk_cap` / `fracture.risk_unit` (F-123) and the removed `mastery_bonuses`.

const V := preload("res://tests/core/data/test_data_validator.gd")


func _balance(raw: Dictionary) -> Dictionary:
	return V.file_of(raw, "balance", V.BALANCE)


func _expect(raw: Dictionary, fragments: Array[String]) -> void:
	for message: String in V.validate(raw):
		var matched: bool = true
		for fragment: String in fragments:
			matched = matched and message.contains(fragment)
		if matched:
			assert_true(true)
			return
	fail_test("no error with %s in %s" % [fragments, V.validate(raw)])


func test_the_fixtures_are_valid() -> void:
	assert_eq(V.validate(V.fixture_raw()), PackedStringArray())


func test_missing_step_is_an_error() -> void:
	var raw: Dictionary = V.fixture_raw()
	(_balance(raw)["mastery"] as Dictionary).erase("step")
	_expect(raw, [V.BALANCE, "missing key 'mastery.step'"])


func test_step_needs_known_stats_and_nonzero_values() -> void:
	var raw: Dictionary = V.fixture_raw()
	var step: Dictionary = (_balance(raw)["mastery"] as Dictionary)["step"] as Dictionary
	((step["gathering"] as Array)[0] as Dictionary)["stat"] = "luck"
	((step["crafting"] as Array)[0] as Dictionary)["value"] = 0
	_expect(raw, [V.BALANCE, "stat 'luck' is not in stats.json"])
	_expect(raw, [V.BALANCE, "mastery.step.crafting[0].value", "must not be 0"])


func test_step_levels_and_lists() -> void:
	var raw: Dictionary = V.fixture_raw()
	var step: Dictionary = (_balance(raw)["mastery"] as Dictionary)["step"] as Dictionary
	step["every_levels"] = 100
	step["gathering"] = []
	_expect(raw, [V.BALANCE, "every_levels", "<= 99"])
	_expect(raw, [V.BALANCE, "gathering"])


func test_step_modifier_has_no_scope() -> void:
	var raw: Dictionary = V.fixture_raw()
	var step: Dictionary = (_balance(raw)["mastery"] as Dictionary)["step"] as Dictionary
	((step["crafting"] as Array)[0] as Dictionary)["scope"] = "global"
	_expect(raw, [V.BALANCE, "mastery.step.crafting[0]", "scope"])


func test_the_risk_cap_and_units_are_checked() -> void:
	var raw: Dictionary = V.fixture_raw()
	var fracture: Dictionary = _balance(raw)["fracture"] as Dictionary
	(fracture["risk_cap"] as Dictionary)["base"] = 0
	(fracture["risk_unit"] as Dictionary)["not_a_risk"] = 3
	_expect(raw, [V.BALANCE, "fracture.risk_cap", "base"])
	_expect(raw, [V.BALANCE, "fracture.risk_unit"])


func test_every_grade_needs_a_modifier_that_fits_the_cap() -> void:
	var raw: Dictionary = V.fixture_raw()
	var fracture: Dictionary = _balance(raw)["fracture"] as Dictionary
	(fracture["risk_cap"] as Dictionary)["base"] = 5
	(fracture["risk_cap"] as Dictionary)["per_grade"] = 0
	_expect(raw, [V.BALANCE, "grade 1", "fits the cap"])


func test_the_removed_mastery_bonuses_are_rejected() -> void:
	var raw: Dictionary = V.fixture_raw()
	V.entry_of(raw, "skills", V.SKILLS, "skills", 2)["mastery_bonuses"] = []
	_expect(raw, [V.SKILLS, "mastery_bonuses", "removed"])
