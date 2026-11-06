extends GutTest
## Reasons: the closed list of docs/05_INTERFACES.md §1 (35 constants of M0-M3 plus the 3 of M4).


func test_reasons_values_match_their_names() -> void:
	var constants: Dictionary = (Reasons as Script).get_script_constant_map()
	assert_eq(constants.size(), 39, "closed list of docs/05_INTERFACES.md §1")
	for constant_name: String in constants:
		var value: Variant = constants[constant_name]
		assert_typeof(value, TYPE_STRING_NAME, constant_name)
		assert_eq(String(value as StringName), constant_name.to_lower(), constant_name)


func test_m4_reasons() -> void:
	assert_eq(Reasons.ARMORY_FULL, &"armory_full")
	assert_eq(Reasons.NOT_STACKABLE, &"not_stackable")
	assert_eq(Reasons.ITEM_EQUIPPED, &"item_equipped")
	assert_eq(Reasons.SLOT_LOCKED, &"slot_locked")
