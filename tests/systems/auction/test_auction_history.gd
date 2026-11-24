extends GutTest
## AuctionHistory and its writers in AuctionHouse (docs/02_FORMULAS_M37.md F-209, F-212; docs/04_DATA_SCHEMA_M37.md §38.2): merge by listing,
## order, cap, the three writers, offline equivalence, the tolerant save.

const AuctionTestData := preload("res://tests/systems/auction/auction_test_data.gd")
const GRIP: StringName = &"redbirch_grip"
const LOG: StringName = &"redbirch_log"
const PLATE: StringName = &"riftite_plate"
const BLOCK_MS: int = 300000
const SEED: int = 12345

var _s: GameSession
var _data: GameData
var _h: AuctionHistory


func before_each() -> void:
	_s = _session()
	_data = _s.data
	_h = _history(50)


func _session() -> GameSession:
	var s: GameSession = AuctionTestData.session(8)
	add_child_autofree(s)
	s.auction.from_save({"seed": SEED, "block": 0, "pending_ms": 0, "items": {}})
	return s


func _history(max_entries: int) -> AuctionHistory:
	var p: AuctionParams = AuctionParams.new()
	p.history_max = max_entries
	return AuctionHistory.new(p, _data)


func _row(kind: String, qty: Variant = 1, extra: Dictionary = {}) -> Dictionary:
	var row: Dictionary = {"k": kind, "item": String(GRIP), "qty": qty, "unit": 5, "net": 4, "block": 1, "listing": 1}
	row.merge(extra, true)
	return row


# --- F-209 ---------------------------------------------------------------------------------------------------

func test_a_sale_of_the_listing_merges_into_one_entry() -> void:
	_h.record_listing_sold(GRIP, 4, 300, 1140, 100, 7)
	assert_eq(_h.entries(), [{"kind": &"listing_sold", "item": GRIP, "qty": 4, "unit": 300, "net": 1140, "block": 100, "listing": 7}])
	_h.record_listing_sold(GRIP, 2, 300, 570, 101, 7)
	assert_eq(_h.count(), 1)
	assert_eq(_h.entries()[0], {"kind": &"listing_sold", "item": GRIP, "qty": 6, "unit": 300, "net": 1710, "block": 101, "listing": 7})


func test_two_listings_give_two_entries_with_the_merged_one_moved_up() -> void:
	_h.record_listing_sold(GRIP, 6, 300, 1710, 101, 7)
	_h.record_listing_sold(GRIP, 1, 300, 285, 102, 7)
	_h.record_listing_sold(GRIP, 1, 50, 47, 102, 8)
	assert_eq(_h.count(), 2)
	assert_eq(_h.entries()[0]["listing"], 8)
	assert_eq(_h.entries()[1]["qty"], 7)
	_h.record_listing_sold(GRIP, 1, 300, 285, 103, 7)  # alternation of blocks: still two entries
	assert_eq(_h.count(), 2)
	assert_eq(_h.entries()[0]["listing"], 7)
	assert_eq(_h.entries()[0]["qty"], 8)


func test_instant_sale_unit_is_floor_and_never_merges() -> void:
	_h.record_instant_sold(GRIP, 5, 1500, 4)
	_h.record_instant_sold(GRIP, 3, 1000, 4)
	assert_eq(_h.count(), 2)
	assert_eq(_h.entries()[1], {"kind": &"instant_sold", "item": GRIP, "qty": 5, "unit": 300, "net": 1500, "block": 4, "listing": 0})
	assert_eq(_h.entries()[0]["unit"], 333, "floor(1000 / 3)")


func test_expired_and_cancelled_carry_the_listing_price_and_no_money() -> void:
	_h.record_closed(&"expired", GRIP, 6, 300, 9, 3)
	_h.record_closed(&"cancelled", GRIP, 2, 300, 10, 4)
	assert_eq(_h.entries()[1], {"kind": &"expired", "item": GRIP, "qty": 6, "unit": 300, "net": 0, "block": 9, "listing": 3})
	assert_eq(_h.entries()[0]["kind"], &"cancelled")


func test_the_cap_drops_the_oldest() -> void:
	var small: AuctionHistory = _history(3)
	for i: int in 5:
		small.record_instant_sold(GRIP, 1, 10 + i, i)
	assert_eq(small.count(), 3)
	assert_eq([small.entries()[0]["block"], small.entries()[2]["block"]], [4, 2], "newest first, the two oldest are gone")


func test_cap_of_fifty() -> void:
	for i: int in 51:
		_h.record_instant_sold(GRIP, 1, 1, i)
	assert_eq(_h.count(), 50)
	assert_eq(_h.entries()[0]["block"], 50)
	assert_eq(_h.entries()[49]["block"], 1)


func test_entries_are_copies() -> void:
	_h.record_instant_sold(GRIP, 1, 1, 0)
	var copy: Array[Dictionary] = _h.entries()
	copy[0]["qty"] = 99
	assert_eq(_h.entries()[0]["qty"], 1)


# --- F-212 ---------------------------------------------------------------------------------------------------

func test_age() -> void:
	assert_eq(AuctionHistory.age_ms(100, 100, 120000, 600000), 120000)
	assert_eq(AuctionHistory.age_ms(100, 103, 120000, 600000), 1920000)
	assert_eq(AuctionHistory.age_ms(100, 99, 120000, 600000), 0)


func test_house_age_uses_block_and_pending() -> void:
	_s.auction.advance(3 * BLOCK_MS + 1000)
	assert_eq(_s.auction.history_age_ms({"block": 1}), 2 * BLOCK_MS + 1000)


# --- the writers in AuctionHouse -------------------------------------------------------------------------------

func _list(qty: int, price: int, duration: StringName = &"short", item: StringName = GRIP, s: GameSession = _s) -> void:
	TestFactory.give(s, item, qty)
	s.wallet.add_gold(1000000)
	assert_true(s.auction.list_item(item, qty, price, duration).ok)


func test_vendi_subito_writes_an_instant_entry() -> void:
	TestFactory.give(_s, LOG, 10)
	var gold: int = _s.auction.sell_quote(LOG, 10)
	assert_true(_s.auction.sell(LOG, 10).ok)
	var e: Dictionary = _s.auction.history()[0]
	assert_eq([e["kind"], e["item"], e["qty"], e["net"], e["unit"], e["listing"]], [&"instant_sold", LOG, 10, gold, gold / 10, 0])


func test_a_failed_sell_writes_nothing() -> void:
	assert_false(_s.auction.sell(LOG, 10).ok)
	assert_eq(_s.auction.history(), [])


func test_cancel_writes_a_cancelled_entry_and_expiry_an_expired_one() -> void:
	var far: int = _s.auction.max_price(GRIP)
	_list(5, far)  # far above the market: never sells
	_s.auction.advance(2 * BLOCK_MS)
	assert_true(_s.auction.cancel_listing(1).ok)
	var e: Dictionary = _s.auction.history()[0]
	assert_eq([e["kind"], e["qty"], e["unit"], e["net"], e["block"], e["listing"]], [&"cancelled", 5, far, 0, 2, 1])
	_list(3, far)
	_s.auction.advance(1000 * BLOCK_MS)  # the short duration ends
	e = _s.auction.history()[0]
	assert_eq([e["kind"], e["qty"], e["unit"], e["net"]], [&"expired", 3, far, 0])


func test_closed_writes_nothing_so_a_sold_out_listing_leaves_only_sales() -> void:
	_list(3, 1)  # at 1 copper it sells out at once
	_s.auction.advance(5 * BLOCK_MS)
	assert_eq(_s.auction.my_listings().size(), 0)
	var sold: int = 0
	for e: Dictionary in _s.auction.history():
		assert_eq(e["kind"], &"listing_sold")
		sold += int(e["qty"])
	assert_eq(sold, 3)


func _scenario(s: GameSession) -> void:
	_list(600, 250, &"short", GRIP, s)
	_list(4000, 5, &"medium", LOG, s)
	_list(8, s.auction.max_price(PLATE), &"short", PLATE, s)


func test_offline_blocks_make_the_same_entries_as_online_ticks() -> void:
	var offline: GameSession = _session()
	var online: GameSession = _session()
	var thirds: GameSession = _session()
	_scenario(offline)
	_scenario(online)
	_scenario(thirds)
	offline.auction.advance(300 * BLOCK_MS + 17)
	for i: int in 300:
		online.auction.advance(BLOCK_MS)
	online.auction.advance(17)
	for i: int in 900:
		thirds.auction.advance(BLOCK_MS / 3)
	thirds.auction.advance(300 * BLOCK_MS + 17 - 900 * (BLOCK_MS / 3))
	assert_gte(offline.auction.history().size(), 3, "sales and an expiry happened")
	assert_eq(online.auction.history(), offline.auction.history())
	assert_eq(thirds.auction.history(), offline.auction.history())
	assert_eq(thirds.auction.to_save(), offline.auction.to_save())


# --- save -------------------------------------------------------------------------------------------------------

func test_round_trip() -> void:
	_h.record_listing_sold(GRIP, 4, 300, 1140, 100, 7)
	_h.record_instant_sold(LOG, 5, 1500, 101)
	_h.record_closed(&"expired", GRIP, 2, 300, 102, 7)
	var saved: Array = _h.to_save()
	assert_eq(saved[0]["k"], "expired")
	var other: AuctionHistory = _history(50)
	other.from_save(JSON.parse_string(JSON.stringify(saved)))  # through JSON: integral floats
	assert_eq(other.entries(), _h.entries())


func test_a_missing_key_is_empty_and_new_game_clears() -> void:
	_s.auction.from_save({"seed": SEED})
	assert_eq(_s.auction.history(), [])
	TestFactory.give(_s, LOG, 3)
	_s.auction.sell(LOG, 3)
	assert_eq(_s.auction.history().size(), 1)
	_s.auction.new_game()
	assert_eq(_s.auction.history(), [])


func test_the_save_of_the_house_has_the_history_and_loads_it() -> void:
	TestFactory.give(_s, LOG, 3)
	_s.auction.sell(LOG, 3)
	var d: Dictionary = _s.auction.to_save()
	assert_eq((d["history"] as Array).size(), 1)
	var other: GameSession = _session()
	other.auction.from_save(JSON.parse_string(JSON.stringify(d)))
	assert_eq(other.auction.history(), _s.auction.history())


func test_tolerant_load_drops_the_bad_entries() -> void:
	_h.from_save([_row("listing_sold"), _row("bogus"), _row("expired", 1, {"item": "no_such_item"}), _row("cancelled", 0),
			_row("expired", 2.0), _row("expired", 1, {"unit": -1}), _row("expired", 1, {"net": "x"}), 5,
			_row("instant_sold", 1, {"block": 3.5}), _row("cancelled", 3, {"listing": 0})])
	assert_eq(_h.count(), 3)
	assert_eq([_h.entries()[0]["kind"], _h.entries()[1]["qty"], _h.entries()[2]["qty"]], [&"listing_sold", 2, 3])
	assert_typeof(_h.entries()[1]["qty"], TYPE_INT)


func test_a_longer_list_is_cut_to_the_max() -> void:
	var small: AuctionHistory = _history(2)
	small.from_save([_row("expired", 1), _row("expired", 2), _row("expired", 3)])
	assert_eq(small.count(), 2)
	assert_eq(small.entries()[0]["qty"], 1, "the newest are kept")


func test_not_a_list_is_empty() -> void:
	_h.record_instant_sold(GRIP, 1, 1, 0)
	_h.from_save("x")
	assert_eq(_h.count(), 0)
	_h.from_save(null)
	assert_eq(_h.count(), 0)
