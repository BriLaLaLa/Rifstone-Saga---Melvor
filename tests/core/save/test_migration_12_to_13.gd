extends GutTest
## v12 -> v13 (M37-1, docs/05_INTERFACES_M37.md §6i): `auction.history = []` is added; nothing else changes.

const Step := preload("res://core/save/migrations/migration_12_to_13.gd")
const SLOT_V11: String = "res://tests/fixtures/saves/slot_v11.json"


func _v12() -> Dictionary:
	return {"format_version": 12, "player_name": "x", "modules": {"wallet": {"copper": 7}, "auction": {"seed": 5, "block": 3, "items": {}}}}


func test_history_is_added_empty_and_nothing_else_changes() -> void:
	var d: Dictionary = _v12()
	var out: Dictionary = Step.migrate(d)
	var expected: Dictionary = _v12()
	(expected["modules"]["auction"] as Dictionary)["history"] = []
	assert_eq(out, expected)
	assert_false((d["modules"]["auction"] as Dictionary).has("history"), "the input is not changed")


func test_an_existing_history_stays() -> void:
	var d: Dictionary = _v12()
	(d["modules"]["auction"] as Dictionary)["history"] = [{"k": "expired"}]
	assert_eq((Step.migrate(d)["modules"]["auction"] as Dictionary)["history"], [{"k": "expired"}])


func test_auction_or_modules_missing_or_not_an_object_leaves_the_file_as_it_is() -> void:
	assert_eq(Step.migrate({"format_version": 12}), {"format_version": 12})
	assert_eq(Step.migrate({"format_version": 12, "modules": 5}), {"format_version": 12, "modules": 5})
	assert_eq(Step.migrate({"format_version": 12, "modules": {}}), {"format_version": 12, "modules": {}})
	assert_eq(Step.migrate({"format_version": 12, "modules": {"auction": 3}}), {"format_version": 12, "modules": {"auction": 3}})


func test_the_chain_reaches_v13_and_a_real_slot_loads_with_an_empty_history() -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(SLOT_V11))
	var out: Dictionary = SaveMigrator.migrate(raw as Dictionary)
	assert_eq(out["format_version"], 13)
	assert_eq((out["modules"]["auction"] as Dictionary)["history"], [])
	var s: GameSession = autofree(TestFactory.session_no_kit(5, TestFactory.real_data()))
	assert_true(s.from_save(out).ok)
	assert_eq(s.auction.history(), [])
	assert_eq(int(s.to_save(0)["format_version"]), 13)
