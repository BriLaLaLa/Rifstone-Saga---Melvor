extends GutTest
## M23-05, final integration of the Auction House on the real data and a real `GameSession` (docs/05_INTERFACES.md §5.30,
## docs/02_FORMULAS.md §5k): build it, sell (the price drops), let the time pass with `advance` and offline (the price rises),
## buy with a limited stock, save and load. The unit rules are in tests/systems/auction/; here only the whole path from outside.

const SEED: int = 2305
const LOG: StringName = &"redbirch_log"
const HOUR_MS: int = 3_600_000
const NOW_MS: int = 1793603600000


func _session(seed_value: int = SEED) -> GameSession:
	var s: GameSession = autofree(TestFactory.session_no_kit(seed_value, TestFactory.real_data()))
	TestFactory.make_roomy(s)
	return s


func _build(s: GameSession) -> void:
	var cost: Dictionary = s.village.next_cost(&"auction_house")
	for row: Dictionary in cost["items"] as Array:
		TestFactory.give(s, row["item"] as StringName, int(row["qty"]))
	s.wallet.add_gold(int(cost["gold"]))
	assert_true(s.village.upgrade(&"auction_house").ok)


func _open_session() -> GameSession:
	var s: GameSession = _session()
	_build(s)
	return s


func _level_one_item(s: GameSession) -> StringName:
	for id: StringName in s.auction.buyable_items():
		if s.auction.buy_level(id) == 1:
			return id
	return &""


func test_closed_until_built_then_open_with_the_real_cost() -> void:
	var s: GameSession = _session()
	TestFactory.give(s, LOG, 10)
	assert_false(s.auction.is_open())
	assert_eq(s.auction.can_sell(LOG, 1).reason, Reasons.REQUIREMENT_NOT_MET)
	var cost: Dictionary = s.village.next_cost(&"auction_house")
	assert_eq(int(cost["gold"]), 30000, "F-145 level 1")
	_build(s)
	assert_true(s.auction.is_open())
	assert_eq(s.auction.level(), 1)


func test_selling_drops_the_price_and_time_brings_it_back() -> void:
	var s: GameSession = _open_session()
	TestFactory.give(s, LOG, 2000)
	var stack: int = s.auction.sell_quote(LOG, 2000)
	var gold: int = s.wallet.get_gold()
	assert_true(s.auction.sell(LOG, 2000).ok)
	assert_eq(s.wallet.get_gold(), gold, "Sell now: the money waits in the Mail (M27-06)")
	assert_eq(int(s.mail.messages()[0]["money"]), stack)
	assert_true(s.mail.collect(int(s.mail.messages()[0]["id"])).ok)
	assert_eq(s.wallet.get_gold(), gold + stack)
	assert_eq(s.bank.get_count(LOG), 0, "the pieces left the Deposit and went nowhere else")
	var low: int = s.auction.sell_quote(LOG, 100)
	var last: int = low
	for hours: int in 3:
		for _i: int in 3600:
			s.advance(1000)
		var now: int = s.auction.sell_quote(LOG, 100)
		assert_gte(now, last, "never drops while resting (hour %d)" % hours)
		last = now
	assert_gt(last, low, "after 3 hours the price is higher")
	for _i: int in 3600 * 7:
		s.advance(1000)
	assert_eq(s.auction.to_save()["items"], {}, "after 10 hours the market is at rest again (F-149)")


func test_offline_gives_the_same_market_as_playing() -> void:
	var online: GameSession = _open_session()
	var away: GameSession = _open_session()
	for s: GameSession in [online, away]:
		TestFactory.give(s, LOG, 1500)
		assert_true(s.auction.sell(LOG, 1500).ok)
		s.wallet.add_gold(1_000_000)
		assert_true(s.auction.buy(_level_one_item(s), 7).ok)
	var five_hours: int = 5 * HOUR_MS
	for _i: int in five_hours / 500:
		online.advance(500)
	await OfflineSimulator.new().run(away, five_hours, false, false)
	assert_eq(away.auction.to_save(), online.auction.to_save(), "F-145: the clock is additive, the offline path = playing")
	assert_eq(away.auction.sell_quote(LOG, 300), online.auction.sell_quote(LOG, 300))


func test_limited_book_runs_out_and_restocks_with_time() -> void:
	var s: GameSession = _open_session()
	var item: StringName = _level_one_item(s)
	assert_ne(item, &"")
	s.wallet.add_gold(100_000_000)
	var cap: int = s.auction.available(item)
	assert_gt(cap, 0, "the book has pieces: the sum of the listings, no maximum")
	assert_eq(s.auction.can_buy(item, cap + 1).reason, Reasons.OUT_OF_STOCK)
	var price: int = s.auction.buy_quote(item, cap)
	var gold: int = s.wallet.get_gold()
	assert_true(s.auction.buy(item, cap).ok)
	assert_eq(s.wallet.get_gold(), gold - price)
	assert_eq(s.bank.get_count(item), cap)
	assert_eq(s.auction.available(item), 0)
	assert_eq(s.auction.can_buy(item, 1).reason, Reasons.OUT_OF_STOCK)
	s.advance(10 * 60 * 1000)
	var refilled: int = s.auction.available(item)
	assert_gt(refilled, 0, "two blocks gave something back")
	assert_lt(refilled, cap)
	assert_true(s.auction.buy(item, refilled).ok)
	assert_eq(s.bank.get_count(item), cap + refilled, "one stack, nothing created or lost")
	s.advance(12 * HOUR_MS)
	assert_eq((s.auction.to_save()["taken"] as Dictionary).size(), 0, "12 hours restock everything")
	assert_gt(s.auction.available(item), 0)


func test_nothing_is_gained_buying_and_selling_back_on_a_real_session() -> void:
	var s: GameSession = _open_session()
	var item: StringName = _level_one_item(s)
	s.wallet.add_gold(1_000_000)
	var start: int = s.wallet.get_gold()
	var qty: int = mini(50, s.auction.available(item))
	assert_true(s.auction.buy(item, qty).ok)
	assert_true(s.auction.sell(item, qty).ok)
	assert_lt(s.wallet.get_gold(), start, "buying and selling back loses gold (F-151)")
	assert_eq(s.bank.get_count(item), 0)
	var cost: int = s.auction.buy_quote(item, qty)
	assert_true(s.auction.buy(item, qty).ok)
	var through_deposit: int = s.shop.sell_value(item, qty)
	assert_lt(through_deposit, cost, "the fixed price of the Deposit does not pay back the purchase either")
	assert_true(s.shop.sell(item, qty).ok)


func test_save_and_load_keep_the_market_taken_and_building() -> void:
	var s: GameSession = _open_session()
	var item: StringName = _level_one_item(s)
	TestFactory.give(s, LOG, 800)
	s.wallet.add_gold(1_000_000)
	s.auction.sell(LOG, 800)
	s.auction.buy(item, 5)
	s.advance(7 * 60 * 1000)
	var blob: String = SaveCodec.encode(s.to_save(NOW_MS))
	var loaded: GameSession = _session(99)
	assert_true(loaded.from_save(SaveCodec.decode(blob)).ok)
	assert_eq(loaded.auction.to_save(), s.auction.to_save())
	assert_eq(loaded.auction.level(), 1)
	assert_eq(loaded.auction.available(item), s.auction.available(item))
	assert_eq(loaded.auction.sell_quote(LOG, 500), s.auction.sell_quote(LOG, 500))
	assert_eq(loaded.auction.trend(LOG), s.auction.trend(LOG))
	s.advance(3 * HOUR_MS)
	loaded.advance(3 * HOUR_MS)
	assert_eq(loaded.auction.to_save(), s.auction.to_save(), "the loaded market goes on exactly like the original")


func test_a_save_without_the_auction_key_starts_a_new_market() -> void:
	var s: GameSession = _open_session()
	var d: Dictionary = s.to_save(NOW_MS)
	(d["modules"] as Dictionary).erase("auction")
	var loaded: GameSession = _session(7)
	assert_true(loaded.from_save(SaveCodec.decode(SaveCodec.encode(d))).ok)
	assert_eq(loaded.auction.level(), 1, "the building is in the village module")
	assert_eq(loaded.auction.to_save()["block"], 0)
	assert_eq(loaded.auction.to_save()["items"], {})
