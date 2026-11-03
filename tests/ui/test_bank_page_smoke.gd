extends GutTest
## BankPage (M1-18) with a TestFactory session (never Game.session, never a real slot): one ItemSlotView per stack of
## `bank.stacks()` in the bank's order, quantities from the last read, cells freed at 0, counter "used / capacity",
## redraw on bank_changed / bank_capacity_changed, everything disconnected by unbind and when the page is freed.

const SCENE: PackedScene = preload("res://ui/pages/bank/bank_page.tscn")
const TWIG := &"test_twig"
const LOG := &"test_log"
const PLANK := &"test_plank"
const BANK_SLOTS_STAT := &"bank_slots"
## Every bank event a page may connect to.
const OBSERVED: Array[StringName] = [&"bank_changed", &"bank_capacity_changed", &"bank_rejected", &"modifiers_changed"]

var _session: GameSession
var _page: BankPage


func before_each() -> void:
	_session = TestFactory.session()


func after_each() -> void:
	# The page first (it unbinds from the session), then the session.
	if is_instance_valid(_page):
		_page.free()
	if is_instance_valid(_session):
		_session.free()
	# Removed cells are freed with queue_free: let them go before the orphan count.
	await wait_physics_frames(1)


func test_empty_bank() -> void:
	_open()
	assert_eq(_cells().size(), 0)
	assert_true(_label("%EmptyLabel").visible)
	assert_eq(_label("%TitleLabel").text, "Bank")
	assert_eq(_label("%SlotsLabel").text, "Caselle: 0 / %s" % NumberFormat.format_int(_session.bank.capacity()))
	assert_false(_label("%FullLabel").visible)


func test_cells_follow_the_order_of_stacks() -> void:
	TestFactory.give(_session, LOG, 1250)
	TestFactory.give(_session, TWIG, 3)
	TestFactory.give(_session, PLANK, 7)
	_open()
	_assert_cells_match_stacks()
	assert_eq(_shown_ids(), [LOG, TWIG, PLANK] as Array[StringName], "insertion order, not data order")
	assert_eq(_count_text(0), "1.250")
	assert_false(_label("%EmptyLabel").visible)
	assert_eq(_label("%SlotsLabel").text, "Caselle: 3 / %s" % NumberFormat.format_int(_session.bank.capacity()))


func test_bank_changed_rereads_the_bank() -> void:
	_open()
	TestFactory.give(_session, TWIG, 3)
	assert_eq(_shown_ids(), [TWIG] as Array[StringName], "new item: new cell")
	assert_eq(_count_text(0), "3")
	TestFactory.give(_session, TWIG, 2)
	assert_eq(_cells().size(), 1, "same item: same cell")
	assert_eq(_count_text(0), NumberFormat.format_int(_session.bank.get_count(TWIG)))
	TestFactory.give(_session, LOG, 1)
	assert_eq(_shown_ids(), [TWIG, LOG] as Array[StringName])
	assert_true(_session.bank.remove(TWIG, 1).ok)
	assert_eq(_count_text(0), "4")
	assert_eq(_label("%SlotsLabel").text, "Caselle: 2 / %s" % NumberFormat.format_int(_session.bank.capacity()))


func test_stack_at_zero_frees_its_cell() -> void:
	TestFactory.give(_session, TWIG, 3)
	TestFactory.give(_session, LOG, 2)
	_open()
	assert_true(_session.bank.remove(TWIG, 3).ok)
	assert_eq(_shown_ids(), [LOG] as Array[StringName], "the next stack moves up")
	assert_eq(_count_text(0), "2")
	assert_eq(_label("%SlotsLabel").text, "Caselle: 1 / %s" % NumberFormat.format_int(_session.bank.capacity()))
	assert_true(_session.bank.remove(LOG, 2).ok)
	assert_eq(_cells().size(), 0)
	assert_true(_label("%EmptyLabel").visible)


func test_lock_and_move_are_read_from_the_bank() -> void:
	TestFactory.give(_session, TWIG, 3)
	TestFactory.give(_session, LOG, 2)
	_open()
	assert_true(_session.bank.set_locked(LOG, true).ok)
	assert_true((_cells()[1].get_node("%LockMarker") as Control).visible, "locked stack drawn locked")
	assert_true(_session.bank.move_stack(LOG, 0).ok)
	_assert_cells_match_stacks()
	assert_eq(_shown_ids(), [LOG, TWIG] as Array[StringName])
	assert_true((_cells()[0].get_node("%LockMarker") as Control).visible)
	assert_false((_cells()[1].get_node("%LockMarker") as Control).visible)


func test_counter_follows_the_capacity() -> void:
	_open()
	var mods: Array[Modifier] = [Modifier.make(BANK_SLOTS_STAT, 6.0, &"global", &"")]
	_session.modifiers.set_source(&"test", mods)
	assert_eq(_label("%SlotsLabel").text, "Caselle: 0 / %s" % NumberFormat.format_int(_session.bank.capacity()))
	assert_eq(_session.bank.capacity(), 30, "F-16: 24 + 6")


func test_unbind_disconnects_everything() -> void:
	var baseline: Dictionary[StringName, int] = _counts()
	_open()
	var bound: Dictionary[StringName, int] = _counts()
	assert_eq(bound[&"bank_changed"], baseline[&"bank_changed"] + 1)
	assert_eq(bound[&"bank_capacity_changed"], baseline[&"bank_capacity_changed"] + 1)
	assert_eq(bound[&"bank_rejected"], baseline[&"bank_rejected"])
	assert_eq(bound[&"modifiers_changed"], baseline[&"modifiers_changed"])
	_page.unbind()
	assert_eq(_counts(), baseline, "back to the baseline")
	TestFactory.give(_session, TWIG, 1)
	assert_eq(_cells().size(), 0, "no redraw after unbind")
	_page.unbind()
	assert_eq(_counts(), baseline, "unbind twice is safe")


func test_freeing_the_page_disconnects_everything() -> void:
	var baseline: Dictionary[StringName, int] = _counts()
	_open()
	_page.free()
	assert_eq(_counts(), baseline)


func test_real_data_bank() -> void:
	_session.free()
	_session = TestFactory.session(1234, TestFactory.real_data())
	_open()
	assert_eq(_cells().size(), _session.bank.used(), "start items of the real data")
	_assert_cells_match_stacks()
	assert_eq(_label("%SlotsLabel").text, "Caselle: %s / %s" % [
		NumberFormat.format_int(_session.bank.used()), NumberFormat.format_int(_session.bank.capacity())])


func _open() -> void:
	_page = SCENE.instantiate() as BankPage
	_page.page_id = &"bank"
	add_child(_page)
	_page.bind(_session)


func _assert_cells_match_stacks() -> void:
	var stacks: Array[Dictionary] = _session.bank.stacks()
	var cells: Array[ItemSlotView] = _cells()
	assert_eq(cells.size(), stacks.size(), "one cell per stack")
	for index: int in mini(cells.size(), stacks.size()):
		assert_eq(cells[index].item_id(), stacks[index]["item"], "cell %d" % index)
		assert_eq(_count_text(index), NumberFormat.format_int(stacks[index]["count"]), "count of cell %d" % index)


func _cells() -> Array[ItemSlotView]:
	var cells: Array[ItemSlotView] = []
	for child: Node in _page.get_node("%Grid").get_children():
		if child is ItemSlotView and not child.is_queued_for_deletion():
			cells.append(child as ItemSlotView)
	return cells


func _shown_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for cell: ItemSlotView in _cells():
		ids.append(cell.item_id())
	return ids


func _count_text(index: int) -> String:
	return (_cells()[index].get_node("%CountLabel") as Label).text


func _counts() -> Dictionary[StringName, int]:
	var counts: Dictionary[StringName, int] = {}
	for signal_name: StringName in OBSERVED:
		counts[signal_name] = _session.events.get_signal_connection_list(signal_name).size()
	return counts


func _label(path: String) -> Label:
	return _page.get_node(path) as Label
