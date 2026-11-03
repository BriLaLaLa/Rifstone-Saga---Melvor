extends GutTest
## SaveMigrator: version check and migration chain.
##
## CURRENT_VERSION is 2 and there is no real migration (a v1 save is unsupported), so the chain is driven through migrate_chain
## with fake steps defined here and targets above CURRENT_VERSION.


class FakeSteps:
	static func from_1_to_2(d: Dictionary) -> Dictionary:
		var out: Dictionary = d.duplicate(true)
		out["order"] = (out.get("order", "") as String) + "1>2;"
		out["coins"] = out.get("gold", 0)
		out.erase("gold")
		return out

	static func from_2_to_3(d: Dictionary) -> Dictionary:
		var out: Dictionary = d.duplicate(true)
		out["order"] = (out.get("order", "") as String) + "2>3;"
		out["seen_v2"] = int(out.get("format_version", 0)) == 2
		return out

	static func broken(_d: Dictionary) -> Dictionary:
		return {}


func _all_steps(from_version: int) -> Callable:
	match from_version:
		1:
			return Callable(FakeSteps, &"from_1_to_2")
		2:
			return Callable(FakeSteps, &"from_2_to_3")
	return Callable()


func _only_first_step(from_version: int) -> Callable:
	if from_version == 1:
		return Callable(FakeSteps, &"from_1_to_2")
	return Callable()


func _broken_step(_from_version: int) -> Callable:
	return Callable(FakeSteps, &"broken")


func test_current_version_is_two() -> void:
	assert_eq(SaveMigrator.CURRENT_VERSION, 2)


func test_can_load_current_version() -> void:
	assert_true(SaveMigrator.can_load({"format_version": 2}))
	assert_true(SaveMigrator.can_load({"format_version": 2.0}), "JSON numbers arrive as float")


func test_can_load_rejects_newer_version() -> void:
	assert_false(SaveMigrator.can_load({"format_version": 3}))
	assert_false(SaveMigrator.can_load({"format_version": 3.0}))


func test_can_load_rejects_missing_or_invalid_version() -> void:
	assert_false(SaveMigrator.can_load({}))
	assert_false(SaveMigrator.can_load({"format_version": "2"}))
	assert_false(SaveMigrator.can_load({"format_version": 2.5}))


func test_migrate_current_version_returns_equal_copy() -> void:
	var d: Dictionary = {"format_version": 2, "modules": {"wallet": {"gold": 5}}}
	var out: Dictionary = SaveMigrator.migrate(d)
	assert_eq(out, d)
	out["modules"]["wallet"]["gold"] = 99
	assert_eq(d["modules"]["wallet"]["gold"], 5, "the input is not shared with the result")


func test_migrate_float_version_becomes_int() -> void:
	var out: Dictionary = SaveMigrator.migrate({"format_version": 2.0})
	assert_typeof(out["format_version"], TYPE_INT)


func test_migrate_newer_version_returns_empty() -> void:
	assert_eq(SaveMigrator.migrate({"format_version": 3}), {})


func test_migrate_without_migration_file_returns_empty() -> void:
	assert_eq(SaveMigrator.migrate({"format_version": 0}), {}, "there is no migration_0_to_1.gd")


func test_migrate_missing_version_returns_empty() -> void:
	assert_eq(SaveMigrator.migrate({"player_name": "x"}), {})


func test_chain_applies_steps_in_order() -> void:
	var out: Dictionary = SaveMigrator.migrate_chain({"format_version": 1, "gold": 7}, 3, _all_steps)
	assert_eq(out["order"], "1>2;2>3;")
	assert_eq(out["coins"], 7)
	assert_false(out.has("gold"))
	assert_true(out["seen_v2"], "the second step sees the version set by the chain after the first")
	assert_eq(out["format_version"], 3, "steps do not set the version themselves")


func test_chain_starts_from_file_version() -> void:
	var out: Dictionary = SaveMigrator.migrate_chain({"format_version": 2}, 3, _all_steps)
	assert_eq(out["order"], "2>3;")
	assert_eq(out["format_version"], 3)


func test_chain_does_not_change_input() -> void:
	var d: Dictionary = {"format_version": 1, "gold": 7}
	SaveMigrator.migrate_chain(d, 3, _all_steps)
	assert_eq(d, {"format_version": 1, "gold": 7})


func test_chain_with_missing_step_returns_empty() -> void:
	assert_eq(SaveMigrator.migrate_chain({"format_version": 1}, 3, _only_first_step), {})


func test_chain_with_failing_step_returns_empty() -> void:
	assert_eq(SaveMigrator.migrate_chain({"format_version": 1}, 2, _broken_step), {})


func test_v1_save_is_loadable_by_header_but_not_migratable() -> void:
	assert_true(SaveMigrator.can_load({"format_version": 1}))
	assert_eq(SaveMigrator.migrate({"format_version": 1}), {}, "there is no migration_1_to_2.gd (D3)")
