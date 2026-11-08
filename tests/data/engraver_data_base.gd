extends GutTest
## Base of the Engraver data tests (M12-04): the validator on a copy of the fixture data, one broken thing per test.

const V: GDScript = preload("res://tests/core/data/test_data_validator.gd")
const ACTIONS: String = "riftbinding.json"
const ITEMS_RUNES: String = "infusions.json"


## The fixture data as `raw`, with the loot table file in it.
func raw() -> Dictionary:
	return V.fixture_raw()


func action(raw_data: Dictionary, index: int) -> Dictionary:
	return V.entry_of(raw_data, "actions", ACTIONS, "actions", index)


func balance(raw_data: Dictionary, section: String) -> Dictionary:
	return V.file_of(raw_data, "balance", V.BALANCE)[section] as Dictionary


func expect(raw_data: Dictionary, fragments: Array[String]) -> void:
	var errors: PackedStringArray = V.validate(raw_data)
	for message: String in errors:
		var matched: bool = true
		for fragment: String in fragments:
			matched = matched and message.contains(fragment)
		if matched:
			assert_true(true)
			return
	fail_test("no error with %s in %s" % [fragments, errors])
