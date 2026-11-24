extends GutTest
## v13 -> v14 (M38-1, docs/05_INTERFACES_M38.md §6j): `stock` leaves every auction item and `auction.taken = {}` is added.

const Step := preload("res://core/save/migrations/migration_13_to_14.gd")
const SLOT_V11: String = "res://tests/fixtures/saves/slot_v11.json"


func _v13() -> Dictionary:
	return {"format_version": 13, "player_name": "x", "modules": {"wallet": {"copper": 7}, "auction": {
		"seed": 5, "block": 3, "pending_ms": 0, "history": [], "items": {
			"redbirch_grip": {"stock": 400}, "riftite_plate": {"sat": 1000, "stock": 3}, "redbirch_log": {"sat": 20}}}}}


func test_stock_is_removed_taken_is_added_and_nothing_else_changes() -> void:
	var d: Dictionary = _v13()
	var out: Dictionary = Step.migrate(d)
	var expected: Dictionary = _v13()
	var auction: Dictionary = (expected["modules"] as Dictionary)["auction"] as Dictionary
	auction["items"] = {"redbirch_grip": {}, "riftite_plate": {"sat": 1000}, "redbirch_log": {"sat": 20}}
	auction["taken"] = {}
	assert_eq(out, expected)
	assert_true(((d["modules"] as Dictionary)["auction"] as Dictionary)["items"]["redbirch_grip"].has("stock"), "the input is not changed")


func test_an_existing_taken_stays() -> void:
	var d: Dictionary = _v13()
	((d["modules"] as Dictionary)["auction"] as Dictionary)["taken"] = {"redbirch_grip": 5}
	assert_eq((((Step.migrate(d))["modules"] as Dictionary)["auction"] as Dictionary)["taken"], {"redbirch_grip": 5})


func test_auction_or_modules_missing_or_not_an_object_leaves_the_file_as_it_is() -> void:
	assert_eq(Step.migrate({"format_version": 13}), {"format_version": 13})
	assert_eq(Step.migrate({"format_version": 13, "modules": 5}), {"format_version": 13, "modules": 5})
	assert_eq(Step.migrate({"format_version": 13, "modules": {}}), {"format_version": 13, "modules": {}})
	assert_eq(Step.migrate({"format_version": 13, "modules": {"auction": 3}}), {"format_version": 13, "modules": {"auction": 3}})
	var odd: Dictionary = {"format_version": 13, "modules": {"auction": {"items": [1], "seed": 4}}}
	assert_eq(((Step.migrate(odd)["modules"] as Dictionary)["auction"] as Dictionary)["items"], [1], "items not an object: untouched")


func test_a_real_v13_save_loads_with_no_taken_and_the_same_prices() -> void:
	var s: GameSession = autofree(TestFactory.session_no_kit(5, TestFactory.real_data()))
	s.auction.advance(3 * 3600000)
	var v14: Dictionary = s.to_save(0)
	# the v13 file of the same game: format 13, a stock on an item, no taken
	var v13: Dictionary = SaveCodec.decode(SaveCodec.encode(v14))
	v13["format_version"] = 13
	var auction: Dictionary = (v13["modules"] as Dictionary)["auction"] as Dictionary
	auction.erase("taken")
	(auction["items"] as Dictionary)["riftite_plate"] = {"stock": 3}
	var out: Dictionary = SaveMigrator.migrate(v13)
	assert_eq(out["format_version"], 14)
	var other: GameSession = autofree(TestFactory.session_no_kit(6, TestFactory.real_data()))
	assert_true(other.from_save(out).ok)
	assert_eq(other.auction.to_save()["taken"], {})
	assert_eq(other.auction.available(&"riftite_plate"), s.auction.available(&"riftite_plate"), "the old stock is not taken")
	assert_eq(other.auction.buy_unit(&"riftite_plate"), s.auction.buy_unit(&"riftite_plate"))
	assert_eq(int(other.to_save(0)["format_version"]), 14)


func test_the_chain_reaches_v14_from_a_v11_slot() -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(SLOT_V11))
	var out: Dictionary = SaveMigrator.migrate(raw as Dictionary)
	assert_eq(out["format_version"], 14)
	assert_eq((out["modules"]["auction"] as Dictionary)["taken"], {})
	var s: GameSession = autofree(TestFactory.session_no_kit(5, TestFactory.real_data()))
	assert_true(s.from_save(out).ok)
	assert_eq(SaveMigrator.CURRENT_VERSION, 14)
	assert_eq(int(s.to_save(0)["format_version"]), 14)


func test_a_new_game_saves_an_empty_taken() -> void:
	var s: GameSession = autofree(TestFactory.session_no_kit(5, TestFactory.real_data()))
	assert_eq((s.to_save(0)["modules"]["auction"] as Dictionary)["taken"], {})
