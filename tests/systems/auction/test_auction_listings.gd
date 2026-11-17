extends GutTest
## The player's listings (docs/02_FORMULAS_M27.md F-179…F-182, F-184; docs/05_INTERFACES_M27.md §5.39): the scenarios of F-180 block by
## block, the commands and their reasons, the Mail they feed, the clock equivalence and the save. Seed 12345, `redbirch_grip` unless said.

const AuctionTestData := preload("res://tests/systems/auction/auction_test_data.gd")
const SEED: int = 12345
const GRIP: StringName = &"redbirch_grip"
const PLATE: StringName = &"riftite_plate"
const BLOCK_MS: int = 300000

var _s: GameSession
var _house: AuctionHouse
var _changed: int = 0


func before_each() -> void:
	_changed = 0
	_s = _session()
	_house = _s.auction


func _session() -> GameSession:
	var s: GameSession = AuctionTestData.session(8)
	add_child_autofree(s)
	s.auction.from_save({"seed": SEED, "block": 0, "pending_ms": 0, "items": {}})
	s.events.auction_listings_changed.connect(func() -> void: _changed += 1)
	return s


func _blocks(n: int) -> void:
	_s.auction.advance(n * BLOCK_MS)


func _list(qty: int, price: int, duration: StringName = &"short", item: StringName = GRIP) -> int:
	TestFactory.give(_s, item, qty)
	var result: CommandResult = _s.auction.list_item(item, qty, price, duration)
	assert_true(result.ok, "list_item: %s" % result.reason)
	return int((_s.auction.my_listings().back() as Dictionary)["id"])


# Pieces and money of the `auction_sold` messages still in the Mail.
func _mail_sold() -> Vector2i:
	var total := Vector2i.ZERO
	for m: Dictionary in _s.mail.messages():
		if m["kind"] == &"auction_sold":
			total += Vector2i(int(m["qty"]), int(m["money"]))
	return total


# Pieces sold in each of the next `n` blocks (read from the Mail).
func _sold_per_block(n: int) -> Array[int]:
	var result: Array[int] = []
	for i: int in n:
		var before: int = _mail_sold().x
		_blocks(1)
		result.append(_mail_sold().x - before)
	return result


func test_600_at_250_block_by_block() -> void:
	var wallet: int = _s.wallet.get_gold()
	_list(600, 250)
	assert_eq(_s.wallet.get_gold(), wallet - 1200, "the deposit")
	assert_eq(_s.bank.get_count(GRIP), 0)
	assert_eq(_house.my_listings()[0]["status"], &"selling", "ahead 291 < D 486")
	assert_eq(_sold_per_block(1), [200] as Array[int])
	assert_eq(_mail_sold(), Vector2i(200, 47500), "gross 50.000, cut 2.500")
	assert_eq(_sold_per_block(2), [0, 0] as Array[int])
	assert_eq(_sold_per_block(1), [139] as Array[int])
	assert_eq(_mail_sold(), Vector2i(339, 80512), "one merged message")
	assert_eq(_s.mail.count(), 1)
	assert_eq(_sold_per_block(1), [0] as Array[int])
	assert_eq(_sold_per_block(1), [261] as Array[int])
	assert_eq(_mail_sold(), Vector2i(600, 142499), "net 142.499 (Vendi subito at block 0: 136.938)")
	assert_eq(_house.my_listings().size(), 0, "closed: sold out")
	assert_eq(_s.wallet.get_gold(), wallet - 1200, "nothing reaches the wallet without collecting")


func test_collecting_midway_gives_a_new_message() -> void:
	_list(600, 250)
	_blocks(4)
	assert_eq(_s.mail.count(), 1)
	var first: Dictionary = _s.mail.messages()[0]
	var wallet: int = _s.wallet.get_gold()
	assert_true(_s.mail.collect(int(first["id"])).ok)
	assert_eq(_s.wallet.get_gold(), wallet + 80512)
	assert_eq(int(first["qty"]), 339)
	_blocks(2)
	assert_eq(_s.mail.count(), 1)
	var second: Dictionary = _s.mail.messages()[0]
	assert_eq(int(second["id"]), 2)
	assert_eq([int(second["qty"]), int(second["money"])], [261, 61987])


func test_300_at_270_waits_for_the_market() -> void:
	_list(300, 270)
	assert_eq(_house.my_listings()[0]["status"], &"undercut", "ahead 747 >= D 486")
	var sold: Array[int] = _sold_per_block(33)
	for i: int in 11:
		assert_eq(sold[i], 0, "blocks 1-11")
	assert_eq(sold[11], 96, "block 12")
	for i: int in range(12, 29):
		assert_eq(sold[i], 0, "blocks 13-29")
	assert_eq(sold.slice(29), [55, 62, 43, 44] as Array[int])
	assert_eq(_house.my_listings().size(), 0)


func test_100_at_300_expires_into_the_mail() -> void:
	_list(100, 300)
	_blocks(143)
	assert_eq(_house.my_listings().size(), 1)
	assert_eq(_house.my_listings()[0]["ends_in_ms"], BLOCK_MS)
	_blocks(1)
	assert_eq(_house.my_listings().size(), 0)
	assert_eq(_s.mail.count(), 1)
	var message: Dictionary = _s.mail.messages()[0]
	assert_eq(message["kind"], &"auction_expired")
	assert_eq(message["items"], [{"item": GRIP, "qty": 100}])
	assert_eq(_s.bank.get_count(GRIP), 0, "the pieces wait in the Mail")
	assert_true(_s.mail.collect(int(message["id"])).ok)
	assert_eq(_s.bank.get_count(GRIP), 100)


func test_riftite_plate_10_at_75000() -> void:
	_s.wallet.add_gold(100000)
	var wallet: int = _s.wallet.get_gold()
	_list(10, 75000, &"long", PLATE)
	assert_eq(_s.wallet.get_gold(), wallet - 23800, "deposit of the long duration")
	assert_eq(_sold_per_block(3), [4, 4, 2] as Array[int])
	assert_eq(_house.my_listings().size(), 0)


func test_ordering_between_my_listings() -> void:
	var cheap: int = _list(100, 245)
	var dear: int = _list(600, 250)
	_blocks(1)
	var by_id: Dictionary = {}
	for m: Dictionary in _house.my_listings():
		by_id[m["id"]] = m
	assert_eq(int((by_id[cheap] as Dictionary)["sold"]) if by_id.has(cheap) else 100, 100, "L1 of F-179 sells all 100")
	assert_eq(int((by_id[dear] as Dictionary)["sold"]), 100, "L2 of F-179: ahead 391, D 491")


func test_book_shows_mine_in_place() -> void:
	var id: int = _list(10, 250)
	var rows: Array[Dictionary] = _house.book(GRIP)
	assert_eq(rows.size(), 13)
	var mine: Array[Dictionary] = rows.filter(func(r: Dictionary) -> bool: return r["mine"])
	assert_eq(mine.size(), 1)
	assert_eq(mine[0]["listing"], id)
	var prices: Array[int] = []
	for r: Dictionary in rows:
		prices.append(int(r["price"]))
	var sorted: Array[int] = prices.duplicate()
	sorted.sort()
	assert_eq(prices, sorted)
	assert_eq(rows[2]["price"], 250)
	assert_false(rows[2]["mine"], "at equal price the NPC listing comes first")
	assert_true(rows[3]["mine"])
	var pop: Dictionary = _house.population(GRIP)
	assert_eq([pop["listings"], pop["units"]], [13, 1203])


func test_creation_costs_and_limits() -> void:
	assert_eq(_house.max_price(GRIP), 2000)
	assert_eq(_house.listing_deposit(GRIP, 600, &"short"), 1200)
	assert_eq(_house.listing_deposit(GRIP, 600, &"medium"), 2400)
	assert_eq(_house.listing_deposit(PLATE, 10, &"long"), 23800)
	assert_eq(_house.listing_deposit(GRIP, 1, &"nope"), 0)
	assert_eq(_house.listing_net(GRIP, 600, 250), 142500, "gross 150.000 minus 7.500")
	assert_eq(_house.max_listings(), 10)
	assert_eq(_house.durations().size(), 3)


func test_can_list_reasons_in_order() -> void:
	TestFactory.give(_s, GRIP, 10)
	assert_eq(_house.can_list(GRIP, 0, 250, &"short").reason, Reasons.INVALID_AMOUNT)
	assert_eq(_house.can_list(&"test_unknown", 1, 250, &"short").reason, Reasons.UNKNOWN_ID)
	assert_eq(_house.can_list(GRIP, 1, 250, &"nope").reason, Reasons.UNKNOWN_ID)
	assert_eq(_house.can_list(GRIP, 11, 250, &"short").reason, Reasons.NOT_ENOUGH_ITEMS)
	assert_eq(_house.can_list(GRIP, 1, 0, &"short").reason, Reasons.INVALID_PRICE)
	assert_eq(_house.can_list(GRIP, 1, 2001, &"short").reason, Reasons.INVALID_PRICE)
	assert_true(_house.can_list(GRIP, 1, 2000, &"short").ok)
	_s.wallet.spend(_s.wallet.get_gold())
	assert_eq(_house.can_list(GRIP, 10, 250, &"short").reason, Reasons.NOT_ENOUGH_GOLD)
	var closed: GameSession = AuctionTestData.session(0)
	add_child_autofree(closed)
	TestFactory.give(closed, GRIP, 1)
	assert_eq(closed.auction.can_list(GRIP, 1, 250, &"short").reason, Reasons.REQUIREMENT_NOT_MET)


func test_failed_commands_change_nothing() -> void:
	TestFactory.give(_s, GRIP, 5)
	var gold: int = _s.wallet.get_gold()
	assert_eq(_house.list_item(GRIP, 5, 0, &"short").reason, Reasons.INVALID_PRICE)
	assert_eq(_s.bank.get_count(GRIP), 5)
	assert_eq(_s.wallet.get_gold(), gold)
	assert_eq(_house.my_listings().size(), 0)
	assert_eq(_changed, 0)


func test_listings_full() -> void:
	for i: int in 10:
		_list(1, 2000)
	TestFactory.give(_s, GRIP, 1)
	assert_eq(_house.can_list(GRIP, 1, 2000, &"short").reason, Reasons.LISTINGS_FULL)
	assert_eq(_house.list_item(GRIP, 1, 2000, &"short").reason, Reasons.LISTINGS_FULL)


func test_mailbox_full_blocks_commands_but_not_automatic_mail() -> void:
	var id: int = _list(100, 2000)
	for i: int in 50:
		_s.mail.post(&"auction_cancelled", {"item": GRIP, "qty": 1, "items": [{"item": GRIP, "qty": 1}]})
	assert_true(_s.mail.is_full())
	TestFactory.give(_s, GRIP, 10)
	assert_eq(_house.can_list(GRIP, 1, 250, &"short").reason, Reasons.MAILBOX_FULL)
	assert_eq(_house.can_sell(GRIP, 1).reason, Reasons.MAILBOX_FULL)
	assert_true(_house.can_cancel(id).ok, "the cancel always delivers")
	assert_true(_house.cancel_listing(id).ok)
	assert_eq(_s.mail.count(), 51)


func test_cancel_returns_the_pieces_and_loses_the_deposit() -> void:
	var wallet: int = _s.wallet.get_gold()
	var id: int = _list(600, 250)
	_blocks(1)
	_changed = 0
	assert_eq(_house.can_cancel(999).reason, Reasons.UNKNOWN_ID)
	assert_eq(_house.cancel_listing(999).reason, Reasons.UNKNOWN_ID)
	assert_true(_house.cancel_listing(id).ok)
	assert_eq(_changed, 1)
	assert_eq(_house.my_listings().size(), 0)
	assert_eq(_s.wallet.get_gold(), wallet - 1200)
	var cancelled: Dictionary = _s.mail.messages()[0]
	assert_eq(cancelled["kind"], &"auction_cancelled")
	assert_eq(cancelled["items"], [{"item": GRIP, "qty": 400}])
	assert_eq(_mail_sold(), Vector2i(200, 47500), "the sales already made stay")
	assert_eq(_house.can_cancel(id).reason, Reasons.UNKNOWN_ID)


func test_sell_now_goes_through_the_mail() -> void:
	TestFactory.give(_s, GRIP, 150)
	var wallet: int = _s.wallet.get_gold()
	var quote: int = _house.sell_quote(GRIP, 100)
	assert_true(_house.sell(GRIP, 100).ok)
	assert_true(_house.sell(GRIP, 50).ok)
	assert_eq(_s.wallet.get_gold(), wallet)
	assert_eq(_s.mail.count(), 1, "two sales of the same item: one message")
	var message: Dictionary = _s.mail.messages()[0]
	assert_eq(message["kind"], &"auction_sale")
	assert_eq(message["qty"], 150)
	assert_gt(int(message["money"]), quote)


func test_signal_once_per_advance() -> void:
	_list(600, 250)
	_changed = 0
	_blocks(1)
	assert_eq(_changed, 1)
	_blocks(1)
	assert_eq(_changed, 1, "nothing happened in block 2")
	_house.advance(60000)
	assert_eq(_changed, 1)


func test_no_roll_of_the_slot_generator() -> void:
	var before: Dictionary = _s.rng.to_save()
	_list(600, 250)
	_blocks(10)
	_house.cancel_listing(1)
	assert_eq(_s.rng.to_save(), before)


# --- F-184: the clock ---------------------------------------------------------------------------------------

func _setup_mixed(s: GameSession) -> void:
	for spec: Array in [[GRIP, 600, 250, &"short"], [&"redbirch_log", 4000, 5, &"medium"], [PLATE, 10, 75000, &"long"], [&"seared_riftmaw", 20, 60000, &"short"]]:
		TestFactory.give(s, spec[0], int(spec[1]))
		s.wallet.add_gold(100000)
		s.auction.list_item(spec[0], int(spec[1]), int(spec[2]), spec[3])


func _state(s: GameSession) -> Dictionary:
	return {"auction": s.auction.to_save(), "mail": s.mail.to_save(), "wallet": s.wallet.to_save(), "bank": s.bank.to_save()}


func test_advance_a_then_b_equals_a_plus_b() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for round: int in 6:
		var a: int = rng.randi_range(0, 40 * BLOCK_MS)
		var b: int = rng.randi_range(0, 40 * BLOCK_MS)
		var one: GameSession = _session()
		var two: GameSession = _session()
		_setup_mixed(one)
		_setup_mixed(two)
		one.auction.advance(a + b)
		two.auction.advance(a)
		two.auction.advance(b)
		assert_eq(_state(one), _state(two), "round %d (%d + %d ms)" % [round, a, b])
		assert_eq(one.auction.to_save()["block"], (a + b) / BLOCK_MS)


func test_twelve_hours_in_every_shape() -> void:
	var whole: GameSession = _session()
	var steps: GameSession = _session()
	var minutes: GameSession = _session()
	var resumed: GameSession = _session()
	for s: GameSession in [whole, steps, minutes, resumed]:
		_setup_mixed(s)
	whole.auction.advance(12 * 3600000)
	for i: int in 432000:
		steps.auction.advance(100)
	for i: int in 720:
		minutes.auction.advance(60000)
	resumed.auction.advance(6 * 3600000)
	var saved: Dictionary = {"auction": resumed.auction.to_save(), "mail": resumed.mail.to_save()}
	resumed.auction.from_save(saved["auction"] as Dictionary)
	resumed.mail.from_save(saved["mail"] as Dictionary)
	resumed.auction.advance(6 * 3600000)
	var expected: Dictionary = _state(whole)
	assert_eq(_state(steps), expected, "100 ms steps")
	assert_eq(_state(minutes), expected, "60 s blocks")
	assert_eq(_state(resumed), expected, "6 h + save/load + 6 h")
	assert_gt((expected["mail"] as Dictionary)["messages"].size(), 0)


# --- save ------------------------------------------------------------------------------------------------------

func test_save_round_trip() -> void:
	_list(600, 250)
	_list(10, 1000, &"long")
	_blocks(3)
	var saved: Dictionary = _house.to_save()
	assert_eq((saved["listings"] as Array).size(), 2)
	var restored: GameSession = _session()
	restored.auction.from_save(JSON.parse_string(JSON.stringify(saved)) as Dictionary)
	assert_eq(restored.auction.to_save(), saved)
	assert_eq(restored.auction.my_listings(), _house.my_listings())


func test_from_save_is_tolerant() -> void:
	var good: Dictionary = {"id": 3, "item": "redbirch_grip", "qty": 400, "sold": 200, "earned": 47500, "price": 250, "duration": "short", "start": 10, "end": 154}
	var rows: Array = [good,
		good.merged({"id": 3}, true),                          # duplicate id
		good.merged({"id": 0}, true),                          # id < 1
		good.merged({"id": 4, "item": "test_unknown"}, true),  # unknown item
		good.merged({"id": 6, "qty": 0}, true),
		good.merged({"id": 7, "sold": -1}, true),
		good.merged({"id": 8, "earned": -5}, true),
		good.merged({"id": 9, "price": 0}, true),
		good.merged({"id": 10, "start": -1}, true),
		good.merged({"id": 11, "end": 10}, true),
		good.merged({"id": 12, "duration": "forever"}, true),
		"junk"]
	_house.from_save({"seed": SEED, "block": 20, "pending_ms": 0, "items": {}, "listings": rows, "next_listing": 2})
	var kept: Array[Dictionary] = _house.my_listings()
	assert_eq(kept.size(), 2, "the good one and the one with the unknown duration")
	assert_eq(kept[0]["id"], 3)
	assert_eq(kept[1]["id"], 12)
	assert_eq(kept[1]["duration"], &"short", "the first duration of the data")
	assert_eq(_house.to_save()["next_listing"], 13, "next_listing above the highest id")


func test_old_save_without_listings() -> void:
	_house.from_save({"seed": SEED, "block": 5, "pending_ms": 100, "items": {}})
	assert_eq(_house.my_listings().size(), 0)
	assert_eq(_house.to_save()["next_listing"], 1)
	_house.new_game()
	assert_eq(_house.my_listings().size(), 0)
