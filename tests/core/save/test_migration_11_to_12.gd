extends GutTest
## v11 -> v12 (M30-02, docs/05_INTERFACES_M30.md §6g): the module `tutorial` is added as completed; nothing else changes.
## Plus the real v11 slot written by the code of main before the change.

const Step := preload("res://core/save/migrations/migration_11_to_12.gd")
const SLOT_V11: String = "res://tests/fixtures/saves/slot_v11.json"
const DONE: Dictionary = {"completed": true, "step": "", "progress": 0, "since_ms": 0, "visited": [], "starter": {"claimed": [], "progress": {}}}


func _v11() -> Dictionary:
	return {"format_version": 11, "player_name": "x", "modules": {"bank": {"stacks": [{"item": "redbirch_log", "count": 5}]}, "mail": {"next_id": 1, "messages": []}}}


func test_the_tutorial_block_is_added_as_completed() -> void:
	var out: Dictionary = Step.migrate(_v11())
	assert_eq((out["modules"] as Dictionary)["tutorial"], DONE)


func test_the_other_modules_are_identical_and_the_input_is_not_changed() -> void:
	var input: Dictionary = _v11()
	var out: Dictionary = Step.migrate(input)
	(out["modules"] as Dictionary).erase("tutorial")
	assert_eq(out, _v11())
	assert_false((input["modules"] as Dictionary).has("tutorial"))


func test_an_existing_tutorial_stays() -> void:
	var d: Dictionary = _v11()
	(d["modules"] as Dictionary)["tutorial"] = {"completed": false, "step": "welcome"}
	assert_eq(((Step.migrate(d)["modules"] as Dictionary)["tutorial"] as Dictionary)["step"], "welcome")


func test_modules_missing_or_not_an_object_leaves_the_file_as_it_is() -> void:
	assert_eq(Step.migrate({"format_version": 11}), {"format_version": 11})
	assert_eq(Step.migrate({"format_version": 11, "modules": 5}), {"format_version": 11, "modules": 5})


func test_the_chain_from_v9_reaches_current_with_the_block() -> void:
	var d: Dictionary = {"format_version": 9, "player_name": "x", "modules": {"wallet": {"gold": 10}}}
	var out: Dictionary = SaveMigrator.migrate(d)
	assert_eq(out["format_version"], 14)
	assert_eq((out["modules"] as Dictionary)["tutorial"], DONE)
	assert_eq(((out["modules"] as Dictionary)["wallet"] as Dictionary)["copper"], 1000)


func test_the_real_v11_slot_loads_with_the_tutorial_completed_and_the_starter_quests_active() -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(SLOT_V11))
	assert_true(raw is Dictionary, "slot_v11.json is readable")
	var v11: Dictionary = raw as Dictionary
	assert_eq(int(v11["format_version"]), 11)
	assert_false((v11["modules"] as Dictionary).has("tutorial"))
	var s: GameSession = autofree(TestFactory.session_no_kit(5, TestFactory.real_data()))
	var result: CommandResult = s.from_save(SaveMigrator.migrate(v11))
	assert_true(result.ok)
	assert_true(s.tutorial.is_completed())
	assert_true(s.tutorial.starter.is_enabled())
	assert_eq(s.bank.get_count(&"redbirch_log"), int(((v11["modules"] as Dictionary)["bank"] as Dictionary)["stacks"][0]["count"]))
	var saved: Dictionary = s.to_save(0)
	assert_eq(saved["format_version"], 14)
	assert_eq(((saved["modules"] as Dictionary)["tutorial"] as Dictionary)["completed"], true)


func test_a_v12_without_the_tutorial_key_is_a_new_game() -> void:
	var s: GameSession = autofree(TestFactory.session(5, TestFactory.real_data()))
	var saved: Dictionary = s.to_save(0)
	(saved["modules"] as Dictionary).erase("tutorial")
	var other: GameSession = autofree(TestFactory.session(6, TestFactory.real_data()))
	assert_true(other.from_save(saved).ok)
	assert_true(other.tutorial.is_active())
	assert_eq(other.tutorial.step_index(), 0)
