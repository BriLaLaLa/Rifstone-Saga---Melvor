extends GutTest
## Card drops from loot tables (F-32 entry with an `item` of category `map`, F-109): they go to the CardStore with the
## rarity of F-109 (global `item_rarity_pct`), never to the loot bag; a full Deposit gives card_rejected.

var _session: GameSession = null
var _rejected: Array[int] = []


func before_each() -> void:
	_session = TestFactory.session(31)
	add_child_autofree(_session)
	_rejected = []
	_session.events.card_rejected.connect(func(grade: int) -> void: _rejected.append(grade))


func _drop(item: StringName, chance: float, qty_min: int, qty_max: int) -> Array[DropEntry]:
	var entry := DropEntry.new()
	entry.item_id = item
	entry.chance_pct = chance
	entry.qty_min = qty_min
	entry.qty_max = qty_max
	var list: Array[DropEntry] = [entry]
	return list


func _roll(drops: Array[DropEntry]) -> void:
	KillRewards.roll_drops(_session, _session.combat.loot, drops, ItemRoller.SOURCE_MONSTER, 10)


func test_a_card_drop_goes_to_the_store_not_to_the_bag() -> void:
	_roll(_drop(&"fracture_card_2", 100.0, 1, 1))
	assert_eq(_session.cards.used(), 1)
	var card: MapCard = _session.cards.cards()[0]
	assert_eq(card.grade, 2)
	assert_eq(card.base_id, &"fracture_card_2")
	assert_eq(_session.combat.loot.used(), 0, "never in the loot bag")
	assert_eq(_session.bank.get_count(&"fracture_card_2"), 0)


func test_the_draws_follow_f109_rarity_first() -> void:
	# A copy of the session rng: the certain chance roll consumes nothing, then the quantity, then the rarity (F-109).
	var probe := RngService.new(1)
	probe.from_save(_session.rng.to_save())
	probe.randi_range(1, 1)
	var expected_rarity: StringName = MapCardRoller.roll_rarity(0.0, _session.data, probe)
	_roll(_drop(&"fracture_card_1", 100.0, 1, 1))
	assert_eq(_session.cards.cards()[0].rarity, expected_rarity)


func test_item_rarity_pct_raises_the_rarity() -> void:
	var rare := 0
	var base := 0
	for i: int in 600:
		_session.cards.take(_session.cards.create(1, _session.cards.roll_rarity()))
		base += 1
	_session.modifiers.set_source(&"test", [Modifier.make(&"item_rarity_pct", 1000.0)] as Array[Modifier])
	for i: int in 600:
		var uid: int = _session.cards.create(1, _session.cards.roll_rarity())
		if _session.cards.get_card(uid).rarity != &"common":
			rare += 1
		_session.cards.take(uid)
	assert_gt(rare, 500, "k = 11: nearly every Card is magic or rare")
	assert_eq(base, 600)


func test_chance_zero_never_drops() -> void:
	for i: int in 30:
		_roll(_drop(&"fracture_card_1", 0.0, 1, 1))
	assert_eq(_session.cards.used(), 0)


func test_full_deposit_loses_the_card_with_a_signal() -> void:
	var free: int = _session.deposit.free_slots()
	_session.deposit.register_occupant(&"test_filler", func() -> int: return free)
	_roll(_drop(&"fracture_card_3", 100.0, 1, 1))
	assert_eq(_session.cards.used(), 0)
	assert_eq(_rejected, [3])
	assert_eq(_session.combat.loot.used(), 0)
