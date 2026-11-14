extends GutTest
## F-141 (docs/02_FORMULAS.md §5j) with a stand-in for the combat engine: the order of the refusals of `open`, the phases and
## the signals of a whole run (ingress, five forks, the boss in three stages), the commands at each phase, leaving, fleeing,
## dying, the pause and the state for the UI. The fights themselves are the engine's (M22-05).

var _s: GameSession = null
var _engine: DungeonEngineDouble = null
var _log: Array = []


func before_each() -> void:
	_s = autofree(TestFactory.session(31))
	_engine = DungeonEngineDouble.attach(_s)
	_log = []
	var ev: GameEvents = _s.events
	ev.dungeon_opened.connect(func(id: StringName) -> void: _log.append(["opened", id]))
	ev.dungeon_room_entered.connect(func(layer: int, kind: StringName) -> void: _log.append(["entered", layer, kind]))
	ev.dungeon_choice_ready.connect(func(kind: StringName, count: int) -> void: _log.append(["choice", kind, count]))
	ev.dungeon_stage_started.connect(func(stage: int, _m: StringName) -> void: _log.append(["stage_started", stage]))
	ev.dungeon_stage_cleared.connect(func(stage: int) -> void: _log.append(["stage_cleared", stage]))
	ev.dungeon_finished.connect(func(o: StringName, rooms: int, _p: int) -> void: _log.append(["finished", o, rooms]))
	ev.dungeon_loot_lost.connect(func(_a: int, _b: int, _c: int) -> void: _log.append(["lost"]))
	ev.dungeon_paused_changed.connect(func(p: bool) -> void: _log.append(["paused", p]))


func _count(name: String) -> int:
	return _log.filter(func(entry: Array) -> bool: return entry[0] == name).size()


func _to_boss() -> void:
	_engine.open_and_clear_entrance()
	_engine.walk_to_boss()


# --- open --------------------------------------------------------------------------------------------------------------

func test_open_refuses_in_the_order_of_the_contract() -> void:
	assert_eq(_s.dungeon.open(&"nope").reason, Reasons.UNKNOWN_ID)
	var s2: GameSession = autofree(TestFactory.session(3))
	s2.bank.add(&"test_den_ticket", 1)
	s2.dungeon.use_engine(DungeonEngineDouble.new(s2))
	assert_eq(s2.dungeon.open(&"test_den").reason, Reasons.REQUIREMENT_NOT_MET, "level 1 < 35")
	assert_true(_s.dungeon.open(&"test_den").ok)
	assert_eq(_s.dungeon.open(&"test_den").reason, Reasons.DUNGEON_ACTIVE)
	assert_eq(_s.dungeon.can_open(&"test_den"), Reasons.DUNGEON_ACTIVE)


func test_open_without_a_ticket_and_with_a_pending_bag() -> void:
	_s.bank.remove(&"test_den_ticket", 3)
	assert_eq(_s.dungeon.open(&"test_den").reason, Reasons.NOT_ENOUGH_ITEMS)
	assert_eq(_s.dungeon.tickets(&"test_den"), 0)
	assert_false(_s.dungeon.is_active(), "nothing changed")
	_s.bank.add(&"test_den_ticket", 1)
	_s.dungeon.from_save({"pending": {"stacks": [{"item": "test_log", "qty": 2}], "pieces": [], "cards": []}})
	assert_eq(_s.dungeon.open(&"test_den").reason, Reasons.DUNGEON_BAG_PENDING)


func test_open_consumes_the_ticket_and_starts_in_the_entrance() -> void:
	assert_true(_s.dungeon.open(&"test_den").ok)
	assert_eq(_s.dungeon.tickets(&"test_den"), 2, "one ticket gone, never given back")
	var run: DungeonRun = _s.dungeon.run()
	assert_eq([run.layer, run.index, run.phase, run.stage, run.paused, run.cleared], [0, 0, &"fight", 0, false, 0])
	assert_between(run.seed_value, 1, 2147483647)
	assert_eq(run.map.layers(), 7, "forks + 2")
	assert_eq(_engine.calls[0], ["start"])
	assert_eq(_engine.rooms.size(), 1)
	assert_eq(_engine.rooms[0]["kind"], &"entrance")
	assert_eq((_engine.rooms[0]["ids"] as Array).size(), 6, "the entrance has six monsters")
	assert_eq(_log[0], ["opened", &"test_den"])
	assert_eq(_log[1], ["entered", 0, &"entrance"])


func test_the_seed_comes_from_the_generator_of_the_slot() -> void:
	var other: GameSession = autofree(TestFactory.session(31))
	var expected: int = other.rng.randi_range(1, 2147483647)
	_s.dungeon.open(&"test_den")
	assert_eq(_s.dungeon.run().seed_value, expected)


func test_a_failed_start_gives_the_ticket_back() -> void:
	_engine.start_result = CommandResult.fail(Reasons.FRACTURE_ACTIVE)
	assert_eq(_s.dungeon.open(&"test_den").reason, Reasons.FRACTURE_ACTIVE)
	assert_eq(_s.dungeon.tickets(&"test_den"), 3)
	assert_false(_s.dungeon.is_active())


# --- the whole run -----------------------------------------------------------------------------------------------------

func test_a_whole_run_emits_the_signals_of_f_141() -> void:
	_to_boss()
	assert_eq(_count("entered"), 6, "ingress and five forks before the boss")
	var run: DungeonRun = _s.dungeon.run()
	assert_eq([run.stage, run.phase, run.layer, run.cleared], [1, &"intro", 6, 6])
	assert_eq(_engine.calls[_engine.calls.size() - 1], ["stage", &"right_hand"])
	for stage: int in [1, 2, 3]:
		assert_eq(_s.dungeon.run().phase, &"intro")
		_engine.end_intro()
		assert_eq(_s.dungeon.run().phase, &"fight")
		_engine.clear_stage()
	assert_false(_s.dungeon.is_active())
	assert_eq(_count("stage_started"), 3)
	assert_eq(_count("stage_cleared"), 3)
	assert_true(_log.has(["finished", &"won", 7]))
	assert_eq(_s.dungeon.wins(&"test_den"), 1)
	assert_eq(_s.dungeon.wins(), 1)
	assert_eq(_engine.returned_to, [&""] as Array[StringName], "the engine heard the end while the run was readable")
	var stages: Array = _engine.calls.filter(func(c: Array) -> bool: return c[0] == "stage").map(func(c: Array) -> StringName: return c[1])
	assert_eq(stages, [&"right_hand", &"strategist", &"king"])


func test_the_return_area_is_the_area_being_fought() -> void:
	_s.combat.start(&"test_area")
	assert_true(_s.dungeon.open(&"test_den").ok)
	assert_eq(_s.dungeon.run().return_area, &"test_area")


func test_the_choices_at_a_fork_are_two_to_four_directions() -> void:
	_engine.open_and_clear_entrance()
	var state: Dictionary = _s.dungeon.state()
	assert_eq(state["phase"], &"await")
	var choices: Array = state["choices"]
	assert_between(choices.size(), 2, 4)
	var seen: Dictionary = {}
	for choice: Dictionary in choices:
		assert_eq(choice["id"], &"exit")
		assert_false(seen.has(choice["direction"]), "distinct directions")
		seen[choice["direction"]] = true
	assert_eq(_log[_log.size() - 1], ["choice", &"fork", choices.size()])


func test_choose_enters_the_room_behind_the_exit() -> void:
	_engine.open_and_clear_entrance()
	var run: DungeonRun = _s.dungeon.run()
	var room: DungeonRoom = run.map.room(0, 0)
	var last: int = room.exits.size() - 1
	assert_true(_s.dungeon.choose(last).ok)
	assert_eq([run.layer, run.index], [1, room.exits[last]])
	assert_eq(run.path, [Vector2i(0, 0)] as Array[Vector2i])


func test_the_commands_refuse_out_of_phase() -> void:
	assert_eq(_s.dungeon.choose(0).reason, Reasons.NO_DUNGEON)
	assert_eq(_s.dungeon.leave().reason, Reasons.NO_DUNGEON)
	assert_eq(_s.dungeon.flee().reason, Reasons.NO_DUNGEON)
	assert_eq(_s.dungeon.resume().reason, Reasons.NO_DUNGEON)
	_s.dungeon.open(&"test_den")
	assert_eq(_s.dungeon.choose(0).reason, Reasons.NOT_AWAITING, "a fight")
	assert_eq(_s.dungeon.leave().reason, Reasons.NOT_AWAITING, "never during a fight")
	assert_eq(_s.dungeon.resume().reason, Reasons.NOT_PAUSED)
	_engine.clear_room()
	assert_eq(_s.dungeon.flee().reason, Reasons.NOT_FIGHTING, "at a fork it is `leave`")
	assert_eq(_s.dungeon.choose(9).reason, Reasons.INVALID_CHOICE)
	assert_eq(_s.dungeon.choose(-1).reason, Reasons.INVALID_CHOICE)


func test_a_paused_run_accepts_nothing_but_resume() -> void:
	_engine.open_and_clear_entrance()
	_s.dungeon.from_save(_s.dungeon.to_save())
	assert_true(_s.dungeon.run().paused, "a loaded run is always paused")
	assert_eq(_s.dungeon.choose(0).reason, Reasons.DUNGEON_PAUSED)
	assert_eq(_s.dungeon.leave().reason, Reasons.DUNGEON_PAUSED)
	assert_eq(_s.dungeon.flee().reason, Reasons.DUNGEON_PAUSED)
	assert_false(_s.dungeon.state()["can_leave"])
	assert_true(_s.dungeon.resume().ok)
	assert_false(_s.dungeon.run().paused)
	assert_eq(_engine.calls[_engine.calls.size() - 1], ["pause", false])
	assert_eq(_log[_log.size() - 1], ["paused", false])
	assert_true(_s.dungeon.state()["can_leave"])
	assert_true(_s.dungeon.choose(0).ok)


# --- the ways out ------------------------------------------------------------------------------------------------------

func test_leaving_at_a_fork_delivers_the_bag_without_the_boss() -> void:
	_engine.open_and_clear_entrance()
	_s.dungeon.run().bag.add_stack(&"test_log", 4)
	var gold: int = _s.wallet.get_gold()
	assert_true(_s.dungeon.leave().ok)
	assert_false(_s.dungeon.is_active())
	assert_eq(_s.bank.get_count(&"test_log"), 4)
	assert_eq(_s.wallet.get_gold(), gold, "no boss gold")
	assert_eq(_log[_log.size() - 1], ["finished", &"left", 1])
	assert_eq(_s.dungeon.wins(), 0, "not a win")
	assert_false(_s.dungeon.has_pending())
	assert_eq(_s.dungeon.tickets(&"test_den"), 2, "the ticket stays spent")


func test_fleeing_is_a_defeat_decided_by_the_engine() -> void:
	_s.dungeon.open(&"test_den")
	_s.dungeon.run().bag.add_stack(&"test_log", 4)
	assert_true(_s.dungeon.flee().ok)
	assert_eq(_engine.calls[_engine.calls.size() - 1], ["abandon", &"fled"])
	assert_false(_s.dungeon.is_active())
	assert_eq(_s.bank.get_count(&"test_log"), 0, "the bag is lost")
	assert_eq(_count("lost"), 1)


func test_flee_is_allowed_during_the_boss_intro() -> void:
	_to_boss()
	assert_eq(_s.dungeon.run().phase, &"intro")
	assert_true(_s.dungeon.flee().ok)
	assert_false(_s.dungeon.is_active())


func test_death_loses_the_bag_and_the_ticket() -> void:
	_to_boss()
	_s.dungeon.run().bag.add_stack(&"test_log", 4)
	_engine.die()
	assert_false(_s.dungeon.is_active())
	assert_eq(_s.bank.get_count(&"test_log"), 0)
	assert_eq(_count("lost"), 1)
	assert_eq(_s.dungeon.tickets(&"test_den"), 2)
	assert_false(_s.dungeon.has_pending())
	assert_eq(_s.dungeon.wins(), 0)


# --- the state for the UI ----------------------------------------------------------------------------------------------

func test_state_is_empty_outside_a_run_and_never_names_the_next_rooms() -> void:
	assert_eq(_s.dungeon.state(), {})
	_engine.open_and_clear_entrance()
	var state: Dictionary = _s.dungeon.state()
	assert_eq(state["dungeon"], &"test_den")
	assert_eq(state["progress"], {"done": 1, "total": 7})
	assert_eq(state["room"]["kind"], &"entrance", "the kind of the room we are in")
	assert_false(state.has("stage"))
	for choice: Dictionary in state["choices"]:
		assert_eq(choice.keys().size(), 2, "id and direction only")
		assert_false(choice.has("kind"))
	assert_true(state["can_leave"])


func test_state_during_the_boss_scene() -> void:
	_to_boss()
	_engine.intro_left_ms = 1200
	var stage: Dictionary = _s.dungeon.state()["stage"]
	assert_eq([stage["index"], stage["id"], stage["intro_ms"], stage["intro_left_ms"]], [1, &"right_hand", 3500, 1200])
	assert_eq(stage["title"], "Il Braccio Destro")
	assert_eq([stage["count"], stage["monster"]], [3, &"tden_right_hand"])
	var acts: Array = stage["acts"]
	assert_eq(acts.size(), 3)
	assert_eq(acts[0]["id"], &"right_hand")
	assert_eq(acts[0]["monster"], &"tden_right_hand")
	assert_eq(acts[0]["name"], _s.data.dungeon(&"test_den").monster_def(&"tden_right_hand").name)
	_engine.end_intro()
	assert_eq(_s.dungeon.state()["stage"]["intro_left_ms"], 0)
	assert_false(_s.dungeon.state()["can_leave"], "never during a fight")
