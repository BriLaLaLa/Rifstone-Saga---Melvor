extends GutTest
## BlueprintCraft and ActionRunner.start_blueprint (F-90, F-91, F-92; docs/05_INTERFACES.md §5.8b).
## Content: the M10 fixtures plus one smelting recipe per grade (blueprint_data.gd). bp_test_blade = grade 1 (level 1):
## 5 test_plate_1 + 1 test_handle_1 + rare component 1 test_log; bp_test_helm_high = grade 2 (level 10).

const BlueprintData := preload("res://tests/systems/actions/blueprint_data.gd")
const BP: StringName = &"bp_test_blade"
const BP_HIGH: StringName = &"bp_test_helm_high"
const PLATE: StringName = &"test_plate_1"
const HANDLE: StringName = &"test_handle_1"
const RARE: StringName = &"test_log"
const FORGING: StringName = &"forging"
const MIN_MS: int = 60000

var _session: GameSession = null
var _log: Array[String] = []
var _kit_uids: Array[int] = []  # pieces owned at the start (the starting kit, if any)


func before_each() -> void:
	_session = autofree(TestFactory.session(1234, BlueprintData.data()))
	_log.clear()
	_kit_uids.clear()
	for inst: ItemInstance in _session.armory.instances():
		_kit_uids.append(inst.uid)


## F-90: 10 min / 3.600 XP (grade 1), 31 min / 44.640 (grade 4), 59 min / 307.980 (grade 8), -10% -> 9 min.
func test_duration_and_xp() -> void:
	var data: GameData = TestFactory.real_data()
	assert_eq(BlueprintCraft.duration_ms(_grade(1), 0.0, data), 10 * MIN_MS)
	assert_eq(BlueprintCraft.xp(_grade(1), data), 3600)
	assert_eq(BlueprintCraft.duration_ms(_grade(4), 0.0, data), 31 * MIN_MS)
	assert_eq(BlueprintCraft.xp(_grade(4), data), 44640)
	assert_eq(BlueprintCraft.duration_ms(_grade(8), 0.0, data), 59 * MIN_MS)
	assert_eq(BlueprintCraft.xp(_grade(8), data), 307980)
	assert_eq(BlueprintCraft.duration_ms(_grade(1), -10.0, data), 9 * MIN_MS)
	assert_eq(BlueprintCraft.xp(_grade(1), data), 3600, "the xp uses the base duration, not the F-03 one")


func test_required_level_is_the_level_of_the_grade() -> void:
	var levels: Array[int] = [1, 10, 20, 30, 45, 60, 75, 90]
	for grade: int in 8:
		assert_eq(BlueprintCraft.required_level(_grade(grade + 1), TestFactory.real_data()), levels[grade])


func test_inputs_are_the_materials_and_the_rare_component() -> void:
	var list: Array[ItemQty] = BlueprintCraft.inputs(_session.data.item(BP))
	assert_eq(list.size(), 3)
	assert_eq([list[0].item_id, list[0].qty], [PLATE, 5])
	assert_eq([list[2].item_id, list[2].qty], [RARE, 1])


func test_can_start_refusals_in_order() -> void:
	assert_eq(BlueprintCraft.can_start(_session, &"nope").reason, Reasons.UNKNOWN_ID)
	assert_eq(BlueprintCraft.can_start(_session, &"test_log").reason, Reasons.UNKNOWN_ID, "not a blueprint")
	assert_eq(BlueprintCraft.can_start(_session, BP).reason, Reasons.UNKNOWN_ID, "not in the bank")
	TestFactory.give(_session, BP_HIGH, 1)
	assert_eq(BlueprintCraft.can_start(_session, BP_HIGH).reason, Reasons.LEVEL_TOO_LOW)
	TestFactory.give(_session, BP, 1)
	assert_eq(BlueprintCraft.can_start(_session, BP, &"test_keen").reason, Reasons.INVALID_CHOICE, "level < 50")
	TestFactory.set_level(_session, FORGING, 50)
	assert_eq(BlueprintCraft.can_start(_session, BP, &"test_nimble").reason, Reasons.INVALID_CHOICE, "not for weapons")
	assert_eq(BlueprintCraft.can_start(_session, BP, &"nope").reason, Reasons.INVALID_CHOICE)
	assert_eq(BlueprintCraft.can_start(_session, BP, &"test_keen").reason, Reasons.MISSING_INPUTS)
	_give_materials()
	_fill_armory()
	assert_eq(BlueprintCraft.can_start(_session, BP, &"test_keen").reason, Reasons.ARMORY_FULL)
	_free_armory_slot()
	assert_true(BlueprintCraft.can_start(_session, BP, &"test_keen").ok)
	assert_true(BlueprintCraft.can_start(_session, BP).ok)


func test_choice_needs_level_50() -> void:
	_give_all()
	TestFactory.set_level(_session, FORGING, 49)
	assert_eq(_session.actions.start_blueprint(BP, &"test_keen").reason, Reasons.INVALID_CHOICE)
	TestFactory.set_level(_session, FORGING, 50)
	assert_true(_session.actions.start_blueprint(BP, &"test_keen").ok)


func test_refused_start_changes_nothing() -> void:
	TestFactory.give(_session, BP, 1)
	_watch()
	assert_eq(_session.actions.start_blueprint(BP).reason, Reasons.MISSING_INPUTS)
	assert_eq(_session.bank.get_count(BP), 1)
	assert_false(_session.actions.is_running())
	assert_eq(_log.size(), 0)


func test_start_consumes_everything_and_emits_action_started() -> void:
	_give_all()
	_watch()
	assert_true(_session.actions.start_blueprint(BP).ok)
	for item_id: StringName in [BP, PLATE, HANDLE, RARE]:
		assert_eq(_session.bank.get_count(item_id), 0, String(item_id))
	assert_true(_session.actions.is_running())
	assert_true(_log.has("started main forging blueprint_craft"))
	var state: Dictionary = _session.actions.blueprint_state()
	assert_eq(state["blueprint"], BP)
	assert_eq(state["duration_ms"], 10 * MIN_MS)
	assert_eq(state["elapsed_ms"], 0)
	assert_false(state["waiting"])
	assert_eq(_session.actions.get_lane()["interval_ms"], 10 * MIN_MS)


func test_direct_start_is_refused() -> void:
	assert_eq(_session.actions.start(FORGING, &"blueprint_craft").reason, Reasons.UNKNOWN_ID)
	assert_false(_session.actions.is_running())


func test_stop_gives_everything_back() -> void:
	_give_all()
	_session.actions.start_blueprint(BP)
	_session.actions.advance(MIN_MS)
	_session.actions.stop()
	assert_eq(_session.bank.get_count(BP), 1)
	assert_eq(_session.bank.get_count(PLATE), 5)
	assert_eq(_session.bank.get_count(HANDLE), 1)
	assert_eq(_session.bank.get_count(RARE), 1)
	assert_eq(_new_pieces().size(), 0)
	assert_eq(_session.actions.blueprint_state(), {})
	assert_eq(_session.actions.stop_reasons_log(), [Reasons.STOPPED_BY_USER] as Array[StringName])


func test_replaced_gives_everything_back() -> void:
	_give_all()
	_session.actions.start_blueprint(BP)
	TestFactory.give(_session, &"test_log", 2)
	assert_true(_session.actions.start(&"test_craft", &"craft_plank").ok)
	assert_eq(_session.bank.get_count(BP), 1)
	assert_eq(_session.bank.get_count(PLATE), 5)
	assert_eq(_session.actions.stop_reasons_log(), [Reasons.REPLACED] as Array[StringName])


func test_completion_creates_a_magic_or_rare_piece_with_xp_and_signals() -> void:
	_give_all()
	TestFactory.set_level(_session, FORGING, 50)
	var xp_before: int = _session.skills.get_xp(FORGING)
	_session.actions.start_blueprint(BP, &"test_keen")
	_watch()
	_session.actions.advance(10 * MIN_MS - 1)
	assert_true(_session.actions.is_running())
	_session.actions.advance(1)
	assert_false(_session.actions.is_running())
	var added: Array[ItemInstance] = _new_pieces()
	assert_eq(added.size(), 1)
	var piece: ItemInstance = added[0]
	assert_eq(piece.base_id, &"test_blade")
	assert_true(piece.rarity == &"magic" or piece.rarity == &"rare")
	assert_eq(piece.ilvl, 1)
	assert_eq(piece.affixes[0].affix_id, &"test_keen")
	assert_eq(_session.skills.get_xp(FORGING) - xp_before, 3600)
	# armory_changed(added) -> xp_gained -> blueprint_crafted -> action_completed -> action_stopped(blueprint_done)
	var pos: Array[int] = []
	for entry: String in ["armory %d added" % piece.uid, "xp forging 3600", "crafted %s %d" % [BP, piece.uid],
			"completed %s" % [{&"test_blade": 1}], "stopped blueprint_done"]:
		pos.append(_log.find(entry))
		assert_gt(pos.back(), -1, entry)
	var sorted: Array[int] = pos.duplicate()
	sorted.sort()
	assert_eq(pos, sorted)
	assert_eq(_session.bank.get_count(PLATE), 0, "nothing is given back at the end")
	assert_eq(_session.actions.stop_reasons_log(), [Reasons.BLUEPRINT_DONE] as Array[StringName])


func test_one_big_advance_finishes_offline() -> void:
	_give_all()
	_session.actions.start_blueprint(BP)
	_session.actions.advance(12 * 60 * MIN_MS)
	assert_false(_session.actions.is_running())
	assert_eq(_new_pieces().size(), 1)


func test_save_in_the_middle_resumes() -> void:
	_give_all()
	_session.actions.start_blueprint(BP)
	_session.actions.advance(4 * MIN_MS)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(_session.actions.to_save()))
	var lane: Dictionary = (saved["lanes"] as Dictionary)["main"]
	assert_eq(lane["blueprint"], String(BP))
	assert_eq(int(lane["duration_ms"]), 10 * MIN_MS)
	assert_eq(lane["action"], "blueprint_craft")
	var other: GameSession = autofree(TestFactory.session(99, BlueprintData.data()))
	other.actions.from_save(saved)
	assert_true(other.actions.is_running())
	assert_eq(other.actions.blueprint_state()["elapsed_ms"], 4 * MIN_MS)
	assert_almost_eq(other.actions.get_progress(), 0.4, 0.0001)
	other.actions.advance(6 * MIN_MS)
	assert_false(other.actions.is_running())
	assert_eq(other.armory.instances().size(), _kit_uids.size() + 1)


func test_bad_saves_leave_the_lane_idle() -> void:
	var entry: Dictionary = {"skill": "forging", "action": "blueprint_craft", "elapsed_ms": 5,
			"blueprint": "no_such", "chosen_affix": "", "duration_ms": 1000}
	_session.actions.from_save({"lanes": {"main": entry}})
	assert_false(_session.actions.is_running())
	entry["blueprint"] = String(BP)
	entry["duration_ms"] = "soon"
	_session.actions.from_save({"lanes": {"main": entry}})
	assert_false(_session.actions.is_running())
	entry["duration_ms"] = 1000.5
	_session.actions.from_save({"lanes": {"main": entry}})
	assert_false(_session.actions.is_running())


func test_full_armory_at_the_end_waits_without_losing_anything() -> void:
	_give_all()
	_session.actions.start_blueprint(BP)
	_fill_armory()
	_watch()
	_session.actions.advance(10 * MIN_MS)
	assert_true(_session.actions.is_running())
	assert_true(_session.actions.blueprint_state()["waiting"])
	assert_almost_eq(_session.actions.get_progress(), 1.0, 0.0001)
	_session.actions.advance(MIN_MS)
	_session.actions.advance(MIN_MS)
	assert_eq(_count("notify"), 1, "one notification")
	assert_eq(_count("stopped"), 0)
	_free_armory_slot()
	_session.actions.advance(1)
	assert_false(_session.actions.is_running())
	assert_eq(_count("crafted"), 1)


func test_no_rolls_while_the_armory_is_full() -> void:
	_give_all()
	_session.actions.start_blueprint(BP)
	_fill_armory()
	var before: Dictionary = _session.rng.to_save()
	_session.actions.advance(10 * MIN_MS)
	assert_eq(_session.rng.to_save(), before)


func test_item_rarity_pct_comes_from_the_action_context() -> void:
	_give_all()
	TestFactory.set_level(_session, FORGING, 99)
	_session.modifiers.set_source(&"test", [Modifier.make(&"item_rarity_pct", 100.0)] as Array[Modifier])
	_session.actions.start_blueprint(BP)
	_session.actions.advance(10 * MIN_MS)
	assert_eq(_new_pieces()[0].rarity, &"rare", "p_rare 119.0 -> 100 at level 99 with +100%")


func test_skill_interval_pct_shortens_the_work() -> void:
	_give_all()
	_session.modifiers.set_source(&"test", [Modifier.make(&"skill_interval_pct", -10.0, Modifier.SCOPE_SKILL,
			FORGING)] as Array[Modifier])
	_session.actions.start_blueprint(BP)
	assert_eq(_session.actions.blueprint_state()["duration_ms"], 9 * MIN_MS)


func _grade(grade: int) -> ItemDef:
	var bp := ItemDef.new()
	bp.id = &"bp_hand_made"
	bp.category = &"blueprint"
	bp.blueprint = BlueprintInfo.new()
	bp.blueprint.base_id = &"test_blade"
	bp.blueprint.grade = grade
	return bp


func _give_materials() -> void:
	TestFactory.give(_session, PLATE, 5)
	TestFactory.give(_session, HANDLE, 1)
	TestFactory.give(_session, RARE, 1)


func _give_all() -> void:
	TestFactory.give(_session, BP, 1)
	_give_materials()


func _fill_armory() -> void:
	while _session.armory.can_add(1):
		TestFactory.give_piece(_session, &"test_blade")


func _free_armory_slot() -> void:
	var all: Array[ItemInstance] = _session.armory.instances()
	assert_true(_session.armory.remove(all.back().uid).ok)


# The instances created after the starting kit.
func _new_pieces() -> Array[ItemInstance]:
	var result: Array[ItemInstance] = []
	for inst: ItemInstance in _session.armory.instances():
		if not _kit_uids.has(inst.uid):
			result.append(inst)
	return result


func _count(prefix: String) -> int:
	return _log.filter(func(line: String) -> bool: return line.begins_with(prefix)).size()


func _watch() -> void:
	var ev: GameEvents = _session.events
	ev.action_started.connect(func(l: StringName, s: StringName, a: StringName) -> void:
		_log.append("started %s %s %s" % [l, s, a]))
	ev.action_stopped.connect(func(_l: StringName, _s: StringName, r: StringName) -> void:
		_log.append("stopped %s" % r))
	ev.action_completed.connect(func(_l: StringName, _s: StringName, _a: StringName, o: Dictionary) -> void:
		_log.append("completed %s" % [o]))
	ev.armory_changed.connect(func(u: int, c: StringName) -> void: _log.append("armory %d %s" % [u, c]))
	ev.xp_gained.connect(func(s: StringName, n: int) -> void: _log.append("xp %s %d" % [s, n]))
	ev.blueprint_crafted.connect(func(b: StringName, u: int) -> void: _log.append("crafted %s %d" % [b, u]))
	ev.notification_requested.connect(func(_t: String, k: StringName) -> void: _log.append("notify %s" % k))
