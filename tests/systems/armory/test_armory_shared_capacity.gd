extends GutTest
## Bank and Armory share one capacity (docs/01_GDD.md §7, F-100): a piece takes a box like an item type; the last free
## box goes to whoever asks first. A tiny Deposit of 3 boxes: fixture content with a copy of the configuration.

const BLADE: StringName = &"test_blade"

var _session: GameSession


func before_each() -> void:
	_session = TestFactory.session(5, TestFactory.data_with_deposit(TestFactory.FIXTURE_CONTENT_ROOT, 3))
	add_child_autofree(_session)


func test_capacity_is_the_base_of_the_deposit() -> void:
	assert_eq(_session.deposit.capacity(), 3)
	assert_eq(_session.bank.capacity(), 3, "the bank redirects to the Deposit")


func test_a_piece_and_an_item_type_use_one_box_each() -> void:
	TestFactory.give(_session, &"test_log", 50)
	TestFactory.give_piece(_session, BLADE)
	assert_eq(_session.deposit.used(), 2)
	assert_eq(_session.deposit.free_slots(), 1)


func test_the_last_box_taken_by_the_bank_blocks_a_piece() -> void:
	TestFactory.give_piece(_session, BLADE)
	TestFactory.give(_session, &"test_log", 1)
	TestFactory.give(_session, &"test_twig", 1)
	assert_eq(_session.deposit.free_slots(), 0)
	watch_signals(_session.events)
	assert_false(_session.armory.can_add(1))
	assert_eq(_session.armory.create(BLADE, &"common", 1), 0)
	assert_signal_emitted_with_parameters(_session.events, "armory_rejected", [BLADE, 1])
	assert_eq(_session.armory.used(), 1)


func test_the_last_box_taken_by_a_piece_blocks_an_item_type() -> void:
	TestFactory.give(_session, &"test_log", 1)
	TestFactory.give_piece(_session, BLADE)
	TestFactory.give_piece(_session, BLADE)
	assert_eq(_session.deposit.free_slots(), 0)
	assert_false(_session.bank.can_add(&"test_twig"))
	assert_eq(_session.bank.add(&"test_twig", 1).reason, Reasons.BANK_FULL)
	assert_true(_session.bank.add(&"test_log", 9).ok, "an item already in the bank still enters")


func test_removing_a_piece_frees_a_box_for_the_bank() -> void:
	TestFactory.give(_session, &"test_log", 1)
	var uid: int = TestFactory.give_piece(_session, BLADE)
	TestFactory.give_piece(_session, BLADE)
	assert_false(_session.bank.can_add(&"test_twig"))
	assert_true(_session.armory.remove(uid).ok)
	assert_true(_session.bank.add(&"test_twig", 1).ok)


func test_worn_pieces_do_not_use_a_box() -> void:
	var uid: int = TestFactory.give_piece(_session, BLADE)
	assert_eq(_session.deposit.used(), 1)
	_session.armory.set_worn(uid, true)
	assert_eq(_session.deposit.used(), 0)
	_session.armory.set_worn(uid, false)
	assert_eq(_session.deposit.used(), 1)


func test_armory_changes_announce_the_deposit() -> void:
	watch_signals(_session.events)
	var uid: int = TestFactory.give_piece(_session, BLADE)
	assert_signal_emitted_with_parameters(_session.events, "deposit_changed", [1, 3])
	_session.armory.set_worn(uid, true)
	assert_signal_emitted_with_parameters(_session.events, "deposit_changed", [0, 3])
	assert_signal_emit_count(_session.events, "deposit_changed", 2)


func test_a_loaded_save_over_the_capacity_blocks_only_new_entries() -> void:
	_session.bank.from_save({"stacks": [{"item": "test_log", "count": 1}, {"item": "test_twig", "count": 1},
			{"item": "test_plank", "count": 1}, {"item": "test_blade_stone", "count": 1}]})
	assert_eq(_session.bank.used(), 3, "the unknown item is dropped, the rest is loaded")
	_session.bank.from_save({"stacks": [{"item": "test_log", "count": 1}, {"item": "test_twig", "count": 1},
			{"item": "test_plank", "count": 1}]})
	_session.deposit.register_occupant(&"test_over", func() -> int: return 2)
	assert_eq(_session.deposit.used(), 5, "above the capacity of 3: loaded as it is")
	assert_false(_session.bank.can_add(&"test_ore"))
	assert_true(_session.bank.add(&"test_log", 1).ok)
