extends GutTest
## M31 (docs/M31_RITOCCHI_TUTORIAL.md §4): `force_node` of the cycle and of the `nodes` tutorial step, on the real data.

const AREA: StringName = &"redrock_plains"


func _session(seed_value: int, learned: bool) -> GameSession:
	var s: GameSession = autofree(TestFactory.session(seed_value, TestFactory.real_data(), false, true))
	if not learned:
		s.disciplines.new_game()
	return s


func test_forced_node_is_the_first_learned_discipline_with_no_roll() -> void:
	var s: GameSession = _session(5, false)
	TestFactory.learn_discipline(s, &"quarrying")
	var rng_before: String = JSON.stringify(s.rng.to_save())
	var next: Dictionary = EncounterCycle.next_kind(s, AREA, false, true)
	assert_eq(next["kind"], EncounterCycle.NODE)
	assert_eq(next["skill"], &"quarrying", "the first learned one in the order of the entries")
	assert_eq(JSON.stringify(s.rng.to_save()), rng_before, "no draw at all")
	TestFactory.learn_discipline(s, &"forestry")
	assert_eq(EncounterCycle.next_kind(s, AREA, false, true)["skill"], &"forestry")


func test_no_learned_discipline_means_the_normal_rule() -> void:
	var s: GameSession = _session(5, false)
	var rng_before: String = JSON.stringify(s.rng.to_save())
	EncounterCycle.next_kind(s, AREA, false, true)
	assert_ne(JSON.stringify(s.rng.to_save()), rng_before, "the roll of the normal rule happened")


func test_a_fight_that_waits_wins_over_the_forced_node() -> void:
	var s: GameSession = _session(5, true)
	var next: Dictionary = EncounterCycle.next_kind(s, AREA, true, true)
	assert_eq(next["kind"], EncounterCycle.FIGHT)


func test_without_the_flag_the_rule_is_unchanged() -> void:
	var a: GameSession = _session(9, true)
	var b: GameSession = _session(9, true)
	assert_eq(EncounterCycle.next_kind(a, AREA, false), EncounterCycle.next_kind(b, AREA, false, false))
	assert_eq(JSON.stringify(a.rng.to_save()), JSON.stringify(b.rng.to_save()))


func test_the_nodes_step_gets_a_worked_node_then_switches_off() -> void:
	for seed_value: int in [3, 4, 5, 6, 7]:
		var s: GameSession = _session(seed_value, false)
		TestFactory.learn_discipline(s, &"forestry")
		assert_true(s.combat.start(AREA).ok)
		s.tutorial.from_save({"completed": false, "step": "nodes", "progress": 0, "since_ms": 0, "visited": []})
		assert_true(s.combat.is_force_node(), "seed %d" % seed_value)
		var spent: int = 0
		while s.tutorial.current_step().id == &"nodes" and spent < 300_000:
			s.advance(100)
			spent += 100
		assert_eq(s.tutorial.current_step().id, &"village", "seed %d: a worked node came" % seed_value)
		assert_false(s.combat.is_force_node(), "seed %d: off after the step" % seed_value)
		assert_gt(s.combat.node_counts()["worked"] + (1 if s.combat.node_skill() != &"" else 0), 0)
