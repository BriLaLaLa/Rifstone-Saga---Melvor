extends GutTest
## M35B: the focused gathering is gone (docs/05_INTERFACES_M35B.md §6i): `to_save` writes no `focus`, `from_save` ignores one that a v12 of M35
## carries, and the format stays 12.

const ZoneTables := preload("res://tests/systems/encounters/zone_tables.gd")


func test_to_save_has_no_focus() -> void:
	var s: GameSession = autofree(TestFactory.session_no_kit(1, ZoneTables.data()))
	assert_false(s.disciplines.to_save().has("focus"))
	assert_eq((s.to_save(0)["modules"]["disciplines"] as Dictionary).keys().size(), 3, "learned, recipes, extra")


func test_a_v12_with_the_focus_of_m35_loads_and_loses_it() -> void:
	var s: GameSession = autofree(TestFactory.session_no_kit(1, ZoneTables.data()))
	TestFactory.learn_discipline(s, &"quarrying")
	var saved: Dictionary = SaveCodec.decode(SaveCodec.encode(s.to_save(0)))
	assert_eq(saved["format_version"], 12)
	((saved["modules"] as Dictionary)["disciplines"] as Dictionary)["focus"] = {"quarrying": "quarry_emberbronze", "bogus": 3}
	var loaded: GameSession = autofree(TestFactory.session_no_kit(2, ZoneTables.data()))
	assert_true(loaded.from_save(saved).ok)
	assert_true(loaded.disciplines.is_learned(&"quarrying"))
	assert_false(loaded.disciplines.to_save().has("focus"), "gone at the next save")
	assert_eq(loaded.to_save(0)["format_version"], 12)


func test_the_removed_api_is_gone() -> void:
	var s: GameSession = autofree(TestFactory.session_no_kit(1, ZoneTables.data()))
	assert_false(s.disciplines.has_method("set_focus"))
	assert_false(s.disciplines.has_method("focus_of"))
	assert_false(s.events.has_signal("gather_focus_changed"))
	assert_false(EncounterCycle.new().has_method("worked_action"))
