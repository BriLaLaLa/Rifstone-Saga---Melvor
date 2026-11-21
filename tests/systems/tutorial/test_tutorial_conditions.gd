extends GutTest
## TutorialConditions (docs/04_DATA_SCHEMA_M30.md §34.2): the argument filter and the signal argument names read from the script.

const NAMES: PackedStringArray = ["monster_id", "index", "grade"]


func test_empty_filter_is_true() -> void:
	assert_true(TutorialConditions.matches({}, NAMES, [&"a", 1, 2]))


func test_scalar_is_equal_with_string_and_stringname() -> void:
	assert_true(TutorialConditions.matches({"monster_id": "ember_rat"}, NAMES, [&"ember_rat", 1, 2]))
	assert_false(TutorialConditions.matches({"monster_id": "ember_rat"}, NAMES, [&"other", 1, 2]))
	assert_true(TutorialConditions.matches({"grade": 2.0}, NAMES, [&"a", 1, 2]), "JSON numbers are floats")
	assert_false(TutorialConditions.matches({"grade": 3}, NAMES, [&"a", 1, 2]))


func test_array_means_any_of() -> void:
	assert_true(TutorialConditions.matches({"monster_id": ["x", "ember_rat"]}, NAMES, [&"ember_rat", 1, 2]))
	assert_false(TutorialConditions.matches({"monster_id": ["x", "y"]}, NAMES, [&"ember_rat", 1, 2]))
	assert_false(TutorialConditions.matches({"monster_id": []}, NAMES, [&"ember_rat", 1, 2]))


func test_comparisons() -> void:
	assert_true(TutorialConditions.matches({"index": {"gte": 1}}, NAMES, [&"a", 1, 2]))
	assert_false(TutorialConditions.matches({"index": {"gt": 1}}, NAMES, [&"a", 1, 2]))
	assert_true(TutorialConditions.matches({"index": {"lte": 1}}, NAMES, [&"a", 1, 2]))
	assert_false(TutorialConditions.matches({"index": {"lt": 1}}, NAMES, [&"a", 1, 2]))
	assert_true(TutorialConditions.matches({"grade": {"gte": 1, "lt": 3}}, NAMES, [&"a", 1, 2]), "all keys must hold")
	assert_false(TutorialConditions.matches({"grade": {"gte": 1, "lt": 2}}, NAMES, [&"a", 1, 2]))
	assert_false(TutorialConditions.matches({"monster_id": {"gte": 1}}, NAMES, [&"a", 1, 2]), "a text is not numeric")


func test_all_keys_must_match_and_an_unknown_name_never_does() -> void:
	assert_true(TutorialConditions.matches({"monster_id": "a", "grade": 2}, NAMES, [&"a", 1, 2]))
	assert_false(TutorialConditions.matches({"monster_id": "a", "grade": 9}, NAMES, [&"a", 1, 2]))
	assert_false(TutorialConditions.matches({"nope": 1}, NAMES, [&"a", 1, 2]))


func test_argument_names_come_from_the_script() -> void:
	var events: GameEvents = autofree(GameEvents.new())
	assert_eq(TutorialConditions.signal_arg_names(events, &"monster_killed"), PackedStringArray(["index", "monster_id"]))
	assert_eq(TutorialConditions.signal_arg_names(events, &"equipment_changed"), PackedStringArray(["slot_id", "uid"]))
	assert_eq(TutorialConditions.signal_arg_names(events, &"player_died").size(), 0)


func test_an_unknown_signal_gives_no_names_and_an_error() -> void:
	var events: GameEvents = autofree(GameEvents.new())
	assert_eq(TutorialConditions.signal_arg_names(events, &"no_such_signal").size(), 0)
	assert_push_error("unknown signal")


func test_every_signal_used_by_the_real_data_exists_with_its_filter_names() -> void:
	var data: GameData = TestFactory.real_data()
	var signals: Dictionary = TutorialConditions.script_signals()
	var conditions: Array[TutorialCondition] = []
	for step: TutorialStepDef in data.tutorial_steps():
		conditions.append_array(step.done_when)
	for quest: StarterQuestDef in data.starter_quests():
		conditions.append(quest.goal)
	var events: GameEvents = autofree(GameEvents.new())
	for c: TutorialCondition in conditions:
		if c.type != TutorialCondition.TYPE_EVENT:
			continue
		assert_true(signals.has(c.signal_name), String(c.signal_name))
		var names: PackedStringArray = TutorialConditions.signal_arg_names(events, c.signal_name)
		for key: Variant in c.args:
			assert_true(names.has(str(key)), "%s.%s" % [c.signal_name, key])
