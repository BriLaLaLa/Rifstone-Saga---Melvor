extends GutTest
## Equivalence (docs/05_INTERFACES_M30.md §5.41 "Offline"): 2 h of combat in one block = steps of 100 ms, with the tutorial in the middle of
## an event step and with the starter quests active. The tutorial adds no `advance`, so the saved state is the same.

const AREA: StringName = &"test_area"
const OTHER_AREA: StringName = &"test_loot_area"  # its monster is outside the filter of the `kills` step: the step stays in the middle
const TWO_HOURS_MS: int = 7_200_000
const TICK_MS: int = 100


func _session(with_tutorial: bool) -> GameSession:
	var area: StringName = OTHER_AREA if with_tutorial else AREA
	var s: GameSession = autofree(TestFactory.session(4321, null, false, with_tutorial))
	TestFactory.give(s, &"seared_brookfin", 50)
	if with_tutorial:
		s.tutorial.acknowledge()  # now at the `kills` step (an event step needing three kills)
	assert_true(s.combat.start(area).ok)
	return s


func _run_in_steps(s: GameSession, total_ms: int) -> void:
	for i: int in total_ms / TICK_MS:
		s.advance(TICK_MS)


func _equal(with_tutorial: bool) -> void:
	var one_block: GameSession = _session(with_tutorial)
	var stepped: GameSession = _session(with_tutorial)
	one_block.advance(TWO_HOURS_MS)
	_run_in_steps(stepped, TWO_HOURS_MS)
	assert_gt(one_block.combat.total_kills().size(), 0, "the fight happened")
	assert_eq(JSON.stringify(one_block.to_save(0)), JSON.stringify(stepped.to_save(0)))


func test_tutorial_in_the_middle_of_an_event_step() -> void:
	_equal(true)
	var s: GameSession = _session(true)
	s.advance(TWO_HOURS_MS)
	assert_eq(s.tutorial.current_step().id, &"kills", "still in the middle of the event step")


func test_starter_quests_active() -> void:
	_equal(false)
	var s: GameSession = _session(false)
	s.advance(TWO_HOURS_MS)
	assert_true(s.tutorial.starter.is_complete(&"kill_two"), "the counted events of a long block count")
