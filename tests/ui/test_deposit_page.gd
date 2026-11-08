extends GutTest
## Deposit page (M12-06, docs/05_INTERFACES.md §7.w): two tabs on the same capacity. Both draw `deposit.capacity()`
## boxes (own items, boxes of the other tab, free boxes), the counters agree with the Equipment page and the TopBar, the
## pieces of the "Equipaggiamento" tab are the ones of the Equipment page, everything redraws on `deposit_changed`.

const BANK_SCENE: PackedScene = preload("res://ui/pages/bank/bank_page.tscn")
const EQUIPMENT_SCENE: PackedScene = preload("res://ui/pages/equipment/equipment_page.tscn")
const TOP_BAR_SCENE: PackedScene = preload("res://ui/screens/main/top_bar.tscn")
const SWORD := &"emberbronze_sword"

var _session: GameSession
var _bank: BankPage
var _equipment: EquipmentPage
var _top: Node


func before_each() -> void:
	_session = TestFactory.session(1234, TestFactory.real_data())


func after_each() -> void:
	for node: Node in [_bank, _equipment, _top]:
		if is_instance_valid(node):
			node.free()
	if is_instance_valid(_session):
		_session.free()
	await wait_physics_frames(1)


func test_two_tabs_with_their_titles() -> void:
	_open()
	var tabs: DepositTabs = _tabs()
	assert_eq(tabs.get_tab_count(), 2)
	assert_eq(tabs.get_tab_title(0), "Oggetti")
	assert_eq(tabs.get_tab_title(1), "Equipaggiamento")


func test_both_tabs_draw_the_whole_capacity() -> void:
	TestFactory.give_piece(_session, SWORD)
	TestFactory.give(_session, &"redbirch_log", 5)
	_open()
	await wait_physics_frames(1)
	var capacity: int = _session.deposit.capacity()
	assert_gte(_session.deposit.used(), 2)
	assert_eq(_live_children(_bank.get_node("%Grid")), capacity, "Oggetti")
	assert_eq(_live_children(_tabs().equipment_grid()), capacity, "Equipaggiamento")
	assert_gt(_named("%Grid", "EmptyCell"), 0)
	assert_eq(_named("%Grid", "EmptyCell"), _session.deposit.free_slots())
	assert_eq(_count_named(_tabs().equipment_grid(), "EmptyCell"), _session.deposit.free_slots())


func test_equipment_tab_shows_the_pieces_not_worn_like_the_equipment_page() -> void:
	var uid: int = TestFactory.give_piece(_session, SWORD)
	_open()
	_equipment = EQUIPMENT_SCENE.instantiate() as EquipmentPage
	add_child(_equipment)
	_equipment.bind(_session)
	var in_tab: Array[int] = []
	for child: Node in _tabs().equipment_grid().get_children():
		if child is InventoryCell and not child.is_queued_for_deletion():
			in_tab.append((child as InventoryCell).uid())
	var in_page: Array[int] = []
	for cell: Node in _equipment.find_children("*", "InventoryCell", true, false):
		if not cell.is_queued_for_deletion():
			in_page.append((cell as InventoryCell).uid())
	in_tab.sort()
	in_page.sort()
	assert_true(in_tab.has(uid))
	assert_eq(in_tab, in_page, "same pieces in both places")


func test_one_capacity_in_every_counter() -> void:
	TestFactory.give_piece(_session, SWORD)
	_open()
	_equipment = EQUIPMENT_SCENE.instantiate() as EquipmentPage
	add_child(_equipment)
	_equipment.bind(_session)
	_top = TOP_BAR_SCENE.instantiate()
	add_child(_top)
	_top.bind(_session)
	var used: String = NumberFormat.format_int(_session.deposit.used())
	var capacity: String = NumberFormat.format_int(_session.deposit.capacity())
	assert_eq((_bank.get_node("%SlotsLabel") as Label).text, "Caselle: %s / %s" % [used, capacity])
	assert_string_contains((_equipment.get_node("%CapacityLabel") as Label).text, "%s / %s" % [used, capacity])
	assert_eq((_top.get_node("%BankLabel") as Label).text, "%s / %s" % [used, capacity])


func test_boxes_used_by_pieces_are_marked_in_the_item_tab() -> void:
	TestFactory.give_piece(_session, SWORD)
	_open()
	var pieces: int = _session.deposit.used() - _session.bank.used()
	assert_gt(pieces, 0)
	assert_eq(_named("%Grid", "OccupiedCell"), pieces)


func test_deposit_changed_redraws_both_tabs() -> void:
	_open()
	var free_before: int = _session.deposit.free_slots()
	TestFactory.give(_session, &"redbirch_log", 1)
	assert_eq(_named("%Grid", "EmptyCell"), free_before - 1)
	assert_eq(_count_named(_tabs().equipment_grid(), "EmptyCell"), free_before - 1)
	TestFactory.give(_session, &"bag_canvas", 1)
	var before_bag: int = _session.deposit.capacity()
	assert_true(_session.bank.equip_bag(0, &"bag_canvas").ok)
	assert_gt(_session.deposit.capacity(), before_bag)
	assert_eq(_live_children(_tabs().equipment_grid()), _session.deposit.capacity())


func _open() -> void:
	_bank = BANK_SCENE.instantiate() as BankPage
	add_child(_bank)
	_bank.bind(_session)


func _tabs() -> DepositTabs:
	return _bank.get_node("%DepositTabs") as DepositTabs


func _live_children(node: Node) -> int:
	return node.get_children().filter(func(n: Node) -> bool: return not n.is_queued_for_deletion()).size()


func _named(path: String, prefix: String) -> int:
	return _count_named(_bank.get_node(path), prefix)


func _count_named(node: Node, prefix: String) -> int:
	return node.get_children().filter(
			func(n: Node) -> bool: return not n.is_queued_for_deletion() and String(n.name).begins_with(prefix)).size()
