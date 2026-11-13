extends GutTest
## A whole dungeon run on the real combat engine and the real `DungeonSystem` (docs/05_INTERFACES.md §5.29, F-141, F-144) with the
## fixture dungeon `test_den`: entrance, five forks, the boss in three stages; the win, the death, the flight, "Esci", `stop()`,
## the way back to the area at the end of the instant, the same seed = the same run, 1x1000 ms = 10x100 ms, save and load in the
## middle of a room and of a scene (the run comes back paused). Fixed seeds.

const AREA: StringName = &"test_area"
const SEED: int = 73

var _s: GameSession = null
var _log: Array = []


func _session(seed_value: int = SEED) -> GameSession:
	var s: GameSession = autofree(FractureUtil.session(seed_value))
	TestFactory.set_character_level(s, 90)
	FractureUtil.hero(s)
	s.bank.add(&"test_den_ticket", 3)
	_log = []
	var ev: GameEvents = s.events
	ev.dungeon_room_entered.connect(func(layer: int, kind: StringName) -> void: _log.append(["entered", layer, kind]))
	ev.dungeon_room_cleared.connect(func(layer: int, _k: StringName) -> void: _log.append(["room", layer]))
	ev.dungeon_stage_started.connect(func(n: int, _m: StringName) -> void: _log.append(["stage_started", n]))
	ev.dungeon_stage_cleared.connect(func(n: int) -> void: _log.append(["stage_cleared", n]))
	ev.dungeon_finished.connect(func(o: StringName, rooms: int, _p: int) -> void: _log.append(["finished", o, rooms]))
	ev.dungeon_loot_lost.connect(func(_a: int, _b: int, _c: int) -> void: _log.append(["lost"]))
	ev.player_died.connect(func() -> void: _log.append(["died"]))
	ev.combat_hit.connect(func(_a: int, _t: int, _h: bool, _d: int, _b: bool) -> void: _log.append(["hit"]))
	ev.combat_started.connect(func(a: StringName) -> void: _log.append(["started", a]))
	ev.combat_stopped.connect(func(r: StringName) -> void: _log.append(["stopped", r]))
	return s


func _phase(s: GameSession) -> StringName:
	var state: Dictionary = s.dungeon.state()
	return state["phase"] if not state.is_empty() else &""


# One move of a player who always takes the first exit and the first choice of an event.
func _step(s: GameSession) -> void:
	match _phase(s):
		&"await", &"event":
			assert_true(s.dungeon.choose(0).ok)
		&"":
			return
		_:
			s.advance(500)


func _play(s: GameSession, done: Callable, limit: int = 20000) -> void:
	var steps: int = 0
	while not done.call() and steps < limit:
		_step(s)
		steps += 1
	assert_lt(steps, limit, "the run does not end")


func _over(s: GameSession) -> Callable:
	return func() -> bool: return not s.dungeon.is_active()


func _indexes(name: String) -> Array[int]:
	var result: Array[int] = []
	for i: int in _log.size():
		if (_log[i] as Array)[0] == name:
			result.append(i)
	return result


func _find(entry: Array) -> int:
	return _log.find(entry)


func _no_hit_between(from: int, to: int) -> bool:
	for i: int in range(from + 1, to):
		if (_log[i] as Array)[0] == "hit":
			return false
	return true


# The loaded copy of `s` (through JSON). The test hero is removed first (a test modifier does not survive a load).
func _roundtrip(s: GameSession) -> GameSession:
	s.modifiers.set_source(FractureUtil.SOURCE, [])
	var parsed: Variant = JSON.parse_string(JSON.stringify(s.to_save(1234)))
	assert_true(parsed is Dictionary)
	var loaded: GameSession = autofree(FractureUtil.session(999))
	assert_true(loaded.from_save(parsed as Dictionary).ok)
	return loaded


# --- the whole run -----------------------------------------------------------------------------------------------------

func test_a_whole_run_to_the_win_with_the_signals_in_order() -> void:
	var s: GameSession = _session()
	assert_true(s.dungeon.open(&"test_den").ok)
	_play(s, _over(s))
	assert_eq(_log.filter(func(e: Array) -> bool: return e[0] == "finished"), [["finished", &"won", 7]])
	assert_eq(_indexes("entered").size(), 6, "the entrance and five forks, then the boss by itself")
	assert_eq(_indexes("stage_started").size(), 3)
	assert_eq(_indexes("stage_cleared").size(), 3)
	var order: Array[int] = [_find(["stage_cleared", 1]), _find(["stage_started", 2]), _find(["stage_cleared", 2]),
		_find(["stage_started", 3]), _find(["stage_cleared", 3])]
	for i: int in 4:
		assert_lt(order[i], order[i + 1], "stage signals in order")
	# DungeonSystem listens first: it ends the run inside the reaction to `dungeon_stage_cleared(3)`, so that a later listener
	# sees `dungeon_finished` just before it.
	assert_eq(_find(["finished", &"won", 7]), order[4] - 1)
	assert_gte(_find(["stage_started", 1]), 0)
	assert_lt(_find(["stage_started", 1]), order[0])
	assert_true(_no_hit_between(order[0], order[1]), "nobody attacks during the scene of stage 2")
	assert_true(_no_hit_between(order[2], order[3]), "nor during the scene of the king")
	for i: int in _indexes("room"):
		assert_lt((_log[i] as Array)[1], 6, "no room signal for the boss")
	assert_eq(_s_wins(s), 1)
	assert_false(s.combat.in_dungeon())
	assert_eq(s.combat.state(), CombatEngine.STATE_IDLE, "no area to go back to: the engine stops")
	assert_eq(s.combat.stop_reasons_log().back(), Reasons.DUNGEON_WON)
	assert_false(s.dungeon.has_pending())


func _s_wins(s: GameSession) -> int:
	return s.dungeon.wins(&"test_den")


func test_with_an_area_the_engine_goes_back_to_it_after_the_win_at_the_end_of_the_instant() -> void:
	var s: GameSession = _session()
	s.combat.start(AREA)
	assert_true(s.dungeon.open(&"test_den").ok)
	assert_eq(s.dungeon.run().return_area, AREA)
	assert_eq(s.combat.area_id(), &"", "no area in the dungeon")
	_play(s, _over(s))
	var finished: int = _find(["finished", &"won", 7])
	assert_gte(finished, 0)
	assert_gt(_log.rfind(["started", AREA]), finished, "the area starts after the run is over")
	assert_true(_no_hit_between(finished, _log.rfind(["started", AREA])), "no fight in between")
	assert_eq(s.combat.area_id(), AREA)
	assert_true(s.combat.is_active())


# --- the end for the player --------------------------------------------------------------------------------------------

func test_death_loses_only_the_bag_of_the_run_and_goes_back_to_the_area_after_the_instant() -> void:
	var s: GameSession = _session()
	s.combat.start(AREA)
	s.combat.loot.add(&"test_log", 2)
	assert_true(s.dungeon.open(&"test_den").ok)
	s.dungeon.run().bag.add_stack(&"test_log", 5)
	var bank_logs: int = s.bank.get_count(&"test_log")
	FractureUtil.weakling(s)
	_play(s, _over(s))
	var died: int = _find(["died"])
	assert_gte(died, 0)
	assert_true(_log.slice(died + 1, died + 3).has(["finished", &"died", 0]))
	assert_true(_log.slice(died + 1, died + 3).has(["lost"]), "DungeonSystem loses the bag when it hears of the death")
	assert_eq(_log[died + 3], ["started", AREA], "the way back is the next thing: nothing else of the instant happens")
	assert_eq(s.bank.get_count(&"test_log"), bank_logs, "the bag of the run is gone")
	assert_false(s.dungeon.has_pending())
	assert_eq(s.combat.deaths(), 1)
	assert_gte(s.combat.loot.used(), 1, "the loot bag of the area is kept")
	assert_eq(s.combat.get_state()["player_hp"], s.combat.get_state()["player_max_hp"])


func test_death_without_an_area_stops_the_engine() -> void:
	var s: GameSession = _session()
	assert_true(s.dungeon.open(&"test_den").ok)
	FractureUtil.weakling(s)
	_play(s, _over(s))
	assert_eq(s.combat.state(), CombatEngine.STATE_IDLE)
	assert_eq(s.combat.stop_reasons_log().back(), Reasons.PLAYER_DIED)


func test_flee_is_a_defeat_without_a_death() -> void:
	var s: GameSession = _session()
	s.combat.start(AREA)
	assert_true(s.dungeon.open(&"test_den").ok)
	s.dungeon.run().bag.add_stack(&"test_log", 5)
	assert_true(s.dungeon.flee().ok)
	assert_eq(_log.filter(func(e: Array) -> bool: return e[0] == "finished"), [["finished", &"fled", 0]])
	assert_gte(_find(["lost"]), 0)
	assert_eq(_indexes("died").size(), 0)
	assert_eq(s.combat.deaths(), 0)
	assert_false(s.dungeon.is_active())
	assert_eq(s.combat.area_id(), AREA, "back in the area at once (no instant is running)")


func test_stop_in_a_dungeon_is_a_flight() -> void:
	var s: GameSession = _session()
	assert_true(s.dungeon.open(&"test_den").ok)
	s.combat.stop(Reasons.STOPPED_BY_USER)
	assert_eq(_log.filter(func(e: Array) -> bool: return e[0] == "finished"), [["finished", &"fled", 0]])
	assert_false(s.dungeon.is_active())
	assert_false(s.combat.in_dungeon())
	assert_eq(s.combat.state(), CombatEngine.STATE_IDLE)
	assert_eq(s.combat.stop_reasons_log().back(), Reasons.STOPPED_BY_USER)


func test_leave_at_a_fork_goes_back_to_the_area() -> void:
	var s: GameSession = _session()
	s.combat.start(AREA)
	assert_true(s.dungeon.open(&"test_den").ok)
	_play(s, func() -> bool: return _phase(s) == &"await")
	assert_eq(s.combat.state(), CombatEngine.STATE_AWAIT)
	assert_true(s.dungeon.leave().ok)
	var finished: Array = _log.filter(func(e: Array) -> bool: return e[0] == "finished")
	assert_eq(finished.size(), 1)
	assert_eq((finished[0] as Array)[1], &"left")
	assert_false(s.combat.in_dungeon())
	assert_eq(s.combat.area_id(), AREA)
	assert_eq(s.combat.state(), CombatEngine.STATE_ENCOUNTER)


# --- time and determinism ----------------------------------------------------------------------------------------------

func test_the_waiting_engine_does_nothing_whatever_the_time() -> void:
	var s: GameSession = _session()
	assert_true(s.dungeon.open(&"test_den").ok)
	_play(s, func() -> bool: return _phase(s) == &"await")
	var rng_state: Dictionary = s.rng.to_save()
	var combat_save: Dictionary = s.combat.to_save()
	_log = []
	s.advance(3_600_000)
	assert_eq(_log, [])
	assert_eq(s.rng.to_save(), rng_state)
	assert_eq(s.combat.to_save(), combat_save)


func test_the_same_seed_gives_the_same_run() -> void:
	var results: Array[Dictionary] = []
	for _i: int in 2:
		var s: GameSession = _session()
		assert_true(s.dungeon.open(&"test_den").ok)
		_play(s, _over(s))
		results.append({"rng": s.rng.to_save(), "bank": s.bank.to_save(), "dungeon": s.dungeon.to_save(), "combat": s.combat.to_save(),
			"character": s.character.to_save(), "log": _log.duplicate()})
	assert_eq(results[0], results[1])


func test_one_step_of_1000_ms_is_ten_steps_of_100_ms() -> void:
	var coarse: GameSession = _session()
	var fine: GameSession = _session()
	assert_true(coarse.dungeon.open(&"test_den").ok)
	assert_true(fine.dungeon.open(&"test_den").ok)
	for _i: int in 8:
		coarse.advance(1000)
		for _k: int in 10:
			fine.advance(100)
	assert_eq(fine.combat.to_save(), coarse.combat.to_save())
	assert_eq(fine.dungeon.to_save(), coarse.dungeon.to_save())
	assert_eq(fine.rng.to_save(), coarse.rng.to_save())


# --- save and load -----------------------------------------------------------------------------------------------------

func test_a_run_saved_in_the_middle_of_a_room_comes_back_paused_with_the_same_enemies() -> void:
	var a: GameSession = _session()
	assert_true(a.dungeon.open(&"test_den").ok)
	a.advance(2000)
	assert_eq(_phase(a), &"fight")
	var b: GameSession = _roundtrip(a)
	assert_true(b.dungeon.run().paused, "F-144 rule 1")
	assert_true(b.combat.get_state()["dungeon"]["paused"])
	assert_eq(b.combat.get_state()["enemies"], a.combat.get_state()["enemies"], "the same hand of enemies and timers")
	assert_eq(b.combat.to_save(), a.combat.to_save())
	var saved: Dictionary = b.combat.to_save()
	b.advance(600_000)
	assert_eq(b.combat.to_save(), saved, "paused: nothing moves")
	assert_eq(b.dungeon.choose(0).reason, Reasons.DUNGEON_PAUSED)
	assert_true(b.dungeon.resume().ok)
	for _i: int in 10:
		a.advance(300)
		b.advance(300)
	assert_eq(b.combat.to_save(), a.combat.to_save())
	assert_eq(b.rng.to_save(), a.rng.to_save())


func test_a_run_saved_in_the_scene_of_a_stage_resumes_the_scene() -> void:
	var a: GameSession = _session()
	assert_true(a.dungeon.open(&"test_den").ok)
	_play(a, func() -> bool: return _phase(a) == &"intro")
	a.advance(1200)
	assert_eq(a.combat.state(), CombatEngine.STATE_INTRO)
	var left: int = a.combat.get_state()["dungeon"]["intro_left_ms"]
	assert_between(left, 1, 5500)
	var b: GameSession = _roundtrip(a)
	assert_eq(b.combat.state(), CombatEngine.STATE_INTRO)
	assert_eq(b.combat.get_state()["dungeon"]["intro_left_ms"], left)
	assert_eq(b.combat.get_state()["enemies"], [])
	assert_true(b.dungeon.resume().ok)
	a.advance(left)
	b.advance(left)
	assert_eq(b.combat.state(), CombatEngine.STATE_ENCOUNTER)
	assert_eq(b.combat.to_save(), a.combat.to_save())
	assert_eq(b.rng.to_save(), a.rng.to_save())


func test_a_run_saved_at_a_fork_comes_back_waiting_and_paused() -> void:
	var a: GameSession = _session()
	assert_true(a.dungeon.open(&"test_den").ok)
	_play(a, func() -> bool: return _phase(a) == &"await")
	var b: GameSession = _roundtrip(a)
	assert_eq(b.combat.state(), CombatEngine.STATE_AWAIT)
	assert_eq(b.dungeon.choose(0).reason, Reasons.DUNGEON_PAUSED)
	assert_true(b.dungeon.resume().ok)
	assert_true(b.dungeon.choose(0).ok)
	assert_true(a.dungeon.choose(0).ok)
	assert_eq(b.combat.get_state()["enemies"], a.combat.get_state()["enemies"], "the same room composed by the same generator")
