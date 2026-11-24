extends GutTest
## M37-6 (docs/02_FORMULAS_M37.md F-209, docs/05_INTERFACES_M37.md §5.49, §6i): the Auction House history, the Mail and the gold
## are identical whatever the step size (12 h in one step = 100 ms ticks = 60 s blocks = the offline simulator), a real v12
## slot loads as v13 with nothing else changed, and a whole game on a real session (list, sell now, cancel, collect).

const SEED: int = 3737
const HOUR_MS: int = 3_600_000
const NOW_MS: int = 1793603600000
const LOG: StringName = &"redbirch_log"
const SLOT_V11: String = "res://tests/fixtures/saves/slot_v11.json"


func _open_session(seed_value: int = SEED) -> GameSession:
	var s: GameSession = autofree(TestFactory.session_no_kit(seed_value, TestFactory.real_data()))
	TestFactory.make_roomy(s)
	var cost: Dictionary = s.village.next_cost(&"auction_house")
	for row: Dictionary in cost["items"] as Array:
		TestFactory.give(s, row["item"] as StringName, int(row["qty"]))
	s.wallet.add_gold(int(cost["gold"]))
	assert_true(s.village.upgrade(&"auction_house").ok)
	return s


## Same actions on every session: some listings (prices around the market, the three first durations) and a Sell now.
func _setup_listings(s: GameSession) -> void:
	s.wallet.add_gold(50_000_000)
	var durations: Array[AuctionDuration] = s.auction.durations()
	var items: Array[StringName] = [LOG, &"copper_ore", &"trout"]
	var made: int = 0
	for id: StringName in s.auction.listed_items():
		if made >= 6:
			break
		TestFactory.give(s, id, 300)
		var price: int = maxi(1, s.auction.suggested_price(id))
		var d: AuctionDuration = durations[made % durations.size()]
		if s.auction.list_item(id, 100 + made * 20, price, d.id).ok:
			made += 1
	assert_gt(made, 2, "the setup made some listings (items %s)" % [items])
	TestFactory.give(s, LOG, 40)
	s.auction.sell(LOG, 40)


func _snapshot(s: GameSession) -> Dictionary:
	return {"auction": s.auction.to_save(), "history": s.auction.history(), "mail": s.mail.to_save(), "gold": s.wallet.get_gold(),
			"listings": s.auction.my_listings().size()}


func _run_ms(s: GameSession, total: int, step: int) -> void:
	for _i: int in total / step:
		s.advance(step)


func test_history_12h_one_step_equals_100ms_equals_60s_equals_offline() -> void:
	var one: GameSession = _open_session()
	var fine: GameSession = _open_session()
	var minute: GameSession = _open_session()
	var away: GameSession = _open_session()
	for s: GameSession in [one, fine, minute, away]:
		_setup_listings(s)
	one.advance(12 * HOUR_MS)
	for _i: int in 12 * HOUR_MS / 100:
		fine.auction.advance(100)
	_run_ms(minute, 12 * HOUR_MS, 60_000)
	await OfflineSimulator.new().run(away, 12 * HOUR_MS, false, false)
	var ref: Dictionary = _snapshot(one)
	assert_gt((ref["history"] as Array).size(), 0, "the 12 h produced history (the test is not vacuous)")
	assert_lte((ref["history"] as Array).size(), one.auction.history_max())
	assert_eq(_snapshot(minute), ref, "60 s steps")
	assert_eq(_snapshot(away), ref, "offline simulator")
	assert_eq((fine.auction.to_save()), ref["auction"], "100 ms ticks: auction state and history")
	assert_eq(fine.auction.history(), ref["history"], "100 ms ticks: history")


func test_a_real_v12_slot_loads_and_saves_as_v13_with_nothing_else_changed() -> void:
	var s: GameSession = _open_session()
	_setup_listings(s)
	s.advance(3 * HOUR_MS)
	assert_gt(s.auction.history().size(), 0)
	var d13: Dictionary = s.to_save(NOW_MS)
	assert_eq(int(d13["format_version"]), 14)
	# build the v12 file of the same game: no history, format 12
	var d12: Dictionary = SaveCodec.decode(SaveCodec.encode(d13))
	d12["format_version"] = 12
	(d12["modules"]["auction"] as Dictionary).erase("history")
	var migrated: Dictionary = SaveMigrator.migrate(d12)
	assert_eq(int(migrated["format_version"]), 14)
	var loaded: GameSession = _open_session(1)
	assert_true(loaded.from_save(migrated).ok)
	assert_eq(loaded.auction.history(), [], "a v12 slot starts with an empty history")
	var back: Dictionary = loaded.to_save(NOW_MS)
	var expected: Dictionary = d13.duplicate(true)
	(expected["modules"]["auction"] as Dictionary)["history"] = []
	assert_eq(back, expected, "no other difference between the v12 slot and its v13 save")


func test_the_v11_fixture_chains_to_v13_and_saves_again_unchanged() -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(SLOT_V11))
	var out: Dictionary = SaveMigrator.migrate(raw as Dictionary)
	assert_eq(int(out["format_version"]), 14)
	var s: GameSession = autofree(TestFactory.session_no_kit(5, TestFactory.real_data()))
	assert_true(s.from_save(out).ok)
	var again: Dictionary = s.to_save(0)
	var twice: GameSession = autofree(TestFactory.session_no_kit(6, TestFactory.real_data()))
	assert_true(twice.from_save(SaveCodec.decode(SaveCodec.encode(again))).ok)
	assert_eq(twice.auction.to_save(), s.auction.to_save())
	assert_eq(twice.auction.history(), [])


func test_save_v13_roundtrip_keeps_a_full_history() -> void:
	var s: GameSession = _open_session()
	_setup_listings(s)
	s.advance(12 * HOUR_MS)
	var h: Array[Dictionary] = s.auction.history()
	assert_gt(h.size(), 0)
	var loaded: GameSession = _open_session(2)
	assert_true(loaded.from_save(SaveCodec.decode(SaveCodec.encode(s.to_save(NOW_MS)))).ok)
	assert_eq(loaded.auction.history(), h, "history survives the save, order included")
	loaded.advance(2 * HOUR_MS)
	s.advance(2 * HOUR_MS)
	assert_eq(loaded.auction.history(), s.auction.history(), "and goes on identically")


func test_a_whole_game_sell_now_cancel_collect_keeps_gold_and_history_consistent() -> void:
	var s: GameSession = _open_session()
	s.wallet.add_gold(10_000_000)
	TestFactory.give(s, LOG, 500)
	var d: AuctionDuration = s.auction.durations()[0]
	var price: int = maxi(1, s.auction.suggested_price(LOG))
	assert_true(s.auction.list_item(LOG, 200, price, d.id).ok)
	var id: int = int(s.auction.my_listings()[0]["id"])
	assert_true(s.auction.sell(LOG, 100).ok)
	var h: Array[Dictionary] = s.auction.history()
	assert_eq(h[0]["kind"], &"instant_sold")
	assert_eq(int(h[0]["listing"]), 0)
	assert_eq(int(h[0]["qty"]), 100)
	assert_true(s.auction.cancel_listing(id).ok)
	h = s.auction.history()
	assert_eq(h[0]["kind"], &"cancelled")
	assert_eq(int(h[0]["qty"]), 200)
	assert_eq(int(h[0]["listing"]), id)
	assert_eq(s.auction.my_listings().size(), 0)
	var gold: int = s.wallet.get_gold()
	for m: Dictionary in s.mail.messages().duplicate(true):
		s.mail.collect(int(m["id"]))
	assert_gt(s.wallet.get_gold(), gold, "the Sell now money came out of the Mail")
	assert_eq(s.bank.get_count(LOG), 500 - 100, "500 minus the 100 sold now; the cancelled pieces came back")
	assert_lte(s.auction.history().size(), s.auction.history_max())
