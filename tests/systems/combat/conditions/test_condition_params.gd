extends GutTest
## docs/04_DATA_SCHEMA_M28.md §33.1-§33.2: `combat.conditions` of balance.json (the validator and `ConditionParams`) and the
## application of a condition (`ConditionApply.from_dict`).


func _errors(conditions: Variant) -> PackedStringArray:
	var v := DataValidatorRules.new()
	DataValidatorConditions.validate_balance(v, {"combat": {"conditions": conditions}})
	return v.errors


func test_the_real_balance_has_the_section_and_it_is_valid() -> void:
	var params: ConditionParams = TestFactory.real_data().conditions()
	assert_not_null(params)
	assert_eq([params.tick_ms, params.stagger_immunity_ms], [1000, 4000])


func test_valid_values() -> void:
	assert_eq(_errors({"tick_ms": 1000, "stagger_immunity_ms": 4000}), PackedStringArray())
	assert_eq(_errors({"tick_ms": 100, "stagger_immunity_ms": 0}), PackedStringArray(), "the limits are in")


func test_the_limits_of_format() -> void:
	assert_false(_errors({"tick_ms": 99, "stagger_immunity_ms": 4000}).is_empty())
	assert_false(_errors({"tick_ms": 10001, "stagger_immunity_ms": 4000}).is_empty())
	assert_false(_errors({"tick_ms": 1000, "stagger_immunity_ms": -1}).is_empty())
	assert_false(_errors({"tick_ms": 1000, "stagger_immunity_ms": 60001}).is_empty())
	assert_false(_errors({"tick_ms": 1000.5, "stagger_immunity_ms": 4000}).is_empty(), "an integer")


func test_both_keys_are_required_and_nothing_else_is_allowed() -> void:
	assert_false(_errors({"tick_ms": 1000}).is_empty())
	assert_false(_errors({"stagger_immunity_ms": 4000}).is_empty())
	assert_false(_errors({"tick_ms": 1000, "stagger_immunity_ms": 4000, "extra": 1}).is_empty())
	assert_false(_errors("x").is_empty())


func test_a_balance_without_the_section_is_rejected() -> void:
	var v := DataValidatorRules.new()
	DataValidatorConditions.validate_balance(v, {"combat": {}})
	assert_false(v.errors.is_empty())


func test_condition_apply_rejects_malformed_entries() -> void:
	assert_null(ConditionApply.from_dict({"condition": "sleep", "pct": 10, "ms": 1000}), "unknown condition")
	assert_null(ConditionApply.from_dict({"condition": "bleed", "ms": 1000}), "a Bleed needs pct")
	assert_null(ConditionApply.from_dict({"condition": "weaken", "pct": 10}), "and ms")
	assert_null(ConditionApply.from_dict({"condition": "expose", "pct": "x", "ms": 1000}))
	assert_push_error(4)  # one error logged for each of the four
	assert_not_null(ConditionApply.from_dict({"condition": "stagger", "ms": 1000}))
