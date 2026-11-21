extends GutTest
## Tutorial save (docs/05_INTERFACES_M30.md §5.41, §6g): round trip and tolerant loading, on the fixture steps.


func _new() -> GameSession:
	return autofree(TestFactory.session(1234, null, false, true))


func _json(d: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(d)) as Dictionary


func test_save_load_save_is_identical_in_the_middle_of_a_step() -> void:
	var s: GameSession = _new()
	s.tutorial.acknowledge()
	s.events.monster_killed.emit(0, &"test_monster_a")
	s.events.monster_killed.emit(1, &"test_monster_a")
	s.advance(1500)
	s.tutorial.notify_page_opened(&"character")
	s.tutorial.notify_page_opened(&"combat")
	var first: Dictionary = s.tutorial.to_save()
	assert_eq(first["step"], "kills")
	assert_eq(first["progress"], 2)
	assert_eq(first["visited"], ["character", "combat"])
	var other: GameSession = _new()
	other.play_time_ms = s.play_time_ms
	other.tutorial.from_save(_json(first))
	assert_eq(JSON.stringify(other.tutorial.to_save()), JSON.stringify(first))
	assert_eq(other.tutorial.step_progress(), 2)
	other.events.monster_killed.emit(0, &"test_monster_a")
	assert_eq(other.tutorial.current_step().id, &"mail", "the count goes on after the load")


func test_a_load_sends_no_signal_and_no_gift() -> void:
	var s: GameSession = _new()
	s.tutorial.acknowledge()
	s.events.monster_killed.emit(0, &"test_monster_a")
	s.events.monster_killed.emit(0, &"test_monster_a")
	s.events.monster_killed.emit(0, &"test_monster_a")
	var saved: Dictionary = s.tutorial.to_save()
	var other: GameSession = _new()
	watch_signals(other.events)
	other.tutorial.from_save(saved)
	assert_signal_not_emitted(other.events, "tutorial_step_changed")
	assert_signal_not_emitted(other.events, "tutorial_completed")
	assert_eq(other.mail.count(), 0)


func test_the_whole_slot_round_trips() -> void:
	var s: GameSession = _new()
	s.tutorial.acknowledge()
	s.advance(300)
	var other: GameSession = autofree(TestFactory.session(1234, null, false, true))
	assert_true(other.from_save(_json(s.to_save(0))).ok)
	assert_eq(JSON.stringify(other.to_save(0)), JSON.stringify(s.to_save(0)))
	assert_eq(other.tutorial.current_step().id, &"kills")


func test_a_completed_tutorial_saves_the_short_form() -> void:
	var s: GameSession = autofree(TestFactory.session())
	s.tutorial.notify_page_opened(&"guide")
	var saved: Dictionary = s.tutorial.to_save()
	assert_eq(saved["completed"], true)
	assert_eq(saved["step"], "")
	assert_eq(saved["progress"], 0)
	assert_eq(saved["since_ms"], 0)
	assert_eq(saved["visited"], ["guide"])
	assert_eq(saved["starter"], {"claimed": [], "progress": {}, "final_claimed": false})


func test_a_completed_save_activates_the_starter_quests() -> void:
	var s: GameSession = _new()
	s.tutorial.from_save({"completed": true, "step": "", "visited": [], "starter": {"claimed": ["kill_two"], "progress": {"eat_once": 1}}})
	assert_true(s.tutorial.starter.is_enabled())
	assert_true(s.tutorial.starter.is_claimed(&"kill_two"))
	assert_true(s.tutorial.starter.is_complete(&"eat_once"))


func test_tolerance_unknown_step_means_completed() -> void:
	var s: GameSession = _new()
	s.tutorial.from_save({"completed": false, "step": "no_such_step"})
	assert_true(s.tutorial.is_completed())
	s.tutorial.from_save({"completed": false})
	assert_true(s.tutorial.is_completed())


func test_tolerance_bad_completed_means_completed() -> void:
	var s: GameSession = _new()
	s.tutorial.from_save({"completed": "no", "step": "kills"})
	assert_true(s.tutorial.is_completed())
	s.tutorial.from_save({})
	assert_true(s.tutorial.is_completed())


func test_tolerance_progress_since_and_visited() -> void:
	var s: GameSession = _new()
	s.advance(5000)
	s.tutorial.from_save({"completed": false, "step": "kills", "progress": 99, "since_ms": 999999999, "visited": ["bank", "nowhere", "bank", 3]})
	assert_eq(s.tutorial.step_progress(), 3, "capped to count")
	assert_false(s.tutorial.can_skip_step(), "since_ms above play_time_ms restarts the valve clock")
	s.advance(s.data.tutorial_stuck_ms())
	assert_true(s.tutorial.can_skip_step())
	assert_eq(s.tutorial.to_save()["visited"], ["bank"])
	s.tutorial.from_save({"completed": false, "step": "kills", "progress": -4, "since_ms": -1})
	assert_eq(s.tutorial.step_progress(), 0)
	s.tutorial.from_save({"completed": false, "step": "kills", "progress": "x", "since_ms": "y"})
	assert_eq(s.tutorial.step_progress(), 0)


func test_starter_tolerance() -> void:
	var s: GameSession = _new()
	s.tutorial.from_save({"completed": true, "starter": {"claimed": ["kill_two", "ghost"], "progress": {"eat_once": 5, "reach_level_2": 1, "ghost": 2, "kill_two": 1, "x": "y"}}})
	var saved: Dictionary = s.tutorial.to_save()["starter"]
	assert_eq(saved["claimed"], ["kill_two"])
	assert_eq(saved["progress"], {"eat_once": 1}, "values capped to count; non-event, claimed, unknown or non-integer progress dropped")
	s.tutorial.from_save({"completed": true, "starter": {"claimed": "x", "progress": []}})
	assert_eq(s.tutorial.to_save()["starter"], {"claimed": [], "progress": {}, "final_claimed": false})
