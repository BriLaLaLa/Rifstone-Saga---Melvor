extends GutTest
## AuctionBook and the NPC book of AuctionPricing (docs/02_FORMULAS_M27.md F-178, F-179, F-181, F-182): hash vectors, the listings of
## the examples, demand, deposit, commission and the no-risk-free-gain constraint. Seed 12345, every item at rest unless said.

const AuctionTestData := preload("res://tests/systems/auction/auction_test_data.gd")
const SEED: int = 12345
const GRIP: StringName = &"redbirch_grip"
const PLATE: StringName = &"riftite_plate"
const BLOCK_MS: int = 300000

var _data: GameData
var _p: AuctionParams


func before_all() -> void:
	_data = TestFactory.real_data()
	_p = _data.auction_params()


func _pricing_at(block: int) -> AuctionPricing:
	var pricing := AuctionPricing.new(_data)
	pricing.reset(SEED)
	pricing.advance(block * BLOCK_MS)
	return pricing


func _asks(block: int, item_id: StringName) -> Array[Vector2i]:
	return _pricing_at(block).npc_asks(item_id)


func _volume(asks: Array[Vector2i]) -> int:
	var v: int = 0
	for ask: Vector2i in asks:
		v += ask.y
	return v


func test_hash_vectors() -> void:
	assert_eq(AuctionMath.hash32("redbirch_grip|ask|12345|0|0"), 2300331800)
	assert_eq(AuctionMath.hash32("redbirch_grip|qty|12345|0|0"), 1891832868)
	assert_eq(AuctionBook.ask_offset(GRIP, SEED, 0, 0, _p), 72599)
	assert_eq(AuctionBook.ask_qty(GRIP, SEED, 0, 0, 200), 69)


func test_parameters_are_converted() -> void:
	assert_eq(_p.book_persist, 6)
	assert_eq(_p.book_hi_ppm, 250000)
	assert_eq(_p.book_fill_ppm, 500000)
	assert_eq(_p.book_fill_max_ppm, 900000)
	assert_eq(_p.listing_cut_ppm, 50000)
	assert_eq(_p.listing_max_price_ppm, 10000000)
	assert_eq(_p.durations.size(), 3)
	assert_eq([_p.durations[0].blocks, _p.durations[1].blocks, _p.durations[2].blocks], [144, 288, 576])
	assert_eq(_p.durations[0].deposit_ppm, 10000)
	assert_eq(AuctionMath.band_of(200, _p).stack, 200)
	assert_eq(AuctionMath.band_of(59500, _p).stack, 5)


func test_listing_count_is_clamped() -> void:
	assert_eq(AuctionBook.listing_count(125, _p), 12)
	assert_eq(AuctionBook.listing_count(118, _p), 11)
	assert_eq(AuctionBook.listing_count(88, _p), 8)
	assert_eq(AuctionBook.listing_count(5, _p), 4)
	assert_eq(AuctionBook.listing_count(1000, _p), 12)


func test_redbirch_grip_block_0() -> void:
	var pricing: AuctionPricing = _pricing_at(0)
	var asks: Array[Vector2i] = pricing.npc_asks(GRIP)
	var expected: Array[Vector2i] = [Vector2i(241, 69), Vector2i(247, 169), Vector2i(250, 53), Vector2i(252, 79), Vector2i(257, 69),
			Vector2i(257, 154), Vector2i(264, 154), Vector2i(273, 18), Vector2i(279, 113), Vector2i(282, 69), Vector2i(291, 176), Vector2i(297, 70)]
	assert_eq(asks, expected)
	assert_eq(_volume(asks), 1193)
	assert_eq(pricing.sell_quote(GRIP, 1), 240, "market price")
	assert_eq(pricing.demand(GRIP), 486)


func test_redbirch_grip_epochs_and_blocks() -> void:
	assert_eq(_asks(5, GRIP)[0], Vector2i(239, 69), "same epoch: the same mark-ups, a new index")
	var epoch_1: Array[Vector2i] = _asks(6, GRIP)
	assert_eq(_volume(epoch_1), 950)
	assert_eq(epoch_1[0], Vector2i(258, 69))
	var far: Array[Vector2i] = _asks(36, GRIP)
	assert_eq(far.size(), 11)
	assert_eq(_volume(far), 1245)
	assert_eq(far[0], Vector2i(240, 194))
	assert_eq(_pricing_at(1).demand(GRIP), 491)
	assert_eq(_pricing_at(36).demand(GRIP), 717)


func test_riftite_plate_block_0() -> void:
	var pricing: AuctionPricing = _pricing_at(0)
	var asks: Array[Vector2i] = pricing.npc_asks(PLATE)
	var expected: Array[Vector2i] = [Vector2i(72640, 4), Vector2i(73168, 4), Vector2i(74627, 4), Vector2i(79671, 3), Vector2i(80070, 3),
			Vector2i(81958, 5), Vector2i(86514, 2), Vector2i(87939, 2)]
	assert_eq(asks, expected)
	assert_eq(_volume(asks), 27)
	assert_eq(pricing.sell_quote(PLATE, 1), 71151)
	assert_eq(pricing.demand(PLATE), 16)


func test_the_book_is_a_function_of_the_market() -> void:
	assert_eq(_asks(10, GRIP), _asks(10, GRIP), "same seed, item, block, saturation: same book")
	var calm: AuctionPricing = _pricing_at(0)
	var busy: AuctionPricing = _pricing_at(0)
	busy.record_sale(GRIP, 500)
	assert_lt(busy.npc_asks(GRIP)[0].x, calm.npc_asks(GRIP)[0].x, "saturation lowers the asks")
	assert_eq(calm.npc_asks(&"test_unknown"), [] as Array[Vector2i])
	assert_eq(calm.demand(&"test_unknown"), 0)


func test_demand_and_fill() -> void:
	assert_eq(AuctionBook.demand(1193, 102, 125, _p), 486)
	assert_eq(AuctionBook.demand(1193, 103, 125, _p), 491)
	assert_eq(AuctionBook.demand(1245, 136, 118, _p), 717)
	assert_eq(AuctionBook.demand(27, 107, 88, _p), 16)
	assert_lt(AuctionBook.demand(1000, 500, 10, _p), 1000, "the cap keeps D below V")
	assert_eq(AuctionBook.fill(486, 69, 100), 100)
	assert_eq(AuctionBook.fill(486, 391, 600), 95, "D - ahead below the remainder")
	assert_eq(AuctionBook.fill(491, 391, 600), 100, "L2 of F-179: ahead 69 + 169 + 53 + 100 = 391")
	assert_eq(AuctionBook.fill(491, 69, 100), 100, "L1 of F-179")
	assert_eq(AuctionBook.fill(486, 747, 600), 0)
	assert_eq(AuctionBook.fill(491, 291, 600), 200)


func test_deposit_and_cut() -> void:
	assert_eq(AuctionBook.deposit(200, 600, 10000), 1200)
	assert_eq(AuctionBook.deposit(59500, 10, 40000), 23800)
	assert_eq(AuctionBook.deposit(100, 1, 10000), 1, "the minimum")
	assert_eq(AuctionBook.cut(50000, _p), 2500)
	assert_eq(AuctionBook.cut(1, _p), 1, "rounded up")
	assert_eq(AuctionBook.max_price(200, _p), 2000)
	assert_eq(AuctionBook.max_price(0, _p), 1)


func test_suggested_and_max_price() -> void:
	var pricing: AuctionPricing = _pricing_at(0)
	assert_eq(pricing.max_price(GRIP), 2000)
	var s: GameSession = AuctionTestData.session(8)
	add_child_autofree(s)
	s.auction.from_save({"seed": SEED, "block": 0, "pending_ms": 0, "items": {}})
	assert_eq(s.auction.suggested_price(GRIP), 240)
	assert_eq(s.auction.suggested_price(PLATE), 72639)
	assert_eq(s.auction.suggested_price(&"test_unknown"), 0)
	assert_eq(s.auction.market_price(PLATE), 71151)


func test_no_risk_free_gain_constraint() -> void:
	var worst: int = AuctionBook.ask_price(59500, _p.max_ppm, _p.book_hi_ppm)
	assert_eq(worst, 93712, "the highest sale of riftite_plate")
	assert_eq(AuctionMath.buy_unit(59500, _p.min_ppm, _p), 130900, "the cheapest counter price")
	assert_eq(AuctionBook.ask_price(200, _p.max_ppm, _p.book_hi_ppm), 315)
	assert_eq(AuctionMath.buy_unit(200, _p.min_ppm, _p), 440)
	assert_gt((_p.min_ppm + _p.spread_ppm) * AuctionMath.PPM, _p.max_ppm * (AuctionMath.PPM + _p.book_hi_ppm))
