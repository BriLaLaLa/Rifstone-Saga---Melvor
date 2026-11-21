extends GutTest
## DataValidatorTutorial (docs/04_DATA_SCHEMA_M30.md §34.6): fixtures and real data are valid; every rejected case of the schema.

const V: String = "res://tests/core/data/test_data_validator.gd"


func _raw() -> Dictionary:
	return load(V).fixture_raw() as Dictionary


func _steps(raw: Dictionary) -> Dictionary:
	return load(V).file_of(raw, "tutorial_steps", "steps.json") as Dictionary


func _quests(raw: Dictionary) -> Dictionary:
	return load(V).file_of(raw, "tutorial_quests", "starter_quests.json") as Dictionary


func _step(raw: Dictionary, index: int) -> Dictionary:
	return (_steps(raw)["steps"] as Array)[index] as Dictionary


func _quest(raw: Dictionary, index: int) -> Dictionary:
	return (_quests(raw)["quests"] as Array)[index] as Dictionary


func _expect(raw: Dictionary, part: String) -> void:
	var errors: PackedStringArray = []
	DataValidator.validate(raw, errors)
	var found: bool = false
	for e: String in errors:
		found = found or e.contains(part)
	assert_true(found, "expected an error with '%s', got %s" % [part, str(errors)])


func test_the_fixtures_are_valid() -> void:
	var errors: PackedStringArray = []
	DataValidator.validate(_raw(), errors)
	assert_eq(errors, PackedStringArray())


func test_the_real_data_is_valid_and_loaded() -> void:
	var data: GameData = TestFactory.real_data()
	assert_gt(data.tutorial_steps().size(), 0)
	assert_gt(data.starter_quests().size(), 0)
	assert_gte(data.tutorial_stuck_ms(), 10000)
	assert_true(data.tutorial_always_open().has(&"guide"))
	assert_not_null(data.tutorial_step(data.tutorial_steps()[0].id))
	assert_null(data.tutorial_step(&"nope"))
	assert_null(data.starter_quest(&"nope"))
	assert_gt(data.starter_groups().size(), 0)


func test_duplicate_step_id() -> void:
	var raw: Dictionary = _raw()
	_step(raw, 1)["id"] = "intro"
	_expect(raw, "duplicate step")


func test_unknown_group() -> void:
	var raw: Dictionary = _raw()
	_quest(raw, 0)["group"] = "nowhere"
	_expect(raw, "unknown group")


func test_group_without_quests() -> void:
	var raw: Dictionary = _raw()
	(_quests(raw)["groups"] as Array).append({"id": "empty", "title": "Empty"})
	_expect(raw, "has no quest")


func test_denied_and_unknown_signals() -> void:
	for name: String in ["combat_hit", "tutorial_completed", "starter_quests_changed", "xp_gained", "no_such_signal"]:
		var raw: Dictionary = _raw()
		((_step(raw, 1)["done_when"] as Dictionary))["signal"] = name
		_expect(raw, "not an allowed EventBus signal")


func test_an_argument_the_signal_does_not_have() -> void:
	var raw: Dictionary = _raw()
	((_step(raw, 1)["done_when"] as Dictionary)["args"] as Dictionary)["nope"] = 1
	_expect(raw, "has no argument 'nope'")


func test_a_comparison_needs_a_numeric_argument() -> void:
	var raw: Dictionary = _raw()
	((_step(raw, 1)["done_when"] as Dictionary))["args"] = {"monster_id": {"gte": 1}}
	_expect(raw, "numeric argument")


func test_a_monster_that_is_in_no_pack() -> void:
	var raw: Dictionary = _raw()
	((_step(raw, 1)["done_when"] as Dictionary))["args"] = {"monster_id": "ghost"}
	_expect(raw, "in no area pack")


func test_ack_in_a_quest() -> void:
	var raw: Dictionary = _raw()
	_quest(raw, 0)["goal"] = {"type": "ack"}
	_expect(raw, "must be one of")


func test_unknown_metric_and_missing_gte() -> void:
	var raw: Dictionary = _raw()
	((_quest(raw, 0)["goal"]) as Dictionary)["metric"] = "gold_total"
	_expect(raw, "unknown metric")
	raw = _raw()
	((_quest(raw, 0)["goal"]) as Dictionary).erase("gte")
	_expect(raw, "gte")


func test_count_zero() -> void:
	var raw: Dictionary = _raw()
	((_quest(raw, 1)["goal"]) as Dictionary)["count"] = 0
	_expect(raw, "count")


func test_reward_with_money_and_items_or_empty() -> void:
	var raw: Dictionary = _raw()
	(_quest(raw, 2)["reward"] as Dictionary)["money"] = 5
	_expect(raw, "cannot be together")
	raw = _raw()
	_quest(raw, 0)["reward"] = {}
	_expect(raw, "is empty")


func test_a_reward_item_that_is_not_sellable_or_is_a_piece() -> void:
	var raw: Dictionary = _raw()
	(((_quest(raw, 2)["reward"] as Dictionary)["items"] as Array)[0] as Dictionary)["item"] = "ghost_item"
	_expect(raw, "unknown item")
	raw = _raw()
	var data: GameData = TestFactory.fixture_data()
	for item: ItemDef in data.items():
		if item.category == &"equipment" or item.category == &"tool":
			(((_quest(raw, 2)["reward"] as Dictionary)["items"] as Array)[0] as Dictionary)["item"] = String(item.id)
			break
	_expect(raw, "forbidden category")


func test_target_of_another_page_and_page_with_argument() -> void:
	var raw: Dictionary = _raw()
	_step(raw, 1)["target"] = "mail.list"
	_expect(raw, "belongs to page")
	raw = _raw()
	_step(raw, 1)["page"] = "skill:forestry"
	_expect(raw, "unknown route")
	raw = _raw()
	_step(raw, 1)["target"] = "nowhere.thing"
	_expect(raw, "unknown target")


func test_last_step_must_be_ack() -> void:
	var raw: Dictionary = _raw()
	(_steps(raw)["steps"] as Array).pop_back()
	_expect(raw, "last step must end with `ack`")


func test_texts_too_long_or_with_braces() -> void:
	var raw: Dictionary = _raw()
	_step(raw, 0)["text"] = "x".repeat(281)
	_expect(raw, "1..280")
	raw = _raw()
	_step(raw, 0)["title"] = "x".repeat(41)
	_expect(raw, "1..40")
	raw = _raw()
	_step(raw, 0)["text"] = "uno {due}"
	_expect(raw, "braces")
	raw = _raw()
	_quest(raw, 0)["description"] = "x".repeat(141)
	_expect(raw, "1..140")


func test_unknown_field() -> void:
	var raw: Dictionary = _raw()
	_step(raw, 0)["colour"] = "red"
	_expect(raw, "unknown field 'colour'")
	raw = _raw()
	_quest(raw, 0)["colour"] = "red"
	_expect(raw, "unknown field 'colour'")


func test_on_enter_with_another_kind_or_both_money_and_items() -> void:
	var raw: Dictionary = _raw()
	((_step(raw, 2)["on_enter"] as Dictionary)["mail"] as Dictionary)["kind"] = "auction_sold"
	_expect(raw, "must be 'tutorial_gift'")
	raw = _raw()
	((_step(raw, 2)["on_enter"] as Dictionary)["mail"] as Dictionary)["items"] = [{"item": "seared_brookfin", "qty": 1}]
	_expect(raw, "not both")


func test_mail_collected_needs_a_gift_before() -> void:
	var raw: Dictionary = _raw()
	(_step(raw, 2) as Dictionary).erase("on_enter")
	_expect(raw, "needs a gift")


func test_stuck_ms_and_routes() -> void:
	var raw: Dictionary = _raw()
	_steps(raw)["stuck_ms"] = 5
	_expect(raw, "stuck_ms")
	raw = _raw()
	_steps(raw)["always_open"] = ["nowhere"]
	_expect(raw, "unknown route")


func test_page_visited_needs_a_route() -> void:
	var raw: Dictionary = _raw()
	_quest(raw, 0)["goal"] = {"type": "metric", "metric": "page_visited", "gte": 1}
	_expect(raw, "needs `arg`")


# --- M31 (docs/M31_RITOCCHI_TUTORIAL.md §2.1, §2.3) ---

func _event_step(raw: Dictionary, signal_name: String, count: int = 0, index: int = 1) -> Dictionary:
	var step: Dictionary = _step(raw, index)
	var cond: Dictionary = {"type": "event", "signal": signal_name}
	if count > 0:
		cond["count"] = count
	step["done_when"] = cond
	return step


func test_valid_new_fields_pass() -> void:
	var raw: Dictionary = _raw()
	var step: Dictionary = _event_step(raw, "monster_killed", 3)
	step["progress_text"] = "Nemici: %d su %d"
	_step(raw, 0)["ack_text"] = "Ok"
	_step(raw, 0)["freeze_combat"] = true
	_event_step(raw, "food_eaten", 0, 2)["wound_hp_pct"] = 30
	var errors: PackedStringArray = []
	DataValidator.validate(raw, errors)
	assert_eq(errors, PackedStringArray())


func test_progress_text_needs_two_placeholders() -> void:
	var raw: Dictionary = _raw()
	_event_step(raw, "monster_killed", 3)["progress_text"] = "Nemici: %d"
	_expect(raw, "exactly two")
	raw = _raw()
	_event_step(raw, "monster_killed", 3)["progress_text"] = "Nemici: %d su %d su %d"
	_expect(raw, "exactly two")


func test_progress_text_needs_a_counted_event_and_a_length() -> void:
	var raw: Dictionary = _raw()
	_step(raw, 0)["progress_text"] = "Passi %d su %d"
	_expect(raw, "count")
	raw = _raw()
	_event_step(raw, "monster_killed", 3)["progress_text"] = "Nemici sconfitti finora in questo scontro: %d su %d"
	_expect(raw, "1..40")


func test_ack_text_needs_ack_and_a_length() -> void:
	var raw: Dictionary = _raw()
	_event_step(raw, "monster_killed", 3)["ack_text"] = "Ok"
	_expect(raw, "'ack_text' needs")
	raw = _raw()
	_step(raw, 0)["ack_text"] = "Va bene, ho capito"
	_expect(raw, "1..12")
	raw = _raw()
	_step(raw, 0)["ack_text"] = ""
	_expect(raw, "1..12")


func test_freeze_combat_needs_ack() -> void:
	var raw: Dictionary = _raw()
	_event_step(raw, "monster_killed", 3)["freeze_combat"] = true
	_expect(raw, "'freeze_combat' needs")


func test_force_node_needs_a_node_started_event() -> void:
	var raw: Dictionary = _raw()
	_event_step(raw, "monster_killed", 3)["force_node"] = true
	_expect(raw, "'force_node' needs")


func test_wound_hp_pct_range_and_food_eaten() -> void:
	var raw: Dictionary = _raw()
	_event_step(raw, "food_eaten")["wound_hp_pct"] = 0
	_expect(raw, "wound_hp_pct")
	raw = _raw()
	_event_step(raw, "food_eaten")["wound_hp_pct"] = 100
	_expect(raw, "wound_hp_pct")
	raw = _raw()
	_event_step(raw, "monster_killed", 3)["wound_hp_pct"] = 30
	_expect(raw, "'wound_hp_pct' needs")


func test_final_reward_is_mandatory() -> void:
	var raw: Dictionary = _raw()
	_quests(raw).erase("final_reward")
	_expect(raw, "'final_reward' is mandatory")


func test_final_reward_rules() -> void:
	var raw: Dictionary = _raw()
	((_quests(raw)["final_reward"] as Dictionary)["reward"] as Dictionary)["money"] = 100
	_expect(raw, "cannot be together")
	raw = _raw()
	var forbidden: String = ""
	for item: ItemDef in TestFactory.fixture_data().items():
		if item.category == &"equipment" or item.category == &"tool":
			forbidden = String(item.id)
			break
	(_quests(raw)["final_reward"] as Dictionary)["reward"] = {"items": [{"item": forbidden, "qty": 1}]}
	_expect(raw, "forbidden category")
	raw = _raw()
	(_quests(raw)["final_reward"] as Dictionary)["reward"] = {"character_xp": 5000}
	_expect(raw, "character_xp")
	raw = _raw()
	(_quests(raw)["final_reward"] as Dictionary)["name"] = ""
	_expect(raw, "'name'")
	raw = _raw()
	(_quests(raw)["final_reward"] as Dictionary)["bonus"] = 1
	_expect(raw, "unknown field")
