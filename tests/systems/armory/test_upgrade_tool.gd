extends GutTest
## F-94 refinement of the unique tools: the table of the nine steps, the refusals in order, the effect (interval and
## extras), atomicity and signals. Content: the M10 fixtures (test_hatchet = forestry tool with extras at +5 and +9;
## plates test_plate_1..8, handles test_handle_1..8; the table of tool_upgrade is the one of F-94).

const BlueprintData := preload("res://tests/systems/actions/blueprint_data.gd")
const FORESTRY: StringName = &"forestry"
const SLOT: StringName = &"tool_forestry"
const MIN_LEVELS: Array[int] = [1, 10, 20, 25, 35, 50, 65, 80, 90]
const GRADES: Array[int] = [1, 2, 3, 3, 4, 5, 6, 7, 8]
const PLATES: Array[int] = [2, 2, 3, 3, 4, 4, 5, 5, 6]
const HANDLES: Array[int] = [1, 1, 1, 1, 2, 2, 2, 2, 3]
const GOLD: Array[int] = [100, 250, 600, 1200, 2500, 5000, 10000, 20000, 40000]

var _data: GameData = BlueprintData.data()
var _session: GameSession = null
var _uid: int = 0


func before_each() -> void:
	_session = autofree(TestFactory.session(5, _data))
	_uid = _session.armory.tool_uid(SLOT)


func _plate(grade: int) -> StringName:
	return StringName("test_plate_%d" % grade)


func _handle(grade: int) -> StringName:
	return StringName("test_handle_%d" % grade)


## Gold, level and the components of the step towards +`target`, so that it can be bought.
func _prepare(target: int) -> void:
	if _session.skills.get_level(FORESTRY) < MIN_LEVELS[target - 1]:
		TestFactory.set_level(_session, FORESTRY, MIN_LEVELS[target - 1])
	_session.wallet.add_gold(GOLD[target - 1])
	TestFactory.give(_session, _plate(GRADES[target - 1]), PLATES[target - 1])
	TestFactory.give(_session, _handle(GRADES[target - 1]), HANDLES[target - 1])


func _interval() -> float:
	return _session.modifiers.total(&"skill_interval_pct", ModifierContext.for_skill(FORESTRY))


func test_the_table_of_the_nine_steps() -> void:
	assert_eq(ToolUpgrade.max_level(_data), 9)
	for t: int in range(1, 10):
		var row: Dictionary = ToolUpgrade.step(t, _data)
		assert_eq(row["target"], t)
		assert_eq(row["min_level"], MIN_LEVELS[t - 1], "min level +%d" % t)
		assert_eq(row["grade"], GRADES[t - 1])
		assert_eq((row["plates"] as ItemQty).item_id, _plate(GRADES[t - 1]))
		assert_eq((row["plates"] as ItemQty).qty, PLATES[t - 1])
		assert_eq((row["handles"] as ItemQty).item_id, _handle(GRADES[t - 1]))
		assert_eq((row["handles"] as ItemQty).qty, HANDLES[t - 1])
		assert_eq(row["gold"], GOLD[t - 1])
		assert_eq(row["interval_pct"], -(5.0 + 2.0 * t))
	assert_true(ToolUpgrade.step(0, _data).is_empty())
	assert_true(ToolUpgrade.step(10, _data).is_empty())


func test_interval_examples() -> void:
	assert_eq(ToolUpgrade.interval_pct(0, _data), -5.0)
	assert_eq(ToolUpgrade.interval_pct(4, _data), -13.0)
	assert_eq(ToolUpgrade.interval_pct(9, _data), -23.0)


## Pickaxe +0 -> +1 with the quarrier at level 1: 2 plates of grade 1, 1 handle, 100 gold.
func test_first_step_costs_and_effect() -> void:
	_session.wallet.add_gold(150)
	TestFactory.give(_session, _plate(1), 3)
	TestFactory.give(_session, _handle(1), 2)
	var uid: int = _session.armory.tool_uid(&"tool_quarrying")
	var gold_before: int = _session.wallet.get_gold()
	watch_signals(_session.events)
	assert_true(_session.armory.upgrade_tool(uid).ok)
	assert_eq(_session.armory.get_instance(uid).upgrade, 1)
	assert_eq(_session.wallet.get_gold(), gold_before - 100)
	assert_eq(_session.bank.get_count(_plate(1)), 1)
	assert_eq(_session.bank.get_count(_handle(1)), 1)
	assert_signal_emitted_with_parameters(_session.events, "item_upgraded", [uid, true, 1])
	assert_signal_emitted_with_parameters(_session.events, "armory_changed", [uid, &"updated"])
	assert_eq(_session.modifiers.total(&"skill_interval_pct", ModifierContext.for_skill(&"quarrying")), -7.0)


## The tool is worn from the start: -5 at +0, the sources `equipment:tool_*` follow the steps.
func test_effect_follows_the_steps() -> void:
	assert_eq(_interval(), -5.0)
	for target: int in range(1, 10):
		_prepare(target)
		assert_true(_session.armory.upgrade_tool(_uid).ok, "step +%d" % target)
		assert_eq(_interval(), -(5.0 + 2.0 * target), "+%d" % target)
	assert_eq(_session.armory.get_instance(_uid).upgrade, 9)


## Axe +4: -13; +9: -23 and double_item_chance +5 (extras at +5 and +9: +2 and +3).
func test_extras_arrive_at_their_step() -> void:
	var ctx: ModifierContext = ModifierContext.for_skill(FORESTRY)
	for target: int in range(1, 10):
		_prepare(target)
		assert_true(_session.armory.upgrade_tool(_uid).ok)
		if target == 4:
			assert_eq(_interval(), -13.0)
			assert_eq(_session.modifiers.total(&"double_item_chance", ctx), 0.0)
		if target == 5:
			assert_eq(_session.modifiers.total(&"double_item_chance", ctx), 2.0)
	assert_eq(_interval(), -23.0)
	assert_eq(_session.modifiers.total(&"double_item_chance", ctx), 5.0)
	var other: ModifierContext = ModifierContext.for_skill(&"quarrying")
	assert_eq(_session.modifiers.total(&"double_item_chance", other), 0.0, "the scope is the skill of the tool")


## F-94: the +4 step needs the craft at level 25; with 24 the answer is level_too_low and nothing changes.
func test_level_too_low_at_plus_four() -> void:
	for target: int in range(1, 4):
		_prepare(target)
		assert_true(_session.armory.upgrade_tool(_uid).ok)
	TestFactory.set_level(_session, FORESTRY, 24)
	_session.wallet.add_gold(GOLD[3])
	TestFactory.give(_session, _plate(3), PLATES[3])
	TestFactory.give(_session, _handle(3), HANDLES[3])
	var gold: int = _session.wallet.get_gold()
	assert_eq(_session.armory.upgrade_tool(_uid).reason, Reasons.LEVEL_TOO_LOW)
	assert_eq(_session.armory.get_instance(_uid).upgrade, 3)
	assert_eq(_session.wallet.get_gold(), gold)
	assert_eq(_session.bank.get_count(_plate(3)), PLATES[3])
	TestFactory.set_level(_session, FORESTRY, 25)
	assert_true(_session.armory.upgrade_tool(_uid).ok)
	assert_eq(_interval(), -13.0, "Axe +4")


func test_refusals_in_order() -> void:
	assert_eq(_session.armory.upgrade_tool(999).reason, Reasons.UNKNOWN_ID)
	var piece: int = _session.armory.create(&"test_blade", &"common", 1)
	assert_eq(_session.armory.upgrade_tool(piece).reason, Reasons.NOT_A_TOOL)
	# +1 needs gold 100 and 2 plates + 1 handle: no gold first, then no items.
	assert_eq(_session.armory.upgrade_tool(_uid).reason, Reasons.NOT_ENOUGH_GOLD)
	_session.wallet.add_gold(100)
	assert_eq(_session.armory.upgrade_tool(_uid).reason, Reasons.NOT_ENOUGH_ITEMS)
	TestFactory.give(_session, _plate(1), 2)
	assert_eq(_session.armory.upgrade_tool(_uid).reason, Reasons.NOT_ENOUGH_ITEMS, "the handle is missing")
	assert_eq(_session.armory.get_instance(_uid).upgrade, 0, "nothing changed")
	assert_eq(_session.bank.get_count(_plate(1)), 2)


## level_too_low comes before not_enough_gold.
func test_level_before_gold() -> void:
	for target: int in range(1, 4):
		_prepare(target)
		_session.armory.upgrade_tool(_uid)
	assert_eq(_session.skills.get_level(FORESTRY), 20)
	assert_eq(_session.armory.upgrade_tool(_uid).reason, Reasons.LEVEL_TOO_LOW)


func test_upgrade_max() -> void:
	for target: int in range(1, 10):
		_prepare(target)
		_session.armory.upgrade_tool(_uid)
	assert_eq(_session.armory.upgrade_tool(_uid).reason, Reasons.UPGRADE_MAX)
	assert_true(_session.armory.tool_next_step(_uid).is_empty())


func test_tool_next_step_and_tool_uid() -> void:
	assert_gt(_uid, 0)
	assert_eq(_session.armory.tool_uid(&"tool_quarrying"), _uid + 1)
	assert_eq(_session.armory.tool_uid(&"weapon"), 0)
	assert_eq(_session.armory.tool_uid(&"tool_nothing"), 0)
	var row: Dictionary = _session.armory.tool_next_step(_uid)
	assert_eq(row["target"], 1)
	assert_eq(row["interval_pct"], -7.0)
	var piece: int = _session.armory.create(&"test_blade", &"common", 1)
	assert_true(_session.armory.tool_next_step(piece).is_empty(), "not a tool")
	assert_true(_session.armory.tool_next_step(999).is_empty())


## A unique tool: no lock, no removal, no F-86 refinement, no sockets.
func test_unique_tool_is_untouchable() -> void:
	assert_eq(_session.armory.set_locked(_uid, true).reason, Reasons.ITEM_UNIQUE)
	assert_eq(_session.armory.remove(_uid).reason, Reasons.ITEM_UNIQUE)
	assert_eq(_session.armory.upgrade(_uid).reason, Reasons.NOT_EQUIPPABLE)
	assert_false(_session.armory.get_instance(_uid).locked)
	assert_eq(_session.armory.socket_count(_uid), 0)


func test_the_upgrade_survives_a_save() -> void:
	_prepare(1)
	_session.armory.upgrade_tool(_uid)
	var saved: Dictionary = _session.to_save(0)
	var loaded: GameSession = autofree(TestFactory.session(9, _data))
	assert_true(loaded.from_save(saved).ok)
	assert_eq(loaded.armory.get_instance(_uid).upgrade, 1)
	assert_eq(loaded.modifiers.total(&"skill_interval_pct", ModifierContext.for_skill(FORESTRY)), -7.0)
