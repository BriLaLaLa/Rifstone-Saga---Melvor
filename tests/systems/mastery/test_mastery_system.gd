extends GutTest
## MasterySystem: per-action mastery (F-09/F-10), pool share and cap (F-12/F-13), per-action bonuses (F-11),
## pool spending (F-14), skills/actions without mastery, save, node placeholders until M2-01.
##
## Fixture skill test_gather: mastery actions gather_twig (3000 ms) and gather_log (4000 ms), cap 600,000;
## gather_bundle has `mastery: false`. Combat skills and riftbinding have no mastery.

const SKILL: StringName = &"test_gather"
const TWIG: StringName = &"gather_twig"
const LOG_ACTION: StringName = &"gather_log"
const BUNDLE: StringName = &"gather_bundle"
const CRAFT_SKILL: StringName = &"test_craft"
const NO_MASTERY_SKILL: StringName = &"blade"
const DOUBLE: StringName = &"double_item_chance"
const MXP_PCT: StringName = &"mastery_xp_pct"
const FIXTURE_CAP: int = 600000

var _session: GameSession
var _mastery: MasterySystem
var _table: XpTable


func before_each() -> void:
	_session = autofree(TestFactory.session())
	_mastery = _session.mastery
	_table = _session.data.mastery_table()


func test_new_game_starts_empty() -> void:
	for action_id: StringName in [TWIG, LOG_ACTION, &"craft_plank"]:
		assert_eq(_mastery.get_mastery_xp(action_id), 0)
		assert_eq(_mastery.get_mastery_level(action_id), 1)
	assert_eq(_mastery.get_pool(SKILL), 0)
	assert_eq(_mastery.get_pool_cap(SKILL), FIXTURE_CAP)
	assert_eq(_mastery.get_pool_cap(CRAFT_SKILL), 300000)
	assert_eq(_mastery.get_pool_cap(&"test_gather_b"), 0)
	assert_almost_eq(_mastery.get_skill_ratio(SKILL), 2.0 / 198.0, 1e-9)


## F-13 with the real data: forestry has 8 mastery actions -> 2,400,000.
func test_f13_real_forestry_cap() -> void:
	var real: GameSession = autofree(TestFactory.session(1, TestFactory.real_data()))
	assert_eq(real.mastery.get_pool_cap(&"forestry"), 2400000)


## F-10 + F-12: gather_twig, t 3, L 1, R 2/198 -> mxp 3, pool +1.
func test_add_for_action_gives_mastery_and_pool_share() -> void:
	watch_signals(_session.events)
	assert_eq(_mastery.add_for_action(_action(TWIG)), 3)
	assert_eq(_mastery.get_mastery_xp(TWIG), 3)
	assert_eq(_mastery.get_pool(SKILL), 1)
	assert_signal_emitted_with_parameters(_session.events, "mastery_xp_gained", [SKILL, TWIG, 3])
	assert_signal_emitted_with_parameters(_session.events, "mastery_pool_changed", [SKILL, 1])
	assert_signal_not_emitted(_session.events, "mastery_level_up")


## R of F-10 uses the mastery levels of the skill's mastery actions: (99 + 1) / (99 × 2).
func test_skill_ratio_uses_mastery_levels() -> void:
	_load({SKILL: {"actions": {TWIG: _table.xp_for_level(99)}}})
	assert_almost_eq(_mastery.get_skill_ratio(SKILL), 100.0 / 198.0, 1e-9)
	assert_eq(_mastery.get_skill_ratio(CRAFT_SKILL), 1.0 / 99.0)
	assert_eq(_mastery.get_skill_ratio(NO_MASTERY_SKILL), 0.0)


## gather_log at L 50 with R 51/198: t 4 × 6.77… -> mxp 27; the level and R raise the gain.
func test_add_for_action_uses_level_and_ratio() -> void:
	_load({SKILL: {"actions": {LOG_ACTION: _table.xp_for_level(50)}}})
	assert_eq(_mastery.add_for_action(_action(LOG_ACTION)), 27)


func test_add_for_action_applies_mastery_xp_pct_of_the_action() -> void:
	var mods: Array[Modifier] = [Modifier.make(MXP_PCT, 100.0, Modifier.SCOPE_ACTION, TWIG)]
	_session.modifiers.set_source(&"test:mxp", mods)
	assert_eq(_mastery.add_for_action(_action(TWIG)), 6)
	assert_eq(_mastery.add_for_action(_action(LOG_ACTION)), 4)


func test_reaching_a_mastery_level_emits_level_up_and_updates_the_bonus_once() -> void:
	_load({SKILL: {"actions": {TWIG: _table.xp_for_level(10) - 1}}})
	assert_eq(_double(TWIG), 0.0)
	watch_signals(_session.events)
	_mastery.add_for_action(_action(TWIG))
	assert_eq(_mastery.get_mastery_level(TWIG), 10)
	assert_signal_emit_count(_session.events, "mastery_level_up", 1)
	assert_signal_emitted_with_parameters(_session.events, "mastery_level_up", [SKILL, TWIG, 10])
	assert_signal_emit_count(_session.events, "modifiers_changed", 1)
	assert_eq(_double(TWIG), 1.0)
	assert_eq(_double(LOG_ACTION), 0.0)


func test_level_up_without_bonus_change_leaves_modifiers_alone() -> void:
	_load({SKILL: {"actions": {TWIG: _table.xp_for_level(2) - 1}}})
	watch_signals(_session.events)
	_mastery.add_for_action(_action(TWIG))
	assert_signal_emitted_with_parameters(_session.events, "mastery_level_up", [SKILL, TWIG, 2])
	assert_signal_not_emitted(_session.events, "modifiers_changed")


## F-11 gathering examples (fixture rules = real gathering rules): L 35 -> +3; L 99 -> +9 +5 = +14.
func test_f11_item_bonus_examples() -> void:
	_load({SKILL: {"actions": {TWIG: _table.xp_for_level(35), LOG_ACTION: _table.xp_for_level(99)}}})
	assert_eq(_double(TWIG), 3.0)
	assert_eq(_double(LOG_ACTION), 14.0)
	assert_eq(_session.modifiers.total(DOUBLE, ModifierContext.for_skill(SKILL)), 0.0)
	assert_eq(_session.modifiers.total(DOUBLE), 0.0)


func test_item_bonus_source_only_when_it_has_modifiers() -> void:
	_load({SKILL: {"actions": {TWIG: _table.xp_for_level(10)}}})
	assert_true(_session.modifiers.has_source(&"mastery_item:gather_twig"))
	assert_false(_session.modifiers.has_source(&"mastery_item:gather_log"))
	assert_false(_session.modifiers.has_source(&"mastery_item:craft_plank"))


func test_f11_with_real_data() -> void:
	var real: GameSession = autofree(TestFactory.session(1, TestFactory.real_data()))
	real.mastery.from_save({"forestry": {"actions": {"cut_redbirch": _table.xp_for_level(99)}}})
	real.rebuild_modifiers()
	var ctx: ModifierContext = ModifierContext.for_action(&"forestry", &"cut_redbirch")
	assert_eq(real.modifiers.total(DOUBLE, ctx), 14.0)
	assert_eq(real.modifiers.total(DOUBLE, ModifierContext.for_action(&"forestry", &"cut_ashpine")), 0.0)


## Acceptance: the pool never exceeds the F-13 cap (gather_log at L 50 gives +5; the surplus is lost).
func test_pool_does_not_exceed_the_cap() -> void:
	_load({SKILL: {"pool": FIXTURE_CAP - 2, "actions": {LOG_ACTION: _table.xp_for_level(50)}}})
	_mastery.add_for_action(_action(LOG_ACTION))
	assert_eq(_mastery.get_pool(SKILL), FIXTURE_CAP)
	watch_signals(_session.events)
	_mastery.add_for_action(_action(LOG_ACTION))
	assert_eq(_mastery.get_pool(SKILL), FIXTURE_CAP)
	assert_signal_not_emitted(_session.events, "mastery_pool_changed")
	assert_signal_emitted(_session.events, "mastery_xp_gained")


func test_mastery_xp_stops_at_the_max_level_but_the_pool_still_grows() -> void:
	var max_xp: int = _table.xp_for_level(99)
	_load({SKILL: {"actions": {TWIG: max_xp - 1}}})
	watch_signals(_session.events)
	# L 98, R 99/198: 3 × (1 + 9.8 + 1.5) -> 36; then L 99, R 100/198: 3 × 12.415… -> 37.
	assert_eq(_mastery.add_for_action(_action(TWIG)), 36)
	assert_eq(_mastery.get_mastery_xp(TWIG), max_xp)
	assert_signal_emitted_with_parameters(_session.events, "mastery_xp_gained", [SKILL, TWIG, 1])
	assert_signal_emitted_with_parameters(_session.events, "mastery_level_up", [SKILL, TWIG, 99])
	assert_eq(_mastery.add_for_action(_action(TWIG)), 37)
	assert_eq(_mastery.get_mastery_xp(TWIG), max_xp)
	assert_signal_emit_count(_session.events, "mastery_xp_gained", 1)
	assert_eq(_mastery.get_pool(SKILL), 7 + 7)


## F-14: pool 10,000, amount 5,000, mastery 0 -> 5,000 spent, mastery level 30.
func test_f14_spend_from_zero() -> void:
	_load({SKILL: {"pool": 10000}})
	watch_signals(_session.events)
	assert_true(_mastery.spend_pool_on_action(TWIG, 5000).ok)
	assert_eq(_mastery.get_mastery_xp(TWIG), 5000)
	assert_eq(_mastery.get_mastery_level(TWIG), 30)
	assert_eq(_table.xp_for_level(30), 4584)
	assert_eq(_table.xp_for_level(31), 5017)
	assert_eq(_mastery.get_pool(SKILL), 5000)
	assert_signal_emitted_with_parameters(_session.events, "mastery_xp_gained", [SKILL, TWIG, 5000])
	assert_signal_emit_count(_session.events, "mastery_level_up", 29)
	assert_signal_emitted_with_parameters(_session.events, "mastery_pool_changed", [SKILL, 5000])
	assert_signal_emit_count(_session.events, "modifiers_changed", 1)
	assert_eq(_double(TWIG), 3.0)


## F-14: mastery 2,296,000, amount 5,000 -> 551 spent (only what reaches level 99).
func test_f14_spend_stops_at_level_99() -> void:
	_load({SKILL: {"pool": 10000, "actions": {TWIG: 2296000}}})
	assert_true(_mastery.spend_pool_on_action(TWIG, 5000).ok)
	assert_eq(_mastery.get_mastery_xp(TWIG), 2296551)
	assert_eq(_mastery.get_mastery_level(TWIG), 99)
	assert_eq(_mastery.get_pool(SKILL), 10000 - 551)
	assert_eq(_double(TWIG), 14.0)


## F-14: pool 300, amount 5,000 -> 300 spent.
func test_f14_spend_limited_by_the_pool() -> void:
	_load({SKILL: {"pool": 300}})
	assert_true(_mastery.spend_pool_on_action(TWIG, 5000).ok)
	assert_eq(_mastery.get_mastery_xp(TWIG), 300)
	assert_eq(_mastery.get_pool(SKILL), 0)


func test_spend_errors_change_nothing() -> void:
	_load({SKILL: {"pool": 50, "actions": {LOG_ACTION: _table.xp_for_level(99)}}})
	watch_signals(_session.events)
	assert_eq(_mastery.spend_pool_on_action(TWIG, 0).reason, Reasons.INVALID_AMOUNT)
	assert_eq(_mastery.spend_pool_on_action(TWIG, -5).reason, Reasons.INVALID_AMOUNT)
	assert_eq(_mastery.spend_pool_on_action(LOG_ACTION, 10).reason, Reasons.MASTERY_MAX)
	assert_eq(_mastery.spend_pool_on_action(BUNDLE, 10).reason, Reasons.UNKNOWN_ID)
	assert_eq(_mastery.spend_pool_on_action(&"ghost", 10).reason, Reasons.UNKNOWN_ID)
	assert_eq(_mastery.spend_pool_on_action(&"craft_plank", 10).reason, Reasons.POOL_INSUFFICIENT)
	assert_eq(_mastery.get_pool(SKILL), 50)
	assert_eq(_mastery.get_mastery_xp(TWIG), 0)
	assert_signal_not_emitted(_session.events, "mastery_xp_gained")
	assert_signal_not_emitted(_session.events, "mastery_pool_changed")


## Actions with `mastery: false` and skills without mastery have no mastery state.
func test_actions_and_skills_without_mastery() -> void:
	watch_signals(_session.events)
	assert_eq(_mastery.add_for_action(_action(BUNDLE)), 0)
	assert_eq(_mastery.get_mastery_xp(BUNDLE), 0)
	assert_eq(_mastery.get_mastery_level(BUNDLE), 0)
	assert_eq(_mastery.get_pool(SKILL), 0)
	for skill_id: StringName in [NO_MASTERY_SKILL, &"riftbinding"]:
		assert_eq(_mastery.get_pool(skill_id), 0)
		assert_eq(_mastery.get_pool_cap(skill_id), 0)
		assert_eq(_mastery.get_skill_ratio(skill_id), 0.0)
	assert_false(_session.modifiers.has_source(&"mastery_item:gather_bundle"))
	assert_signal_not_emitted(_session.events, "mastery_xp_gained")
	assert_signal_not_emitted(_session.events, "mastery_pool_changed")


func test_node_methods_wait_for_m2_01() -> void:
	assert_eq(_mastery.node_cost(&"test_gather_n1"), 0)
	assert_false(_mastery.owns_node(&"test_gather_n1"))
	assert_eq(_mastery.can_buy_node(&"test_gather_n1").reason, Reasons.UNKNOWN_ID)
	assert_eq(_mastery.buy_node(&"test_gather_n1").reason, Reasons.UNKNOWN_ID)


func test_to_save_writes_every_skill_with_mastery() -> void:
	_mastery.add_for_action(_action(TWIG))
	var saved: Dictionary = _mastery.to_save()
	assert_eq(saved.keys(), ["test_gather", "test_gather_b", "test_craft"])
	assert_eq(saved["test_gather"], {"pool": 1, "actions": {"gather_twig": 3, "gather_log": 0}, "nodes": []})
	assert_eq(saved["test_gather_b"], {"pool": 0, "actions": {}, "nodes": []})


func test_save_round_trip_through_the_session() -> void:
	_load({SKILL: {"pool": 1234, "actions": {TWIG: _table.xp_for_level(35)}}})
	var text: String = SaveCodec.encode(_session.to_save(1))
	var other: GameSession = autofree(TestFactory.session(9))
	watch_signals(other.events)
	assert_true(other.from_save(SaveCodec.decode(text)).ok)
	assert_eq(other.mastery.to_save(), _mastery.to_save())
	assert_eq(other.modifiers.total(DOUBLE, ModifierContext.for_action(SKILL, TWIG)), 3.0)
	assert_signal_not_emitted(other.events, "mastery_xp_gained")
	assert_signal_not_emitted(other.events, "mastery_pool_changed")


func test_from_save_is_tolerant() -> void:
	_mastery.add_for_action(_action(TWIG))
	_mastery.from_save({
		"ghost": {"pool": 5},
		"blade": {"pool": 5},
		"test_gather_b": "oops",
		"test_craft": {"pool": "x", "actions": {"craft_plank": -4}},
		"test_gather": {"pool": FIXTURE_CAP + 10, "actions": {
			"gather_twig": 12.0, "gather_log": 99999999, "craft_plank": 7, "ghost": 3, "gather_bundle": 2}},
	})
	assert_eq(_mastery.get_pool(SKILL), FIXTURE_CAP)
	assert_eq(_mastery.get_mastery_xp(TWIG), 12)
	assert_eq(_mastery.get_mastery_xp(LOG_ACTION), _table.xp_for_level(99))
	assert_eq(_mastery.get_mastery_xp(&"craft_plank"), 0)
	assert_eq(_mastery.get_pool(CRAFT_SKILL), 0)
	assert_eq(_mastery.get_mastery_xp(BUNDLE), 0)
	assert_eq(_mastery.get_pool(NO_MASTERY_SKILL), 0)


func test_from_save_with_bad_actions_keeps_the_pool() -> void:
	_mastery.from_save({"test_gather": {"pool": 40, "actions": [1, 2]}})
	assert_eq(_mastery.get_pool(SKILL), 40)
	assert_eq(_mastery.get_mastery_xp(TWIG), 0)


func test_new_game_resets_and_emits_nothing() -> void:
	_mastery.add_for_action(_action(TWIG))
	watch_signals(_session.events)
	_mastery.new_game()
	assert_eq(_mastery.get_mastery_xp(TWIG), 0)
	assert_eq(_mastery.get_pool(SKILL), 0)
	assert_signal_not_emitted(_session.events, "mastery_xp_gained")
	assert_signal_not_emitted(_session.events, "mastery_pool_changed")


func _action(action_id: StringName) -> ActionDef:
	return _session.data.action(action_id)


func _double(action_id: StringName) -> float:
	return _session.modifiers.total(DOUBLE, ModifierContext.for_action(SKILL, action_id))


# Loads a mastery module (StringName keys are fine: from_save reads them with str) and rebuilds the modifiers.
func _load(d: Dictionary) -> void:
	_mastery.from_save(d)
	_session.rebuild_modifiers()
