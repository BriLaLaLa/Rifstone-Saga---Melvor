extends GutTest
## M31 on the real data (docs/M31_RITOCCHI_TUTORIAL.md §3): the meal step wounds the character, `combat_food` freezes the combat until Ok,
## the equivalence of the blocks, the guarantee of the meal on many seeds, the counter per kill.

const AREA: StringName = &"redrock_plains"
const TICK_MS: int = 100
const HALF_DAY_MS: int = 43_200_000


func _session(seed_value: int, step: String) -> GameSession:
	var s: GameSession = autofree(TestFactory.session(seed_value, TestFactory.real_data(), false, true))
	assert_true(s.combat.start(AREA).ok)
	_at(s, step)
	return s


func _at(s: GameSession, step: String) -> void:
	s.tutorial.from_save({"completed": false, "step": step, "progress": 0, "since_ms": 0, "visited": []})


# Ticks of 100 ms until the tutorial leaves `step` (or `limit_ms` passed); returns the game time spent.
func _run_until_left(s: GameSession, step: StringName, limit_ms: int) -> int:
	var spent: int = 0
	while spent < limit_ms and s.tutorial.is_active() and s.tutorial.current_step().id == step:
		s.advance(TICK_MS)
		spent += TICK_MS
	return spent


func test_counter_text_comes_from_the_data() -> void:
	var s: GameSession = _session(1, "combat_kills")
	assert_eq(s.tutorial.step_progress_text(), "Nemici sconfitti: %d su %d")
	assert_eq(s.tutorial.ack_text(), "")
	_at(s, "combat_food")
	assert_eq(s.tutorial.ack_text(), "Ok")
	assert_eq(s.tutorial.step_progress_text(), "")
	assert_true(s.tutorial.is_combat_frozen())
	_at(s, "welcome")
	assert_false(s.tutorial.is_combat_frozen())


func test_counter_goes_up_at_every_kill() -> void:
	var s: GameSession = autofree(TestFactory.session(2, TestFactory.real_data(), false, true))
	watch_signals(s.events)
	_at(s, "combat_kills")
	for i: int in 3:  # a group of three killed in the same instant
		s.events.monster_killed.emit(i, &"ember_rat")
	assert_signal_emit_count(s.events, "tutorial_progress", 3)
	assert_signal_emitted_with_parameters(s.events, "tutorial_progress", [&"combat_kills", 3, 3])
	assert_eq(s.tutorial.current_step().id, &"combat_triangle")


func test_the_meal_step_freezes_the_combat_and_ok_keeps_the_pause() -> void:
	var s: GameSession = _session(11, "combat_eat")
	assert_false(s.combat.is_frozen())
	var spent: int = _run_until_left(s, &"combat_eat", 600_000)
	assert_lt(spent, 600_000, "the meal arrived")
	assert_eq(s.tutorial.current_step().id, &"combat_food")
	assert_true(s.combat.is_frozen())
	var combat_before: String = JSON.stringify(s.combat.to_save())
	var rng_before: String = JSON.stringify(s.rng.to_save())
	var time_before: int = s.play_time_ms
	s.advance(60000)
	assert_eq(JSON.stringify(s.combat.to_save()), combat_before)
	assert_eq(JSON.stringify(s.rng.to_save()), rng_before)
	assert_eq(s.play_time_ms, time_before + 60000)
	assert_true(s.tutorial.acknowledge().ok)
	assert_true(s.combat.is_frozen(), "M33: Ok does not restart the combat, the pause goes on to step 14")
	assert_ne(s.tutorial.current_step().id, &"combat_food")


func test_equivalence_of_the_blocks_at_the_pause() -> void:
	var one_block: GameSession = _session(21, "combat_eat")
	var stepped: GameSession = _session(21, "combat_eat")
	var minutes: GameSession = _session(21, "combat_eat")
	one_block.advance(HALF_DAY_MS)
	for i: int in HALF_DAY_MS / TICK_MS:
		stepped.advance(TICK_MS)
	for i: int in HALF_DAY_MS / 60000:
		minutes.advance(60000)
	assert_eq(one_block.tutorial.current_step().id, &"combat_food")
	assert_true(one_block.combat.is_frozen())
	var expected: String = _state(one_block)
	assert_eq(_state(stepped), expected, "100 ms ticks")
	assert_eq(_state(minutes), expected, "60 s blocks")


func test_save_and_load_in_the_middle_of_the_pause() -> void:
	var s: GameSession = _session(31, "combat_eat")
	_run_until_left(s, &"combat_eat", 600_000)
	assert_true(s.combat.is_frozen())
	var twin: GameSession = autofree(TestFactory.session(31, TestFactory.real_data(), false, true))
	assert_true(twin.from_save(s.to_save(0)).ok)
	assert_eq(twin.tutorial.current_step().id, &"combat_food")
	assert_true(twin.combat.is_frozen(), "still frozen after the load")
	assert_true(twin.tutorial.acknowledge().ok)
	assert_true(twin.combat.is_frozen(), "M33: Ok keeps the pause")


func test_the_meal_is_guaranteed_on_many_seeds() -> void:
	for seed_value: int in range(100, 160):
		var s: GameSession = _session(seed_value, "combat_eat")
		var spent: int = 0
		while spent < 900_000 and s.tutorial.current_step().id == &"combat_eat":
			s.advance(TICK_MS)
			spent += TICK_MS
			if s.combat.deaths() > 0:
				break
		assert_eq(s.combat.deaths(), 0, "seed %d: no death before the meal" % seed_value)
		assert_eq(s.tutorial.current_step().id, &"combat_food", "seed %d: the meal arrived" % seed_value)
		assert_lt(spent, 120_000, "seed %d: within the first fight" % seed_value)


# The whole save, without `since_ms` of the step: it is the play time at the entry, and a step entered inside a block sees the time of the
# start of that block (it only serves the valve of the steps that are not `ack`).
func _state(s: GameSession) -> String:
	var d: Dictionary = s.to_save(0)
	(d["modules"]["tutorial"] as Dictionary)["since_ms"] = 0
	return JSON.stringify(d).md5_text()
