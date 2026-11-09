extends GutTest
## Reasons: the closed list of docs/05_INTERFACES.md §1 (35 constants of M0-M3 plus the 3 of M4, 4 of M10).


func test_reasons_values_match_their_names() -> void:
	var constants: Dictionary = (Reasons as Script).get_script_constant_map()
	assert_eq(constants.size(), 55, "closed list of docs/05_INTERFACES.md §1")
	for constant_name: String in constants:
		var value: Variant = constants[constant_name]
		assert_typeof(value, TYPE_STRING_NAME, constant_name)
		assert_eq(String(value as StringName), constant_name.to_lower(), constant_name)


func test_m4_reasons() -> void:
	assert_eq(Reasons.ARMORY_FULL, &"armory_full")
	assert_eq(Reasons.NOT_STACKABLE, &"not_stackable")
	assert_eq(Reasons.ITEM_EQUIPPED, &"item_equipped")
	assert_eq(Reasons.SLOT_LOCKED, &"slot_locked")
func test_m7_reasons() -> void:
	assert_eq(Reasons.UPGRADE_MAX, &"upgrade_max")


func test_m13_reasons() -> void:
	assert_eq(Reasons.FRACTURE_ACTIVE, &"fracture_active")
	assert_eq(Reasons.FRACTURE_BAG_PENDING, &"fracture_bag_pending")
	assert_eq(Reasons.NO_FRACTURE, &"no_fracture")
	assert_eq(Reasons.FRACTURE_WON, &"fracture_won")
	assert_eq(Reasons.FRACTURE_ABANDONED, &"fracture_abandoned")


func test_m10_reasons() -> void:
	assert_eq(Reasons.ITEM_UNIQUE, &"item_unique")
	assert_eq(Reasons.NOT_A_TOOL, &"not_a_tool")
	assert_eq(Reasons.INVALID_CHOICE, &"invalid_choice")
	assert_eq(Reasons.BLUEPRINT_DONE, &"blueprint_done")
