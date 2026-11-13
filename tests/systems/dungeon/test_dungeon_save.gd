extends GutTest
## The save of the dungeon (docs/05_INTERFACES.md §5.29 and §6): round trip in the middle of a run (the map is rebuilt from the
## seed, the run is always paused after loading), a tolerant `from_save` (a bad run is dropped with its bag, a bad `pending` or
## `wins` is emptied), additive (a missing key = no run), and the same through a whole session file.

var _s: GameSession = null
var _engine: DungeonEngineDouble = null


func before_each() -> void:
	_s = autofree(TestFactory.session(41))
	_engine = DungeonEngineDouble.attach(_s)


func _through_json(d: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(d))


func _fresh() -> GameSession:
	return autofree(TestFactory.session(42))


func _kinds(map: DungeonMap) -> Array:
	var kinds: Array = []
	for layer: int in map.layers():
		for k: int in map.width(layer):
			var room: DungeonRoom = map.room(layer, k)
			kinds.append([layer, k, room.kind, room.trap_kind, room.hint, room.exits, room.x])
	return kinds


func test_a_run_in_the_middle_comes_back_paused_with_the_same_map() -> void:
	_engine.open_and_clear_entrance()
	_s.dungeon.choose(0)
	_s.dungeon.run().bag.add_stack(&"test_log", 3)
	var saved: Dictionary = _through_json(_s.dungeon.to_save())
	var twin: GameSession = _fresh()
	twin.dungeon.from_save(saved)
	var a: DungeonRun = _s.dungeon.run()
	var b: DungeonRun = twin.dungeon.run()
	assert_not_null(b)
	assert_eq([b.dungeon_id, b.seed_value, b.layer, b.index, b.phase, b.stage, b.cleared, b.return_area],
			[a.dungeon_id, a.seed_value, a.layer, a.index, a.phase, a.stage, a.cleared, a.return_area])
	assert_eq(b.path, a.path)
	assert_eq(_kinds(b.map), _kinds(a.map), "the map comes from the seed")
	assert_eq(b.bag.stacks(), a.bag.stacks())
	assert_true(b.paused, "always paused after loading")


func test_a_run_saved_unpaused_is_still_loaded_paused() -> void:
	_s.dungeon.open(&"test_den")
	assert_false(_s.dungeon.to_save()["run"]["paused"])
	var twin: GameSession = _fresh()
	twin.dungeon.from_save(_through_json(_s.dungeon.to_save()))
	assert_true(twin.dungeon.run().paused)


func test_the_loaded_run_waits_for_resume_and_goes_on() -> void:
	_engine.open_and_clear_entrance()
	var twin: GameSession = _fresh()
	var twin_engine: DungeonEngineDouble = DungeonEngineDouble.attach(twin)
	twin.dungeon.from_save(_through_json(_s.dungeon.to_save()))
	var fired: Array = []
	twin.events.dungeon_paused_changed.connect(func(p: bool) -> void: fired.append(p))
	assert_eq(twin.dungeon.choose(0).reason, Reasons.DUNGEON_PAUSED)
	assert_true(twin.dungeon.resume().ok)
	assert_eq(fired, [false])
	assert_true(twin.dungeon.choose(0).ok)
	assert_eq(twin_engine.rooms.size() + (1 if twin.dungeon.run().phase == &"event" else 0), 1)


func test_a_boss_in_the_middle_of_its_scene_comes_back_in_the_scene() -> void:
	_engine.open_and_clear_entrance()
	_engine.walk_to_boss()
	_engine.end_intro()
	_engine.clear_stage()
	var twin: GameSession = _fresh()
	twin.dungeon.from_save(_through_json(_s.dungeon.to_save()))
	var run: DungeonRun = twin.dungeon.run()
	assert_eq([run.stage, run.phase, run.layer], [2, &"intro", 6])


func test_pending_and_wins_round_trip() -> void:
	_s.dungeon.from_save({"pending": {"stacks": [{"item": "test_log", "qty": 4}], "pieces": [], "cards": []},
			"wins": {"test_den": 3}})
	assert_eq(_s.dungeon.wins(&"test_den"), 3)
	assert_eq(_s.dungeon.pending()["stacks"], [{"item": &"test_log", "qty": 4}])
	var twin: GameSession = _fresh()
	twin.dungeon.from_save(_through_json(_s.dungeon.to_save()))
	assert_eq(twin.dungeon.wins(), 3)
	assert_true(twin.dungeon.has_pending())
	assert_false(twin.dungeon.is_active())


func test_a_missing_key_is_no_run() -> void:
	_s.dungeon.open(&"test_den")
	_s.dungeon.from_save({})
	assert_false(_s.dungeon.is_active())
	assert_false(_s.dungeon.has_pending())
	assert_eq(_s.dungeon.wins(), 0)
	assert_eq(_s.dungeon.to_save(), {"run": {}, "pending": {}, "wins": {}})


func test_a_bad_run_is_dropped_with_its_bag() -> void:
	_engine.open_and_clear_entrance()
	_s.dungeon.run().bag.add_stack(&"test_log", 3)
	var good: Dictionary = _through_json(_s.dungeon.to_save()["run"])
	var bad_cases: Array[Dictionary] = [
		{"dungeon": "nope"}, {"seed": 0}, {"seed": "x"}, {"phase": "dancing"}, {"layer": 9}, {"layer": -1},
		{"stage": 1}, {"stage": 9}, {"phase": "intro"}, {"phase": "event"}, {"index": 99}, {"cleared": "a"}]
	for change: Dictionary in bad_cases:
		var d: Dictionary = good.duplicate(true)
		d.merge(change, true)
		_s.dungeon.from_save({"run": d})
		assert_false(_s.dungeon.is_active(), "dropped: %s" % str(change))
		assert_false(_s.dungeon.has_pending())
	_s.dungeon.from_save({"run": good})
	assert_true(_s.dungeon.is_active(), "the good one loads")


func test_malformed_pending_and_wins_are_emptied() -> void:
	_s.dungeon.from_save({"pending": "x", "wins": [1, 2]})
	assert_false(_s.dungeon.has_pending())
	assert_eq(_s.dungeon.wins(), 0)
	_s.dungeon.from_save({"wins": {"nope": 4, "test_den": -2}})
	assert_eq(_s.dungeon.wins(), 0)


func test_the_unknown_return_area_is_cleared() -> void:
	_s.dungeon.open(&"test_den")
	var d: Dictionary = _through_json(_s.dungeon.to_save()["run"])
	d["return_area"] = "gone"
	_s.dungeon.from_save({"run": d})
	assert_eq(_s.dungeon.run().return_area, &"")


func test_the_session_file_carries_the_module_and_loads_it() -> void:
	_engine.open_and_clear_entrance()
	var file: Dictionary = _through_json(_s.to_save(1_000))
	assert_true((file["modules"] as Dictionary).has("dungeon"))
	var twin: GameSession = _fresh()
	assert_true(twin.from_save(file).ok)
	assert_true(twin.dungeon.is_active())
	assert_true(twin.dungeon.run().paused)
	assert_eq(twin.dungeon.run().cleared, 1)


func test_an_old_file_without_the_module_loads_with_no_run() -> void:
	var file: Dictionary = _through_json(_s.to_save(1_000))
	(file["modules"] as Dictionary).erase("dungeon")
	var twin: GameSession = _fresh()
	assert_true(twin.from_save(file).ok)
	assert_false(twin.dungeon.is_active())
	assert_eq(file["format_version"], SaveMigrator.CURRENT_VERSION, "no migration: version unchanged")


func test_a_new_game_forgets_everything() -> void:
	_s.dungeon.open(&"test_den")
	_s.dungeon.from_save({"pending": {"stacks": [{"item": "test_log", "qty": 4}], "pieces": [], "cards": []}, "wins": {"test_den": 1}})
	_s.dungeon.new_game()
	assert_eq(_s.dungeon.to_save(), {"run": {}, "pending": {}, "wins": {}})
