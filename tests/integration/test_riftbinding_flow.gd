extends GutTest
## Integration, Riftbinding and the Altar of the Rift (M8, GDD §11, §26, F-03, 02_FORMULAS §8.7) on the real data.
## Shards and materials in the bank -> bind_* action -> infusion / stone / currency in the bank with skill and mastery
## XP; the Altar unlocks sockets by level, holds infusions and their modifiers reach the real formulas.
## Fixed seeds; the sessions are freed; no real slot is touched.

const SEED: int = 80601
const NOW_MS: int = 1793603600000
const SKILL: StringName = &"riftbinding"
const SHARD: StringName = &"rift_shard"
const FORESTRY: StringName = &"forestry"
const MIN_INTERVAL_KEY: String = "action.min_interval_ms"
const TICK_MS: int = 100
const MAX_STEPS: int = 5000

var _s: GameSession = null


func before_each() -> void:
	_s = TestFactory.session(SEED, TestFactory.real_data())


func after_each() -> void:
	if _s != null:
		_s.free()
	_s = null


func _items_of(category: StringName) -> Array[ItemDef]:
	var out: Array[ItemDef] = []
	for def: ItemDef in _s.data.items():
		if def.category == category:
			out.append(def)
	return out


# Gives the inputs of `action_id` for `cycles` cycles and runs them through the real runner.
func _bind(action_id: StringName, cycles: int = 1) -> void:
	var action: ActionDef = _s.data.action(action_id)
	for input: ItemQty in action.inputs:
		TestFactory.give(_s, input.item_id, input.qty * cycles)
	var started: CommandResult = _s.actions.start(SKILL, action_id)
	assert_true(started.ok, "start %s: %s" % [action_id, started.reason])
	var out: StringName = action.outputs[0].item_id
	var goal: int = _s.bank.get_count(out) + action.outputs[0].qty * cycles
	var steps: int = 0
	while _s.bank.get_count(out) < goal and steps < MAX_STEPS:
		_s.advance(TICK_MS)
		steps += 1
	_s.actions.stop()
	assert_eq(_s.bank.get_count(out), goal, "%s done within the guard" % action_id)


func test_every_bind_recipe_yields_its_item_with_xp_and_mastery() -> void:
	var actions: Array[ActionDef] = _s.data.actions_for_skill(SKILL)
	assert_gt(actions.size(), 20, "infusions + stones + currencies")
	var categories: Dictionary[StringName, int] = {}
	for action: ActionDef in actions:
		_s.free()
		_s = TestFactory.session(SEED, TestFactory.real_data())
		TestFactory.set_level(_s, SKILL, action.level)
		var xp_start: int = _s.skills.get_xp(SKILL)
		_bind(action.id)
		var out: ItemDef = _s.data.item(action.outputs[0].item_id)
		categories[out.category] = int(categories.get(out.category, 0)) + 1
		assert_true(out.category in [&"infusion", &"stone", &"currency"], "%s: output is %s" % [action.id, out.category])
		for input: ItemQty in action.inputs:
			assert_eq(_s.bank.get_count(input.item_id), 0, "%s: %s consumed" % [action.id, input.item_id])
		assert_gt(_s.skills.get_xp(SKILL), xp_start, "%s: skill XP earned" % action.id)
		assert_gt(_s.mastery.get_mastery_xp(action.id), 0, "%s: mastery XP earned" % action.id)
	assert_eq(categories.size(), 3, "the three families are produced")


func test_bind_below_the_level_is_refused_and_nothing_is_spent() -> void:
	var action: ActionDef = _s.data.action(&"bind_keen_edge")
	for input: ItemQty in action.inputs:
		TestFactory.give(_s, input.item_id, input.qty)
	var result: CommandResult = _s.actions.start(SKILL, action.id)
	assert_false(result.ok, "level %d needed" % action.level)
	assert_eq(_s.bank.get_count(SHARD), action.inputs[0].qty)


func test_bind_without_materials_does_not_produce() -> void:
	var action: ActionDef = _s.data.action(&"bind_swift_hands")
	TestFactory.give(_s, SHARD, action.inputs[0].qty)  # shards but no logs
	var started: CommandResult = _s.actions.start(SKILL, action.id)
	if started.ok:
		for i: int in 200:
			_s.advance(TICK_MS)
	assert_eq(_s.bank.get_count(action.outputs[0].item_id), 0, "no infusion without the second ingredient")
	assert_eq(_s.bank.get_count(SHARD), action.inputs[0].qty, "shards untouched")


func test_sockets_unlock_at_the_balance_levels() -> void:
	var levels: Array[int] = []
	for entry: Variant in _s.data.balance_value("rift.sockets") as Array:
		levels.append(int((entry as Dictionary)["level"]))
	assert_eq(levels, [1, 20, 40, 60, 80] as Array[int])
	assert_eq(_s.rift.socket_total(), 5)
	for i: int in levels.size():
		assert_eq(_s.rift.is_unlocked(i), levels[i] <= 1, "socket %d at level 1" % i)
	for i: int in levels.size():
		TestFactory.set_level(_s, SKILL, levels[i])
		for j: int in levels.size():
			assert_eq(_s.rift.is_unlocked(j), j <= i, "socket %d at level %d" % [j, levels[i]])
	# Just below a threshold the next socket is still locked.
	var t: GameSession = TestFactory.session(SEED, TestFactory.real_data())
	TestFactory.set_level(t, SKILL, 79)
	assert_false(t.rift.is_unlocked(4), "79 < 80")
	t.free()


func test_socket_swift_hands_changes_real_intervals_and_clear_restores() -> void:
	var action: ActionDef = _s.data.actions_for_skill(FORESTRY)[0]
	var before: int = _s.actions.current_interval_ms(action.id)
	TestFactory.give(_s, &"inf_swift_hands", 1)
	assert_true(_s.rift.socket(0, &"inf_swift_hands").ok)
	assert_eq(_s.bank.get_count(&"inf_swift_hands"), 0, "taken from the bank (the object lives in one place)")
	assert_eq(_s.rift.get_socket(0), &"inf_swift_hands")
	assert_true(_s.modifiers.has_source(&"rift_socket:0"))
	var pct: float = _s.modifiers.total(&"skill_interval_pct", ModifierContext.for_skill(FORESTRY))
	assert_eq(pct, -3.0)
	var min_ms: int = int(_s.data.balance_value(MIN_INTERVAL_KEY))
	var after: int = _s.actions.current_interval_ms(action.id)
	assert_eq(after, ActionMath.interval_ms(action.interval_ms, pct, min_ms), "F-03 with the infusion")
	assert_lt(after, before)
	assert_true(_s.rift.clear_socket(0).ok)
	assert_eq(_s.bank.get_count(&"inf_swift_hands"), 0, "removing destroys the infusion")
	assert_false(_s.modifiers.has_source(&"rift_socket:0"))
	assert_eq(_s.actions.current_interval_ms(action.id), before, "restored")
	assert_eq(_s.rift.clear_socket(0).reason, Reasons.SLOT_EMPTY)


func test_socket_refusals() -> void:
	TestFactory.give(_s, &"inf_swift_hands", 3)
	assert_eq(_s.rift.socket(1, &"inf_swift_hands").reason, Reasons.SOCKET_LOCKED, "level 20 needed")
	assert_eq(_s.rift.socket(9, &"inf_swift_hands").reason, Reasons.SOCKET_LOCKED, "unknown index")
	assert_true(_s.rift.socket(0, &"inf_swift_hands").ok)
	assert_eq(_s.rift.socket(0, &"inf_swift_hands").reason, Reasons.SOCKET_OCCUPIED)
	TestFactory.set_level(_s, SKILL, 20)
	assert_eq(_s.rift.socket(1, &"stone_ember_chip").reason, Reasons.NOT_EQUIPPABLE, "a stone is not an infusion")
	assert_eq(_s.rift.socket(1, &"rift_shard").reason, Reasons.NOT_EQUIPPABLE)
	assert_eq(_s.rift.socket(1, &"inf_bulwark").reason, Reasons.NOT_ENOUGH_ITEMS, "none in the bank")
	assert_eq(_s.bank.get_count(&"inf_swift_hands"), 2, "refusals changed nothing")


func test_same_infusion_stacks_but_unique_only_once() -> void:
	TestFactory.set_level(_s, SKILL, 60)
	TestFactory.give(_s, &"inf_swift_hands", 2)
	assert_true(_s.rift.socket(0, &"inf_swift_hands").ok)
	assert_true(_s.rift.socket(1, &"inf_swift_hands").ok)
	assert_eq(_s.modifiers.total(&"skill_interval_pct", ModifierContext.for_skill(FORESTRY)), -6.0, "modifiers add up")
	assert_true(_s.data.item(&"inf_riftsense").infusion_unique)
	TestFactory.give(_s, &"inf_riftsense", 2)
	assert_true(_s.rift.socket(2, &"inf_riftsense").ok)
	var again: CommandResult = _s.rift.socket(3, &"inf_riftsense")
	assert_eq(again.reason, Reasons.REQUIREMENT_NOT_MET, "unique")
	assert_eq(_s.bank.get_count(&"inf_riftsense"), 1, "the refused one stays in the bank")
	assert_true(_s.rift.clear_socket(2).ok)
	assert_true(_s.rift.socket(3, &"inf_riftsense").ok, "free again after clearing")


# Every infusion of the data has a real, measurable effect through the modifier system and the formulas.
func test_every_infusion_effect_reaches_its_formula() -> void:
	TestFactory.set_level(_s, SKILL, 80)
	var base_stats: CombatantStats = CombatantStats.for_player(_s)
	var forest: ModifierContext = ModifierContext.for_skill(FORESTRY)
	var forest_action: ActionDef = _s.data.actions_for_skill(FORESTRY)[0]
	var infusions: Array[ItemDef] = _items_of(&"infusion")
	assert_eq(infusions.size(), 9)
	for def: ItemDef in infusions:
		_s.rift.clear_socket(0)
		TestFactory.give(_s, def.id, 1)
		assert_true(_s.rift.socket(0, def.id).ok, "socket %s" % def.id)
		var stats: CombatantStats = CombatantStats.for_player(_s)
		for mod: Modifier in def.infusion_modifiers:
			assert_eq(_s.modifiers.total(mod.stat, forest), mod.value, "%s: %s total" % [def.id, mod.stat])
			match mod.stat:
				&"skill_interval_pct":
					assert_lt(_s.actions.current_interval_ms(forest_action.id), forest_action.interval_ms)
				&"accuracy_pct":
					assert_gt(stats.accuracy, base_stats.accuracy, "%s raises accuracy" % def.id)
				&"damage_reduction":
					assert_gt(stats.damage_reduction, base_stats.damage_reduction, "%s raises damage reduction" % def.id)
				&"max_hp_flat":
					assert_gt(stats.max_hp, base_stats.max_hp, "%s raises max hp" % def.id)
	_s.rift.clear_socket(0)


func test_scholar_and_deep_roots_raise_skill_and_mastery_xp() -> void:
	# F-02 floors per grant: +3% of a 10 XP cycle is invisible (floor(10.3) = 10), so the check uses 1000.
	assert_eq(_s.skills.add_xp(FORESTRY, 1000), 1000)
	var action: ActionDef = _s.data.actions_for_skill(FORESTRY)[0]
	var plain_mastery: int = _s.mastery.add_for_action(action)
	TestFactory.set_level(_s, SKILL, 60)
	TestFactory.give(_s, &"inf_scholar", 1)
	TestFactory.give(_s, &"inf_deep_roots", 1)
	assert_true(_s.rift.socket(0, &"inf_scholar").ok)
	assert_true(_s.rift.socket(1, &"inf_deep_roots").ok)
	assert_eq(_s.skills.add_xp(FORESTRY, 1000), 1060, "skill_xp_pct +6 (inf_scholar)")
	var boosted: int = _s.mastery.add_for_action(action)
	assert_gte(boosted, plain_mastery, "mastery_xp_pct +10 never lowers: %d vs %d" % [boosted, plain_mastery])
	assert_eq(_s.modifiers.total(&"mastery_xp_pct", ModifierContext.for_skill(FORESTRY)), 10.0)
	gut.p("measure: %s mastery gain per cycle %d -> %d with +10%% (floor hides small bonuses)" % [action.id, plain_mastery, boosted])


func test_altar_save_load_save_identical_and_rebuilds_modifiers() -> void:
	TestFactory.set_level(_s, SKILL, 40)
	TestFactory.give(_s, &"inf_bulwark", 1)
	TestFactory.give(_s, &"inf_scholar", 1)
	_s.rift.socket(0, &"inf_bulwark")
	_s.rift.socket(2, &"inf_scholar")
	var text: String = SaveCodec.encode(_s.to_save(NOW_MS))
	var copy: GameSession = TestFactory.session(SEED + 1, TestFactory.real_data())
	assert_true(copy.from_save(SaveCodec.decode(text)).ok)
	assert_eq(copy.rift.get_socket(0), &"inf_bulwark")
	assert_eq(copy.rift.get_socket(1), &"")
	assert_eq(copy.rift.get_socket(2), &"inf_scholar")
	assert_eq(copy.modifiers.total(&"max_hp_flat"), 60.0, "modifiers rebuilt after the load")
	assert_eq(copy.modifiers.total(&"skill_xp_pct"), 6.0)
	assert_eq(SaveCodec.encode(copy.to_save(NOW_MS)), text, "save -> load -> save identical")
	copy.free()
