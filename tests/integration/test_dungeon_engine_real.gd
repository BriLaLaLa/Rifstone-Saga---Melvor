extends GutTest
## M22-05, integration on the real data: `DungeonSystem` and the real combat engine complete a whole run of the Covo delle Scimmie
## (`monkey_den`, entrance, five forks, Gorom, Ziki, Uuk-Maar) with a fixed seed; the same seed gives the same run and the boss
## loot arrives (F-143). The player is a test hero: the numbers of the fights are checked by `tools/sim_dungeon.gd` (M22-07).

const SEED: int = 2211
const TICKET: StringName = &"dungeon_ticket_monkey_den"
const HERO: StringName = &"test:hero"

var _log: Array = []


func _session() -> GameSession:
	var s: GameSession = autofree(TestFactory.session(SEED, TestFactory.real_data()))
	TestFactory.make_roomy(s)
	TestFactory.set_character_level(s, 55)
	s.modifiers.set_source(HERO, [Modifier.make(&"power_bonus", 5000.0), Modifier.make(&"max_hp_flat", 100000.0)])
	s.bank.add(TICKET, 1)
	_log = []
	s.events.dungeon_room_entered.connect(func(_l: int, k: StringName) -> void: _log.append(["entered", k]))
	s.events.dungeon_stage_started.connect(func(n: int, m: StringName) -> void: _log.append(["stage", n, m]))
	s.events.dungeon_finished.connect(func(o: StringName, rooms: int, _p: int) -> void: _log.append(["finished", o, rooms]))
	return s


func _complete(s: GameSession) -> void:
	assert_true(s.dungeon.open(&"monkey_den").ok)
	var steps: int = 0
	while s.dungeon.is_active() and steps < 30000:
		var phase: StringName = s.dungeon.state()["phase"]
		if phase == &"await" or phase == &"event":
			assert_true(s.dungeon.choose(0).ok)
		else:
			s.advance(500)
		steps += 1
	assert_false(s.dungeon.is_active(), "the run ends")


func test_a_whole_run_of_the_monkey_den_on_the_real_engine() -> void:
	var s: GameSession = _session()
	var before: int = s.armory.used()
	_complete(s)
	assert_eq(_log.filter(func(e: Array) -> bool: return e[0] == "stage"),
			[["stage", 1, &"monkey_gorom"], ["stage", 2, &"monkey_ziki"], ["stage", 3, &"monkey_king"]])
	assert_eq(_log.filter(func(e: Array) -> bool: return e[0] == "finished"), [["finished", &"won", 7]])
	assert_eq(_log.filter(func(e: Array) -> bool: return e[0] == "entered").size(), 6)
	assert_eq(s.dungeon.wins(&"monkey_den"), 1)
	assert_eq(s.dungeon.tickets(&"monkey_den"), 0, "the ticket is spent and not given back")
	assert_false(s.combat.in_dungeon())
	assert_false(s.dungeon.has_pending(), "the bag was delivered (roomy Deposit)")
	assert_gte(s.armory.used(), before + 2, "at least the two pieces of the boss")


func test_the_same_seed_is_the_same_run_on_the_real_data() -> void:
	var results: Array[Dictionary] = []
	for _i: int in 2:
		var s: GameSession = _session()
		_complete(s)
		results.append({"rng": s.rng.to_save(), "bank": s.bank.to_save(), "armory": s.armory.to_save(), "log": _log.duplicate(),
			"character": s.character.to_save()})
	assert_eq(results[0], results[1])
