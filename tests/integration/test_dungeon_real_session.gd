extends GutTest
## M22-08, final integration on the real data and a real `GameSession`: the rules of the run (F-144, docs/01_GDD.md §33) seen from
## the outside, with the real combat engine. What the component tests already cover with doubles is not repeated here (the whole
## run: `test_dungeon_engine_real.gd`; the page: `tests/ui/test_dungeon_page_session.gd`; offline with a double:
## `test_offline_dungeon.gd`). Here: ticket at the entry, defeat and flight lose the bag, "leave" keeps it, the way back to the
## area, the save in the middle of a run, offline frozen, one instance with the Fractures.

const SEED: int = 2208
const TICKET: StringName = &"dungeon_ticket_monkey_den"
const DEN: StringName = &"monkey_den"
const AREA: StringName = &"cracked_mines"
const HERO: StringName = &"test:hero"
const STEP_MS: int = 500
const STEP_LIMIT: int = 30000


func _session(strong: bool = true) -> GameSession:
	var s: GameSession = autofree(TestFactory.session(SEED, TestFactory.real_data()))
	TestFactory.make_roomy(s)
	TestFactory.set_character_level(s, 55 if strong else 40)
	if strong:
		s.modifiers.set_source(HERO, [Modifier.make(&"power_bonus", 5000.0), Modifier.make(&"max_hp_flat", 100000.0)])
	s.bank.add(TICKET, 2)
	return s


## Plays until the run waits for a choice at a fork (phase `await`), returns false if it ends first.
func _to_fork(s: GameSession) -> bool:
	for _i: int in STEP_LIMIT:
		if not s.dungeon.is_active():
			return false
		var phase: StringName = s.dungeon.state()["phase"]
		if phase == &"await" or phase == &"event":
			return true
		s.advance(STEP_MS)
	return false


func test_the_ticket_is_spent_at_the_entry_and_the_first_fork_waits_for_the_player() -> void:
	var s: GameSession = _session()
	assert_eq(s.dungeon.tickets(DEN), 2)
	assert_true(s.dungeon.open(DEN).ok)
	assert_eq(s.dungeon.tickets(DEN), 1, "spent when the run begins, not when it ends")
	assert_true(s.combat.in_dungeon())
	assert_true(_to_fork(s))
	assert_eq(s.dungeon.state()["phase"], &"await")
	var choices: Array = s.dungeon.state()["choices"]
	assert_between(choices.size(), 2, 4)


func test_flight_in_a_fight_loses_the_bag_and_goes_back_to_the_area() -> void:
	var s: GameSession = _session()
	s.combat.start(AREA)
	assert_true(s.dungeon.open(DEN).ok)
	assert_eq(s.dungeon.run().return_area, AREA)
	assert_true(_to_fork(s))
	assert_true(s.dungeon.choose(0).ok)
	var bank_before: Dictionary = s.bank.to_save()
	s.dungeon.run().bag.add_stack(&"rift_dust", 7)
	assert_true(s.dungeon.flee().ok)
	assert_false(s.dungeon.is_active())
	assert_false(s.dungeon.has_pending())
	assert_eq(s.bank.to_save(), bank_before, "the bag is lost, not delivered")
	assert_eq(s.dungeon.tickets(DEN), 1, "the ticket is not given back")
	assert_false(s.combat.in_dungeon())
	assert_eq(s.combat.area_id(), AREA, "back to the area being fought")


func test_defeat_loses_the_bag() -> void:
	var s: GameSession = _session(false)
	assert_true(s.dungeon.open(DEN).ok)
	var finished: Array = []
	s.events.dungeon_finished.connect(func(o: StringName, _r: int, _p: int) -> void: finished.append(o))
	var dust: int = s.bank.get_count(&"rift_dust")
	s.dungeon.run().bag.add_stack(&"rift_dust", 7)
	for _i: int in STEP_LIMIT:
		if not s.dungeon.is_active():
			break
		var phase: StringName = s.dungeon.state()["phase"]
		if phase == &"await" or phase == &"event":
			s.dungeon.choose(0)
		else:
			s.advance(STEP_MS)
	assert_false(s.dungeon.is_active())
	assert_eq(finished, [&"died"])
	assert_false(s.dungeon.has_pending())
	assert_eq(s.bank.get_count(&"rift_dust"), dust, "the bag is lost")
	assert_eq(s.dungeon.wins(), 0)


func test_leaving_at_a_fork_keeps_the_bag_and_not_the_boss_prizes() -> void:
	var s: GameSession = _session()
	s.combat.start(AREA)
	assert_true(s.dungeon.open(DEN).ok)
	assert_true(_to_fork(s))
	var gold: int = s.wallet.get_gold()
	s.dungeon.run().bag.add_stack(&"rift_dust", 9)
	var dust: int = s.bank.get_count(&"rift_dust")
	var armory: int = s.armory.used()
	assert_true(s.dungeon.leave().ok)
	assert_false(s.dungeon.is_active())
	assert_gte(s.bank.get_count(&"rift_dust"), dust + 9, "the bag is delivered")
	assert_gte(s.wallet.get_gold(), gold, "the room prizes arrive, never the boss gold")
	assert_lt(s.wallet.get_gold() - gold, 1500, "no boss prize")
	assert_eq(s.armory.used(), armory, "no boss pieces")
	assert_eq(s.dungeon.wins(), 0)
	assert_eq(s.dungeon.tickets(DEN), 1)
	assert_eq(s.combat.area_id(), AREA)


func test_a_run_saved_in_the_middle_comes_back_paused_and_goes_on_after_resume() -> void:
	var s: GameSession = _session()
	assert_true(s.dungeon.open(DEN).ok)
	assert_true(_to_fork(s))
	var state: Dictionary = s.dungeon.state()
	var twin: GameSession = autofree(TestFactory.session(SEED + 1, TestFactory.real_data()))
	assert_true(twin.from_save(s.to_save(0)).ok)
	assert_true(twin.dungeon.is_active())
	assert_true(twin.dungeon.run().paused, "in pause until the player resumes")
	assert_eq(twin.dungeon.run().seed_value, s.dungeon.run().seed_value)
	assert_eq(twin.dungeon.state()["choices"], state["choices"], "the same fork")
	assert_false(twin.dungeon.choose(0).ok, "a paused run accepts nothing but resume")
	assert_true(twin.dungeon.resume().ok)
	assert_false(twin.dungeon.run().paused)
	assert_true(twin.dungeon.choose(0).ok)


func test_offline_the_run_is_frozen_on_a_real_session() -> void:
	var s: GameSession = _session()
	s.combat.start(AREA)
	assert_true(s.dungeon.open(DEN).ok)
	assert_true(_to_fork(s))
	var run: DungeonRun = s.dungeon.run()
	var before: Array = [run.layer, run.index, run.phase, run.cleared, run.stage, run.bag.counts()]
	var deaths: int = s.combat.deaths()
	var summary: OfflineSummary = await OfflineSimulator.new().run(s, 3_600_000, false, false)
	assert_true(summary.dungeon_frozen)
	assert_true(s.dungeon.is_active())
	assert_eq([run.layer, run.index, run.phase, run.cleared, run.stage, run.bag.counts()], before)
	assert_eq(s.combat.deaths(), deaths, "no death while away")


func test_one_instance_at_a_time_with_the_fractures() -> void:
	var s: GameSession = _session()
	assert_true(s.dungeon.open(DEN).ok)
	assert_eq(s.dungeon.can_open(DEN), Reasons.DUNGEON_ACTIVE, "not twice")
	var uid: int = FractureUtil.card(s, 1)
	assert_eq(s.fractures.open(uid).reason, Reasons.DUNGEON_ACTIVE)
	assert_true(s.dungeon.flee().ok)
