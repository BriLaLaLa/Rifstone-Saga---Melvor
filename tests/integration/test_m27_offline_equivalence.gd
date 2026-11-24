extends GutTest
## M27-09 (F-184): the Auction House v2 on the same engine as the game. Three listings (one sells out, one sells in pieces, one
## expires), a Sell now and mail that nobody collects: 12 h in one block = ticks of 100 ms = blocks of 60 s = 6 h + save/load + 6 h,
## whole state identical (auction with its listings, mail, wallet, bank, rng). Real data, real session. Plus the real v10 slot
## migrated and used end to end, and the conservation of money through the Mail.

const SEED: int = 2709
const HOUR_MS: int = 3_600_000
const TICK_MS: int = 100
const SLOT_V10: String = "res://tests/fixtures/saves/slot_v10.json"


func _session() -> GameSession:
	var s: GameSession = autofree(TestFactory.session_no_kit(SEED, TestFactory.real_data()))
	TestFactory.make_roomy(s)
	s.wallet.add_gold(2_000_000_000)
	_build_auction(s)
	return s


func _build_auction(s: GameSession) -> void:
	var cost: Dictionary = s.village.next_cost(&"auction_house")
	for row: Dictionary in cost["items"] as Array:
		TestFactory.give(s, row["item"] as StringName, int(row["qty"]))
	_ok(s.village.upgrade(&"auction_house"))


## Listings of F-180 (sells out; pieces; expires) and a Sell now, all created at the same block.
func _with_listings() -> GameSession:
	var s: GameSession = _session()
	TestFactory.give(s, &"redbirch_grip", 1000)  # 600 + 100 + 300
	TestFactory.give(s, &"riftite_plate", 10)
	TestFactory.give(s, &"ashlead_plate", 50)
	_ok(s.auction.list_item(&"redbirch_grip", 600, 250, &"short"))
	_ok(s.auction.list_item(&"redbirch_grip", 100, s.auction.max_price(&"redbirch_grip"), &"short"))
	_ok(s.auction.list_item(&"redbirch_grip", 300, 270, &"short"))
	_ok(s.auction.list_item(&"riftite_plate", 10, 75_000, &"long"))
	TestFactory.give(s, &"ashpine_grip", 100)
	_ok(s.auction.list_item(&"ashpine_grip", 100, s.auction.max_price(&"ashpine_grip"), &"long"))
	_ok(s.auction.sell(&"ashlead_plate", 50))
	assert_eq(s.auction.my_listings().size(), 5)
	return s


func _ok(r: CommandResult) -> void:
	assert_true(r.ok, "command failed: %s" % [r.reason])


func _state(s: GameSession) -> Dictionary:
	var d: Dictionary = s.to_save(0)
	d.erase("play_time_ms")
	return d


func _assert_same(a: GameSession, b: GameSession, what: String) -> void:
	var left: Dictionary = _state(a)
	var right: Dictionary = _state(b)
	var modules_a: Dictionary = left["modules"]
	var modules_b: Dictionary = right["modules"]
	assert_eq(modules_b.keys().size(), modules_a.keys().size(), "%s: same modules" % what)
	for module: Variant in modules_a:
		assert_eq(modules_b.get(module), modules_a[module], "%s: module %s" % [what, module])
	assert_eq(right["rng"], left["rng"], "%s: the rng" % what)


func _reload(s: GameSession, seed_value: int) -> GameSession:
	var loaded: GameSession = autofree(TestFactory.session_no_kit(seed_value, TestFactory.real_data()))
	assert_true(loaded.from_save(SaveCodec.decode(SaveCodec.encode(s.to_save(0)))).ok)
	return loaded


func _mail_money(s: GameSession) -> int:
	var total: int = 0
	for m: Dictionary in s.mail.messages():
		total += int(m["money"])
	return total


func test_twelve_hours_with_listings_and_mail_are_the_same_in_a_block_ticks_and_blocks() -> void:
	var one: GameSession = _with_listings()
	var ticks: GameSession = _with_listings()
	var blocks: GameSession = _with_listings()
	var twelve: int = 12 * HOUR_MS
	one.advance(twelve)
	for _i: int in twelve / TICK_MS:
		ticks.advance(TICK_MS)
	for _i: int in twelve / 60_000:
		blocks.advance(60_000)
	# The run is not trivial: something sold, something expired, the Mail has more than the Sell now.
	var kinds: Array[StringName] = []
	for m: Dictionary in one.mail.messages():
		kinds.append(m["kind"] as StringName)
	assert_true(kinds.has(&"auction_sale"), "Sell now")
	assert_true(kinds.has(&"auction_sold"), "sold listings")
	assert_true(kinds.has(&"auction_expired"), "the listing at the ceiling expired")
	assert_eq(one.auction.my_listings().size(), 1, "only the 48 h listing without buyers is still active")
	_assert_same(one, ticks, "12 h block vs ticks")
	_assert_same(one, blocks, "12 h block vs blocks")


func test_six_hours_save_and_load_six_hours_equals_twelve_straight() -> void:
	var straight: GameSession = _with_listings()
	var half: GameSession = _with_listings()
	straight.advance(12 * HOUR_MS)
	half.advance(6 * HOUR_MS)
	var loaded: GameSession = _reload(half, SEED + 1)
	_assert_same(half, loaded, "right after the load")
	assert_eq(loaded.auction.my_listings(), half.auction.my_listings(), "listings survive the save")
	loaded.advance(6 * HOUR_MS)
	_assert_same(straight, loaded, "straight vs save-reload")


func test_collecting_in_the_middle_does_not_change_the_end_when_done_on_both_sides() -> void:
	var straight: GameSession = _with_listings()
	var split: GameSession = _with_listings()
	straight.advance(6 * HOUR_MS)
	split.advance(6 * HOUR_MS)
	assert_gt(straight.mail.collect_all(), 0)
	assert_gt(split.mail.collect_all(), 0)
	var loaded: GameSession = _reload(split, SEED + 2)
	straight.advance(6 * HOUR_MS)
	loaded.advance(6 * HOUR_MS)
	_assert_same(straight, loaded, "collect at 6 h, then save-reload")


func test_a_single_advance_then_collect_equals_collecting_each_block() -> void:
	# The Mail merges messages of the same listing: the sum of the money is what counts, not how often one looks.
	var lazy: GameSession = _with_listings()
	var eager: GameSession = _with_listings()
	for i: int in 12 * 60:
		eager.advance(60_000)
		if i % 30 == 0:
			eager.mail.collect_all()
	lazy.advance(12 * HOUR_MS)
	var lazy_before: int = lazy.wallet.get_gold()
	var lazy_waiting: int = _mail_money(lazy)
	assert_gt(lazy_waiting, 0)
	lazy.mail.collect_all()
	eager.mail.collect_all()
	assert_eq(lazy.wallet.get_gold(), lazy_before + lazy_waiting)
	assert_eq(eager.wallet.get_gold(), lazy.wallet.get_gold(), "the same money however often the Mail is collected")


func test_money_only_comes_from_the_mail_and_goes_out_as_deposit() -> void:
	var s: GameSession = _session()
	TestFactory.give(s, &"redbirch_grip", 600)
	var start: int = s.wallet.get_gold()
	var deposit: int = s.auction.listing_deposit(&"redbirch_grip", 600, &"short")
	_ok(s.auction.list_item(&"redbirch_grip", 600, 250, &"short"))
	assert_eq(s.wallet.get_gold(), start - deposit, "only the deposit leaves the wallet")
	s.advance(12 * HOUR_MS)
	assert_eq(s.wallet.get_gold(), start - deposit, "sales do not touch the wallet")
	var waiting: int = _mail_money(s)
	assert_gt(waiting, 0)
	var messages: int = s.mail.count()
	assert_eq(s.mail.collect_all(), messages)
	assert_eq(s.wallet.get_gold(), start - deposit + waiting)
	assert_eq(s.mail.count(), 0)


func test_the_real_v10_slot_migrated_runs_the_auction_end_to_end() -> void:
	var text: String = FileAccess.get_file_as_string(SLOT_V10)
	var raw: Variant = JSON.parse_string(text)
	assert_true(raw is Dictionary, "slot_v10.json is readable")
	var v10: Dictionary = raw as Dictionary
	assert_eq(int(v10["format_version"]), 10)
	var gold: int = int((v10["modules"] as Dictionary)["wallet"]["gold"])
	var s: GameSession = autofree(TestFactory.session_no_kit(SEED + 3, TestFactory.real_data()))
	_ok(s.from_save(SaveMigrator.migrate(v10)))
	assert_eq(s.wallet.get_gold(), gold * 100, "the wallet is in copper (x100)")
	assert_eq(s.mail.count(), 0, "a v10 slot has an empty Mail")
	assert_eq(s.auction.my_listings().size(), 0, "no listings in a v10 slot")
	assert_true(s.auction.is_open(), "the Auction House of the slot (level 1) is open")
	# The slot owns 100 redbirch logs: sell some at once, list the rest, let a day pass, collect.
	var logs: int = s.bank.get_count(&"redbirch_log")
	assert_gt(logs, 10)
	var start: int = s.wallet.get_gold()
	_ok(s.auction.sell(&"redbirch_log", 10))
	var price: int = s.auction.suggested_price(&"redbirch_log")
	var deposit: int = s.auction.listing_deposit(&"redbirch_log", logs - 10, &"short")
	_ok(s.auction.list_item(&"redbirch_log", logs - 10, price, &"short"))
	assert_eq(s.wallet.get_gold(), start - deposit)
	var loaded: GameSession = _reload(s, SEED + 4)
	_assert_same(s, loaded, "a migrated slot saves and loads as is (format %d)" % SaveMigrator.CURRENT_VERSION)
	s.advance(12 * HOUR_MS)
	loaded.advance(12 * HOUR_MS)
	_assert_same(s, loaded, "the migrated slot after 12 h")
	assert_gt(s.mail.count(), 0)
	var waiting: int = _mail_money(s)
	assert_gt(waiting, 0)
	# One piece in one place: bank + still listed + sold (Mail messages) + returned (Mail attachments) = what the slot had.
	var pieces: int = s.bank.get_count(&"redbirch_log")
	for l: Dictionary in s.auction.my_listings():
		pieces += int(l["qty"])
	for m: Dictionary in s.mail.messages():
		if m["kind"] == &"auction_sold" or m["kind"] == &"auction_sale":
			pieces += int(m["qty"])
		for it: Dictionary in m["items"] as Array:
			pieces += int(it["qty"])
	assert_eq(pieces, logs, "no piece appears out of nothing or in two places")
	s.mail.collect_all()
	assert_eq(s.wallet.get_gold(), start - deposit + waiting)


## M38-1 (F-216, F-184 extended): `taken` is part of the compared state; pieces bought at the start are restocked the same way in a
## block, ticks of 100 ms and blocks of 60 s, with the listings of the player active, and they are all back after 12 h.
func _with_listings_and_purchases() -> GameSession:
	var s: GameSession = _with_listings()
	_ok(s.auction.buy(&"redbirch_grip", 1000))
	var more: int = 0
	for id: StringName in s.auction.buyable_items():
		if more < 3 and id != &"redbirch_grip" and s.auction.buy_level(id) <= s.auction.level():
			_ok(s.auction.buy(id, mini(20, s.auction.available(id))))
			more += 1
	assert_eq(more, 3)
	return s


func test_taken_is_the_same_in_a_block_ticks_and_blocks() -> void:
	var one: GameSession = _with_listings_and_purchases()
	var ticks: GameSession = _with_listings_and_purchases()
	var blocks: GameSession = _with_listings_and_purchases()
	var three: int = 3 * HOUR_MS
	one.advance(three)
	for _i: int in three / TICK_MS:
		ticks.advance(TICK_MS)
	for _i: int in three / 60_000:
		blocks.advance(60_000)
	var taken: Dictionary = one.auction.to_save()["taken"] as Dictionary
	assert_gt(int(taken.get("redbirch_grip", 0)), 0, "3 h later the grip is not back yet: 1.000 - 36 * 17")
	assert_eq(taken["redbirch_grip"], 1000 - 36 * 17)
	_assert_same(one, ticks, "3 h block vs ticks, with taken")
	_assert_same(one, blocks, "3 h block vs blocks, with taken")
	one.advance(9 * HOUR_MS)
	ticks.advance(9 * HOUR_MS)
	assert_eq(one.auction.to_save()["taken"], {}, "12 h: everything is back")
	_assert_same(one, ticks, "12 h with taken")


func test_taken_survives_a_save_in_the_middle() -> void:
	var straight: GameSession = _with_listings_and_purchases()
	var half: GameSession = _with_listings_and_purchases()
	straight.advance(5 * HOUR_MS)
	half.advance(2 * HOUR_MS)
	var loaded: GameSession = _reload(half, SEED + 5)
	assert_eq(loaded.auction.to_save()["taken"], half.auction.to_save()["taken"])
	loaded.advance(3 * HOUR_MS)
	_assert_same(straight, loaded, "straight vs save-reload with taken")
