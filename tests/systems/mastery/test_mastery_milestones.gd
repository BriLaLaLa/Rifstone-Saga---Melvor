extends GutTest
## MasterySystem milestones of the gathering actions (F-103, F-108, 05 §5.7): `mastery_item:<action>` from level 50,
## `mastery_trade:<skill>` from level 99 summed across the resources, `milestones_reached`/`milestone_active`, the
## `mastery_milestone_reached` signal (not in `from_save`/`new_game`), F-11 still valid for the artisan skills.
##
## Fixture test_gather: twig (resource double +8, trade +0.5), log (resource double +6, trade +1).

const SKILL: StringName = &"test_gather"
const TWIG: StringName = &"gather_twig"
const LOG_ACTION: StringName = &"gather_log"
const BUNDLE: StringName = &"gather_bundle"
const DOUBLE: StringName = &"double_item_chance"
const ITEM_TWIG: StringName = &"mastery_item:gather_twig"
const TRADE: StringName = &"mastery_trade:test_gather"

var _session: GameSession
var _mastery: MasterySystem
var _table: XpTable


func before_each() -> void:
	_session = autofree(TestFactory.session())
	_mastery = _session.mastery
	_table = _session.data.mastery_table()


## F-103: level 49 -> no bonus; level 50 -> the resource bonus on its own action only.
func test_resource_milestone_at_50_is_for_its_own_resource() -> void:
	_load({TWIG: _table.xp_for_level(49)})
	assert_false(_session.modifiers.has_source(ITEM_TWIG))
	assert_eq(_double(TWIG), 0.0)
	_load({TWIG: _table.xp_for_level(50)})
	assert_true(_session.modifiers.has_source(ITEM_TWIG))
	assert_eq(_double(TWIG), 8.0)
	assert_eq(_double(LOG_ACTION), 0.0)
	assert_false(_session.modifiers.has_source(&"mastery_item:gather_log"))


## F-108: no source below 99, then the trade bonuses add up across resources (1 resource: +0.5, 2 resources: +1.5).
func test_trade_milestone_is_summed_across_resources() -> void:
	_load({TWIG: _table.xp_for_level(98), LOG_ACTION: _table.xp_for_level(98)})
	assert_false(_session.modifiers.has_source(TRADE))
	_load({TWIG: _table.xp_for_level(99), LOG_ACTION: _table.xp_for_level(98)})
	assert_true(_session.modifiers.has_source(TRADE))
	assert_eq(_session.modifiers.total(DOUBLE, ModifierContext.for_skill(SKILL)), 0.5)
	_load({TWIG: _table.xp_for_level(99), LOG_ACTION: _table.xp_for_level(99)})
	assert_eq(_session.modifiers.total(DOUBLE, ModifierContext.for_skill(SKILL)), 1.5)
	assert_eq(_session.modifiers.total(DOUBLE, ModifierContext.for_action(SKILL, BUNDLE)), 1.5, "the whole trade")


## The trade source is rebuilt at the level up that crosses 99 (one modifiers_changed), not before.
func test_crossing_99_rebuilds_the_trade_source() -> void:
	_load({TWIG: _table.xp_for_level(99) - 1})
	assert_false(_session.modifiers.has_source(TRADE))
	watch_signals(_session.events)
	_mastery.add_for_action(_session.data.action(TWIG))
	assert_eq(_mastery.get_mastery_level(TWIG), 99)
	assert_signal_emit_count(_session.events, "modifiers_changed", 1)
	assert_true(_session.modifiers.has_source(TRADE))
	assert_eq(_session.modifiers.total(DOUBLE, ModifierContext.for_skill(SKILL)), 0.5)


func test_milestones_reached_and_active() -> void:
	assert_eq(_mastery.milestones_reached(TWIG), [] as Array[int])
	_load({TWIG: _table.xp_for_level(25), LOG_ACTION: _table.xp_for_level(60)})
	assert_eq(_mastery.milestones_reached(TWIG), [25] as Array[int])
	assert_eq(_mastery.milestones_reached(LOG_ACTION), [25, 50] as Array[int])
	_load({TWIG: _table.xp_for_level(99)})
	assert_eq(_mastery.milestones_reached(TWIG), [25, 50, 99] as Array[int])
	assert_true(_mastery.milestone_active(TWIG, 99))
	assert_false(_mastery.milestone_active(LOG_ACTION, 25))
	assert_eq(_mastery.milestones_reached(&"craft_plank"), [] as Array[int], "artisan: none")
	assert_eq(_mastery.milestones_reached(BUNDLE), [] as Array[int], "no mastery: none")
	assert_eq(_mastery.milestones_reached(&"ghost"), [] as Array[int])


## One signal per threshold crossed, after the mastery_level_up signals and before the pool change.
func test_signal_per_threshold() -> void:
	_load({TWIG: _table.xp_for_level(24)}, 100000)
	watch_signals(_session.events)
	assert_true(_mastery.spend_pool_on_action(TWIG, _table.xp_for_level(51) - _table.xp_for_level(24)).ok)
	assert_signal_emit_count(_session.events, "mastery_milestone_reached", 2)
	assert_eq(get_signal_parameters(_session.events, "mastery_milestone_reached", 0), [SKILL, TWIG, 25])
	assert_eq(get_signal_parameters(_session.events, "mastery_milestone_reached", 1), [SKILL, TWIG, 50])


func test_no_signal_when_a_level_up_crosses_nothing() -> void:
	_load({TWIG: _table.xp_for_level(30) - 1})
	watch_signals(_session.events)
	_mastery.add_for_action(_session.data.action(TWIG))
	assert_signal_emitted(_session.events, "mastery_level_up")
	assert_signal_not_emitted(_session.events, "mastery_milestone_reached")


func test_no_signal_in_from_save_and_new_game() -> void:
	watch_signals(_session.events)
	_load({TWIG: _table.xp_for_level(99), LOG_ACTION: _table.xp_for_level(60)})
	_mastery.new_game()
	assert_signal_not_emitted(_session.events, "mastery_milestone_reached")
	assert_signal_not_emitted(_session.events, "mastery_level_up")


## Artisan: F-11 stays (preservation +1.5 per 10 levels), and no trade source for a non-gathering skill.
func test_artisan_keeps_f11() -> void:
	_mastery.from_save({"test_craft": {"actions": {"craft_plank": _table.xp_for_level(50)}}})
	_session.rebuild_modifiers()
	var ctx: ModifierContext = ModifierContext.for_action(&"test_craft", &"craft_plank")
	assert_eq(_session.modifiers.total(&"preservation_chance", ctx), 7.5)
	assert_false(_session.modifiers.has_source(&"mastery_trade:test_craft"))


func test_new_game_clears_the_sources() -> void:
	_load({TWIG: _table.xp_for_level(99)})
	_mastery.new_game()
	_session.rebuild_modifiers()
	assert_false(_session.modifiers.has_source(ITEM_TWIG))
	assert_false(_session.modifiers.has_source(TRADE))


## F-108 on the real Boscaiolo (trade bonus -0.5 per resource at 99, resource bonus -8 on its own action only).
func test_real_data_milestones() -> void:
	var real: GameSession = autofree(TestFactory.session_no_kit(1, TestFactory.real_data()))
	var ids: Array[StringName] = [&"cut_redbirch", &"cut_ashpine", &"cut_thornalder", &"cut_duskelm", &"cut_shardcedar",
			&"cut_veilcypress", &"cut_emberlarch", &"cut_riftspruce"]
	var actions: Dictionary = {}
	for index: int in 3:
		actions[ids[index]] = _table.xp_for_level(99)
	real.mastery.from_save({"forestry": {"pool": 0, "actions": actions}})
	real.rebuild_modifiers()
	var interval: StringName = &"skill_interval_pct"
	assert_eq(real.modifiers.total(interval, ModifierContext.for_action(&"forestry", &"cut_veilcypress")), -1.5, "3 resources")
	for id: StringName in ids:
		actions[id] = _table.xp_for_level(99)
	real.mastery.from_save({"forestry": {"pool": 0, "actions": actions}})
	real.rebuild_modifiers()
	assert_eq(real.modifiers.total(interval, ModifierContext.for_action(&"forestry", &"cut_veilcypress")), -12.0,
			"8 resources: -4.0 of the trade and -8 of its own resource")


func _double(action_id: StringName) -> float:
	return _session.modifiers.total(DOUBLE, ModifierContext.for_action(SKILL, action_id))


func _load(actions: Dictionary, pool: int = 0) -> void:
	_mastery.from_save({String(SKILL): {"pool": pool, "actions": actions}})
	_session.rebuild_modifiers()
