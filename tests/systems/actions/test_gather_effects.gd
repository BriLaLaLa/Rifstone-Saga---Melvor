extends GutTest
## F-120 gathering effects of the legendary tools (hook `on_gather`): `gather_bonus_item` (+1 item), `gather_grade_up_pct`
## (the product of the next resource, the xp of the worked one), `byproduct_mult` (the byproduct of the milestone 25 x mult).
## Only the player's cycle counts (never a helper's), only the tool of the skill that is being worked, no draw without a tool.
## Content: tests/helpers/m14_data.gd (skills forestry / quarrying / angling, actions `<skill>_a` level 1 -> test_twig and
## `<skill>_b` level 10 -> test_log; legendary tools fx_leg_hatchet, fx_leg_rod, fx_leg_pick).

const FORESTRY_A: StringName = &"forestry_a"
const ANGLING_A: StringName = &"angling_a"
const ANGLING_B: StringName = &"angling_b"
const QUARRYING_A: StringName = &"quarrying_a"
const TWIG: StringName = &"test_twig"
const LOG_ITEM: StringName = &"test_log"
const RESIN: StringName = &"test_resin"


func _session(seed_value: int = 5) -> GameSession:
	return autofree(LegendaryKit.session(seed_value))


func _resolve(s: GameSession, action: StringName, helper: StringName = &"") -> ActionOutcome:
	return GatheringResolver.resolve(s, s.data.action(action), helper)


func test_gather_bonus_item_adds_one_item_to_the_product() -> void:
	var s: GameSession = _session()
	LegendaryKit.wear(s, &"fx_leg_hatchet")
	var outcome: ActionOutcome = _resolve(s, FORESTRY_A)
	assert_true(outcome.ok)
	assert_gte(outcome.outputs[TWIG], 1, "the product of the cycle")
	assert_eq(outcome.outputs[RESIN], 1, "pct 100: +1 Resin")
	assert_eq(s.bank.get_count(RESIN), 1)


func test_without_the_tool_or_with_the_tool_of_another_skill_nothing_happens() -> void:
	var s: GameSession = _session()
	assert_false(_resolve(s, FORESTRY_A).outputs.has(RESIN))
	LegendaryKit.wear(s, &"fx_leg_rod")  # angling: it does not work for forestry
	assert_false(_resolve(s, FORESTRY_A).outputs.has(RESIN))
	assert_gt(_resolve(s, FORESTRY_A).outputs[TWIG], 0)


func test_without_a_tool_no_draw_is_made() -> void:
	var s: GameSession = _session(9)
	var replica: GameSession = _session(9)
	_resolve(s, FORESTRY_A)
	_resolve(replica, FORESTRY_A)
	LegendaryKit.wear(replica, &"fx_leg_rod")  # not for this skill: the same draws
	_resolve(s, FORESTRY_A)
	_resolve(replica, FORESTRY_A)
	assert_eq(s.rng.randf(), replica.rng.randf())


func test_a_helper_never_triggers_the_effect() -> void:
	var s: GameSession = _session()
	LegendaryKit.wear(s, &"fx_leg_hatchet")
	var outcome: ActionOutcome = _resolve(s, FORESTRY_A, &"apprentice")
	assert_true(outcome.ok)
	assert_false(outcome.outputs.has(RESIN), "the helper does not use the tool of the player")
	assert_false(_resolve(s, FORESTRY_A).outputs.is_empty())


func test_grade_up_gives_the_next_resource_with_the_xp_of_the_worked_one() -> void:
	var s: GameSession = _session()
	var plain: GameSession = _session()
	LegendaryKit.wear(s, &"fx_leg_rod")
	var outcome: ActionOutcome = _resolve(s, ANGLING_A)
	var base: ActionOutcome = _resolve(plain, ANGLING_A)
	assert_true(outcome.outputs.has(LOG_ITEM), "angling_b gives test_log")
	assert_false(outcome.outputs.has(TWIG), "instead of the Twig of angling_a")
	assert_true(base.outputs.has(TWIG))
	assert_eq(outcome.xp, base.xp, "the xp is that of the worked resource")
	assert_eq(s.skills.get_xp(&"angling"), plain.skills.get_xp(&"angling"))
	assert_eq(s.mastery.get_mastery_xp(ANGLING_A), plain.mastery.get_mastery_xp(ANGLING_A), "and its mastery")
	assert_eq(s.mastery.get_mastery_xp(ANGLING_B), 0)


func test_the_last_resource_stays_what_it_is() -> void:
	var s: GameSession = _session()
	LegendaryKit.wear(s, &"fx_leg_rod")
	var outcome: ActionOutcome = _resolve(s, ANGLING_B)
	assert_true(outcome.outputs.has(LOG_ITEM))
	assert_false(outcome.outputs.has(TWIG))


func test_byproduct_mult_raises_the_byproduct_chance_of_the_milestone() -> void:
	var table: XpTable = LegendaryKit.session(1).data.mastery_table()
	var with_tool: int = _byproducts(true, table)
	var without: int = _byproducts(false, table)
	assert_gt(without, 0)
	assert_gt(with_tool, without * 2, "2.0%% x 3 = 6%%: about three times as many (%d vs %d)" % [with_tool, without])


func _byproducts(tool: bool, table: XpTable) -> int:
	var s: GameSession = _session(31)
	TestFactory.set_level(s, &"quarrying", 20)
	if tool:
		LegendaryKit.wear(s, &"fx_leg_pick")
	s.mastery.from_save({"quarrying": {"actions": {String(QUARRYING_A): table.xp_for_level(25)}}})
	s.rebuild_modifiers()
	var count: int = 0
	for i: int in 3000:
		count += _resolve(s, QUARRYING_A).outputs.get(RESIN, 0)
	return count


func test_one_big_step_equals_many_small_steps_with_the_tool() -> void:
	var big: GameSession = _runner_session()
	var small: GameSession = _runner_session()
	for i: int in 30:
		big.advance(1000)
	for i: int in 300:
		small.advance(100)
	assert_gt(big.bank.get_count(RESIN), 0, "the effect fired")
	assert_eq(SaveCodec.encode(small.to_save(0)), SaveCodec.encode(big.to_save(0)))


func _runner_session() -> GameSession:
	var s: GameSession = _session(17)
	LegendaryKit.wear(s, &"fx_leg_hatchet")
	assert_true(s.actions.start(&"forestry", FORESTRY_A).ok)
	return s
