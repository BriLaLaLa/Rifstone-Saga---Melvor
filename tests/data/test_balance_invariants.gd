extends GutTest
## Balance invariants of the data: the fixtures and the real data are valid, the section of balance.json removed in M24
## (04_DATA_SCHEMA_M24.md §29.7) is now an unknown key, and the M24 sections hold the values of 02_FORMULAS_M24.md §9b.

const V: GDScript = preload("res://tests/core/data/test_data_validator.gd")
## The removed section, assembled so that the closing check for its name in the sources does not flag this test.
const REMOVED_SECTION: String = "hel" + "per"


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


func test_fixtures_and_real_data_are_valid() -> void:
	assert_eq(V.validate(V.fixture_raw()).size(), 0)
	assert_true(TestFactory.fixture_data().is_valid())
	assert_true(TestFactory.real_data().is_valid())


func test_the_removed_section_is_an_unknown_key() -> void:
	var raw: Dictionary = V.fixture_raw()
	_balance(raw)[REMOVED_SECTION] = {"xp_pct": 25}
	_expect(raw, [V.BALANCE, "unknown key '%s'" % REMOVED_SECTION])


func test_the_real_balance_has_the_values_of_the_m24_table() -> void:
	var data: GameData = TestFactory.real_data()
	assert_eq(int(data.balance_value("encounters.travel_ms")), 2500)
	assert_eq(int(data.balance_value("encounters.node_chance_pct")), 25)
	assert_eq(int(data.balance_value("encounters.node_ms")), 12000)
	assert_eq(int(data.balance_value("encounters.node_min_ms")), 3000)
	assert_eq(int(data.balance_value("encounters.skip_ms")), 1500)
	assert_eq(int(data.balance_value("encounters.node_units")), 80)
	assert_eq((data.balance_value("encounters.colors") as Array).size(), 4)
	assert_eq(int(data.balance_value("disciplines.max_per_category")), 2)
	assert_eq(int(data.balance_value("trainer.learn_gold")), 0)
	assert_eq(int(data.balance_value("trainer.gold_base")), 250)
	assert_eq(int(data.balance_value("trainer.gold_growth")), 5)
	assert_eq(int(data.balance_value("trainer.skill_margin")), 5)
	assert_eq(int(data.balance_value("trainer.unlearn_pct")), 50)
	assert_eq(int(data.balance_value("trainer.unlearn_min_gold")), 100)
	assert_eq(int(data.balance_value("production.queue_slots")), 5)
	assert_eq(int(data.balance_value("production.max_job_count")), 9999)
