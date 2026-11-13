extends GutTest
## F-116 for the bag of the dungeon (docs/01_GDD.md §33.5): a win delivers the bag, what does not fit waits (`pending`) until
## `collect`, and while something waits no other dungeon opens. Also the rule of the single instance (a Fracture and a dungeon
## never together) and a leave with a full Bank.

var _s: GameSession = null
var _engine: DungeonEngineDouble = null
var _fill: Array[int] = [0]


func before_each() -> void:
	_s = autofree(TestFactory.session(51))
	_fill = [0]
	_s.deposit.register_occupant(&"test:fill", func() -> int: return _fill[0])
	_engine = DungeonEngineDouble.attach(_s)


func _stack_ids(count: int) -> Array[StringName]:
	var ids: Array[StringName] = []
	for item: ItemDef in _s.data.items():
		if item.equip == null and not item.is_map() and not item.is_bag() and item.id != &"test_den_ticket":
			ids.append(item.id)
		if ids.size() == count:
			break
	assert_eq(ids.size(), count)
	return ids



func _limit_to(boxes: int) -> void:
	_fill[0] = 0
	_fill[0] = maxi(0, _s.deposit.free_slots() - boxes)


func _win_with(ids: Array[StringName]) -> void:
	_engine.open_and_clear_entrance()
	_engine.walk_to_boss()
	for id: StringName in ids:
		_s.dungeon.run().bag.add_stack(id, 2)
	_limit_to(10)
	for _i: int in 3:
		_engine.end_intro()
		_engine.clear_stage()


func test_what_fits_is_delivered_and_the_rest_waits() -> void:
	var ids: Array[StringName] = _stack_ids(30)
	_win_with(ids)
	assert_false(_s.dungeon.is_active())
	assert_true(_s.dungeon.has_pending())
	var delivered: int = ids.filter(func(id: StringName) -> bool: return _s.bank.get_count(id) >= 2).size()
	assert_gt(delivered, 0)
	assert_eq((_s.dungeon.pending()["stacks"] as Array).size() >= 1, true)
	assert_eq(_s.dungeon.open(&"test_den").reason, Reasons.DUNGEON_BAG_PENDING)


func test_collect_after_making_room_delivers_the_rest() -> void:
	var ids: Array[StringName] = _stack_ids(30)
	_win_with(ids)
	assert_eq(_s.dungeon.collect().reason, Reasons.BANK_FULL, "still no room")
	_fill[0] = 0
	assert_true(_s.dungeon.collect().ok)
	assert_false(_s.dungeon.has_pending())
	for id: StringName in ids:
		assert_gte(_s.bank.get_count(id), 2, str(id))
	assert_eq(_s.dungeon.collect().reason, Reasons.NO_DUNGEON, "nothing left")
	assert_eq(_s.dungeon.pending(), {})


func test_the_bag_event_tells_the_ui_what_is_left() -> void:
	var seen: Array = []
	_s.events.dungeon_bag_changed.connect(func(stacks: int, pieces: int, cards: int) -> void: seen.append([stacks, pieces, cards]))
	var ids: Array[StringName] = _stack_ids(30)
	_win_with(ids)
	var left: int = (_s.dungeon.pending()["stacks"] as Array).size()
	assert_eq(seen[seen.size() - 1], [left, 0, 0])


func test_leaving_with_a_full_bank_keeps_the_rest_waiting() -> void:
	var ids: Array[StringName] = _stack_ids(30)
	_engine.open_and_clear_entrance()
	for id: StringName in ids:
		_s.dungeon.run().bag.add_stack(id, 1)
	_limit_to(5)
	assert_true(_s.dungeon.leave().ok)
	assert_true(_s.dungeon.has_pending())
	assert_eq(_s.dungeon.wins(), 0)


func test_a_delivery_of_the_pieces_goes_through_the_armory() -> void:
	var s: GameSession = autofree(TestFactory.session(52, DungeonEngineDouble.data_with_pool()))
	var engine: DungeonEngineDouble = DungeonEngineDouble.attach(s)
	engine.open_and_clear_entrance()
	engine.walk_to_boss()
	for _i: int in 3:
		engine.end_intro()
		engine.clear_stage()
	assert_gt(s.armory.instances().size(), 0, "the boss pieces are in the Armory")
	assert_false(s.dungeon.has_pending(), "pieces never wait: the filter settles them")


func test_a_fracture_cannot_open_during_a_dungeon_and_the_other_way_round() -> void:
	_s.dungeon.open(&"test_den")
	var uid: int = FractureUtil.card(_s, 1)
	assert_eq(_s.fractures.open(uid).reason, Reasons.DUNGEON_ACTIVE)
	assert_true(_s.cards.has(uid), "the Card is not spent")
	_s.dungeon.flee()
	assert_false(_s.dungeon.is_active())


func test_a_dungeon_cannot_open_during_a_fracture() -> void:
	var s: GameSession = autofree(FractureUtil.session(53))
	var engine: DungeonEngineDouble = DungeonEngineDouble.attach(s, 3, false)
	assert_true(s.fractures.open(FractureUtil.card(s, 1)).ok)
	assert_eq(s.dungeon.open(&"test_den").reason, Reasons.FRACTURE_ACTIVE)
	assert_eq(s.dungeon.tickets(&"test_den"), 3)
	assert_eq(engine.calls.size(), 0)
