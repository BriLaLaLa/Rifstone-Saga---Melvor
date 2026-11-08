extends GutTest
## Balance invariants of the data (docs/02_FORMULAS.md F-102) and the validator rules of `helper.*` and of the
## `contract` items (docs/04_DATA_SCHEMA.md §3, §5). One broken thing per test, in a copy of the fixture data.

const V: GDScript = preload("res://tests/core/data/test_data_validator.gd")


func _balance(raw: Dictionary) -> Dictionary:
	return V.file_of(raw, "balance", V.BALANCE)


func _expect(raw: Dictionary, fragments: Array[String]) -> void:
	var errors: PackedStringArray = V.validate(raw)
	for message: String in errors:
		var matched: bool = true
		for fragment: String in fragments:
			matched = matched and message.contains(fragment)
		if matched:
			assert_true(true)
			return
	fail_test("no error with %s in %s" % [fragments, errors])


func _contract(raw: Dictionary, index: int) -> Dictionary:
	return V.entry_of(raw, "items", "contracts.json", "items", index)


func test_f102_invariant_holds_on_the_real_data() -> void:
	var data: GameData = TestFactory.real_data()
	var min_mult: float = INF
	for grade: HelperGradeDef in data.helper_grades():
		min_mult = minf(min_mult, grade.interval_mult)
	var ratio: float = 3.0 * float(data.balance_value("helper.xp_pct")) / (100.0 * min_mult)
	assert_lte(ratio, 1.0)
	assert_eq(ratio, 0.5)


func test_fixtures_and_real_data_are_valid() -> void:
	assert_eq(V.validate(V.fixture_raw()).size(), 0)
	assert_eq(TestFactory.fixture_data().helper_grades().size(), 4)
	assert_eq(TestFactory.real_data().helper_grade(&"expert").interval_mult, 2.0)


func test_contract_lookup() -> void:
	var data: GameData = TestFactory.fixture_data()
	var contract: ItemDef = data.contract_for(&"test_gather", &"master")
	assert_not_null(contract)
	assert_true(contract.is_contract())
	assert_eq(contract.contract_grade, &"master")
	assert_null(data.contract_for(&"test_craft", &"master"))


func test_invariant_violation_is_rejected() -> void:
	var raw: Dictionary = V.fixture_raw()
	(_balance(raw)["helper"] as Dictionary)["xp_pct"] = 80.0
	_expect(raw, [V.BALANCE, "helper", "<= 1"])


func test_grades_rules() -> void:
	var raw: Dictionary = V.fixture_raw()
	((_balance(raw)["helper"] as Dictionary)["grades"] as Array).pop_back()
	_expect(raw, [V.BALANCE, "helper.grades", "4 entries"])
	var raw_order: Dictionary = V.fixture_raw()
	(((_balance(raw_order)["helper"] as Dictionary)["grades"] as Array)[0] as Dictionary)["interval_mult"] = 1.0
	_expect(raw_order, [V.BALANCE, "interval_mult", "not increasing"])
	var raw_dup: Dictionary = V.fixture_raw()
	(((_balance(raw_dup)["helper"] as Dictionary)["grades"] as Array)[1] as Dictionary)["id"] = "apprentice"
	_expect(raw_dup, [V.BALANCE, "duplicate"])


func test_percent_ranges() -> void:
	var raw: Dictionary = V.fixture_raw()
	(_balance(raw)["helper"] as Dictionary)["mastery_pct"] = 0.0
	_expect(raw, [V.BALANCE, "mastery_pct"])


func test_missing_helper_key() -> void:
	var raw: Dictionary = V.fixture_raw()
	(_balance(raw)["helper"] as Dictionary).erase("grades")
	_expect(raw, [V.BALANCE, "missing key 'helper.grades'"])


func test_contract_rules() -> void:
	var raw: Dictionary = V.fixture_raw()
	(_contract(raw, 0)["contract"] as Dictionary)["grade"] = "legend"
	_expect(raw, ["contracts.json", "contract", "grade"])
	var raw_skill: Dictionary = V.fixture_raw()
	(_contract(raw_skill, 0)["contract"] as Dictionary)["skill"] = "test_craft"
	_expect(raw_skill, ["contracts.json", "not a gathering skill"])
	var raw_value: Dictionary = V.fixture_raw()
	_contract(raw_value, 0)["value"] = 5
	_expect(raw_value, ["contracts.json", "value 0"])
	var raw_id: Dictionary = V.fixture_raw()
	_contract(raw_id, 0)["id"] = "contract_x"
	_expect(raw_id, ["contracts.json", "contract_<skill>_<grade>"])


func test_contract_without_its_sub_object_and_the_other_way_round() -> void:
	var raw: Dictionary = V.fixture_raw()
	_contract(raw, 0).erase("contract")
	_expect(raw, ["contracts.json", "contract"])
	var raw_extra: Dictionary = V.fixture_raw()
	var twig: Dictionary = V.entry_of(raw_extra, "items", "materials.json", "items", 0)
	twig["contract"] = {"skill": "test_gather", "grade": "master"}
	_expect(raw_extra, ["materials.json", "'contract' is not allowed"])


func test_a_missing_contract_of_the_set_is_reported() -> void:
	var raw: Dictionary = V.fixture_raw()
	var list: Array = V.file_of(raw, "items", "contracts.json")["items"]
	list.pop_back()
	_expect(raw, ["missing contract", "test_gather_b", "master"])
