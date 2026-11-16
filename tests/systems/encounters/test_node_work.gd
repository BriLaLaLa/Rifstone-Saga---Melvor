extends GutTest
## F-155 (units, xp by color, mastery, full Deposit) with the numbers of docs/02_FORMULAS_M24.md and the node in progress (NodeWork).
## Real data: Betulla (`cut_redbirch`, xp 10, forestry level 1). The Deposit-full case uses a scripted generator.

const FORESTRY: StringName = &"forestry"
const QUARRYING: StringName = &"quarrying"
const BETULLA: StringName = &"cut_redbirch"
const LOG_ITEM: StringName = &"redbirch_log"
const AREA: StringName = &"redrock_plains"
const UNITS: int = 80


## Rolls false except the scripted indexes (every unit draws double then shard: calls 2k and 2k+1).
class ScriptedRng extends RngService:
	var calls: int = 0
	var true_calls: Array[int] = []

	func _init() -> void:
		super(1)

	func roll_pct(_chance_pct: float) -> bool:
		calls += 1
		return true_calls.has(calls - 1)


func _session(double_pct: float = 0.0) -> GameSession:
	var s: GameSession = autofree(TestFactory.session_no_kit(77, GameData.load_from_dirs(TestFactory.REAL_CONTENT_ROOT, TestFactory.CONFIG_ROOT)))
	s.disciplines._grades.clear()  # the factory learns some disciplines: only forestry here
	TestFactory.learn_discipline(s, FORESTRY)
	s.modifiers.set_source(&"test:double", [Modifier.make(&"double_item_chance", double_pct)])
	return s


func _betulla(s: GameSession) -> ActionDef:
	return s.data.action(BETULLA)


func test_the_log_item_is_the_output_of_the_betulla() -> void:
	assert_eq((_betulla(_session()).outputs[0] as ItemQty).item_id, LOG_ITEM)


# --- xp by color ---------------------------------------------------------------------------------------------------

func test_xp_by_color_for_eighty_units_of_the_betulla() -> void:
	var s: GameSession = _session()
	var expected: Array = [[100.0, 800], [50.0, 400], [20.0, 160], [0.0, 0]]
	for pair: Array in expected:
		var fresh: GameSession = _session()
		var out: ActionOutcome = GatheringResolver.resolve_units(fresh, _betulla(fresh), UNITS, pair[0])
		assert_eq(out.units, UNITS)
		assert_eq(out.xp, pair[1], "color %s%%" % pair[0])
	assert_not_null(s)


func test_the_xp_stat_applies_after_the_color() -> void:
	var s: GameSession = _session()
	s.modifiers.set_source(&"test:xp", [Modifier.make(&"skill_xp_pct", 15.0)])
	assert_eq(GatheringResolver.resolve_units(s, _betulla(s), UNITS, 50.0).xp, 460)
	var other: GameSession = _session()
	other.modifiers.set_source(&"test:xp", [Modifier.make(&"skill_xp_pct", 15.0)])
	assert_eq(GatheringResolver.resolve_units(other, _betulla(other), UNITS, 100.0).xp, 920)


func test_grey_gives_no_xp_and_no_xp_signal_but_the_products_and_mastery() -> void:
	var s: GameSession = _session()
	watch_signals(s.events)
	var out: ActionOutcome = GatheringResolver.resolve_units(s, _betulla(s), UNITS, 0.0)
	assert_eq(out.xp, 0)
	assert_signal_not_emitted(s.events, "xp_gained")
	assert_eq(out.outputs[LOG_ITEM], UNITS)
	assert_gt(out.mastery_xp, 0)


# --- products ------------------------------------------------------------------------------------------------------

func test_double_chance_zero_gives_eighty_logs_and_one_hundred_gives_one_sixty() -> void:
	var s: GameSession = _session(0.0)
	assert_eq(GatheringResolver.resolve_units(s, _betulla(s), UNITS, 100.0).outputs[LOG_ITEM], 80)
	assert_eq(s.bank.get_count(LOG_ITEM), 80)
	var d: GameSession = _session(100.0)
	assert_eq(GatheringResolver.resolve_units(d, _betulla(d), UNITS, 100.0).outputs[LOG_ITEM], 160)


func test_mastery_of_the_example_and_its_pool() -> void:
	var s: GameSession = _session()
	var out: ActionOutcome = GatheringResolver.resolve_units(s, _betulla(s), UNITS, 0.0)  # no xp: the level stays 1
	assert_eq(out.mastery_xp, 240, "80 units x F-10 (3) once")
	assert_eq(s.mastery.get_pool(FORESTRY), 48, "F-12 on the total")
	assert_eq(s.mastery.get_mastery_xp(BETULLA), 240)


func test_a_full_deposit_closes_the_node_at_the_unit_that_does_not_fit() -> void:
	var s: GameSession = _session()
	assert_true(s.bank.add(LOG_ITEM, 1).ok)
	for item: ItemDef in s.data.items():
		if s.bank.free_boxes() > 0 and item.id != &"rift_shard" and s.bank.can_add(item.id) and s.bank.get_count(item.id) == 0:
			s.bank.add(item.id, 1)
	assert_eq(s.bank.free_boxes(), 0)
	var rng := ScriptedRng.new()
	rng.true_calls = [2 * 36 + 1]  # the shard of the 37th unit: a new item with no room
	s.rng = rng
	var out: ActionOutcome = GatheringResolver.resolve_units(s, _betulla(s), UNITS, 100.0)
	assert_true(out.ok)
	assert_eq(out.units, 36)
	assert_eq(out.reason, Reasons.BANK_FULL)
	assert_eq(out.outputs[LOG_ITEM], 36)
	assert_eq(out.xp, 360, "the xp of the units put: 36 x 10")
	assert_eq(out.mastery_xp, 108, "36 x 3")


func test_no_room_at_all_changes_nothing() -> void:
	var s: GameSession = _session()
	for item: ItemDef in s.data.items():
		if s.bank.free_boxes() > 0 and item.id != LOG_ITEM and s.bank.can_add(item.id):
			s.bank.add(item.id, 1)
	var xp: int = s.skills.get_xp(FORESTRY)
	var out: ActionOutcome = GatheringResolver.resolve_units(s, _betulla(s), UNITS, 100.0)
	assert_false(out.ok)
	assert_eq(out.reason, Reasons.BANK_FULL)
	assert_eq(out.units, 0)
	assert_eq(s.skills.get_xp(FORESTRY), xp)
	assert_eq(s.bank.get_count(LOG_ITEM), 0)


# --- NodeWork ------------------------------------------------------------------------------------------------------

func test_begin_fixes_the_resource_and_the_duration_of_a_learned_discipline() -> void:
	var s: GameSession = _session()
	var work: NodeWork = NodeWork.begin(s, AREA, FORESTRY)
	assert_false(work.skipped)
	assert_eq(work.action_id, BETULLA)
	assert_eq(work.duration_ms, 12000)
	assert_eq(work.elapsed_ms, 0)


func test_an_unlearned_discipline_is_skipped_for_skip_ms_and_gives_nothing() -> void:
	var s: GameSession = _session()
	var work: NodeWork = NodeWork.begin(s, AREA, QUARRYING)
	assert_true(work.skipped)
	assert_eq(work.duration_ms, int(s.data.balance_value("encounters.skip_ms")))
	assert_eq(s.data.action(work.action_id).skill_id, QUARRYING, "it shows the resource that would have been worked")
	var rng_before: Dictionary = s.rng.to_save()
	watch_signals(s.events)
	var out: ActionOutcome = work.finish(s)
	assert_false(out.ok)
	assert_eq(out.units, 0)
	assert_true(out.outputs.is_empty())
	assert_eq(s.rng.to_save(), rng_before, "a skipped node rolls nothing")
	assert_signal_not_emitted(s.events, "xp_gained")
	assert_signal_not_emitted(s.events, "bank_changed")


func test_the_color_is_taken_when_the_node_ends() -> void:
	var s: GameSession = _session()
	var work: NodeWork = NodeWork.begin(s, AREA, FORESTRY)
	assert_eq(work.color(s)["id"], &"orange")
	s.skills.add_xp(FORESTRY, 1_000_000)
	assert_eq(work.action_id, BETULLA, "the resource does not change with the level")
	assert_ne(work.color(s)["id"], &"orange", "the color follows the level of now")


func test_save_round_trip_and_malformed_input() -> void:
	var s: GameSession = _session()
	var work: NodeWork = NodeWork.begin(s, AREA, FORESTRY)
	work.elapsed_ms = 4000
	var back: NodeWork = NodeWork.from_save(work.to_save(), s.data)
	assert_eq(back.to_save(), work.to_save())
	assert_null(NodeWork.from_save({}, s.data))
	assert_null(NodeWork.from_save({"skill": "forestry", "action": "no_such", "elapsed_ms": 0, "duration_ms": 10, "skipped": false}, s.data))
	assert_null(NodeWork.from_save({"skill": "quarrying", "action": "cut_redbirch", "elapsed_ms": 0, "duration_ms": 10, "skipped": false}, s.data))
	assert_null(NodeWork.from_save({"skill": "forestry", "action": "cut_redbirch", "elapsed_ms": "x", "duration_ms": 10, "skipped": false}, s.data))
	var clamped: NodeWork = NodeWork.from_save({"skill": "forestry", "action": "cut_redbirch", "elapsed_ms": 99999, "duration_ms": 10, "skipped": true}, s.data)
	assert_eq(clamped.elapsed_ms, 10)
