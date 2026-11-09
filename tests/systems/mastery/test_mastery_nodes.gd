extends GutTest
## MasterySystem nodes (docs/01_GDD.md §6.3): F-15 cost, prerequisites, purchase, `mastery_node:*` sources,
## permanence after the pool is spent, save.
##
## Fixture skill test_gather (cap 600,000): test_gather_n1 (5%, no prerequisites, skill_interval_pct -3 with the
## default scope skill:test_gather), test_gather_n2 (10%, needs n1, skill_xp_pct +5 on action:gather_twig),
## test_gather_n3 (20%, needs n1 and n2, double_item_chance +2 global). test_craft has no nodes.

const SKILL: StringName = &"test_gather"
const CRAFT_SKILL: StringName = &"test_craft"
const TWIG: StringName = &"gather_twig"
const LOG_ACTION: StringName = &"gather_log"
const N1: StringName = &"test_gather_n1"
const N2: StringName = &"test_gather_n2"
const N3: StringName = &"test_gather_n3"
const FIXTURE_CAP: int = 600000
const N1_COST: int = 30000
const N2_COST: int = 60000
const N3_COST: int = 120000

var _session: GameSession
var _mastery: MasterySystem


func before_each() -> void:
	_session = autofree(TestFactory.session())
	_mastery = _session.mastery


## F-15 examples: cap 2,400,000 -> 10% = 240,000; 7.5% = 180,000.
func test_f15_examples() -> void:
	assert_eq(MasteryMath.node_cost(2400000, 10.0), 240000)
	assert_eq(MasteryMath.node_cost(2400000, 7.5), 180000)


## F-15 through the system: ceil(cap 600,000 × cost_pct / 100).
func test_node_cost_uses_the_pool_cap_of_the_skill() -> void:
	assert_eq(_mastery.get_pool_cap(SKILL), FIXTURE_CAP)
	assert_eq(_mastery.node_cost(N1), N1_COST)
	assert_eq(_mastery.node_cost(N2), N2_COST)
	assert_eq(_mastery.node_cost(N3), N3_COST)
	assert_eq(_mastery.node_cost(&"ghost_node"), 0)


## F-15 with the real data (cap 2,400,000 of forestry, §8.8): n2/n3 at 7.5% -> 180,000, n4/n5 at 10% -> 240,000.
func test_f15_real_forestry_nodes() -> void:
	var real: GameSession = autofree(TestFactory.session(1, TestFactory.real_data()))
	var nodes: Array[MasteryNodeDef] = real.data.mastery_nodes(&"forestry")
	if nodes.is_empty():
		pending("forestry mastery nodes arrive with M2-02")
		return
	for node: MasteryNodeDef in nodes:
		assert_eq(real.mastery.node_cost(node.id), MasteryMath.node_cost(2400000, node.cost_pct), String(node.id))
		if is_equal_approx(node.cost_pct, 7.5):
			assert_eq(real.mastery.node_cost(node.id), 180000)
		elif is_equal_approx(node.cost_pct, 10.0):
			assert_eq(real.mastery.node_cost(node.id), 240000)


func test_new_game_owns_no_node() -> void:
	for node_id: StringName in [N1, N2, N3, &"ghost_node"]:
		assert_false(_mastery.owns_node(node_id))


func test_unknown_node_is_unknown_id() -> void:
	_load_pool(FIXTURE_CAP)
	assert_eq(_mastery.can_buy_node(&"ghost_node").reason, Reasons.UNKNOWN_ID)
	assert_eq(_mastery.buy_node(&"ghost_node").reason, Reasons.UNKNOWN_ID)
	assert_eq(_mastery.get_pool(SKILL), FIXTURE_CAP)


func test_pool_insufficient() -> void:
	assert_eq(_mastery.can_buy_node(N1).reason, Reasons.POOL_INSUFFICIENT)
	_load_pool(N1_COST - 1)
	assert_eq(_mastery.can_buy_node(N1).reason, Reasons.POOL_INSUFFICIENT)
	assert_eq(_mastery.buy_node(N1).reason, Reasons.POOL_INSUFFICIENT)
	assert_false(_mastery.owns_node(N1))
	assert_eq(_mastery.get_pool(SKILL), N1_COST - 1)


## A pool equal to the cost is enough and empties the pool.
func test_pool_equal_to_the_cost_buys() -> void:
	_load_pool(N1_COST)
	assert_true(_mastery.can_buy_node(N1).ok)
	assert_true(_mastery.buy_node(N1).ok)
	assert_true(_mastery.owns_node(N1))
	assert_eq(_mastery.get_pool(SKILL), 0)


func test_prerequisites() -> void:
	_load_pool(FIXTURE_CAP)
	assert_eq(_mastery.can_buy_node(N2).reason, Reasons.NODE_PREREQ_MISSING)
	assert_eq(_mastery.buy_node(N3).reason, Reasons.NODE_PREREQ_MISSING)
	assert_true(_mastery.buy_node(N1).ok)
	# n3 needs both n1 and n2.
	assert_eq(_mastery.can_buy_node(N3).reason, Reasons.NODE_PREREQ_MISSING)
	assert_true(_mastery.buy_node(N2).ok)
	assert_true(_mastery.buy_node(N3).ok)
	assert_eq(_mastery.get_pool(SKILL), FIXTURE_CAP - N1_COST - N2_COST - N3_COST)


## Order of the checks: node_owned before node_prereq_missing and pool_insufficient; prerequisites before the pool.
func test_error_order() -> void:
	_load_pool(N1_COST)
	assert_true(_mastery.buy_node(N1).ok)
	assert_eq(_mastery.get_pool(SKILL), 0)
	assert_eq(_mastery.can_buy_node(N1).reason, Reasons.NODE_OWNED)
	assert_eq(_mastery.can_buy_node(N3).reason, Reasons.NODE_PREREQ_MISSING)
	assert_eq(_mastery.can_buy_node(N2).reason, Reasons.POOL_INSUFFICIENT)


func test_errors_change_nothing_and_emit_nothing() -> void:
	_load_pool(FIXTURE_CAP)
	assert_true(_mastery.buy_node(N1).ok)
	watch_signals(_session.events)
	assert_eq(_mastery.buy_node(N1).reason, Reasons.NODE_OWNED)
	assert_eq(_mastery.buy_node(N3).reason, Reasons.NODE_PREREQ_MISSING)
	assert_eq(_mastery.get_pool(SKILL), FIXTURE_CAP - N1_COST)
	assert_false(_mastery.owns_node(N3))
	assert_signal_not_emitted(_session.events, "mastery_node_purchased")
	assert_signal_not_emitted(_session.events, "mastery_pool_changed")
	assert_signal_not_emitted(_session.events, "modifiers_changed")


## can_buy_node only checks.
func test_can_buy_node_changes_nothing() -> void:
	_load_pool(FIXTURE_CAP)
	watch_signals(_session.events)
	assert_true(_mastery.can_buy_node(N1).ok)
	assert_false(_mastery.owns_node(N1))
	assert_eq(_mastery.get_pool(SKILL), FIXTURE_CAP)
	assert_signal_emit_count(_session.events, "modifiers_changed", 0)


## Effects in order: state -> source (one modifiers_changed) -> mastery_node_purchased -> mastery_pool_changed.
func test_buy_node_effects_and_signal_order() -> void:
	_load_pool(FIXTURE_CAP)
	watch_signals(_session.events)
	var order: Array[String] = []
	var mastery: MasterySystem = _mastery
	var modifiers: ModifierService = _session.modifiers
	_session.events.modifiers_changed.connect(func() -> void:
		order.append("modifiers:%s" % mastery.owns_node(N1)))
	_session.events.mastery_node_purchased.connect(func(_s: StringName, _n: StringName) -> void:
		order.append("purchased:%s" % modifiers.has_source(&"mastery_node:test_gather_n1")))
	_session.events.mastery_pool_changed.connect(func(_s: StringName, pool: int) -> void:
		order.append("pool:%d" % pool))
	assert_true(_mastery.buy_node(N1).ok)
	assert_eq(order, ["modifiers:true", "purchased:true", "pool:%d" % (FIXTURE_CAP - N1_COST)])
	assert_signal_emitted_with_parameters(_session.events, "mastery_node_purchased", [SKILL, N1])
	assert_signal_emitted_with_parameters(_session.events, "mastery_pool_changed", [SKILL, FIXTURE_CAP - N1_COST])
	assert_signal_emit_count(_session.events, "modifiers_changed", 1)


## Each owned node is the mastery_node:<id> source with its modifiers and their scopes from the data.
func test_owned_nodes_apply_their_modifiers() -> void:
	_load_pool(FIXTURE_CAP)
	var skill_ctx: ModifierContext = ModifierContext.for_skill(SKILL)
	assert_true(_mastery.buy_node(N1).ok)
	assert_eq(_total(&"skill_interval_pct", skill_ctx), -3.0)
	assert_eq(_total(&"skill_interval_pct", ModifierContext.for_skill(CRAFT_SKILL)), 0.0)
	assert_true(_mastery.buy_node(N2).ok)
	assert_eq(_total(&"skill_xp_pct", ModifierContext.for_action(SKILL, TWIG)), 5.0)
	assert_eq(_total(&"skill_xp_pct", ModifierContext.for_action(SKILL, LOG_ACTION)), 0.0)
	assert_true(_mastery.buy_node(N3).ok)
	assert_eq(_total(&"double_item_chance", null), 2.0)
	assert_eq(_total(&"double_item_chance", ModifierContext.for_skill(CRAFT_SKILL)), 2.0)
	for node_id: String in ["test_gather_n1", "test_gather_n2", "test_gather_n3"]:
		assert_true(_session.modifiers.has_source(StringName("mastery_node:" + node_id)))


## A bought node stays owned (and keeps its modifiers) when the pool is spent afterwards.
func test_nodes_are_permanent_after_spending_the_pool() -> void:
	_load_pool(N1_COST + 5000)
	assert_true(_mastery.buy_node(N1).ok)
	assert_true(_mastery.spend_pool_on_action(TWIG, 5000).ok)
	assert_eq(_mastery.get_pool(SKILL), 0)
	assert_true(_mastery.owns_node(N1))
	assert_eq(_mastery.can_buy_node(N1).reason, Reasons.NODE_OWNED)
	assert_eq(_total(&"skill_interval_pct", ModifierContext.for_skill(SKILL)), -3.0)
	_session.rebuild_modifiers()
	assert_true(_mastery.owns_node(N1))
	assert_eq(_total(&"skill_interval_pct", ModifierContext.for_skill(SKILL)), -3.0)


## rebuild_modifiers registers mastery_item:* and mastery_node:* in the same batch: one modifiers_changed.
func test_rebuild_modifiers_registers_node_sources_in_one_batch() -> void:
	var twig_l50: int = _session.data.mastery_table().xp_for_level(50)
	_mastery.from_save({SKILL: {"pool": 0, "actions": {TWIG: twig_l50}, "nodes": [N1, N3]}})
	_session.modifiers.clear_all()
	watch_signals(_session.events)
	_mastery.rebuild_modifiers()
	assert_signal_emit_count(_session.events, "modifiers_changed", 1)
	assert_true(_session.modifiers.has_source(&"mastery_item:gather_twig"))
	assert_true(_session.modifiers.has_source(&"mastery_node:test_gather_n1"))
	assert_true(_session.modifiers.has_source(&"mastery_node:test_gather_n3"))
	assert_false(_session.modifiers.has_source(&"mastery_node:test_gather_n2"))
	assert_eq(_total(&"double_item_chance", ModifierContext.for_action(SKILL, TWIG)), 15.0)  # 8 resource milestone + node 2 + 5 steps of +1


func test_to_save_lists_owned_nodes_in_data_order() -> void:
	_load_pool(FIXTURE_CAP)
	assert_true(_mastery.buy_node(N1).ok)
	assert_true(_mastery.buy_node(N2).ok)
	var saved: Dictionary = _mastery.to_save()
	assert_eq(saved["test_gather"]["nodes"], ["test_gather_n1", "test_gather_n2"])
	assert_eq(saved["test_craft"]["nodes"], [])
	assert_eq(saved["test_gather_b"]["nodes"], [])


func test_save_round_trip_through_the_session() -> void:
	_load_pool(FIXTURE_CAP)
	assert_true(_mastery.buy_node(N1).ok)
	assert_true(_mastery.buy_node(N2).ok)
	var text: String = SaveCodec.encode(_session.to_save(1))
	var other: GameSession = autofree(TestFactory.session(9))
	watch_signals(other.events)
	assert_true(other.from_save(SaveCodec.decode(text)).ok)
	assert_eq(other.mastery.to_save(), _mastery.to_save())
	assert_true(other.mastery.owns_node(N1))
	assert_true(other.mastery.owns_node(N2))
	assert_false(other.mastery.owns_node(N3))
	assert_eq(other.modifiers.total(&"skill_interval_pct", ModifierContext.for_skill(SKILL)), -3.0)
	assert_eq(other.modifiers.total(&"skill_xp_pct", ModifierContext.for_action(SKILL, TWIG)), 5.0)
	assert_signal_not_emitted(other.events, "mastery_node_purchased")
	assert_signal_not_emitted(other.events, "mastery_pool_changed")


## Unknown ids, nodes of another skill and non-id entries are dropped; the rest is kept.
func test_from_save_nodes_are_tolerant() -> void:
	_mastery.from_save({
		"test_gather": {"pool": 10, "nodes": ["ghost_node", 5, "test_gather_n2", null, "test_gather_n1"]},
		"test_craft": {"pool": 0, "nodes": ["test_gather_n3"]},
	})
	assert_true(_mastery.owns_node(N1))
	assert_true(_mastery.owns_node(N2))
	assert_false(_mastery.owns_node(N3))
	assert_false(_mastery.owns_node(&"ghost_node"))
	assert_eq(_mastery.get_pool(SKILL), 10)
	assert_eq(_mastery.to_save()["test_gather"]["nodes"], ["test_gather_n1", "test_gather_n2"])
	assert_eq(_mastery.to_save()["test_craft"]["nodes"], [])


func test_from_save_with_bad_nodes_owns_none() -> void:
	_mastery.from_save({"test_gather": {"pool": 40, "actions": {TWIG: 12}, "nodes": "test_gather_n1"}})
	assert_false(_mastery.owns_node(N1))
	assert_eq(_mastery.get_pool(SKILL), 40)
	assert_eq(_mastery.get_mastery_xp(TWIG), 12)


## Nodes are still read when the actions entry is malformed.
func test_from_save_reads_nodes_with_bad_actions() -> void:
	_mastery.from_save({"test_gather": {"pool": 40, "actions": [1, 2], "nodes": ["test_gather_n1"]}})
	assert_true(_mastery.owns_node(N1))


func test_new_game_clears_nodes_and_their_sources() -> void:
	_load_pool(FIXTURE_CAP)
	assert_true(_mastery.buy_node(N1).ok)
	watch_signals(_session.events)
	_session.new_game()
	assert_false(_mastery.owns_node(N1))
	assert_false(_session.modifiers.has_source(&"mastery_node:test_gather_n1"))
	assert_eq(_total(&"skill_interval_pct", ModifierContext.for_skill(SKILL)), 0.0)
	assert_signal_not_emitted(_session.events, "mastery_node_purchased")


func _total(stat: StringName, ctx: ModifierContext) -> float:
	return _session.modifiers.total(stat, ctx)


# Sets the test_gather pool through from_save (no node owned) and rebuilds the modifiers.
func _load_pool(pool: int) -> void:
	_mastery.from_save({SKILL: {"pool": pool}})
	_session.rebuild_modifiers()
