extends GutTest
## BankPage (M1-18) with a TestFactory session (never Game.session, never a real slot): one ItemSlotView per stack of
## `bank.stacks()` in the bank's order, quantities from the last read, cells freed at 0, counter "used / capacity",
## redraw on bank_changed / bank_capacity_changed, everything disconnected by unbind and when the page is freed.
## M2-04: search by name, "Ordina" (sort_stacks), item panel with lock / unlock (set_locked), drag and drop with real
## mouse events (move_stack; a refused move moves nothing and shows its reason), order kept by the save, compact counts
## that never widen a cell, tooltip of the hovered cell reread on bank_changed, layout constants from UiStyle.BANK_*.

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
	Tooltips.hide_tooltip()
	# Removed cells are freed with queue_free: let them go before the orphan count.
	await wait_physics_frames(1)


func test_empty_bank() -> void:
	_open()
	assert_eq(_cells().size(), 0)
	assert_true(_label("%EmptyLabel").visible)
	assert_eq(_label("%TitleLabel").text, "Deposito")
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
	assert_eq(_count_text(0), NumberFormat.format_compact(_session.bank.get_count(TWIG)))
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


func test_layout_constants_and_long_counts() -> void:
	TestFactory.give(_session, TWIG, 123456789)
	TestFactory.give(_session, LOG, 3)
	_open()
	await _settle()
	assert_eq(_count_text(0), "123M")
	assert_eq(_cells()[0].size, _cells()[1].size, "a long number does not widen its cell")
	assert_eq(_cells()[0].size, UiStyle.BANK_CELL_SIZE)
	var grid: HFlowContainer = _page.get_node("%Grid") as HFlowContainer
	assert_eq(grid.get_theme_constant("h_separation"), UiStyle.BANK_GRID_SEPARATION)
	assert_eq(grid.get_theme_constant("v_separation"), UiStyle.BANK_GRID_SEPARATION)
	assert_eq((_page.get_node("%Margin") as Control).get_theme_constant("margin_left"), UiStyle.BANK_MARGIN)


func test_search_filters_by_name() -> void:
	TestFactory.give(_session, TWIG, 3)
	TestFactory.give(_session, LOG, 2)
	TestFactory.give(_session, PLANK, 1)
	_open()
	_search("TRONCO")
	assert_eq(_shown_ids(), [LOG] as Array[StringName], "case-insensitive, by name")
	_search("di prova")
	assert_eq(_shown_ids(), [TWIG, LOG, PLANK] as Array[StringName], "bank order kept")
	_search("nessuno")
	assert_eq(_cells().size(), 0)
	assert_true(_label("%EmptyLabel").visible)
	assert_eq(_label("%EmptyLabel").text, BankPage.NO_MATCH_TEXT)
	TestFactory.give(_session, TWIG, 1)
	assert_eq(_cells().size(), 0, "the filter stays on after a bank change")
	_search("")
	assert_eq(_shown_ids(), [TWIG, LOG, PLANK] as Array[StringName])
	assert_eq(_label("%SlotsLabel").text, "Caselle: 3 / %s" % NumberFormat.format_int(_session.bank.capacity()))


func test_sort_button_sorts_the_bank() -> void:
	TestFactory.give(_session, PLANK, 1)
	TestFactory.give(_session, TWIG, 3)
	TestFactory.give(_session, LOG, 2)
	_open()
	(_page.get_node("%SortButton") as Button).pressed.emit()
	assert_eq(_session.bank.stacks().map(func(s: Dictionary) -> StringName: return s["item"]),
			[TWIG, LOG, PLANK], "sort_order of the fixture items")
	_assert_cells_match_stacks()


func test_click_opens_the_item_panel() -> void:
	TestFactory.give(_session, TWIG, 3)
	TestFactory.give(_session, LOG, 1250)
	_open()
	assert_false(_panel().visible, "closed until a cell is clicked")
	_click(_cells()[1])
	assert_true(_panel().visible)
	assert_eq(_panel().item_id(), LOG)
	assert_eq(_panel_label("%NameLabel").text, _session.data.item(LOG).name)
	assert_eq(_panel_label("%CountLabel").text, "Quantità: 1.250", "full quantity in the panel")
	TestFactory.give(_session, LOG, 5)
	assert_eq(_panel_label("%CountLabel").text, "Quantità: 1.255", "the panel rereads the bank")
	assert_true(_session.bank.remove(LOG, 1255).ok)
	assert_false(_panel().visible, "stack gone: panel closed")
	_click(_cells()[0])
	_panel().close_requested.emit()
	assert_false(_panel().visible)
	assert_eq(_panel().item_id(), &"")


func test_lock_and_unlock_from_the_panel() -> void:
	TestFactory.give(_session, TWIG, 3)
	TestFactory.give(_session, LOG, 2)
	_open()
	_click(_cells()[1])
	var button: Button = _panel().get_node("%LockButton") as Button
	assert_eq(button.text, BankItemPanel.LOCK_TEXT)
	button.pressed.emit()
	assert_true(_session.bank.is_locked(LOG), "set_locked through the bank")
	assert_false(_session.bank.is_locked(TWIG))
	assert_true((_cells()[1].get_node("%LockMarker") as Control).visible)
	assert_eq(button.text, BankItemPanel.UNLOCK_TEXT)
	assert_eq(_panel_label("%LockStateLabel").text, BankItemPanel.LOCKED_TEXT)
	button.pressed.emit()
	assert_false(_session.bank.is_locked(LOG))
	assert_false((_cells()[1].get_node("%LockMarker") as Control).visible)


func test_drag_onto_a_cell_moves_the_stack_and_the_save_keeps_it() -> void:
	TestFactory.give(_session, TWIG, 3)
	TestFactory.give(_session, LOG, 2)
	TestFactory.give(_session, PLANK, 1)
	_open()
	await _settle()
	await _drag(_cells()[2], _center(_cells()[0]))
	assert_eq(_session.bank.stacks().map(func(s: Dictionary) -> StringName: return s["item"]),
			[PLANK, TWIG, LOG], "move_stack to the index of the target cell")
	_assert_cells_match_stacks()
	assert_false(_label("%MessageLabel").visible)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(_session.to_save(0)))
	_page.free()
	_session.free()
	_session = TestFactory.session()
	assert_true(_session.from_save(saved).ok)
	_open()
	assert_eq(_shown_ids(), [PLANK, TWIG, LOG] as Array[StringName], "order read back from the save")


func test_drag_outside_the_cells_moves_the_stack_last() -> void:
	TestFactory.give(_session, TWIG, 3)
	TestFactory.give(_session, LOG, 2)
	TestFactory.give(_session, PLANK, 1)
	_open()
	await _settle()
	var gap: Vector2 = Vector2(_cells()[0].get_global_rect().end.x + UiStyle.BANK_GRID_SEPARATION * 0.5,
			_center(_cells()[0]).y)
	await _drag(_cells()[0], gap)
	assert_eq(_shown_ids(), [LOG, PLANK, TWIG] as Array[StringName], "spacing between cells: last")
	var free_spot: Vector2 = _center(_cells()[2]) + Vector2(UiStyle.BANK_CELL_SIZE.x * 3.0, 0.0)
	assert_true((_page.get_node("%Grid") as Control).get_global_rect().has_point(free_spot), "inside the grid")
	await _drag(_cells()[0], free_spot)
	assert_eq(_shown_ids(), [PLANK, TWIG, LOG] as Array[StringName], "after the last cell: last")
	_assert_cells_match_stacks()


func test_refused_move_moves_nothing() -> void:
	TestFactory.give(_session, TWIG, 3)
	TestFactory.give(_session, LOG, 2)
	TestFactory.give(_session, PLANK, 1)
	_open()
	await _settle()
	var target: Vector2 = _center(_cells()[1])
	# The dragged stack leaves the bank while it is dragged (its cell now shows the next stack): unknown_id.
	await _drag(_cells()[0], target, func() -> void: assert_true(_session.bank.remove(TWIG, 3).ok))
	assert_eq(_shown_ids(), [LOG, PLANK] as Array[StringName], "nothing moved")
	_assert_cells_match_stacks()
	assert_true(_label("%MessageLabel").visible)
	assert_eq(_label("%MessageLabel").text, BankPage.REFUSED_TEXTS[Reasons.UNKNOWN_ID])


func test_tooltip_follows_bank_changed() -> void:
	TestFactory.give(_session, TWIG, 3)
	TestFactory.give(_session, LOG, 2)
	_open()
	var tooltip: CustomTooltip = Tooltips.get_node("TooltipLayer/CustomTooltip") as CustomTooltip
	_cells()[0].mouse_entered.emit()
	assert_string_contains(tooltip.title_text(), "Quantità: 3")
	TestFactory.give(_session, TWIG, 1247)
	assert_true(tooltip.is_shown())
	assert_string_contains(tooltip.title_text(), "Quantità: 1.250", "quantity reread while visible")
	assert_true(_session.bank.remove(TWIG, 1250).ok)
	assert_string_contains(tooltip.title_text(), _session.data.item(LOG).name, "the cell now holds the next stack")
	assert_true(_session.bank.remove(LOG, 2).ok)
	assert_false(tooltip.is_shown(), "hovered cell gone: tooltip closed")


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
		assert_eq(_count_text(index), NumberFormat.format_compact(stacks[index]["count"]), "count of cell %d" % index)


## The cells that hold an item (the grid also draws empty cells up to the capacity).
func _cells() -> Array[ItemSlotView]:
	var cells: Array[ItemSlotView] = []
	for child: Node in _page.get_node("%Grid").get_children():
		if child is ItemSlotView and not child.is_queued_for_deletion() and (child as ItemSlotView).item_id() != &"":
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


func _panel() -> BankItemPanel:
	return _page.get_node("%ItemPanel") as BankItemPanel


func _panel_label(path: String) -> Label:
	return _panel().get_node(path) as Label


func _search(text: String) -> void:
	var edit: LineEdit = _page.get_node("%SearchEdit") as LineEdit
	edit.text = text
	edit.text_changed.emit(text)


func _click(cell: ItemSlotView) -> void:
	cell.pressed.emit(cell.item_id())


func _center(control: Control) -> Vector2:
	return control.get_global_rect().get_center()


## Lets the containers sort their children (the grid lays out its cells deferred).
func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


## Real drag and drop through the viewport: left press on `cell`, motion past the drag threshold, `during` (if valid),
## motion and release at the global position `to`.
func _drag(cell: ItemSlotView, to: Vector2, during: Callable = Callable()) -> void:
	var from: Vector2 = _center(cell)
	var moved: Vector2 = from + Vector2(24, 0)
	_push_button(from, true)
	_push_motion(from, moved)
	await _settle()
	if during.is_valid():
		during.call()
		await _settle()
	_push_motion(moved, to)
	_push_button(to, false)
	await _settle()


func _push_button(at: Vector2, pressed: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.position = at
	event.global_position = at
	get_viewport().push_input(event, true)


func _push_motion(previous: Vector2, at: Vector2) -> void:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.position = at
	event.global_position = at
	event.relative = at - previous
	get_viewport().push_input(event, true)


func test_empty_cells_fill_the_grid_up_to_the_capacity() -> void:
	TestFactory.give(_session, TWIG, 3)
	_open()
	await _settle()
	var all: Array[Node] = _page.get_node("%Grid").get_children().filter(
			func(n: Node) -> bool: return not n.is_queued_for_deletion())
	assert_eq(all.size(), _session.bank.capacity(), "one cell per slot")
	assert_eq(_cells().size(), _session.bank.used())
