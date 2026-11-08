extends GutTest
## Deposit (docs/05_INTERFACES.md §5.20, F-100): capacity from the base and the bags in the slots, used from the
## registered occupants, deposit_changed only on a real change, tolerant save. Fixture bags: small +6, large +10.

const SMALL: StringName = &"test_bag_small"
const LARGE: StringName = &"test_bag_large"

var _session: GameSession
var _extra_used: int = 0


func before_each() -> void:
	_session = TestFactory.session(7)
	add_child_autofree(_session)
	_extra_used = 0
	_session.deposit.register_occupant(&"test_filler", func() -> int: return _extra_used)


# --- F-100 -------------------------------------------------------------------------------------------------------

func test_no_bags_capacity_is_the_base() -> void:
	assert_eq(_session.deposit.capacity(), 60, "F-100 example: no bag -> 60")
	assert_eq(_session.deposit.extra_slots(), 0)
	assert_eq(_session.deposit.bag_slot_count(), 6)


func test_two_bags_capacity() -> void:
	_give_and_equip(0, SMALL)
	_give_and_equip(1, LARGE)
	assert_eq(_session.deposit.extra_slots(), 16)
	assert_eq(_session.deposit.capacity(), 76, "F-100 example: +6 and +10 -> 76 (same shape as canvas + leather)")


func test_six_bags_capacity() -> void:
	TestFactory.give(_session, LARGE, 6)
	for slot: int in 6:
		assert_true(_session.bank.equip_bag(slot, LARGE).ok)
	assert_eq(_session.deposit.capacity(), 60 + 6 * 10)


func test_six_runic_bags_example() -> void:
	var runic: Array[StringName] = []
	for item: ItemDef in TestFactory.real_data().items():
		if item.category == &"bag" and item.bag_slots == 24:
			runic.append(item.id)
	if runic.is_empty():
		pending("M12-05: the real runic bag (+24) arrives with the content task: 60 + 6 x 24 = 204")
		return
	var real: GameSession = autofree(TestFactory.session(3, TestFactory.real_data()))
	TestFactory.give(real, runic[0], 6)
	for slot: int in 6:
		assert_true(real.bank.equip_bag(slot, runic[0]).ok)
	assert_eq(real.deposit.capacity(), 204)


func test_used_free_and_has_room() -> void:
	_extra_used = 58
	assert_eq(_session.deposit.used(), 58)
	assert_eq(_session.deposit.free_slots(), 2)
	assert_true(_session.deposit.has_room(2))
	assert_false(_session.deposit.has_room(3))
	_extra_used = 80
	assert_eq(_session.deposit.free_slots(), 0, "never negative")
	assert_false(_session.deposit.has_room(1))


func test_used_sums_every_occupant() -> void:
	TestFactory.give(_session, &"test_log", 3)
	TestFactory.give_piece(_session, &"test_blade")
	_extra_used = 5
	assert_eq(_session.deposit.used(), _session.bank.used() + _session.armory.used() + 5)
	assert_eq(_session.bank.used(), 1)
	assert_eq(_session.armory.used(), 1)


# --- unequip_bag examples of F-100 ---------------------------------------------------------------------------------

func test_unequip_large_bag_with_used_66_is_refused() -> void:
	_give_and_equip(0, SMALL)
	_give_and_equip(1, LARGE)
	_extra_used = 66
	var result: CommandResult = _session.bank.unequip_bag(1)
	assert_false(result.ok, "66 + 1 = 67 > 66")
	assert_eq(result.reason, Reasons.DEPOSIT_NOT_EMPTY)
	assert_eq(_session.deposit.get_bag(1), LARGE, "nothing changed")


func test_unequip_large_bag_with_used_65_is_allowed() -> void:
	_give_and_equip(0, SMALL)
	_give_and_equip(1, LARGE)
	_extra_used = 65
	assert_true(_session.bank.unequip_bag(1).ok, "65 + 1 = 66 <= 66")
	assert_eq(_session.deposit.capacity(), 66)
	assert_eq(_session.bank.get_count(LARGE), 1)


# --- deposit_changed / bags_changed ----------------------------------------------------------------------------------

func test_deposit_changed_only_on_a_real_change() -> void:
	watch_signals(_session.events)
	_session.deposit.notify_changed()
	assert_signal_not_emitted(_session.events, "deposit_changed", "a new game is synced: nothing changed")
	_extra_used = 4
	_session.deposit.notify_changed()
	assert_signal_emit_count(_session.events, "deposit_changed", 1)
	assert_signal_emitted_with_parameters(_session.events, "deposit_changed", [4, 60])
	_session.deposit.notify_changed()
	assert_signal_emit_count(_session.events, "deposit_changed", 1, "same used and capacity: no signal")
	_extra_used = 0
	_session.deposit.notify_changed()
	assert_signal_emit_count(_session.events, "deposit_changed", 2)


func test_bank_add_new_type_notifies_but_more_of_the_same_does_not() -> void:
	watch_signals(_session.events)
	_session.bank.add(&"test_log", 1)
	assert_signal_emit_count(_session.events, "deposit_changed", 1)
	_session.bank.add(&"test_log", 5)
	assert_signal_emit_count(_session.events, "deposit_changed", 1, "an existing item does not use a new box")
	_session.bank.remove(&"test_log", 6)
	assert_signal_emit_count(_session.events, "deposit_changed", 2)


func test_equip_bag_emits_bags_changed_and_one_deposit_changed() -> void:
	TestFactory.give(_session, SMALL, 1)
	watch_signals(_session.events)
	assert_true(_session.bank.equip_bag(3, SMALL).ok)
	assert_signal_emit_count(_session.events, "bags_changed", 1)
	assert_signal_emit_count(_session.events, "deposit_changed", 1)
	assert_signal_emitted_with_parameters(_session.events, "deposit_changed", [0, 66])


func test_new_game_and_from_save_are_silent() -> void:
	watch_signals(_session.events)
	_session.deposit.new_game()
	_session.deposit.from_save({"bags": [SMALL, "", "", "", "", ""]})
	assert_signal_not_emitted(_session.events, "bags_changed")
	assert_signal_not_emitted(_session.events, "deposit_changed")


# --- accessors ---------------------------------------------------------------------------------------------------

func test_get_bag_out_of_range_is_empty() -> void:
	assert_eq(_session.deposit.get_bag(-1), &"")
	assert_eq(_session.deposit.get_bag(6), &"")
	assert_eq(_session.deposit.get_bag(0), &"")


func test_bags_returns_a_copy_of_bag_slot_count_entries() -> void:
	_give_and_equip(2, SMALL)
	var bags: Array[StringName] = _session.deposit.bags()
	assert_eq(bags.size(), 6)
	assert_eq(bags[2], SMALL)
	bags[2] = &""
	assert_eq(_session.deposit.get_bag(2), SMALL, "a copy")


# --- save --------------------------------------------------------------------------------------------------------

func test_new_game_empties_the_slots() -> void:
	_give_and_equip(0, SMALL)
	_session.deposit.new_game()
	assert_eq(_session.deposit.bags(), _empty_slots())


func test_save_round_trip() -> void:
	_give_and_equip(0, SMALL)
	_give_and_equip(4, LARGE)
	var saved: Dictionary = _session.deposit.to_save()
	assert_eq(saved, {"bags": ["test_bag_small", "", "", "", "test_bag_large", ""]})
	_session.deposit.new_game()
	_session.deposit.from_save(saved)
	assert_eq(_session.deposit.get_bag(0), SMALL)
	assert_eq(_session.deposit.get_bag(4), LARGE)
	assert_eq(_session.deposit.capacity(), 76)


func test_from_save_bags_not_a_list_is_all_empty() -> void:
	_give_and_equip(0, SMALL)
	_session.deposit.from_save({"bags": "nope"})
	assert_eq(_session.deposit.bags(), _empty_slots())
	_session.deposit.from_save({})
	assert_eq(_session.deposit.bags(), _empty_slots())


func test_from_save_bad_entries_become_empty_slots() -> void:
	_session.deposit.from_save({"bags": [5, "ghost_bag", "test_log", SMALL, null, LARGE]})
	assert_eq(_session.deposit.bags(), [&"", &"", &"", SMALL, &"", LARGE] as Array[StringName],
			"not a string, unknown id and not a bag are empty")


func test_from_save_longer_list_is_cut_and_shorter_completed() -> void:
	_session.deposit.from_save({"bags": [SMALL, SMALL, SMALL, SMALL, SMALL, SMALL, SMALL, SMALL]})
	assert_eq(_session.deposit.bag_slot_count(), 6)
	assert_eq(_session.deposit.capacity(), 60 + 6 * 6)
	_session.deposit.from_save({"bags": [LARGE]})
	assert_eq(_session.deposit.bag_slot_count(), 6)
	assert_eq(_session.deposit.bags(), [LARGE, &"", &"", &"", &"", &""] as Array[StringName])


func test_from_save_does_not_check_the_capacity() -> void:
	_extra_used = 100
	_session.deposit.from_save({"bags": []})
	assert_eq(_session.deposit.used(), 100, "used above the capacity is loaded as it is")
	assert_false(_session.deposit.has_room(1))


func _give_and_equip(slot: int, bag: StringName) -> void:
	TestFactory.give(_session, bag, 1)
	assert_true(_session.bank.equip_bag(slot, bag).ok)


func _empty_slots() -> Array[StringName]:
	return [&"", &"", &"", &"", &"", &""] as Array[StringName]
