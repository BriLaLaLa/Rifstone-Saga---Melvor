extends GutTest
## Integration, mastery per resource (M12-08; F-103, F-108, 05 §5.7) on the real data and the real runner: milestone 25
## (by-product), 50 (resource bonus), 99 (trade bonus summed across resources), the signal, save -> load keeps them.
## Fixed seeds, sessions freed, no real slot.

const SEED: int = 120803
const NOW_MS: int = 1793603600000
const FORESTRY: StringName = &"forestry"
const BIRCH: StringName = &"cut_redbirch"
const PINE: StringName = &"cut_ashpine"
const RESIN: StringName = &"birch_resin"
const INTERVAL: String = "skill_interval_pct"

var _s: GameSession = null
var _table: XpTable = null


func before_each() -> void:
	_s = TestFactory.session_no_kit(SEED, TestFactory.real_data())
	_table = _s.data.mastery_table()


func after_each() -> void:
	if _s != null:
		_s.free()
	_s = null


func _set_levels(levels: Dictionary) -> void:
	var xp: Dictionary = {}
	for action_id: StringName in levels:
		xp[String(action_id)] = _table.xp_for_level(int(levels[action_id]))
	_s.mastery.from_save({String(FORESTRY): {"pool": 0, "actions": xp}})
	_s.rebuild_modifiers()


func _trade_actions() -> Array[ActionDef]:
	return _s.data.actions_for_skill(FORESTRY)


func test_the_real_data_has_three_milestones_per_gathering_resource() -> void:
	for skill: StringName in [&"forestry", &"quarrying", &"angling"]:
		var actions: Array[ActionDef] = _s.data.actions_for_skill(skill)
		assert_eq(actions.size(), 8, "%s: 8 resources" % skill)
		for action: ActionDef in actions:
			var ats: Array[int] = []
			for m: MilestoneDef in action.milestones:
				ats.append(m.at)
			assert_eq(ats, [25, 50, 99] as Array[int], "%s milestones" % action.id)
	for skill: StringName in [&"forging", &"woodwright", &"hearthcraft", &"riftbinding"]:
		for action: ActionDef in _s.data.actions_for_skill(skill):
			assert_true(action.milestones.is_empty(), "%s: crafting keeps F-11, no milestones" % action.id)


func test_below_25_no_byproduct_from_25_on_it_drops_at_about_the_set_chance() -> void:
	_set_levels({BIRCH: 1})
	assert_true(_s.actions.start(FORESTRY, BIRCH).ok)
	for i: int in 200:
		_s.advance(3000)
	assert_lt(_s.mastery.get_mastery_level(BIRCH), 25, "still under the threshold")
	assert_eq(_s.bank.get_count(RESIN), 0, "F-103: level < 25 -> no roll")
	_s.actions.stop()
	_set_levels({BIRCH: 25})
	assert_true(_s.actions.start(FORESTRY, BIRCH).ok)
	var cycles: int = 1500
	for i: int in cycles:
		_s.advance(3000)
	var chance: float = float(_s.data.balance_value("mastery.milestones.byproduct_chance_pct"))
	var expected: float = cycles * chance / 100.0
	var got: int = _s.bank.get_count(RESIN)
	assert_gt(got, int(expected * 0.5), "about %.0f resin in %d cycles, got %d" % [expected, cycles, got])
	assert_lt(got, int(expected * 1.6), "never doubled by F-06: about %.0f, got %d" % [expected, got])


func test_resource_bonus_at_50_changes_only_its_own_resource() -> void:
	_set_levels({BIRCH: 49, PINE: 49})
	var birch_base: int = _s.actions.current_interval_ms(BIRCH)
	var pine_base: int = _s.actions.current_interval_ms(PINE)
	assert_eq(birch_base, 3000)
	_set_levels({BIRCH: 50, PINE: 49})
	var bonus: float = float((_s.data.action(BIRCH).milestones[1] as MilestoneDef).modifiers[0].value)
	assert_lt(bonus, 0.0)
	assert_eq(_s.actions.current_interval_ms(BIRCH), ActionMath.interval_ms(3000, bonus, 250), "F-103: -8% on Birch at 50")
	assert_eq(_s.actions.current_interval_ms(PINE), pine_base, "Pine untouched")
	assert_true(_s.modifiers.has_source(&"mastery_item:cut_redbirch"))
	assert_false(_s.modifiers.has_source(&"mastery_item:cut_ashpine"))


func test_trade_bonus_sums_across_resources_and_needs_level_99() -> void:
	var actions: Array[ActionDef] = _trade_actions()
	var ctx: ModifierContext = ModifierContext.for_skill(FORESTRY)
	var per: float = float((actions[0].milestones[2] as MilestoneDef).modifiers[0].value)
	var all_98: Dictionary = {}
	for a: ActionDef in actions:
		all_98[a.id] = 98
	_set_levels(all_98)
	assert_false(_s.modifiers.has_source(&"mastery_trade:forestry"), "0 resources at 99 -> no source")
	var some: Dictionary = all_98.duplicate()
	for i: int in 3:
		some[actions[i].id] = 99
	_set_levels(some)
	assert_true(_s.modifiers.has_source(&"mastery_trade:forestry"))
	var three: float = _s.modifiers.total(StringName(INTERVAL), ctx)
	assert_almost_eq(three, per * 3.0, 0.0001, "F-108: 3 resources at 99")
	var every: Dictionary = {}
	for a: ActionDef in actions:
		every[a.id] = 99
	_set_levels(every)
	assert_almost_eq(_s.modifiers.total(StringName(INTERVAL), ctx), per * 8.0, 0.0001, "F-108: 8 resources at 99")


func test_the_signal_comes_once_per_threshold_while_playing() -> void:
	_set_levels({BIRCH: 24})
	var reached: Array[int] = []
	_s.events.mastery_milestone_reached.connect(func(skill: StringName, action: StringName, at: int) -> void:
		if skill == FORESTRY and action == BIRCH:
			reached.append(at))
	# Push the mastery to the thresholds through the same door the runner uses.
	var action: ActionDef = _s.data.action(BIRCH)
	var guard: int = 0
	while _s.mastery.get_mastery_level(BIRCH) < 26 and guard < 100000:
		_s.mastery.add_for_action(action)
		guard += 1
	assert_eq(reached, [25] as Array[int])
	_s.mastery.from_save({String(FORESTRY): {"pool": 0, "actions": {String(BIRCH): _table.xp_for_level(60)}}})
	assert_eq(reached, [25] as Array[int], "loading does not announce anything")


func test_milestones_survive_a_save_and_load() -> void:
	_set_levels({BIRCH: 50, PINE: 99})
	var saved: Dictionary = _s.to_save(NOW_MS)
	var other: GameSession = autofree(TestFactory.session_no_kit(SEED + 1, TestFactory.real_data()))
	assert_true(other.from_save(SaveCodec.decode(SaveCodec.encode(saved))).ok)
	assert_true(other.modifiers.has_source(&"mastery_item:cut_redbirch"), "50 rebuilt")
	assert_true(other.modifiers.has_source(&"mastery_trade:forestry"), "99 rebuilt")
	assert_eq(other.mastery.milestones_reached(BIRCH), [25, 50] as Array[int])
	assert_eq(other.actions.current_interval_ms(BIRCH), _s.actions.current_interval_ms(BIRCH))
	assert_eq(SaveCodec.encode(other.to_save(NOW_MS)), SaveCodec.encode(saved))


func test_the_helper_gets_the_resource_bonus_and_the_byproduct() -> void:
	_set_levels({BIRCH: 50})
	TestFactory.give(_s, &"contract_forestry_master", 1)
	assert_true(_s.helpers.hire(&"contract_forestry_master").ok)
	assert_true(_s.helpers.set_action(FORESTRY, BIRCH).ok)
	var bonus: float = float((_s.data.action(BIRCH).milestones[1] as MilestoneDef).modifiers[0].value)
	var base: int = ActionMath.interval_ms(3000, bonus, 250)
	assert_eq(_s.helpers.interval_ms(FORESTRY), int(round(base * 1.5)), "F-101: the resource node of the mastery counts for the helper")
