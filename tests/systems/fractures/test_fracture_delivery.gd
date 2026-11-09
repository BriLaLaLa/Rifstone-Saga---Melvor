extends GutTest
## F-116: delivery of the bag of the Fracture on a win (stacks to the Bank, pieces through the Armory filter, Cards to the
## CardStore; what does not fit stays pending until `collect`) and the loss on a defeat. The bag is filled by hand and the
## end is announced with `fracture_finished`, which is what the engine emits (the fights are in test_fracture_flow.gd).

var _s: GameSession = null
var _fill: Array[int] = [0]


func before_each() -> void:
	_s = autofree(TestFactory.session(9, FractureUtil.data()))
	_fill = [0]
	var free: int = _s.deposit.free_slots()
	_s.deposit.register_occupant(&"test:fill", func() -> int: return _fill[0])
	_fill[0] = free  # the Deposit is full until a test frees boxes


func _free_boxes(count: int) -> void:
	_fill[0] = 0
	_fill[0] = _s.deposit.free_slots() - count


func _open_with_empty_bag() -> FractureBag:
	_free_boxes(2)
	assert_true(_s.fractures.open(FractureUtil.card(_s, 1)).ok)
	_free_boxes(0)
	return _s.fractures.run().bag


func _stack_ids(count: int) -> Array[StringName]:
	var ids: Array[StringName] = []
	for item: ItemDef in _s.data.items():
		if item.equip == null and not item.is_map() and not item.is_bag():
			ids.append(item.id)
		if ids.size() == count:
			break
	assert_eq(ids.size(), count, "enough stackable items in the fixtures")
	return ids


func _finish(outcome: StringName) -> void:
	_s.events.fracture_finished.emit(outcome, 1, 3, 0, 0)


func test_forty_stacks_with_25_free_boxes_deliver_25_and_keep_15() -> void:
	var bag: FractureBag = _open_with_empty_bag()
	var ids: Array[StringName] = _stack_ids(40)
	for id: StringName in ids:
		bag.add_stack(id, 2)
	_free_boxes(25)
	_finish(&"won")
	assert_false(_s.fractures.is_active())
	var delivered: Array[StringName] = ids.filter(func(id: StringName) -> bool: return _s.bank.get_count(id) == 2)
	assert_eq(delivered, ids.slice(0, 25), "in the order of insertion")
	var pending: Dictionary = _s.fractures.pending()
	assert_eq((pending["stacks"] as Array).size(), 15)
	assert_true(_s.fractures.has_pending())


func test_collect_after_making_room_delivers_the_rest() -> void:
	var bag: FractureBag = _open_with_empty_bag()
	var ids: Array[StringName] = _stack_ids(40)
	for id: StringName in ids:
		bag.add_stack(id, 1)
	_free_boxes(25)
	_finish(&"won")
	assert_eq(_s.fractures.collect().reason, Reasons.BANK_FULL, "still no room")
	_free_boxes(5)
	assert_eq(_s.fractures.collect().reason, Reasons.BANK_FULL, "five more entered, ten remain")
	assert_eq((_s.fractures.pending()["stacks"] as Array).size(), 10)
	_free_boxes(30)
	assert_true(_s.fractures.collect().ok)
	assert_false(_s.fractures.has_pending())
	assert_eq(_s.fractures.pending(), {})
	assert_eq(_s.fractures.collect().reason, Reasons.NO_FRACTURE, "nothing is waiting")
	for id: StringName in ids:
		assert_eq(_s.bank.get_count(id), 1)


func test_no_new_fracture_while_something_waits() -> void:
	var bag: FractureBag = _open_with_empty_bag()
	for id: StringName in _stack_ids(3):
		bag.add_stack(id, 1)
	_free_boxes(0)
	_finish(&"won")
	assert_true(_s.fractures.has_pending())
	_s.combat.stop()  # the engine is still in the Fracture: the test announced its end by hand
	_free_boxes(5)
	var uid: int = FractureUtil.card(_s, 1)
	assert_eq(_s.fractures.open(uid).reason, Reasons.FRACTURE_BAG_PENDING)
	assert_true(_s.cards.has(uid), "the Card is not spent by a refused open")
	assert_true(_s.fractures.collect().ok)
	assert_true(_s.fractures.open(uid).ok)


func test_pieces_go_through_the_armory_filter_and_nothing_waits() -> void:
	var bag: FractureBag = _open_with_empty_bag()
	var salvaged: Array[bool] = []
	_s.events.item_salvaged.connect(func(_u: int, _b: StringName, auto: bool) -> void: salvaged.append(auto))
	var base: ItemDef = _s.data.item(&"test_blade")
	bag.add_piece(ItemRoller.create(base, &"common", 5, _s.data, _s.rng))
	bag.add_piece(ItemRoller.create(base, &"magic", 5, _s.data, _s.rng))
	_free_boxes(1)
	var armory_before: int = _s.armory.used()
	_finish(&"won")
	assert_eq(_s.armory.used(), armory_before + 1, "one fits, the other is dismantled as for any drop")
	assert_eq(salvaged, [true] as Array[bool])
	assert_false(_s.fractures.has_pending(), "pieces never wait")


func test_a_card_that_does_not_fit_waits_and_collect_delivers_it() -> void:
	var bag: FractureBag = _open_with_empty_bag()
	var card := MapCard.new()
	card.base_id = &"fracture_card_2"
	card.grade = 2
	card.rarity = &"common"
	bag.add_card(card)
	var rejected: Array[int] = []
	_s.events.card_rejected.connect(func(g: int) -> void: rejected.append(g))
	_finish(&"won")
	assert_eq(_s.cards.used(), 0)
	assert_eq(_s.fractures.pending()["cards"], 1)
	assert_true(rejected.is_empty(), "waiting is not a loss: no card_rejected")
	assert_eq(_s.fractures.collect().reason, Reasons.ARMORY_FULL)
	_free_boxes(3)
	assert_true(_s.fractures.collect().ok)
	assert_eq(_s.cards.used(), 1)
	assert_eq(_s.cards.cards()[0].grade, 2)


func test_a_defeat_loses_everything_and_says_how_much() -> void:
	var bag: FractureBag = _open_with_empty_bag()
	for id: StringName in _stack_ids(4):
		bag.add_stack(id, 3)
	bag.add_piece(ItemRoller.create(_s.data.item(&"test_blade"), &"common", 5, _s.data, _s.rng))
	var lost: Array = []
	_s.events.fracture_loot_lost.connect(func(a: int, b: int, c: int) -> void: lost.append([a, b, c]))
	_free_boxes(50)
	_finish(&"died")
	assert_eq(lost, [[4, 1, 0]])
	assert_false(_s.fractures.is_active())
	assert_false(_s.fractures.has_pending())
	assert_eq(_s.bank.stacks().size(), 0)


func test_bag_changed_is_emitted_after_the_delivery() -> void:
	var bag: FractureBag = _open_with_empty_bag()
	bag.add_stack(_stack_ids(1)[0], 1)
	var seen: Array = []
	_s.events.fracture_bag_changed.connect(func(a: int, b: int, c: int) -> void: seen.append([a, b, c]))
	_free_boxes(10)
	_finish(&"won")
	assert_eq(seen.back(), [0, 0, 0], "everything was delivered")


func test_the_win_of_a_real_fight_delivers_the_drops() -> void:
	_free_boxes(500)
	FractureUtil.hero(_s)
	assert_true(_s.fractures.open(FractureUtil.card(_s, 1)).ok)
	FractureUtil.run_until(_s, func() -> bool: return not _s.combat.in_fracture())
	assert_false(_s.fractures.has_pending())
	assert_gt(_s.bank.get_count(&"rift_shard"), 0, "the shards of the kills reached the Bank on the win")
