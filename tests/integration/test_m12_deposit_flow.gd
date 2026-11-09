extends GutTest
## Integration, Deposit and bags (M12-08; F-100, 05 §5.20, §6): new game, bags with items and pieces, Bank and Armory on
## the same room, save v4 round trip, v1-v3 refused, one object in one place. Real data, fixed seeds, sessions freed,
## no real slot touched.

const SEED: int = 120801
const NOW_MS: int = 1793603600000
const SWORD: StringName = &"emberbronze_sword"
const REAL_ROOT: String = "res://data"
const TINY_SLOTS: int = 8

var _s: GameSession = null


func before_each() -> void:
	_s = null


func after_each() -> void:
	if _s != null:
		_s.free()
	_s = null


func _new(base_slots: int = -1) -> GameSession:
	if _s != null:
		_s.free()
	var data: GameData = TestFactory.real_data() if base_slots < 0 else TestFactory.data_with_deposit(TestFactory.REAL_CONTENT_ROOT, base_slots)
	_s = TestFactory.session_no_kit(SEED, data)
	return _s


# Distinct material ids from the real data, to fill boxes one type at a time.
func _materials(count: int) -> Array[StringName]:
	var out: Array[StringName] = []
	for def: ItemDef in _s.data.items():
		if def.category == &"material" and out.size() < count:
			out.append(def.id)
	assert_eq(out.size(), count, "enough material types in the data")
	return out


func _fill(until_free: int) -> void:
	for id: StringName in _materials(70):
		if _s.deposit.free_slots() <= until_free:
			return
		TestFactory.give(_s, id, 1)


func _bank_pieces_total() -> int:
	# Every object of the model, counted once: bank units + armory pieces.
	var n: int = _s.armory.used()
	for stack: Dictionary in _s.bank.stacks():
		n += int(stack["count"])
	return n


func test_new_game_has_empty_bag_slots_and_the_base_capacity() -> void:
	_new()
	var base: int = int(_s.data.balance_value("deposit.base_slots"))
	assert_eq(_s.deposit.bag_slot_count(), int(_s.data.balance_value("deposit.bag_slots")))
	assert_eq(_s.deposit.bags().size(), _s.deposit.bag_slot_count())
	for slot: int in _s.deposit.bag_slot_count():
		assert_eq(_s.deposit.get_bag(slot), &"", "slot %d empty" % slot)
	assert_eq(_s.deposit.capacity(), base, "F-100: no bags -> base_slots")
	assert_eq(_s.deposit.used(), _s.bank.stacks().size() + (_s.armory.used()), "used = Bank boxes + Armory pieces not worn... new game: nothing worn")
	assert_eq(_s.deposit.free_slots(), base - _s.deposit.used())


func test_bags_raise_the_capacity_by_their_slots_and_leave_the_bank() -> void:
	_new()
	var base: int = _s.deposit.capacity()
	TestFactory.give(_s, &"bag_canvas", 1)
	TestFactory.give(_s, &"bag_leather", 1)
	var used_before: int = _s.deposit.used()
	assert_true(_s.bank.equip_bag(0, &"bag_canvas").ok)
	assert_true(_s.bank.equip_bag(1, &"bag_leather").ok)
	var extra: int = _s.data.item(&"bag_canvas").bag_slots + _s.data.item(&"bag_leather").bag_slots
	assert_eq(_s.deposit.capacity(), base + extra, "F-100 example: canvas + leather")
	assert_eq(_s.deposit.used(), used_before - 2, "bags in the slots take no box")
	assert_eq(_s.bank.get_count(&"bag_canvas"), 0, "the bag lives in the slot only")
	assert_eq(_s.bank.get_count(&"bag_leather"), 0)
	assert_true(_s.bank.unequip_bag(1).ok)
	assert_eq(_s.bank.get_count(&"bag_leather"), 1, "back in the Bank, one place")
	assert_eq(_s.deposit.get_bag(1), &"")
	assert_eq(_s.deposit.capacity(), base + _s.data.item(&"bag_canvas").bag_slots)


func test_bank_and_armory_share_the_same_room_and_refuse_when_full() -> void:
	_new(TINY_SLOTS)
	assert_eq(_s.deposit.capacity(), TINY_SLOTS)
	_fill(3)
	assert_eq(_s.deposit.used(), TINY_SLOTS - 3)
	for i: int in 3:
		assert_gt(TestFactory.give_piece(_s, SWORD), 0)
	assert_eq(_s.deposit.used(), TINY_SLOTS, "pieces and item types count on the same room")
	assert_eq(_s.deposit.free_slots(), 0)
	var uid_before: int = _s.armory.used()
	assert_lte(_s.armory.create(SWORD, &"common", 1), 0, "armory_full: no piece is created")
	assert_eq(_s.armory.used(), uid_before)
	var extra_type: StringName = _materials(70)[69]
	var refused: CommandResult = _s.bank.add(extra_type, 1)
	assert_false(refused.ok)
	assert_eq(refused.reason, Reasons.BANK_FULL)
	# More of a type already in the Bank always fits (no new box).
	var held: StringName = _s.bank.stacks()[0]["item"]
	assert_true(_s.bank.add(held, 5).ok)
	# Room freed in the Bank is room for the Armory, and vice versa.
	assert_true(_s.bank.remove(held, _s.bank.get_count(held)).ok)
	assert_gt(TestFactory.give_piece(_s, SWORD), 0)
	assert_false(_s.bank.add(extra_type, 1).ok, "the freed box went to the piece")


func test_unequip_bag_is_refused_while_the_boxes_in_use_do_not_fit() -> void:
	_new(TINY_SLOTS)
	TestFactory.give(_s, &"bag_leather", 1)
	assert_true(_s.bank.equip_bag(0, &"bag_leather").ok)
	var cap: int = _s.deposit.capacity()
	assert_eq(cap, TINY_SLOTS + _s.data.item(&"bag_leather").bag_slots)
	_fill(0)
	assert_eq(_s.deposit.free_slots(), 0, "full with the bag")
	var snapshot: int = _bank_pieces_total()
	var refused: CommandResult = _s.bank.unequip_bag(0)
	assert_eq(refused.reason, Reasons.DEPOSIT_NOT_EMPTY)
	assert_eq(_s.deposit.get_bag(0), &"bag_leather", "nothing changed")
	assert_eq(_bank_pieces_total(), snapshot, "no object created or lost by the refusal")
	# Free enough boxes (bag.slots + 1): now it works.
	var need: int = _s.data.item(&"bag_leather").bag_slots + 1
	var removed: int = 0
	for stack: Dictionary in _s.bank.stacks():
		if removed >= need:
			break
		assert_true(_s.bank.remove(stack["item"], int(stack["count"])).ok)
		removed += 1
	assert_true(_s.bank.unequip_bag(0).ok)
	assert_eq(_s.bank.get_count(&"bag_leather"), 1)
	assert_lte(_s.deposit.used(), _s.deposit.capacity())


func test_armory_pieces_worn_do_not_count_but_stay_in_the_armory() -> void:
	_new()
	var uid: int = TestFactory.give_piece(_s, SWORD)
	var used: int = _s.deposit.used()
	assert_true(_s.equipment.equip(uid).ok)
	assert_eq(_s.deposit.used(), used - 1, "a worn piece leaves the room")
	assert_true(_s.armory.has(uid), "and stays one object in the Armory")
	assert_true(_s.equipment.unequip(&"weapon").ok)
	assert_eq(_s.deposit.used(), used)


func test_save_v4_round_trip_keeps_bags_capacity_and_is_idempotent() -> void:
	_new()
	TestFactory.give(_s, &"bag_canvas", 1)
	TestFactory.give(_s, &"bag_runic", 1)
	assert_true(_s.bank.equip_bag(2, &"bag_canvas").ok)
	assert_true(_s.bank.equip_bag(5, &"bag_runic").ok)
	TestFactory.give_piece(_s, SWORD)
	var capacity: int = _s.deposit.capacity()
	var used: int = _s.deposit.used()
	var saved: Dictionary = _s.to_save(NOW_MS)
	assert_eq(saved["format_version"], 5)
	assert_false((saved["modules"] as Dictionary)["deposit"].has("capacity"), "capacity is derived, never saved")
	var other: GameSession = autofree(TestFactory.session_no_kit(SEED + 1, TestFactory.real_data()))
	var loaded: CommandResult = other.from_save(SaveCodec.decode(SaveCodec.encode(saved)))
	assert_true(loaded.ok, "load: %s" % loaded.reason)
	assert_eq(other.deposit.capacity(), capacity)
	assert_eq(other.deposit.used(), used)
	assert_eq(other.deposit.get_bag(2), &"bag_canvas")
	assert_eq(other.deposit.get_bag(5), &"bag_runic")
	assert_eq(SaveCodec.encode(other.to_save(NOW_MS)), SaveCodec.encode(saved), "save -> load -> save is identical")


func test_a_save_without_the_deposit_module_starts_with_empty_bags() -> void:
	_new()
	TestFactory.give(_s, &"bag_canvas", 1)
	assert_true(_s.bank.equip_bag(0, &"bag_canvas").ok)
	var saved: Dictionary = _s.to_save(NOW_MS)
	(saved["modules"] as Dictionary).erase("deposit")
	var other: GameSession = autofree(TestFactory.session_no_kit(SEED, TestFactory.real_data()))
	assert_true(other.from_save(saved).ok)
	assert_eq(other.deposit.extra_slots(), 0)
	assert_eq(other.deposit.capacity(), int(other.data.balance_value("deposit.base_slots")))


func test_session_refuses_v1_v2_v3_without_touching_its_state() -> void:
	_new()
	TestFactory.give(_s, &"bag_canvas", 3)
	var before: String = SaveCodec.encode(_s.to_save(NOW_MS))
	for version: int in [1, 2, 3]:
		var old: Dictionary = _s.to_save(NOW_MS)
		old["format_version"] = version
		var result: CommandResult = _s.from_save(old)
		assert_false(result.ok, "v%d is refused" % version)
		assert_eq(result.reason, Reasons.VERSION_UNSUPPORTED, "v%d" % version)
		assert_eq(SaveCodec.encode(_s.to_save(NOW_MS)), before, "state untouched after v%d" % version)


func test_every_item_lives_in_one_place_through_a_bag_cycle() -> void:
	_new()
	TestFactory.give(_s, &"bag_reinforced", 1)
	var total_before: int = _bank_pieces_total()
	assert_true(_s.bank.equip_bag(0, &"bag_reinforced").ok)
	var in_slot: int = 1
	assert_eq(_bank_pieces_total() + in_slot, total_before + 0, "one bag: in the slot, not in the Bank")
	assert_true(_s.bank.unequip_bag(0).ok)
	assert_eq(_bank_pieces_total(), total_before)
