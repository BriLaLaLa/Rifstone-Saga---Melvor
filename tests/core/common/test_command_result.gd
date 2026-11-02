extends GutTest
## CommandResult: success and failure constructors.


func test_success_is_ok_without_reason() -> void:
	var result: CommandResult = CommandResult.success()
	assert_true(result.ok)
	assert_eq(result.reason, &"")


func test_fail_keeps_reason() -> void:
	var result: CommandResult = CommandResult.fail(Reasons.BANK_FULL)
	assert_false(result.ok)
	assert_eq(result.reason, &"bank_full")


func test_fail_with_empty_reason_is_a_programming_error() -> void:
	var result: CommandResult = CommandResult.fail(&"")
	assert_false(result.ok)
	assert_push_error(1)


func test_each_call_returns_a_new_instance() -> void:
	assert_ne(CommandResult.success(), CommandResult.success())
	assert_ne(CommandResult.fail(Reasons.IO_ERROR), CommandResult.fail(Reasons.IO_ERROR))


func test_reasons_values_match_their_names() -> void:
	var constants: Dictionary = (Reasons as Script).get_script_constant_map()
	assert_eq(constants.size(), 35, "closed list of docs/05_INTERFACES.md §1")
	for constant_name: String in constants:
		var value: Variant = constants[constant_name]
		assert_typeof(value, TYPE_STRING_NAME, constant_name)
		assert_eq(String(value as StringName), constant_name.to_lower(), constant_name)
