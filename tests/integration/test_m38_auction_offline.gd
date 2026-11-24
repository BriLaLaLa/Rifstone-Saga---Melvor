extends GutTest
## M38-5 (docs/02_FORMULAS_M38.md F-215, F-216, F-184; docs/05_INTERFACES_M38.md §5.50, §6j): the single book on a real `GameSession`.
## Big purchases and active listings: 12 h in one step = 100 ms ticks = 60 s blocks = the offline simulator (`taken`, gold, Deposit,
## Mail and history identical), a v13 slot loads as v14 with nothing else changed, and a whole game of buying and restocking.

const SEED: int = 3838
const HOUR_MS: int = 3_600_000
const NOW_MS: int = 1793603600000
const LOG: StringName = &"redbirch_log"
const GRIP: StringName = &"redbirch_grip"
const PLATE: StringName = &"riftite_plate"


func _open_session(seed_value: int = SEED) -> GameSession:
	var s: GameSession = autofree(TestFactory.session_no_kit(seed_value, TestFactory.real_data()))
	TestFactory.make_roomy(s)
	var cost: Dictionary = s.village.next_cost(&"auction_house")
	for row: Dictionary in cost["items"] as Array:
		TestFactory.give(s, row["item"] as StringName, int(row["qty"]))
	s.wallet.add_gold(int(cost["gold"]))
	assert_true(s.village.upgrade(&"auction_house").ok)
	return s


## The same actions on every session: big purchases of items of several bands, a listing and a Sell now.
func _setup_big(s: GameSession) -> void:
	s.wallet.add_gold(2_000_000_000)
	var bought: int = 0
	for id: StringName in s.auction.buyable_items():
		var qty: int = mini(s.auction.available(id), 40 + bought * 150)
		if qty > 0 and s.auction.buy(id, qty).ok:
			bought += 1
		if bought >= 6:
			break
	assert_gte(bought, 4, "the setup made big purchases")
	var duration: AuctionDuration = s.auction.durations()[0]
	TestFactory.give(s, LOG, 400)
	assert_true(s.auction.list_item(LOG, 200, maxi(1, s.auction.suggested_price(LOG)), duration.id).ok)
	assert_true(s.auction.sell(LOG, 100).ok)


func _snapshot(s: GameSession) -> Dictionary:
	var counts: Dictionary = {}
	for id: StringName in s.auction.buyable_items():
		counts[id] = s.bank.get_count(id)
	return {"auction": s.auction.to_save(), "history": s.auction.history(), "mail": s.mail.to_save(), "gold": s.wallet.get_gold(),
			"listings": s.auction.my_listings(), "bank": counts, "taken": (s.auction.to_save()["taken"] as Dictionary).duplicate()}


func _run_ms(s: GameSession, total: int, step: int) -> void:
	for _i: int in total / step:
		s.advance(step)


func test_12h_one_step_equals_100ms_equals_60s_equals_offline_with_taken() -> void:
	var one: GameSession = _open_session()
	var fine: GameSession = _open_session()
	var minute: GameSession = _open_session()
	var away: GameSession = _open_session()
	for s: GameSession in [one, fine, minute, away]:
		_setup_big(s)
	var start: Dictionary = _snapshot(one)
	assert_gt((start["taken"] as Dictionary).size(), 3, "the purchases left `taken` on several items (not vacuous)")
	one.advance(12 * HOUR_MS)
	for _i: int in 12 * HOUR_MS / 100:
		fine.auction.advance(100)
	_run_ms(minute, 12 * HOUR_MS, 60_000)
	await OfflineSimulator.new().run(away, 12 * HOUR_MS, false, false)
	var ref: Dictionary = _snapshot(one)
	assert_eq((ref["taken"] as Dictionary).size(), 0, "F-216: 12 h bring every `taken` back to 0")
	assert_eq(_snapshot(minute), ref, "60 s steps")
	assert_eq(_snapshot(away), ref, "offline simulator")
	assert_eq(fine.auction.to_save(), ref["auction"], "100 ms ticks: auction state")
	assert_eq(fine.auction.history(), ref["history"], "100 ms ticks: history")
	assert_eq(fine.mail.to_save(), ref["mail"], "100 ms ticks: Mail")


func test_taken_still_present_after_2h_is_identical_in_every_step_size() -> void:
	var one: GameSession = _open_session()
	var fine: GameSession = _open_session()
	var minute: GameSession = _open_session()
	var away: GameSession = _open_session()
	for s: GameSession in [one, fine, minute, away]:
		_setup_big(s)
	one.advance(2 * HOUR_MS)
	for _i: int in 2 * HOUR_MS / 100:
		fine.auction.advance(100)
	_run_ms(minute, 2 * HOUR_MS, 60_000)
	await OfflineSimulator.new().run(away, 2 * HOUR_MS, false, false)
	var ref: Dictionary = _snapshot(one)
	assert_gt((ref["taken"] as Dictionary).size(), 0, "after 2 h some `taken` is still there: the comparison is not trivial")
	assert_eq(_snapshot(minute), ref, "60 s steps")
	assert_eq(_snapshot(away), ref, "offline simulator")
	assert_eq(fine.auction.to_save(), ref["auction"], "100 ms ticks")


func test_advance_a_then_b_equals_a_plus_b_on_taken_of_every_band() -> void:
	var a: GameSession = _open_session()
	var b: GameSession = _open_session()
	_setup_big(a)
	_setup_big(b)
	a.auction.advance(37 * 60_000 + 123)
	a.auction.advance(5 * HOUR_MS + 17)
	b.auction.advance(37 * 60_000 + 123 + 5 * HOUR_MS + 17)
	assert_eq(a.auction.to_save(), b.auction.to_save())


func test_a_v13_slot_loads_as_v14_and_saves_with_nothing_else_changed() -> void:
	var s: GameSession = _open_session()
	s.wallet.add_gold(50_000_000)
	TestFactory.give(s, LOG, 600)
	s.auction.sell(LOG, 600)
	s.advance(3 * HOUR_MS)
	var d14: Dictionary = s.to_save(NOW_MS)
	assert_eq(int(d14["format_version"]), 14)
	assert_eq((d14["modules"]["auction"] as Dictionary)["taken"], {}, "a game that bought nothing saves an empty `taken`")
	# the v13 file of the same game: format 13, a `stock` on two items, no `taken`
	var d13: Dictionary = SaveCodec.decode(SaveCodec.encode(d14))
	d13["format_version"] = 13
	var auction: Dictionary = (d13["modules"] as Dictionary)["auction"] as Dictionary
	auction.erase("taken")
	var items: Dictionary = auction["items"] as Dictionary
	items[GRIP] = (items.get(GRIP, {}) as Dictionary).merged({"stock": 123})
	items[PLATE] = (items.get(PLATE, {}) as Dictionary).merged({"stock": 3})
	var migrated: Dictionary = SaveMigrator.migrate(d13)
	assert_eq(int(migrated["format_version"]), 14)
	var loaded: GameSession = _open_session(1)
	assert_true(loaded.from_save(migrated).ok)
	assert_eq(loaded.auction.available(GRIP), s.auction.available(GRIP), "the old `stock` is not a purchase")
	assert_eq(loaded.auction.buy_unit(PLATE), s.auction.buy_unit(PLATE))
	assert_eq(loaded.to_save(NOW_MS), d14, "no other difference between the v13 slot and its v14 save")
	loaded.advance(HOUR_MS)
	s.advance(HOUR_MS)
	assert_eq(loaded.auction.to_save(), s.auction.to_save(), "and the market goes on identically")


func test_a_whole_game_big_buy_price_rises_stock_drains_and_comes_back() -> void:
	var s: GameSession = _open_session()
	s.wallet.add_gold(2_000_000_000)
	var item: StringName = GRIP
	var avail0: int = s.auction.available(item)
	assert_gt(avail0, 0)
	var unit0: int = s.auction.buy_unit(item)
	var q: int = avail0 / 2
	var gold0: int = s.wallet.get_gold()
	var cost: int = s.auction.buy_quote(item, q)
	assert_gte(cost, q * unit0, "the cheapest pieces go first: the average is never below the best price")
	var preview: Dictionary = s.auction.buy_preview(item, q)
	assert_true(s.auction.buy(item, q).ok)
	assert_eq(s.wallet.get_gold(), gold0 - cost, "the gold paid is the sum of the book (F-215)")
	assert_eq(s.bank.get_count(item), q)
	assert_eq(s.auction.available(item), avail0 - q)
	assert_gt(s.auction.buy_unit(item), unit0, "after a big purchase the next piece costs more (scarcity)")
	assert_false(preview.is_empty())
	assert_eq(s.auction.can_buy(item, avail0).reason, Reasons.OUT_OF_STOCK, "more than what is left")
	# buy the rest: sold out, the message of the restock time
	assert_true(s.auction.buy(item, s.auction.available(item)).ok)
	assert_eq(s.auction.available(item), 0)
	assert_eq(s.auction.can_buy(item, 1).reason, Reasons.OUT_OF_STOCK)
	assert_gt(s.auction.restock_ms(item), 0)
	# pieces come back with the time, the total of the item in the bank never exceeds what was bought
	s.advance(HOUR_MS)
	var back: int = s.auction.available(item)
	assert_gt(back, 0, "one hour gave pieces back")
	assert_lt(back, avail0)
	s.advance(12 * HOUR_MS)
	assert_eq((s.auction.to_save()["taken"] as Dictionary).size(), 0)
	assert_gt(s.auction.available(item), 0)
	# save and load in the middle of a restock
	assert_true(s.auction.buy(item, mini(300, s.auction.available(item))).ok)
	var loaded: GameSession = _open_session(2)
	assert_true(loaded.from_save(SaveCodec.decode(SaveCodec.encode(s.to_save(NOW_MS)))).ok)
	assert_eq(loaded.auction.to_save(), s.auction.to_save())
	s.advance(90 * 60_000)
	loaded.advance(90 * 60_000)
	assert_eq(loaded.auction.to_save(), s.auction.to_save(), "the loaded `taken` recovers exactly like the original")
	assert_eq(loaded.auction.available(item), s.auction.available(item))


func test_a_big_buy_and_a_resale_never_gains_gold_on_a_real_session() -> void:
	var s: GameSession = _open_session()
	s.wallet.add_gold(1_000_000_000)
	var item: StringName = GRIP
	var qty: int = s.auction.available(item)
	var start: int = s.wallet.get_gold()
	assert_true(s.auction.buy(item, qty).ok)
	assert_true(s.auction.sell(item, qty).ok)
	for m: Dictionary in s.mail.messages():
		if int(m.get("money", 0)) > 0:
			assert_true(s.mail.collect(int(m["id"])).ok)
	assert_lt(s.wallet.get_gold(), start, "buying the whole book and selling it back loses gold (F-217)")
	assert_eq(s.bank.get_count(item), 0)
