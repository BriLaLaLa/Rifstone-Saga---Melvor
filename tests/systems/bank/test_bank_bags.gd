extends GutTest
## Bank.equip_bag / unequip_bag (docs/05_INTERFACES.md §5.20, F-100) and the box accounting of bags.

const SMALL: StringName = &"test_bag_small"
const LARGE: StringName = &"test_bag_large"

var _session: GameSession
var _filler: int = 0


func before_each() -> void:
	_session = TestFactory.session(9)
	add_child_autofree(_session)
	_filler = 0
	_session.deposit.register_occupant(&"test_filler", func() -> int: return _filler)


func test_equip_bag_moves_one_bag_from_the_bank_to_the_slot() -> void:
	TestFactory.give(_session, SMALL, 2)
	watch_signals(_session.events)
	assert_true(_session.bank.equip_bag(1, SMALL).ok)
	assert_eq(_session.bank.get_count(SMALL), 1)
	assert_eq(_session.deposit.get_bag(1), SMALL)
	assert_signal_emitted_with_parameters(_session.events, "bank_changed", [SMALL, 1, -1])
	assert_signal_emitted(_session.events, "bags_changed")
	assert_eq(_session.deposit.capacity(), 66)


func test_equipping_the_last_bag_frees_its_box() -> void:
	TestFactory.give(_session, SMALL, 1)
	assert_eq(_session.bank.used(), 1)
	assert_true(_session.bank.equip_bag(0, SMALL).ok)
	assert_eq(_session.bank.used(), 0, "a bag in a slot occupies no box")
	assert_eq(_session.bank.get_count(SMALL), 0)


func test_equip_bag_rejections_in_order() -> void:
	assert_eq(_session.bank.equip_bag(-1, SMALL).reason, Reasons.INVALID_AMOUNT)
	assert_eq(_session.bank.equip_bag(6, SMALL).reason, Reasons.INVALID_AMOUNT)
	assert_eq(_session.bank.equip_bag(0, &"ghost").reason, Reasons.UNKNOWN_ID)
	TestFactory.give(_session, &"test_log", 1)
	assert_eq(_session.bank.equip_bag(0, &"test_log").reason, Reasons.NOT_A_BAG)
	assert_eq(_session.bank.equip_bag(0, SMALL).reason, Reasons.NOT_ENOUGH_ITEMS)
	TestFactory.give(_session, SMALL, 2)
	assert_true(_session.bank.equip_bag(0, SMALL).ok)
	assert_eq(_session.bank.equip_bag(0, SMALL).reason, Reasons.BAG_SLOT_OCCUPIED)
	assert_eq(_session.bank.equip_bag(9, &"ghost").reason, Reasons.INVALID_AMOUNT, "slot checked first")


func test_failed_equip_changes_nothing() -> void:
	TestFactory.give(_session, SMALL, 1)
	assert_true(_session.bank.equip_bag(0, SMALL).ok)
	TestFactory.give(_session, SMALL, 1)
	watch_signals(_session.events)
	assert_false(_session.bank.equip_bag(0, SMALL).ok)
	assert_signal_not_emitted(_session.events, "bank_changed")
	assert_signal_not_emitted(_session.events, "bags_changed")
	assert_signal_not_emitted(_session.events, "deposit_changed")
	assert_eq(_session.bank.get_count(SMALL), 1)


func test_unequip_bag_returns_it_to_the_bank_as_one_box() -> void:
	TestFactory.give(_session, SMALL, 1)
	_session.bank.equip_bag(2, SMALL)
	watch_signals(_session.events)
	assert_true(_session.bank.unequip_bag(2).ok)
	assert_eq(_session.deposit.get_bag(2), &"")
	assert_eq(_session.bank.get_count(SMALL), 1)
	assert_eq(_session.bank.used(), 1, "back in the bank it occupies a box")
	assert_signal_emitted_with_parameters(_session.events, "bank_changed", [SMALL, 1, 1])
	assert_signal_emitted(_session.events, "bags_changed")
	assert_eq(_session.deposit.capacity(), 60)


func test_unequip_bag_with_a_stack_already_in_the_bank_uses_no_new_box() -> void:
	TestFactory.give(_session, SMALL, 2)
	_session.bank.equip_bag(0, SMALL)
	# Capacity 66, the bank holds the other small bag (1 box): used' stays at used, capacity' = 60.
	_filler = 59
	assert_eq(_session.deposit.used(), 60)
	assert_true(_session.bank.unequip_bag(0).ok, "used' = 60 <= capacity' = 60 (the stack exists)")
	assert_eq(_session.bank.get_count(SMALL), 2)


func test_unequip_bag_rejections() -> void:
	assert_eq(_session.bank.unequip_bag(-1).reason, Reasons.INVALID_AMOUNT)
	assert_eq(_session.bank.unequip_bag(6).reason, Reasons.INVALID_AMOUNT)
	assert_eq(_session.bank.unequip_bag(0).reason, Reasons.SLOT_EMPTY)


func test_deposit_not_empty_changes_nothing() -> void:
	TestFactory.give(_session, LARGE, 1)
	_session.bank.equip_bag(0, LARGE)
	_filler = 65
	watch_signals(_session.events)
	var result: CommandResult = _session.bank.unequip_bag(0)
	assert_eq(result.reason, Reasons.DEPOSIT_NOT_EMPTY)
	assert_eq(_session.deposit.get_bag(0), LARGE)
	assert_eq(_session.bank.get_count(LARGE), 0)
	assert_eq(_session.deposit.capacity(), 70)
	assert_signal_not_emitted(_session.events, "bank_changed")
	assert_signal_not_emitted(_session.events, "bags_changed")
	assert_signal_not_emitted(_session.events, "deposit_changed")


func test_a_bag_outside_the_slots_is_an_ordinary_bank_item() -> void:
	assert_true(_session.bank.add(SMALL, 3).ok)
	assert_eq(_session.bank.used(), 1)
	assert_eq(_session.deposit.capacity(), 60, "it adds nothing until it is in a slot")


func test_sort_puts_bags_after_materials_and_before_food() -> void:
	TestFactory.give(_session, &"seared_brookfin", 1)
	TestFactory.give(_session, SMALL, 1)
	TestFactory.give(_session, &"test_log", 1)
	_session.bank.sort_stacks()
	var order: Array[StringName] = []
	for stack: Dictionary in _session.bank.stacks():
		order.append(stack["item"])
	assert_lt(order.find(&"test_log"), order.find(SMALL), "material, then bag")
	assert_lt(order.find(SMALL), order.find(&"seared_brookfin"), "bag, then food")
	assert_lt(Bank.SORT_CATEGORIES.find(&"bag"), Bank.SORT_CATEGORIES.find(&"contract"))
	assert_lt(Bank.SORT_CATEGORIES.find(&"contract"), Bank.SORT_CATEGORIES.find(&"food"))


func test_full_deposit_blocks_a_new_type_but_not_more_of_an_existing_one() -> void:
	TestFactory.give(_session, &"test_log", 1)
	_filler = 59
	assert_eq(_session.deposit.free_slots(), 0)
	watch_signals(_session.events)
	assert_eq(_session.bank.add(&"test_twig", 1).reason, Reasons.BANK_FULL)
	assert_signal_emitted_with_parameters(_session.events, "bank_rejected", [&"test_twig", 1])
	assert_true(_session.bank.add(&"test_log", 4).ok)
	assert_false(_session.bank.can_add(&"test_twig"))
	assert_true(_session.bank.can_add(&"test_log"))
