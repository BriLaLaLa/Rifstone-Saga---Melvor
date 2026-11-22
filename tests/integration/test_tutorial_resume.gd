extends GutTest
## M30-05: save and reload at every step of the tutorial (also in the middle of a `count`): same step, same progress, same visited
## pages; the tutorial goes on to the end. A real v11 slot migrates to a completed tutorial with the starter quests on
## (docs/05_INTERFACES_M30.md §5.41, §6g; docs/01_GDD_M30.md §41.9). Slots are never touched: the save goes through a dictionary.

const Play := preload("res://tests/integration/test_tutorial_playthrough.gd")
const AREA: StringName = &"redrock_plains"
const TICK_MS: int = 100
const MAX_TICKS: int = 60000
const SLOT_V11: String = "res://tests/fixtures/saves/slot_v11.json"


## The slot file as written to disk and read back (JSON round trip), then migrated and loaded in a new session. The old one is freed.
func _reload(old: GameSession) -> GameSession:
	var text: String = JSON.stringify(old.to_save(1_700_000_000_000))
	var parsed: Variant = JSON.parse_string(text)
	assert_true(parsed is Dictionary, "the save is valid JSON")
	var d: Dictionary = SaveMigrator.migrate(parsed as Dictionary)
	var events: GameEvents = GameEvents.new()
	var s: GameSession = GameSession.new(TestFactory.real_data(), events, 1)
	s.add_child(events)
	var result: CommandResult = s.from_save(d)
	assert_true(result.ok, "the slot loads")
	old.free()
	return s


func _same_tutorial(a: Dictionary, b: Dictionary, what: String) -> void:
	for key: String in ["completed", "step", "progress", "visited"]:
		assert_eq(b.get(key), a.get(key), "%s: %s" % [what, key])


func _tut(s: GameSession) -> Dictionary:
	return (s.to_save(0)["modules"] as Dictionary)["tutorial"]


func _advance_until(s: GameSession, done: Callable) -> void:
	var ticks: int = 0
	while not done.call() and ticks < MAX_TICKS:
		if not s.combat.is_active():
			s.combat.start(AREA)
		s.advance(TICK_MS)
		ticks += 1
	assert_lt(ticks, MAX_TICKS, "the step ended")


func _act(s: GameSession, id: StringName) -> void:
	var index: int = s.tutorial.step_index()
	match id:
		&"equipment":
			for inst: ItemInstance in s.armory.instances():
				if inst.base_id == &"emberbronze_greatsword":
					assert_true(s.equipment.equip(inst.uid).ok)
		&"combat_start":
			assert_true(s.combat.start(AREA).ok)
		&"combat_kills", &"combat_eat", &"nodes":
			_advance_until(s, func() -> bool: return s.tutorial.step_index() != index)
		&"trainers":
			assert_true(s.disciplines.learn(&"forestry").ok)
		&"mail":
			for message: Dictionary in s.mail.messages():
				if s.mail.collect(int(message["id"])).ok:
					break
		_:
			s.tutorial.notify_page_opened(s.tutorial.current_step().page)
			assert_true(s.tutorial.acknowledge().ok)


func test_save_and_reload_at_every_step_keeps_the_step_and_goes_on_to_the_end() -> void:
	var s: GameSession = Play.new_game_session(3006)
	var steps: Array[TutorialStepDef] = s.data.tutorial_steps()
	for i: int in steps.size():
		var before: Dictionary = _tut(s)
		s = _reload(s)
		assert_eq(s.tutorial.step_index(), i, "reloaded at step %d (%s)" % [i + 1, steps[i].id])
		_same_tutorial(before, _tut(s), "step %d" % (i + 1))
		assert_true(s.tutorial.is_active())
		assert_eq(s.tutorial.can_acknowledge(), steps[i].done_when.size() > 0 and steps[i].done_when[0].type == &"ack")
		_act(s, steps[i].id)
	assert_true(s.tutorial.is_completed(), "the tutorial reaches the end through the reloads")
	assert_true(s.tutorial.starter.is_enabled())
	s = _reload(s)
	assert_true(s.tutorial.is_completed(), "and stays completed after a reload")
	assert_eq(s.tutorial.starter.total(), 21)
	s.free()


func test_a_reload_in_the_middle_of_the_three_kills_keeps_the_count() -> void:
	var s: GameSession = Play.new_game_session(3007)
	for id: StringName in [&"welcome", &"character", &"equipment", &"combat_start"]:
		_act(s, id)
	assert_eq(s.tutorial.current_step().id, &"combat_kills")
	assert_eq(s.tutorial.step_target_count(), 3)
	_advance_until(s, func() -> bool: return s.tutorial.step_progress() >= 1)
	var progress: int = s.tutorial.step_progress()
	assert_between(progress, 1, 2, "stopped in the middle of the count")
	s = _reload(s)
	assert_eq(s.tutorial.current_step().id, &"combat_kills")
	assert_eq(s.tutorial.step_progress(), progress, "same progress after the reload")
	s.combat.start(AREA)
	_advance_until(s, func() -> bool: return s.tutorial.current_step().id != &"combat_kills")
	assert_eq(s.tutorial.current_step().id, &"combat_triangle", "the remaining kills finish the step")
	s.free()


func test_the_valve_clock_survives_the_reload() -> void:
	var s: GameSession = Play.new_game_session(3008)
	s.tutorial.acknowledge()
	s.tutorial.acknowledge()
	s.play_time_ms += s.data.tutorial_stuck_ms() - 1000
	assert_false(s.tutorial.can_skip_step())
	s = _reload(s)
	assert_false(s.tutorial.can_skip_step(), "not stuck yet after the reload")
	s.play_time_ms += 1000
	assert_true(s.tutorial.can_skip_step(), "the time kept running from where it was")
	s.free()


func test_a_real_v11_slot_migrates_to_a_completed_tutorial_with_the_starter_quests_on() -> void:
	var text: String = FileAccess.get_file_as_string(SLOT_V11)
	assert_false(text.is_empty())
	var parsed: Variant = JSON.parse_string(text)
	assert_true(parsed is Dictionary)
	assert_eq(int((parsed as Dictionary)["format_version"]), 11)
	var d: Dictionary = SaveMigrator.migrate(parsed as Dictionary)
	assert_eq(int(d["format_version"]), 12)
	var events: GameEvents = GameEvents.new()
	var s: GameSession = autofree(GameSession.new(TestFactory.real_data(), events, 1))
	s.add_child(events)
	assert_true(s.from_save(d).ok)
	assert_true(s.tutorial.is_completed(), "who already plays never sees the tutorial")
	assert_false(s.tutorial.is_active())
	assert_null(s.tutorial.current_step())
	assert_true(s.tutorial.starter.is_enabled(), "the starter quests are on")
	assert_eq(s.tutorial.starter.total(), 21)
	assert_true(s.tutorial.is_page_open(&"fractures"), "every page is open")
	assert_false(s.tutorial.has_visited(&"guide"), "the visits start empty in a migrated slot")


func test_an_unreadable_or_unknown_tutorial_state_means_completed() -> void:
	var s: GameSession = Play.new_game_session(3009)
	for bad: Variant in [{"completed": false, "step": "no_such_step"}, {"completed": "yes"}, {"step": 4}, {}]:
		s.tutorial.from_save(bad as Dictionary)
		assert_true(s.tutorial.is_completed(), "never trapped by %s" % str(bad))
	s.free()
