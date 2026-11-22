extends GutTest
## M33-02 (docs/M33_TUTORIAL_FORZATO.md §3-§6): the forced first fight, the pause after it and in steps 9-13, the repeated wound,
## the forced node, and the resume at every step, on the real data.

const F: String = "res://tests/systems/combat/test_combat_force_pack.gd"
const AREA: StringName = &"redrock_plains"
const SETUPS: Array[StringName] = [&"sword_shield", &"greatsword", &"dual_swords"]
const SEEDS: int = 100
const TICK_MS: int = 1000

var _progress: Array = []


func _session(seed_value: int, step: String, setup: StringName = &"sword_shield") -> GameSession:
	var s: GameSession = autofree(load(F).session(seed_value, step, setup))
	_progress.clear()
	s.events.tutorial_progress.connect(func(_id: StringName, n: int, _total: int) -> void: _progress.append(n))
	return s


# Advances until the tutorial leaves `step` (or `limit_ms`), restarting the fight if it stopped. Returns false if the hero died.
func _run_until_left(s: GameSession, step: StringName, limit_ms: int = 600_000) -> int:
	var spent: int = 0
	while spent < limit_ms and s.tutorial.is_active() and s.tutorial.current_step().id == step and s.combat.deaths() == 0:
		if not s.combat.is_active():
			s.combat.start(AREA)
		s.advance(TICK_MS)
		spent += TICK_MS
	return spent


func _pack(step_id: StringName) -> Array[StringName]:
	return TestFactory.real_data().tutorial_step(step_id).force_pack


func _step_id(s: GameSession) -> StringName:
	return s.tutorial.current_step().id


func test_group_a_is_won_by_every_setup_on_100_seeds() -> void:
	for setup: StringName in SETUPS:
		for seed_value: int in SEEDS:
			var s: GameSession = _session(seed_value, "combat_kills", setup)
			s.combat.start(AREA)
			_run_until_left(s, &"combat_kills")
			var label: String = "%s seed %d" % [setup, seed_value]
			assert_eq(s.combat.deaths(), 0, label)
			assert_eq(_step_id(s), &"combat_triangle", label)
			assert_eq(_progress, [1, 2, 3], label)


func test_the_combat_stops_after_group_a_and_the_pause_is_exact() -> void:
	var s: GameSession = _session(7, "combat_kills")
	s.combat.start(AREA)
	_run_until_left(s, &"combat_kills")
	assert_eq(_step_id(s), &"combat_triangle")
	assert_true(s.combat.is_frozen())
	assert_true(s.tutorial.is_combat_frozen())
	var combat_before: String = JSON.stringify(s.combat.to_save())
	var rng_before: String = JSON.stringify(s.rng.to_save())
	var time_before: int = s.play_time_ms
	s.advance(60000)
	assert_eq(JSON.stringify(s.combat.to_save()), combat_before)
	assert_eq(JSON.stringify(s.rng.to_save()), rng_before)
	assert_eq(s.play_time_ms, time_before + 60000)
	assert_true(s.tutorial.acknowledge().ok)
	assert_false(s.combat.is_frozen())
	assert_eq(_step_id(s), &"combat_eat")
	assert_eq(s.combat.force_pack(), _pack(&"combat_eat"))


func test_the_blocks_are_equivalent_at_step_6() -> void:
	var states: Array[String] = []
	for mode: int in 3:
		var s: GameSession = _session(21, "combat_triangle")
		s.combat.start(AREA)
		match mode:
			0:
				s.advance(43_200_000)
			1:
				for i: int in 43_200_000 / 100:
					s.advance(100)
			2:
				for i: int in 43_200_000 / 60_000:
					s.advance(60_000)
		var d: Dictionary = s.to_save(0)
		(d["modules"]["tutorial"] as Dictionary)["since_ms"] = 0
		states.append(JSON.stringify(d).md5_text())
		assert_true(s.combat.is_frozen())
	assert_eq(states[1], states[0], "100 ms ticks")
	assert_eq(states[2], states[0], "60 s blocks")


func test_the_meal_with_the_wound_never_kills_on_100_seeds_and_comes_in_the_first_group() -> void:
	for setup: StringName in SETUPS:
		for seed_value: int in SEEDS:
			var s: GameSession = _session(seed_value, "combat_kills", setup)
			s.combat.start(AREA)
			_run_until_left(s, &"combat_kills")
			var groups: Array = []
			s.events.encounter_started.connect(func(monsters: Array[StringName]) -> void: groups.append(monsters))
			s.tutorial.acknowledge()
			_run_until_left(s, &"combat_eat")
			var label: String = "%s seed %d" % [setup, seed_value]
			assert_eq(s.combat.deaths(), 0, label)
			assert_eq(_step_id(s), &"combat_food", label)
			assert_lte(groups.size(), 1, "%s: the meal came within the first group B" % label)
			assert_gte(s.combat.food_eaten(), 1, label)
			assert_true(s.combat.is_frozen(), label)


func test_the_wound_repeats_at_every_group_while_the_meal_step_is_current() -> void:
	var s: GameSession = _session(5, "combat_eat")
	s.combat.start(AREA)
	var limit: int = (s.combat.player_stats().max_hp * 30 + 99) / 100
	assert_lte(int(s.combat.get_state()["player_hp"]), limit, "first group")
	s.combat.stop()
	assert_eq(int(s.combat.get_state()["player_hp"]), s.combat.player_stats().max_hp, "the stop heals")
	s.combat.start(AREA)
	assert_lte(int(s.combat.get_state()["player_hp"]), limit, "the next group finds the wound again")
	assert_eq(s.combat.force_pack(), _pack(&"combat_eat"))


func test_the_pause_goes_on_from_8_to_13_and_step_14_resumes() -> void:
	var s: GameSession = _session(11, "combat_food")
	s.disciplines.new_game()
	s.combat.start(AREA)
	for id: StringName in [&"combat_food", &"bank", &"shop", &"rift", &"trainers", &"skill"]:
		assert_eq(_step_id(s), id)
		assert_true(s.combat.is_frozen(), "%s is frozen" % id)
		assert_true(s.combat.force_pack().is_empty())
		if id == &"trainers":
			assert_true(s.disciplines.learn(&"forestry").ok)
		else:
			assert_true(s.tutorial.acknowledge().ok)
	assert_eq(_step_id(s), &"nodes")
	assert_false(s.combat.is_frozen(), "step 14 resumes")
	assert_true(s.combat.is_force_node())
	assert_true(s.combat.is_guarded())
	assert_eq(s.combat.force_pack(), _pack(&"nodes"))


func test_skip_step_does_not_unfreeze() -> void:
	var s: GameSession = _session(11, "trainers")
	s.combat.start(AREA)
	s.advance(300_000)
	assert_true(s.tutorial.can_skip_step())
	assert_true(s.tutorial.skip_step().ok)
	assert_eq(_step_id(s), &"skill")
	assert_true(s.combat.is_frozen())


func test_step_14_gets_the_forced_node_with_no_roll_and_switches_everything_off() -> void:
	for seed_value: int in [3, 4, 6, 7, 8, 12, 15]:
		var s: GameSession = _session(seed_value, "skill")
		s.disciplines.new_game()
		TestFactory.learn_discipline(s, &"forestry")
		s.combat.start(AREA)
		s.tutorial.from_save({"completed": false, "step": "skill", "progress": 0, "since_ms": 0, "visited": []})
		assert_true(s.tutorial.acknowledge().ok)
		assert_eq(_step_id(s), &"nodes")
		var spent: int = 0
		while _step_id(s) == &"nodes" and spent < 600_000:
			if not s.combat.is_active():
				s.combat.start(AREA)
			s.advance(500)
			spent += 500
		assert_eq(_step_id(s), &"village", "seed %d: the node was worked" % seed_value)
		assert_false(s.combat.is_guarded(), "seed %d" % seed_value)
		assert_false(s.combat.is_force_node())
		assert_true(s.combat.force_pack().is_empty())
		assert_false(s.combat.is_frozen())


func test_a_stopped_combat_restarts_into_the_forced_pack_at_steps_5_7_14() -> void:
	for step: String in ["combat_kills", "combat_eat", "nodes"]:
		var s: GameSession = _session(4, step)
		var seen: Array = []
		s.events.encounter_started.connect(func(monsters: Array[StringName]) -> void: seen.append(monsters))
		s.combat.start(AREA)
		assert_eq(seen.size(), 1, step)
		assert_eq(seen[0], s.combat.force_pack(), step)


func test_resume_at_every_step_reapplies_the_effects() -> void:
	var data: GameData = TestFactory.real_data()
	for index: int in data.tutorial_steps().size():
		var step: TutorialStepDef = data.tutorial_steps()[index]
		var s: GameSession = _session(30 + index, String(step.id))
		if step.id != &"combat_start":
			s.combat.start(AREA)
		var twin: GameSession = autofree(TestFactory.session(99, data, false, true))
		assert_true(twin.from_save(s.to_save(0)).ok, String(step.id))
		assert_eq(twin.tutorial.current_step().id, step.id)
		assert_eq(twin.combat.is_frozen(), step.freeze_combat, String(step.id))
		assert_eq(twin.combat.is_force_node(), step.force_node, String(step.id))
		assert_eq(twin.combat.force_pack(), step.force_pack, String(step.id))
		assert_eq(twin.combat.is_guarded(), step.force_node or (not step.force_pack.is_empty() and step.force_pack_area == AREA), String(step.id))
		if step.id == &"trainers":
			continue
		if step.done_when[0].type == TutorialCondition.TYPE_ACK:
			assert_true(twin.tutorial.acknowledge().ok, "%s can be completed" % step.id)


func test_an_old_save_with_the_combat_running_at_step_9_resumes_frozen() -> void:
	var s: GameSession = _session(8, "bank")
	s.combat.start(AREA)
	s.combat.set_frozen(false)  # an old save: the combat was running
	var d: Dictionary = s.to_save(0)
	var twin: GameSession = autofree(TestFactory.session(2, TestFactory.real_data(), false, true))
	assert_true(twin.from_save(d).ok)
	assert_true(twin.combat.is_frozen())
	assert_true(twin.combat.is_active())
	assert_true(twin.tutorial.acknowledge().ok)
	assert_true(twin.combat.is_frozen(), "the next step is frozen too")


func test_a_completed_tutorial_has_no_forced_pack_and_no_guard() -> void:
	var s: GameSession = autofree(TestFactory.session(3, TestFactory.real_data(), false, false))
	s.combat.start(AREA)
	assert_true(s.combat.force_pack().is_empty())
	assert_false(s.combat.is_guarded())
	assert_false(s.combat.is_frozen())
