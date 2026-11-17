extends GutTest
## M26-06 (docs/01_GDD_M26.md §38.4): a craft quest is a candidate only when the recipe that makes its item is known.

var _session: GameSession


func before_each() -> void:
	_session = TestFactory.session_no_kit(5, TestFactory.real_data())
	add_child_autofree(_session)
	TestFactory.learn_discipline(_session, &"forging")
	TestFactory.set_character_level(_session, 10)
	TestFactory.set_level(_session, &"forging", 10)
	_session.modifiers.set_source(&"test:board", [Modifier.from_dict({"stat": "quest_slots", "value": 1.0, "scope": "global"})])
	_session.quests.new_game()


func _assigned() -> Array[StringName]:
	var ids: Array[StringName] = []
	for slot: int in _session.quests.slot_count():
		ids.append(_session.quests.quest_at(slot))
	return ids


# Every quest the board offers while slot 0 is abandoned and refilled over and over (the cursor goes round the whole file).
func _seen() -> Array[StringName]:
	var seen: Array[StringName] = []
	_session.quests.refill()
	for i: int in 60:
		for id: StringName in _assigned():
			if not seen.has(id):
				seen.append(id)
		_session.quests.abandon(0)
	return seen


func test_craft_quest_of_an_unknown_scheme_is_not_a_candidate() -> void:
	var seen: Array[StringName] = _seen()
	assert_false(seen.has(&"craft_forging_t2"), "forge_ashlead_plate is a scheme not yet known")
	assert_true(seen.has(&"craft_forging_t1"), "the first plate is from the Maestro: its quest stays")


func test_craft_quest_of_a_known_scheme_is_a_candidate() -> void:
	TestFactory.teach_recipes(_session, &"forging")
	assert_true(_seen().has(&"craft_forging_t2"), "the scheme is known: the quest can be assigned")
