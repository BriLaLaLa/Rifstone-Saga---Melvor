extends GutTest
## F-136 (docs/02_FORMULAS.md §5i): the Market entries of the shop. `requires.village` against the Market level, the
## chain of the shelves, summed effects, and the 15 entries of the real data.

var _session: GameSession
var _shop: Shop


func before_each() -> void:
	_session = TestFactory.session_no_kit(11, TestFactory.real_data())
	add_child_autofree(_session)
	_shop = _session.shop
	_session.wallet.add_gold(200000 - _session.wallet.get_gold())


func _market(level: int) -> void:
	_session.village.from_save({"levels": {"market": level}})


func test_market_level_gates_the_entries() -> void:
	_market(2)
	assert_eq(_shop.can_buy(&"market_shelf_2").reason, Reasons.REQUIREMENT_NOT_MET, "needs Market 3")
	assert_true(_shop.can_buy(&"market_shelf_1").ok, "Market 1 is enough")
	_market(0)
	assert_eq(_shop.can_buy(&"market_shelf_1").reason, Reasons.REQUIREMENT_NOT_MET, "not built")


func test_the_chain_is_required() -> void:
	_market(3)
	assert_eq(_shop.can_buy(&"market_shelf_2").reason, Reasons.REQUIREMENT_NOT_MET, "market_shelf_1 not bought")
	assert_true(_shop.buy(&"market_shelf_1").ok)
	assert_true(_shop.buy(&"market_shelf_2").ok)


func test_shelves_add_up_to_the_deposit_capacity() -> void:
	_market(3)
	var before: int = _session.deposit.capacity()
	assert_true(_shop.buy(&"market_shelf_1").ok)
	assert_true(_shop.buy(&"market_shelf_2").ok)
	assert_eq(_session.modifiers.total(&"deposit_slots"), 8.0)
	assert_eq(_session.deposit.capacity(), before + 8, "F-133: 60 + 8 = 68 without other buildings")
	assert_eq(_shop.can_buy(&"market_shelf_1").reason, Reasons.MAX_PURCHASES)
	assert_eq(_session.wallet.get_gold(), 200000 - 2000 - 12000)


func test_requirement_is_checked_before_gold() -> void:
	_market(0)
	var broke: GameSession = TestFactory.session_no_kit(12, TestFactory.real_data())
	add_child_autofree(broke)
	assert_eq(broke.shop.can_buy(&"market_loot_pouch").reason, Reasons.REQUIREMENT_NOT_MET)


func test_the_fifteen_entries_of_the_real_data() -> void:
	var count: int = 0
	var total: int = 0
	for entry: ShopEntryDef in _session.data.shop_entries():
		if entry.category != &"market":
			continue
		count += 1
		total += entry.cost_gold
		assert_eq(entry.vendor, &"mercato")
		assert_eq(entry.max_purchases, 1)
		assert_true(entry.req_village.has(&"market"), str(entry.id))
	assert_eq(count, 15)
	assert_eq(total, 314000, "F-136: 314.000 gold in total")
