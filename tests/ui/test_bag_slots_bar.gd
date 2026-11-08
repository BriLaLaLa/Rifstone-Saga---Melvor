extends GutTest
## BagSlotsBar inside the BankPage (M12-06, docs/05_INTERFACES.md §7.w): one `BagSlot_<i>` per slot of
## `deposit.bag_slots`, empty ones visible, put / take a bag through the bank commands, the refusal in Italian, the
## "Metti nello slot" button of the item panel. Real data, TestFactory session (never a real slot).

const SCENE: PackedScene = preload("res://ui/pages/bank/bank_page.tscn")
const BAG := &"bag_canvas"

var _session: GameSession
var _page: BankPage


func before_each() -> void:
	_session = TestFactory.session(1234, TestFactory.real_data())


func after_each() -> void:
	if is_instance_valid(_page):
		_page.free()
	if is_instance_valid(_session):
		_session.free()
	await wait_physics_frames(1)


func test_one_node_per_bag_slot_with_empty_ones_visible() -> void:
	_open()
	var count: int = _session.deposit.bag_slot_count()
	assert_eq(count, 6)
	for index: int in count:
		var slot: Button = _slot(index)
		assert_not_null(slot, "BagSlot_%d" % index)
		assert_true(slot.is_visible_in_tree())
		assert_eq(slot.text, BagTexts.EMPTY_SLOT_TEXT)
	assert_null(_slot(count), "no slot beyond the data")


func test_bar_asks_and_the_page_puts_the_bag_in_the_slot() -> void:
	TestFactory.give(_session, BAG, 1)
	_open()
	var capacity: int = _session.deposit.capacity()
	_bar().equip_requested.emit(2, BAG)
	assert_eq(_session.deposit.get_bag(2), BAG)
	assert_eq(_session.deposit.capacity(), capacity + _session.data.item(BAG).bag_slots)
	assert_string_contains(_slot(2).text, _session.data.item(BAG).name)
	assert_eq(_session.bank.get_count(BAG), 0, "the bag left the Deposit boxes")


func test_clicking_a_full_slot_takes_the_bag_back() -> void:
	TestFactory.give(_session, BAG, 1)
	_open()
	assert_true(_session.bank.equip_bag(0, BAG).ok)
	_slot(0).pressed.emit()
	assert_eq(_session.deposit.get_bag(0), &"")
	assert_eq(_session.bank.get_count(BAG), 1)
	assert_eq(_slot(0).text, BagTexts.EMPTY_SLOT_TEXT)


func test_refusal_deposit_not_empty_is_shown() -> void:
	TestFactory.give(_session, BAG, 1)
	assert_true(_session.bank.equip_bag(0, BAG).ok)
	for item: ItemDef in _session.data.items():
		if _session.deposit.has_room() and not item.is_bag() and not item.is_contract() and item.category != &"equipment":
			TestFactory.give(_session, item.id, 1)
	assert_gt(_session.deposit.used(), _session.data.balance_value("deposit.base_slots"), "uses the boxes of the bag")
	_open()
	_slot(0).pressed.emit()
	var label: Label = _page.get_node("%MessageLabel")
	assert_true(label.visible)
	assert_eq(label.text, BagTexts.refused(Reasons.DEPOSIT_NOT_EMPTY))
	assert_string_contains(label.text, "Libera prima")
	assert_eq(_session.deposit.get_bag(0), BAG, "nothing changed")


func test_item_panel_button_puts_a_bag_in_the_first_free_slot() -> void:
	TestFactory.give(_session, BAG, 1)
	_open()
	assert_true(_session.bank.equip_bag(0, BAG).ok)
	TestFactory.give(_session, BAG, 1)
	var panel: BankItemPanel = _page.get_node("%ItemPanel")
	assert_true(panel.show_item(_session, BAG))
	var button: Button = panel.find_child("BagButton", true, false)
	assert_true(button.visible)
	assert_eq(button.text, "Metti nello slot")
	button.pressed.emit()
	assert_eq(_session.deposit.get_bag(1), BAG, "slot 0 was taken: the next one")


func test_bags_changed_redraws_the_bar() -> void:
	_open()
	TestFactory.give(_session, BAG, 1)
	assert_true(_session.bank.equip_bag(5, BAG).ok)
	assert_string_contains(_slot(5).text, _session.data.item(BAG).name)


func test_unbind_disconnects_bags_changed() -> void:
	_open()
	assert_gt(_session.events.get_signal_connection_list(&"bags_changed").size(), 0)
	_page.unbind()
	assert_eq(_session.events.get_signal_connection_list(&"bags_changed").size(), 0)


func _open() -> void:
	_page = SCENE.instantiate() as BankPage
	add_child(_page)
	_page.bind(_session)


func _bar() -> BagSlotsBar:
	return _page.get_node("%BagSlotsBar") as BagSlotsBar


func _slot(index: int) -> Button:
	return _bar().get_node_or_null("BagSlot_%d" % index) as Button
