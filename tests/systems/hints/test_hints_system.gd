extends GutTest
## HintsSystem (docs/01_GDD.md §14, docs/05_INTERFACES.md §5.15): one hint_triggered per hint and per slot, saved
## as `seen`. Fixture hints in tests/fixtures/data/hints/hints.json (two hints share the trigger player_died).

const SKILL: StringName = &"test_gather"

var _session: GameSession
var _hints: HintsSystem


func before_each() -> void:
	_session = autofree(TestFactory.session())
	_hints = _session.hints
	watch_signals(_session.events)


func _emitted(hint_id: StringName) -> int:
	var count: int = 0
	for params: Variant in (get_signal_parameters_list(_session.events, "hint_triggered")):
		if (params as Array)[0] == hint_id:
			count += 1
	return count


func get_signal_parameters_list(obj: Object, signal_name: String) -> Array:
	var result: Array = []
	for i: int in get_signal_emit_count(obj, signal_name):
		result.append(get_signal_parameters(obj, signal_name, i))
	return result


func test_new_game_has_nothing_seen_and_is_silent() -> void:
	assert_false(_hints.is_seen(&"test_first_action"))
	assert_signal_not_emitted(_session.events, "hint_triggered")
	assert_eq(_hints.to_save(), {"seen": []})


func test_session_started_new_triggers_once() -> void:
	_session.events.session_started.emit(0, true)
	assert_eq(_emitted(&"test_first_action"), 1)
	assert_true(_hints.is_seen(&"test_first_action"))
	_session.events.session_started.emit(0, true)
	assert_eq(_emitted(&"test_first_action"), 1, "once per slot")


func test_session_started_not_new_does_not_trigger() -> void:
	_session.events.session_started.emit(0, false)
	assert_signal_not_emitted(_session.events, "hint_triggered")


func test_bank_full_from_rejected_and_from_stopped_action() -> void:
	_session.events.action_stopped.emit(&"main", SKILL, Reasons.REPLACED)
	assert_signal_not_emitted(_session.events, "hint_triggered")
	_session.events.action_stopped.emit(&"main", SKILL, Reasons.BANK_FULL)
	assert_eq(_emitted(&"test_bank_full"), 1)
	_session.events.bank_rejected.emit(&"rift_shard", 1)
	assert_eq(_emitted(&"test_bank_full"), 1)


func test_bank_rejected_triggers_bank_full() -> void:
	_session.events.bank_rejected.emit(&"rift_shard", 1)
	assert_eq(_emitted(&"test_bank_full"), 1)


func test_first_shard_needs_a_gain_of_the_shard() -> void:
	_session.events.bank_changed.emit(&"rift_shard", 0, -1)
	_session.events.bank_changed.emit(&"gnarled_log", 3, 3)
	assert_signal_not_emitted(_session.events, "hint_triggered")
	assert_true(_session.bank.add(&"rift_shard", 1).ok)
	assert_eq(_emitted(&"test_first_shard"), 1)


func test_mastery_node_affordable_needs_a_buyable_node() -> void:
	_session.events.mastery_pool_changed.emit(SKILL, 0)
	assert_signal_not_emitted(_session.events, "hint_triggered")
	_session.mastery.from_save({SKILL: {"pool": 30000}})
	_session.events.mastery_pool_changed.emit(SKILL, 30000)
	assert_eq(_emitted(&"test_node"), 1)


func test_player_died_triggers_every_hint_of_the_trigger_in_order() -> void:
	_session.events.player_died.emit()
	assert_eq(_emitted(&"test_death"), 1)
	assert_eq(_emitted(&"test_second_death"), 1)
	_session.events.player_died.emit()
	assert_eq(_emitted(&"test_death"), 1)


func test_first_level_10_from_skill_and_from_character() -> void:
	_session.events.level_up.emit(SKILL, 9)
	_session.events.character_level_up.emit(9)
	assert_signal_not_emitted(_session.events, "hint_triggered")
	_session.events.character_level_up.emit(10)
	assert_eq(_emitted(&"test_level_10"), 1)
	_session.events.level_up.emit(SKILL, 10)
	assert_eq(_emitted(&"test_level_10"), 1)


func test_level_up_of_a_real_skill_triggers() -> void:
	TestFactory.set_level(_session, SKILL, 10)
	assert_eq(_emitted(&"test_level_10"), 1)


func test_mark_seen_prevents_the_trigger_and_unknown_is_ignored() -> void:
	_hints.mark_seen(&"test_death")
	_hints.mark_seen(&"test_death")
	_hints.mark_seen(&"nope")
	assert_push_error("unknown hint 'nope'")
	assert_false(_hints.is_seen(&"nope"))
	_session.events.player_died.emit()
	assert_eq(_emitted(&"test_death"), 0)
	assert_eq(_emitted(&"test_second_death"), 1)


func test_connect_triggers_twice_does_not_duplicate() -> void:
	_hints.connect_triggers()
	_session.events.player_died.emit()
	assert_signal_emit_count(_session.events, "hint_triggered", 2, "two hints, one emission each")


func test_save_roundtrip_in_file_order() -> void:
	_hints.mark_seen(&"test_death")
	_hints.mark_seen(&"test_bank_full")
	var saved: Dictionary = _hints.to_save()
	assert_eq(saved, {"seen": ["test_bank_full", "test_death"]})
	var other: GameSession = autofree(TestFactory.session())
	other.hints.from_save(saved)
	assert_true(other.hints.is_seen(&"test_death"))
	assert_true(other.hints.is_seen(&"test_bank_full"))
	assert_false(other.hints.is_seen(&"test_node"))
	watch_signals(other.events)
	other.events.player_died.emit()
	assert_eq(get_signal_emit_count(other.events, "hint_triggered"), 1, "only test_second_death")


func test_from_save_is_tolerant() -> void:
	_hints.from_save({"seen": ["test_death", "gone", 7]})
	assert_true(_hints.is_seen(&"test_death"))
	assert_eq(_hints.to_save(), {"seen": ["test_death"]})
	_hints.from_save({"seen": "x"})
	assert_eq(_hints.to_save(), {"seen": []})
	_hints.from_save({})
	assert_eq(_hints.to_save(), {"seen": []})


func test_new_game_forgets_the_seen_hints() -> void:
	_hints.mark_seen(&"test_death")
	_session.new_game()
	assert_false(_hints.is_seen(&"test_death"))


func test_session_save_has_the_hints_module() -> void:
	_hints.mark_seen(&"test_death")
	var modules: Dictionary = _session.to_save(0)["modules"]
	assert_eq(modules["hints"], {"seen": ["test_death"]})
