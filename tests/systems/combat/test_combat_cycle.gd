extends GutTest
## The cycle of the encounters in the engine (docs/05_INTERFACES_M24.md §5.33, F-153..F-155): fight -> journey -> fight or node -> journey,
## the node worked or skipped, stop and save at every state, the equivalence of the steps, the way back from a dungeon.
## Real data, an overpowered hero in `redrock_plains` (the node entries of the area are reduced to forestry so the kind is known).

const AREA: StringName = &"redrock_plains"
const SWORD: StringName = &"emberbronze_sword"
const FORESTRY: StringName = &"forestry"
const LOG_ITEM: StringName = &"redbirch_log"
const SEED: int = 31337
const HERO: StringName = &"test:hero"


func _data(node_chance: float) -> GameData:
	var data: GameData = GameData.load_from_dirs(TestFactory.REAL_CONTENT_ROOT, TestFactory.CONFIG_ROOT)
	((data.get("_balance") as Dictionary)["encounters"] as Dictionary)["node_chance_pct"] = node_chance
	((data.get("_balance") as Dictionary)["miniboss"] as Dictionary)["chance_pct"] = 0.0
	((data.get("_balance") as Dictionary)["encounters"] as Dictionary)["rich_chance_pct"] = 0  # a normal node: 3 attempts, 80 units
	((data.get("_balance") as Dictionary)["encounters"] as Dictionary)["yield_free_levels"] = 99  # yield 100
	var entry := NodeEntryDef.new()
	entry.skill = FORESTRY
	entry.weight = 1
	entry.difficulty = 10
	entry.min_level = 1
	data.area_nodes(AREA).entries = [entry]
	return data


func _session(node_chance: float, learned: bool = true, seed_value: int = SEED) -> GameSession:
	var s: GameSession = autofree(TestFactory.session_no_kit(seed_value, _data(node_chance)))
	s.disciplines._grades.clear()
	if learned:
		TestFactory.learn_discipline(s, FORESTRY)
	TestFactory.set_character_level(s, 65)
	assert_true(s.equipment.equip(TestFactory.give_piece(s, SWORD)).ok)
	s.modifiers.set_source(HERO, [Modifier.make(&"power_bonus", 100000.0), Modifier.make(&"max_hp_flat", 100000.0),
			Modifier.make(&"armor", 100000.0), Modifier.make(&"evasion_bonus", 80000.0)])
	s.set_meta("room", TestFactory.make_roomy(s))
	return s


# Advance 100 ms at a time until `done` or 600 s.
func _until(s: GameSession, done: Callable) -> void:
	var guard: int = 0
	while not done.call() and guard < 6000:
		s.combat.advance(100)
		guard += 1
	assert_true(done.call(), "the state was reached")


func _is(s: GameSession, state: StringName) -> Callable:
	return func() -> bool: return s.combat.state() == state


# --- the cycle -------------------------------------------------------------------------------------------------------

func test_the_first_encounter_is_a_fight_with_no_journey() -> void:
	var s: GameSession = _session(100.0)
	watch_signals(s.events)
	assert_true(s.combat.start(AREA).ok)
	assert_eq(s.combat.state(), CombatEngine.STATE_ENCOUNTER)
	assert_signal_not_emitted(s.events, "travel_started")


func test_a_cleared_fight_starts_a_journey_to_the_node_and_the_node_is_worked() -> void:
	var s: GameSession = _session(100.0)
	s.combat.start(AREA)
	watch_signals(s.events)
	_until(s, _is(s, CombatEngine.STATE_TRAVEL))
	var travel_ms: int = int(s.data.balance_value("encounters.travel_ms"))
	assert_signal_emitted_with_parameters(s.events, "travel_started", [&"node", FORESTRY, travel_ms])
	var view: Dictionary = s.combat.get_state()
	assert_eq(view["next"], {"kind": &"node", "skill": FORESTRY})
	assert_eq(view["travel_total_ms"], travel_ms)
	_until(s, _is(s, CombatEngine.STATE_NODE))
	assert_signal_emitted_with_parameters(s.events, "node_started", [FORESTRY, &"cut_redbirch", false, 12000])
	assert_eq(s.combat.node_skill(), FORESTRY)
	var node_view: Dictionary = s.combat.get_state()["node"]
	assert_eq([node_view["skill"], node_view["skipped"], node_view["color"], node_view["units"]], [FORESTRY, false, &"orange", 0])
	assert_eq([node_view["attempts"], node_view["attempt"], node_view["rich"], node_view["units_planned"]], [3, 0, false, 80])
	var bank_before: int = s.bank.get_count(LOG_ITEM)
	s.combat.advance(3999)
	assert_eq(s.combat.state(), CombatEngine.STATE_NODE)
	assert_eq(s.bank.get_count(LOG_ITEM), bank_before, "nothing before the first attempt")
	watch_signals(s.events)
	s.combat.advance(1)
	assert_signal_emitted_with_parameters(s.events, "node_attempt_done", [FORESTRY, &"cut_redbirch", 1, 3, 26, 26, &"orange"])
	assert_eq(s.bank.get_count(LOG_ITEM), bank_before + 26)
	assert_eq(s.combat.get_state()["node"]["last_attempt"]["units"], 26)
	s.combat.advance(7999)
	assert_eq(s.combat.state(), CombatEngine.STATE_NODE)
	assert_eq(s.bank.get_count(LOG_ITEM), bank_before + 53, "two attempts are in")
	s.combat.advance(1)
	assert_eq(s.combat.state(), CombatEngine.STATE_TRAVEL)
	assert_gte(s.bank.get_count(LOG_ITEM), bank_before + 80)
	assert_signal_emitted_with_parameters(s.events, "node_finished", [FORESTRY, &"cut_redbirch", 80, Reasons.NODE_DONE])
	assert_signal_emit_count(s.events, "node_attempt_done", 3)
	assert_signal_emit_count(s.events, "action_completed", 3, "one per attempt")
	assert_signal_emitted_with_parameters(s.events, "travel_started", [&"node", FORESTRY, travel_ms])
	assert_eq(get_signal_parameters(s.events, "action_completed")[0], ActionRunner.NODE)
	assert_eq(s.combat.node_counts(), {"worked": 1, "skipped": 0})
	assert_eq(s.combat.node_skill(), &"", "no node in progress")


func test_a_node_of_an_unlearned_discipline_is_skipped_and_gives_nothing() -> void:
	var s: GameSession = _session(100.0, false)
	s.combat.start(AREA)
	_until(s, _is(s, CombatEngine.STATE_NODE))
	watch_signals(s.events)
	var rng_before: Dictionary = s.rng.to_save()
	var view: Dictionary = s.combat.get_state()["node"]
	assert_true(view["skipped"])
	assert_eq(view["duration_ms"], int(s.data.balance_value("encounters.skip_ms")))
	assert_eq(s.combat.node_skill(), &"", "a skipped node is not a discipline at work")
	var logs: int = s.bank.get_count(LOG_ITEM)
	s.combat.advance(int(view["duration_ms"]) - int(view["elapsed_ms"]))
	assert_signal_emitted_with_parameters(s.events, "node_finished", [FORESTRY, &"cut_redbirch", 0, Reasons.NOT_LEARNED])
	assert_signal_not_emitted(s.events, "action_completed")
	assert_signal_not_emitted(s.events, "xp_gained")
	assert_eq(s.bank.get_count(LOG_ITEM), logs)
	assert_eq(s.combat.node_counts(), {"worked": 0, "skipped": 1})
	assert_eq(s.rng.to_save(), rng_before, "a skipped node rolls nothing (a single entry area picks without a draw)")


func test_chance_zero_never_gives_a_node() -> void:
	var s: GameSession = _session(0.0)
	watch_signals(s.events)
	s.combat.start(AREA)
	for i: int in 3000:
		s.combat.advance(100)
	assert_signal_not_emitted(s.events, "node_started")
	assert_gt(s.combat.total_kills().size(), 0)


func test_a_pending_miniboss_is_a_fight_even_with_chance_one_hundred() -> void:
	var s: GameSession = _session(100.0)
	s.combat.start(AREA)
	s.combat._miniboss_pending = true
	_until(s, _is(s, CombatEngine.STATE_TRAVEL))
	assert_eq(s.combat.get_state()["next"]["kind"], &"fight", "forced, no roll")


func test_a_full_deposit_closes_the_node_with_bank_full() -> void:
	var s: GameSession = _session(100.0)
	s.combat.start(AREA)
	_until(s, _is(s, CombatEngine.STATE_NODE))
	(s.get_meta("room") as Array[int])[0] = 0
	for item: ItemDef in s.data.items():  # no free box and no log: not even the first unit fits
		if s.bank.free_boxes() > 0 and item.id != LOG_ITEM and s.bank.can_add(item.id):
			s.bank.add(item.id, 1)
	watch_signals(s.events)
	var remaining: int = int(s.combat.get_state()["node"]["duration_ms"]) - int(s.combat.get_state()["node"]["elapsed_ms"])
	s.combat.advance(remaining)
	assert_signal_emitted_with_parameters(s.events, "node_finished", [FORESTRY, &"cut_redbirch", 0, Reasons.BANK_FULL])
	assert_signal_not_emitted(s.events, "action_completed")


func test_a_level_below_the_minimum_skips_the_node_as_too_hard() -> void:
	var s: GameSession = _session(100.0)
	s.data.area_nodes(AREA).entries[0].min_level = 5
	s.combat.start(AREA)
	_until(s, _is(s, CombatEngine.STATE_NODE))
	var view: Dictionary = s.combat.get_state()["node"]
	assert_true(view["skipped"])
	assert_eq(view["skip_reason"], Reasons.TOO_HARD)
	watch_signals(s.events)
	s.combat.advance(int(view["duration_ms"]))
	assert_signal_emitted_with_parameters(s.events, "node_finished", [FORESTRY, &"cut_redbirch", 0, Reasons.TOO_HARD])
	assert_signal_not_emitted(s.events, "node_attempt_done")
	assert_eq(s.combat.node_counts(), {"worked": 0, "skipped": 1})


func test_a_stop_in_the_middle_keeps_the_attempts_already_resolved() -> void:
	# Q129: what is already in the Deposit stays; the attempts not resolved are lost and the node is not counted.
	var s: GameSession = _session(100.0)
	s.combat.start(AREA)
	_until(s, _is(s, CombatEngine.STATE_NODE))
	var before: int = s.bank.get_count(LOG_ITEM)
	s.combat.advance(8000)
	assert_eq(s.bank.get_count(LOG_ITEM), before + 53)
	s.combat.stop()
	assert_eq(s.bank.get_count(LOG_ITEM), before + 53)
	assert_eq(s.combat.node_counts(), {"worked": 0, "skipped": 0})


func test_a_node_in_the_middle_is_saved_and_loaded_with_its_attempts() -> void:
	var s: GameSession = _session(100.0)
	s.combat.start(AREA)
	_until(s, _is(s, CombatEngine.STATE_NODE))
	s.combat.advance(5000)
	var saved: Dictionary = s.combat.to_save()
	assert_eq([saved["node"]["attempts"], saved["node"]["attempt"], saved["node"]["rich"], saved["node"]["units"]], [3, 1, false, 26])
	var other: GameSession = _session(100.0, true, SEED + 1)
	other.combat.from_save(saved)
	assert_eq(other.combat.to_save(), saved)
	other.combat.advance(3000)
	assert_eq(other.combat.get_state()["node"]["attempt"], 2)


func test_discipline_busy_only_while_a_worked_node_runs() -> void:
	var s: GameSession = _session(100.0)
	s.combat.start(AREA)
	_until(s, _is(s, CombatEngine.STATE_TRAVEL))
	assert_ne(s.disciplines.can_unlearn(FORESTRY).reason, Reasons.DISCIPLINE_BUSY, "a journey is not a node")
	_until(s, _is(s, CombatEngine.STATE_NODE))
	var result: CommandResult = s.disciplines.can_unlearn(FORESTRY)
	assert_false(result.ok)
	assert_eq(result.reason, Reasons.DISCIPLINE_BUSY)
	var before: Dictionary = s.disciplines.to_save()
	assert_eq(s.disciplines.unlearn(FORESTRY).reason, Reasons.DISCIPLINE_BUSY)
	assert_eq(s.disciplines.to_save(), before, "a refusal changes nothing")


# --- stop, Fractures and dungeons --------------------------------------------------------------------------------------

func test_stop_during_the_journey_and_the_node_loses_the_node_without_products() -> void:
	for state: StringName in [CombatEngine.STATE_TRAVEL, CombatEngine.STATE_NODE]:
		var s: GameSession = _session(100.0)
		s.combat.start(AREA)
		_until(s, _is(s, state))
		var logs: int = s.bank.get_count(LOG_ITEM)
		watch_signals(s.events)
		s.combat.stop()
		assert_eq(s.combat.state(), CombatEngine.STATE_IDLE)
		assert_signal_emitted_with_parameters(s.events, "combat_stopped", [Reasons.STOPPED_BY_USER])
		assert_eq(s.bank.get_count(LOG_ITEM), logs)
		assert_eq(s.combat.node_counts(), {"worked": 0, "skipped": 0}, "%s: a lost node is not counted" % state)
		assert_eq(s.combat.get_state()["node"], {})
		assert_eq(s.combat.get_state()["next"], {})


func test_replacing_the_fight_loses_the_node() -> void:
	# `start_fracture` and `start_dungeon` stop the fight in the area with `replaced`: the node in progress is lost without products.
	var s: GameSession = _session(100.0)
	s.combat.start(AREA)
	_until(s, _is(s, CombatEngine.STATE_NODE))
	s.combat.stop(Reasons.REPLACED)
	assert_eq(s.combat.node_counts(), {"worked": 0, "skipped": 0})
	assert_eq(s.combat.state(), CombatEngine.STATE_IDLE)


# --- save ------------------------------------------------------------------------------------------------------------

func test_save_load_save_is_identical_in_idle_travel_and_node() -> void:
	var s: GameSession = _session(100.0)
	for state: StringName in [CombatEngine.STATE_IDLE, CombatEngine.STATE_TRAVEL, CombatEngine.STATE_NODE]:
		if state != CombatEngine.STATE_IDLE:
			if not s.combat.is_active():
				s.combat.start(AREA)
			_until(s, _is(s, state))
			s.combat.advance(700)
		var saved: Dictionary = s.combat.to_save()
		assert_eq(saved["state"], String(state))
		var other: GameSession = _session(100.0)
		other.combat.from_save(saved)
		assert_eq(other.combat.state(), state)
		assert_eq(other.combat.to_save(), saved, "save -> load -> save: %s" % state)
		assert_eq(other.combat.get_state()["node"], s.combat.get_state()["node"])
		assert_eq(other.combat.get_state()["travel_ms"], s.combat.get_state()["travel_ms"])
		if state == CombatEngine.STATE_NODE:
			assert_eq(saved["travel_ms"], 0)
			assert_eq(saved["next"], {})
			assert_eq((saved["node"] as Dictionary)["skill"], "forestry")
		elif state == CombatEngine.STATE_TRAVEL:
			assert_eq(saved["node"], {})
			assert_eq(saved["next"], {"kind": "node", "skill": "forestry"})
		else:
			assert_eq(saved["travel_ms"], 0)
			assert_eq(saved["next"], {})
			assert_eq(saved["node"], {})
		if state == CombatEngine.STATE_NODE:
			assert_eq(saved["nodes"], {"worked": 0, "skipped": 0})


func test_the_node_counters_survive_a_stop_and_a_save() -> void:
	var s: GameSession = _session(100.0)
	s.combat.start(AREA)
	_until(s, _is(s, CombatEngine.STATE_NODE))
	s.combat.advance(12000)
	s.combat.stop()
	var other: GameSession = _session(100.0)
	other.combat.from_save(s.combat.to_save())
	assert_eq(other.combat.node_counts(), {"worked": 1, "skipped": 0})


func test_a_saved_between_of_an_area_loads_as_a_full_journey_to_a_fight() -> void:
	var s: GameSession = _session(100.0)
	var saved: Dictionary = {"state": "between", "area": String(AREA), "player_hp": 50, "player_timer_ms": 0, "hand": 0, "between_ms": 400,
		"enemies": [], "abilities": {}, "buffs": {}, "loot": [], "kills": {}, "deaths": 0, "food_eaten": 0}
	s.combat.from_save(saved)
	assert_eq(s.combat.state(), CombatEngine.STATE_TRAVEL)
	var view: Dictionary = s.combat.get_state()
	assert_eq(view["travel_ms"], int(s.data.balance_value("encounters.travel_ms")))
	assert_eq(view["next"], {"kind": &"fight", "skill": &""})
	s.combat.advance(int(view["travel_ms"]))
	assert_eq(s.combat.state(), CombatEngine.STATE_ENCOUNTER)


func test_a_malformed_next_or_node_loads_as_a_full_journey_to_a_fight() -> void:
	var s: GameSession = _session(100.0)
	var base: Dictionary = {"player_hp": 50, "player_timer_ms": 0, "hand": 0, "between_ms": 0, "enemies": [], "abilities": {},
		"buffs": {}, "loot": [], "kills": {}, "deaths": 0, "food_eaten": 0, "area": String(AREA)}
	var bad: Array[Dictionary] = [
		{"state": "travel", "travel_ms": 900, "next": {"kind": "node", "skill": "no_such"}, "node": {}},
		{"state": "travel", "travel_ms": 900, "next": "x", "node": {}},
		{"state": "node", "travel_ms": 0, "next": {}, "node": {"skill": "forestry", "action": "nope", "elapsed_ms": 1, "duration_ms": 5, "skipped": false}},
		{"state": "node", "travel_ms": 0, "next": {}, "node": 5},
	]
	for extra: Dictionary in bad:
		var d: Dictionary = base.duplicate()
		d.merge(extra)
		s.combat.from_save(d)
		assert_eq(s.combat.state(), CombatEngine.STATE_TRAVEL, str(extra))
		assert_eq(s.combat.get_state()["next"]["kind"], &"fight")
		assert_eq(s.combat.get_state()["travel_ms"], int(s.data.balance_value("encounters.travel_ms")))
	var ok: Dictionary = base.duplicate()
	ok.merge({"state": "travel", "travel_ms": 900, "next": {"kind": "node", "skill": "forestry"}, "node": {}})
	s.combat.from_save(ok)
	assert_eq(s.combat.get_state()["travel_ms"], 900)
	assert_eq(s.combat.get_state()["next"], {"kind": &"node", "skill": FORESTRY})


func test_an_unknown_area_in_a_saved_journey_leaves_the_engine_idle() -> void:
	var s: GameSession = _session(100.0)
	s.combat.from_save({"state": "travel", "area": "no_such_area", "travel_ms": 500, "next": {}, "node": {}, "enemies": []})
	assert_eq(s.combat.state(), CombatEngine.STATE_IDLE)


# --- the steps ---------------------------------------------------------------------------------------------------------

func test_one_step_of_1000_ms_equals_ten_of_100_ms_with_journeys_and_nodes() -> void:
	var coarse: GameSession = _session(50.0, true, 8)
	var fine: GameSession = _session(50.0, true, 8)
	coarse.combat.start(AREA)
	fine.combat.start(AREA)
	for i: int in 400:
		coarse.combat.advance(1000)
		for j: int in 10:
			fine.combat.advance(100)
	assert_eq(coarse.combat.to_save(), fine.combat.to_save())
	assert_eq(coarse.bank.get_count(LOG_ITEM), fine.bank.get_count(LOG_ITEM))
	assert_eq(coarse.rng.to_save(), fine.rng.to_save())
	assert_gt(coarse.combat.node_counts()["worked"], 3, "the run really worked nodes")
	assert_gt(coarse.bank.get_count(LOG_ITEM), 100)
