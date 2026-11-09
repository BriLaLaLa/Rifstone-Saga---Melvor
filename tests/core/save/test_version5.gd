extends GutTest
## Save format v5 (M14, F-124): the `discoveries` module; a v4 save does not load (`version_unsupported`, no migration).


func test_current_version_is_5_and_the_save_has_the_discoveries_module() -> void:
	var s: GameSession = autofree(TestFactory.session_no_kit(1, TestFactory.real_data()))
	var saved: Dictionary = s.to_save(1)
	assert_eq(SaveMigrator.CURRENT_VERSION, 5)
	assert_eq(saved["format_version"], 5)
	assert_true((saved["modules"] as Dictionary).has("discoveries"))
	assert_true(((saved["modules"] as Dictionary)["discoveries"] as Dictionary).has("items"))


func test_a_v4_save_is_unsupported() -> void:
	var s: GameSession = autofree(TestFactory.session_no_kit(1, TestFactory.real_data()))
	var saved: Dictionary = s.to_save(1)
	saved["format_version"] = 4
	assert_eq(SaveMigrator.migrate(saved), {}, "there is no migration_4_to_5.gd")
	var result: CommandResult = autofree(TestFactory.session_no_kit(2, TestFactory.real_data())).from_save(saved)
	assert_false(result.ok)
	assert_eq(result.reason, Reasons.VERSION_UNSUPPORTED)


func test_a_v5_save_without_the_module_starts_with_the_kit_only() -> void:
	var s: GameSession = autofree(TestFactory.session_no_kit(1, TestFactory.real_data()))
	var kit: Array[StringName] = s.discoveries.items()
	var saved: Dictionary = s.to_save(1)
	(saved["modules"] as Dictionary).erase("discoveries")
	var other: GameSession = autofree(TestFactory.session_no_kit(2, TestFactory.real_data()))
	assert_true(other.from_save(saved).ok)
	assert_eq(other.discoveries.items(), kit)
