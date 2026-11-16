extends GutTest
## The node in progress with its attempts (NodeWork; F-161..F-164, docs/02_FORMULAS_M25.md): begin, rich roll, `too_hard`, xp and
## mastery per attempt, the yield, the Deposit full in the middle, the save. Real data: Betulla (`cut_redbirch`, xp 10, level 1).

const FORESTRY: StringName = &"forestry"
const QUARRYING: StringName = &"quarrying"
const BETULLA: StringName = &"cut_redbirch"
const LOG_ITEM: StringName = &"redbirch_log"
const AREA: StringName = &"redrock_plains"


## Rolls false except the scripted indexes; counts the calls.
class ScriptedRng extends RngService:
	var calls: int = 0
	var true_calls: Array[int] = []

	func _init() -> void:
		super(1)

	func roll_pct(_chance_pct: float) -> bool:
		calls += 1
		return true_calls.has(calls - 1)


func _session() -> GameSession:
	var s: GameSession = autofree(TestFactory.session_no_kit(77, GameData.load_from_dirs(TestFactory.REAL_CONTENT_ROOT, TestFactory.CONFIG_ROOT)))
	s.disciplines._grades.clear()  # the factory learns some disciplines: only forestry here
	_enc(s, "rich_chance_pct", 0)  # a normal node unless the test says otherwise (F-164)
	_enc(s, "yield_free_levels", 99)  # yield 100 unless the test says otherwise (F-162)
	TestFactory.learn_discipline(s, FORESTRY)
	return s


func _enc(s: GameSession, key: String, value: Variant) -> void:
	((s.data.get("_balance") as Dictionary)["encounters"] as Dictionary)[key] = value


# A node of the Betulla whatever the level (the docs' examples of F-163: the resource is fixed at the start, here forced).
func _betulla_node(s: GameSession) -> NodeWork:
	var work: NodeWork = NodeWork.begin(s, AREA, FORESTRY)
	work.action_id = BETULLA
	return work


# Resolves every attempt; one row [units, color, xp, mastery_xp] each.
func _resolve_all(s: GameSession, work: NodeWork) -> Array:
	var rows: Array = []
	while not work.is_complete():
		var out: ActionOutcome = work.resolve_attempt(s)
		rows.append([out.units, work.last_attempt["color"], out.xp, out.mastery_xp])
	return rows


func _units_of(rows: Array) -> Array:
	var units: Array = []
	for row: Array in rows:
		units.append(row[0])
	return units


# --- begin (F-161, F-164) ------------------------------------------------------------------------------------------

func test_begin_fixes_the_resource_the_duration_and_the_attempts_of_a_normal_node() -> void:
	var s: GameSession = _session()
	var work: NodeWork = NodeWork.begin(s, AREA, FORESTRY)
	assert_false(work.skipped)
	assert_eq(work.action_id, BETULLA)
	assert_eq([work.duration_ms, work.elapsed_ms, work.attempts, work.attempt, work.rich, work.units], [12000, 0, 3, 0, false, 0])
	assert_eq(work.difficulty, s.data.area_nodes(AREA).max_level)


func test_a_rich_node_has_five_attempts_and_lasts_eighteen_seconds() -> void:
	var s: GameSession = _session()
	_enc(s, "rich_chance_pct", 100)
	var work: NodeWork = NodeWork.begin(s, AREA, FORESTRY)
	assert_true(work.rich)
	assert_eq([work.attempts, work.duration_ms], [5, 18000])
	assert_eq(work.action_id, BETULLA, "the resource of a rich node is the normal one")


func test_the_rich_roll_is_one_per_worked_node_even_with_a_zero_chance_and_none_for_a_skipped_one() -> void:
	var s: GameSession = _session()
	var rng := ScriptedRng.new()
	s.rng = rng
	NodeWork.begin(s, AREA, FORESTRY)
	assert_eq(rng.calls, 1, "a worked node rolls once, whatever the chance")
	NodeWork.begin(s, AREA, QUARRYING)
	assert_eq(rng.calls, 1, "a skipped node rolls nothing")


func test_a_discipline_not_learned_is_skipped_for_skip_ms_and_gives_nothing() -> void:
	var s: GameSession = _session()
	var work: NodeWork = NodeWork.begin(s, AREA, QUARRYING)
	assert_true(work.skipped)
	assert_eq([work.skip_reason, work.attempts], [Reasons.NOT_LEARNED, 0])
	assert_eq(work.duration_ms, int(s.data.balance_value("encounters.skip_ms")))
	assert_eq(s.data.action(work.action_id).skill_id, QUARRYING, "it shows the resource that would have been worked")
	var rng_before: Dictionary = s.rng.to_save()
	watch_signals(s.events)
	var out: ActionOutcome = work.resolve_attempt(s)
	assert_false(out.ok)
	assert_eq(out.units, 0)
	assert_true(out.outputs.is_empty())
	assert_eq(s.rng.to_save(), rng_before, "a skipped node rolls nothing")
	assert_eq(work.next_event_ms(), work.duration_ms)
	assert_signal_not_emitted(s.events, "xp_gained")
	assert_signal_not_emitted(s.events, "bank_changed")


func test_a_level_below_the_minimum_skips_the_node_as_too_hard() -> void:
	var s: GameSession = _session()
	s.data.area_nodes(AREA).entries[0].min_level = 5  # forestry, level 1
	var rng_before: Dictionary = s.rng.to_save()
	var work: NodeWork = NodeWork.begin(s, AREA, FORESTRY)
	assert_true(work.skipped)
	assert_eq(work.skip_reason, Reasons.TOO_HARD)
	assert_eq(work.duration_ms, int(s.data.balance_value("encounters.skip_ms")))
	assert_eq(s.rng.to_save(), rng_before, "no rich roll for a skipped node")
	TestFactory.set_level(s, FORESTRY, 5)
	assert_false(NodeWork.begin(s, AREA, FORESTRY).skipped, "the level equal to the minimum works")


# --- attempts (F-162, F-163) ---------------------------------------------------------------------------------------

func test_orange_attempts_give_260_270_270_xp_and_the_mastery_of_each_attempt() -> void:
	var s: GameSession = _session()
	var work: NodeWork = _betulla_node(s)
	var action: ActionDef = s.data.action(BETULLA)
	var rows: Array = []
	var expected_mastery: Array = []
	for k: int in 3:
		# F-10 with the mastery level and the ratio before the gain of the attempt (the docs quote 3 per unit: true for the first)
		var per_unit: int = MasteryMath.mastery_xp(action.interval_ms, s.mastery.get_mastery_level(BETULLA), s.mastery.get_skill_ratio(FORESTRY),
				0.0, s.data)
		var out: ActionOutcome = work.resolve_attempt(s)
		rows.append([out.units, work.last_attempt["color"], out.xp])
		expected_mastery.append([out.mastery_xp, out.units * per_unit])
	assert_eq(rows, [[26, &"orange", 260], [27, &"orange", 270], [27, &"orange", 270]])
	assert_eq(expected_mastery[0], [78, 78], "26 units x F-10 (3)")
	for pair: Array in expected_mastery:
		assert_eq(pair[0], pair[1], "mastery = units x F-10 of that moment")
	assert_eq(s.bank.get_count(LOG_ITEM), 80)


func test_yellow_green_and_grey_attempts() -> void:
	var cases: Array = [[15, [130, 135, 135]], [25, [52, 54, 54]], [60, [0, 0, 0]]]
	for pair: Array in cases:
		var s: GameSession = _session()
		TestFactory.set_level(s, FORESTRY, pair[0])
		var xp: Array = []
		for row: Array in _resolve_all(s, _betulla_node(s)):
			xp.append(row[2])
		assert_eq(xp, pair[1], "level %d" % pair[0])


func test_a_level_up_in_the_middle_changes_the_color_of_the_next_attempts() -> void:
	var s: GameSession = _session()
	TestFactory.set_level(s, FORESTRY, 10)
	s.skills.add_xp(FORESTRY, s.data.xp_table().xp_for_level(11) - s.skills.get_xp(FORESTRY) - 100)
	assert_eq(s.skills.get_level(FORESTRY), 10)
	var rows: Array = _resolve_all(s, _betulla_node(s))
	assert_eq([rows[0][1], rows[1][1], rows[2][1]], [&"orange", &"yellow", &"yellow"])
	assert_eq([rows[0][2], rows[1][2], rows[2][2]], [260, 135, 135])


func test_a_lower_yield_gives_fewer_units_per_attempt() -> void:
	var s: GameSession = _session()
	_enc(s, "yield_free_levels", 5)
	TestFactory.set_level(s, FORESTRY, 60)  # grey for the resource: no xp, so the level is the same at every attempt
	var work: NodeWork = NodeWork.begin(s, AREA, FORESTRY)
	work.difficulty = 70  # gap 10: 80%
	assert_eq(work.yield_pct(s), 80)
	assert_eq(work.units_planned(s), 64)
	assert_eq(_units_of(_resolve_all(s, work)), [21, 21, 22])


func test_a_rich_node_gives_24_units_per_attempt() -> void:
	var s: GameSession = _session()
	_enc(s, "rich_chance_pct", 100)
	var work: NodeWork = NodeWork.begin(s, AREA, FORESTRY)
	assert_eq(work.units_planned(s), 120)
	assert_eq(_units_of(_resolve_all(s, work)), [24, 24, 24, 24, 24])
	assert_eq(work.units, 120)


func test_due_attempts_follow_the_elapsed_time_and_several_can_be_due_at_once() -> void:
	var s: GameSession = _session()
	var work: NodeWork = NodeWork.begin(s, AREA, FORESTRY)
	assert_eq([work.due_attempts(), work.next_event_ms()], [0, 4000])
	work.elapsed_ms = 4000
	assert_eq(work.due_attempts(), 1)
	work.elapsed_ms = 9000
	assert_eq(work.due_attempts(), 2)
	work.resolve_attempt(s)
	assert_eq(work.due_attempts(), 1)
	work.elapsed_ms = 12000
	assert_eq(work.due_attempts(), 2)


func test_a_full_deposit_in_the_middle_closes_the_node_and_keeps_what_is_in() -> void:
	var s: GameSession = _session()
	assert_true(s.bank.add(LOG_ITEM, 1).ok)
	for item: ItemDef in s.data.items():
		if s.bank.free_boxes() > 0 and item.id != &"rift_shard" and s.bank.can_add(item.id) and s.bank.get_count(item.id) == 0:
			s.bank.add(item.id, 1)
	var rng := ScriptedRng.new()
	s.rng = rng
	rng.true_calls = [74]  # call 0 is the rich roll; the shard of the 11th unit of the second attempt (53 + 2 x 10 + 1)
	var work: NodeWork = NodeWork.begin(s, AREA, FORESTRY)
	assert_true(work.resolve_attempt(s).ok)
	var second: ActionOutcome = work.resolve_attempt(s)
	assert_eq([second.ok, second.units, second.reason], [true, 10, Reasons.BANK_FULL])
	assert_true(work.closed)
	assert_true(work.is_complete())
	assert_eq([work.units, work.attempt, work.due_attempts()], [36, 2, 0])
	assert_eq(s.bank.get_count(LOG_ITEM), 37, "the logs of the two attempts and the first one")


# --- save ----------------------------------------------------------------------------------------------------------

func test_save_round_trip_of_a_rich_a_skipped_and_a_too_hard_node() -> void:
	var s: GameSession = _session()
	_enc(s, "rich_chance_pct", 100)
	var rich: NodeWork = NodeWork.begin(s, AREA, FORESTRY)
	rich.elapsed_ms = 7300
	rich.resolve_attempt(s)
	var back: NodeWork = NodeWork.from_save(rich.to_save(), s.data, AREA)
	assert_eq(back.to_save(), rich.to_save())
	assert_eq([back.rich, back.attempts, back.attempt, back.units, back.difficulty], [true, 5, 1, 24, rich.difficulty])
	var skipped: NodeWork = NodeWork.begin(s, AREA, QUARRYING)
	assert_eq(NodeWork.from_save(skipped.to_save(), s.data, AREA).to_save(), skipped.to_save())
	s.data.area_nodes(AREA).entries[0].min_level = 5
	var hard: NodeWork = NodeWork.begin(s, AREA, FORESTRY)
	assert_eq(NodeWork.from_save(hard.to_save(), s.data, AREA).skip_reason, Reasons.TOO_HARD)


func test_a_node_saved_by_m24_restarts_at_zero_attempts() -> void:
	var s: GameSession = _session()
	var old: Dictionary = {"skill": "forestry", "action": "cut_redbirch", "elapsed_ms": 9000, "duration_ms": 12000, "skipped": false}
	var work: NodeWork = NodeWork.from_save(old, s.data, AREA)
	assert_eq([work.elapsed_ms, work.attempt, work.rich, work.units, work.attempts, work.duration_ms], [0, 0, false, 0, 3, 12000])


func test_malformed_nodes_and_incoherent_attempts_are_refused() -> void:
	var s: GameSession = _session()
	var base: Dictionary = {"skill": "forestry", "action": "cut_redbirch", "elapsed_ms": 0, "duration_ms": 10, "skipped": false,
		"attempts": 3, "attempt": 1, "rich": false, "units": 26}
	assert_not_null(NodeWork.from_save(base, s.data, AREA))
	assert_null(NodeWork.from_save({}, s.data, AREA))
	assert_null(NodeWork.from_save({"skill": "forestry", "action": "no_such", "elapsed_ms": 0, "duration_ms": 10, "skipped": false}, s.data, AREA))
	assert_null(NodeWork.from_save({"skill": "quarrying", "action": "cut_redbirch", "elapsed_ms": 0, "duration_ms": 10, "skipped": false}, s.data, AREA))
	assert_null(NodeWork.from_save({"skill": "forestry", "action": "cut_redbirch", "elapsed_ms": "x", "duration_ms": 10, "skipped": false}, s.data, AREA))
	for change: Dictionary in [{"attempt": 4}, {"attempt": -1}, {"attempts": 0}, {"units": -2}, {"rich": 1}, {"units": "x"}]:
		var bad: Dictionary = base.duplicate()
		bad.merge(change, true)
		assert_null(NodeWork.from_save(bad, s.data, AREA), "incoherent %s" % change)
	var clamped: NodeWork = NodeWork.from_save({"skill": "forestry", "action": "cut_redbirch", "elapsed_ms": 99999, "duration_ms": 10, "skipped": true}, s.data, AREA)
	assert_eq(clamped.elapsed_ms, 10)
