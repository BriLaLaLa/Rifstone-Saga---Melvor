extends GutTest
## Buying from the book (docs/02_FORMULAS_M38.md F-215, F-216): every example of the formulas, the book in order, `taken`, the
## restock, the floor EQMIN, `max_qty` and the additivity of the clock.

const AuctionTestData := preload("res://tests/systems/auction/auction_test_data.gd")
const SEED: int = 12345
const GRIP: StringName = &"redbirch_grip"  # v 200, band 1, STEP_i 200, r_i 17
const PLATE: StringName = &"riftite_plate"  # v 59.500, band 4, STEP_i 277, r_i 1
const LOG: StringName = &"redbirch_log"
const BLOCK_MS: int = 300000

var _data: GameData
var _p: AuctionParams


func before_all() -> void:
	_data = TestFactory.real_data()
	_p = _data.auction_params()


func _pricing() -> AuctionPricing:
	var pricing := AuctionPricing.new(_data)
	pricing.reset(SEED)
	return pricing


func _book(pricing: AuctionPricing, id: StringName) -> Array:
	var rows: Array = []
	for row: Dictionary in pricing.buy_book(id):
		rows.append([row["buy_price"], row["qty"]])
	return rows


# --- F-215: the book ---------------------------------------------------------------------------------------------

func test_the_grip_book_in_order() -> void:
	var pricing: AuctionPricing = _pricing()
	var rows: Array[Dictionary] = pricing.buy_book(GRIP)
	assert_eq(rows.size(), 12)
	assert_eq(pricing.volume(GRIP), 1193)
	var prices: Array = []
	var js: Array = []
	for row: Dictionary in rows:
		prices.append(row["buy_price"])
		js.append(row["j"])
	assert_eq(prices, [350, 359, 363, 366, 373, 373, 383, 396, 405, 409, 422, 431])
	assert_eq(js, [11, 5, 6, 1, 0, 3, 8, 10, 4, 9, 7, 2], "j0 and j3 have the same ask and price (373): F-178 order by j; the doc lists 3 before 0, with no effect on any cost")
	assert_eq([rows[0]["qty"], rows[1]["qty"], rows[2]["qty"], rows[3]["qty"]], [69, 169, 53, 79])
	assert_eq(rows[0]["price"], 241, "the F-178 ask next to the buy price")
	assert_eq(rows[0]["left"], 69)


func test_cost_of_the_grip_by_quantity_at_rest() -> void:
	var pricing: AuctionPricing = _pricing()
	assert_eq(pricing.buy_unit(GRIP), 350)
	assert_eq(pricing.buy_quote(GRIP, 1), 350)
	assert_eq(pricing.buy_quote(GRIP, 100), 35279, "69 * 350 + 31 * 359")
	assert_eq(pricing.buy_quote(GRIP, 300), 107354)
	assert_eq(pricing.buy_quote(GRIP, 600), 218834)
	assert_eq(pricing.buy_quote(GRIP, 1000), 378615)
	assert_eq(pricing.buy_quote(GRIP, 1193), 460691, "the whole book")
	assert_eq(pricing.buy_quote(GRIP, 1194), 0, "more than the book")
	assert_eq(pricing.buy_quote(GRIP, 0), 0)
	assert_eq(pricing.buy_quote(GRIP, -3), 0)


func test_scarcity_after_400_and_1000_pieces_taken() -> void:
	var pricing: AuctionPricing = _pricing()
	pricing.record_purchase(GRIP, 400)
	assert_eq(pricing.available(GRIP), 793)
	assert_eq(pricing.buy_quote(GRIP, 100), 39800, "100 * ceil(274 * 1,45)")
	pricing.record_purchase(GRIP, 600)
	assert_eq(pricing.taken(GRIP), 1000)
	assert_eq(pricing.available(GRIP), 193)
	assert_eq(pricing.buy_unit(GRIP), 493)
	assert_eq(pricing.buy_quote(GRIP, 1), 493)
	assert_eq(pricing.buy_quote(GRIP, 193), 95919)
	assert_eq(pricing.buy_quote(GRIP, 194), 0)


func test_the_plate_book_and_costs() -> void:
	var pricing: AuctionPricing = _pricing()
	assert_eq(pricing.volume(PLATE), 27)
	assert_eq(_book(pricing, PLATE), [[105328, 4], [106094, 4], [108210, 4], [115523, 3], [116102, 3], [118840, 5], [125446, 2], [127512, 2]])
	assert_eq(pricing.buy_quote(PLATE, 1), 105328)
	assert_eq(pricing.buy_quote(PLATE, 10), 1062108)
	assert_eq(pricing.buy_quote(PLATE, 27), 3073519)
	pricing.record_purchase(PLATE, 10)
	assert_eq(pricing.buy_quote(PLATE, 5), 564290, "taken 10: scar 2.770")


func test_the_floor_eqmin_with_a_saturated_item() -> void:
	var pricing: AuctionPricing = _pricing()
	pricing.record_sale(GRIP, 2800)  # sat 560.000 (the cap): index 700.000, the floor is EQMIN 1.050.000
	assert_eq(pricing.buy_unit(GRIP), 305, "ceil(floor(200 * 1,05 * 1,004039) * 1,45) = ceil(210 * 1,45)")


func test_the_purchase_does_not_move_the_ask_or_the_sale_side() -> void:
	var pricing: AuctionPricing = _pricing()
	var asks: Array[Vector2i] = pricing.npc_asks(GRIP)
	var sell: int = pricing.sell_quote(GRIP, 10)
	var demand: int = pricing.demand(GRIP)
	pricing.record_purchase(GRIP, 1000)
	assert_eq(pricing.npc_asks(GRIP), asks, "F-178 does not see taken")
	assert_eq(pricing.sell_quote(GRIP, 10), sell)
	assert_eq(pricing.demand(GRIP), demand, "F-179 does not see taken")


func test_the_whole_book_taken_leaves_nothing_to_buy() -> void:
	var pricing: AuctionPricing = _pricing()
	pricing.record_purchase(GRIP, 1193)
	assert_eq(pricing.available(GRIP), 0)
	assert_eq(pricing.buy_unit(GRIP), 0)
	assert_eq(pricing.buy_quote(GRIP, 1), 0)
	assert_eq(AuctionBuy.available(950, 1000), 0, "V falls under taken: nothing to buy, taken stays")
	assert_eq(AuctionBuy.restock_blocks(950, 1000, 17), 3, "ceil(51 / 17): 15 minutes")
	assert_eq(AuctionBuy.restock_blocks(1193, 1193, 17), 1, "5 minutes")
	assert_eq(AuctionBuy.restock_blocks(1193, 1000, 17), 0, "a piece is available")


# --- F-216: taken, recovery, sold out ------------------------------------------------------------------------------

func test_recovery_examples() -> void:
	var pricing: AuctionPricing = _pricing()
	pricing.record_purchase(GRIP, 1000)
	pricing.advance(30 * BLOCK_MS)
	assert_eq(pricing.taken(GRIP), 490)
	pricing.advance(29 * BLOCK_MS)
	assert_eq(pricing.taken(GRIP), 0, "59 blocks in all")
	pricing.record_purchase(PLATE, 3)
	pricing.advance(2 * BLOCK_MS)
	assert_eq(pricing.taken(PLATE), 1)


func test_sold_out_and_restock_blocks() -> void:
	var pricing: AuctionPricing = _pricing()
	assert_eq(pricing.restock_blocks(GRIP), 0)
	pricing.record_purchase(GRIP, 1193)
	assert_eq([pricing.available(GRIP), pricing.restock_blocks(GRIP)], [0, 1], "N = 5 * ceil(1 / 17) = 5 min")
	var plate: AuctionPricing = _pricing()
	plate.record_purchase(PLATE, 27)
	assert_eq([plate.available(PLATE), plate.restock_blocks(PLATE)], [0, 1])
	plate.advance(5 * BLOCK_MS)  # still the same epoch (6 blocks)
	assert_eq(plate.taken(PLATE), 22)
	assert_eq(plate.available(PLATE), 5, "r_i = 1 a block; the book is the one of the first epoch")


func test_taken_never_exceeds_kmax_times_stack() -> void:
	var pricing: AuctionPricing = _pricing()
	pricing.record_purchase(PLATE, 1000)
	assert_eq(pricing.taken(PLATE), 60)
	pricing.record_purchase(LOG, 5)
	assert_eq(pricing.taken(LOG), 0, "not buyable")


func test_the_listings_of_the_player_do_not_count_and_cannot_be_bought() -> void:
	var s: GameSession = AuctionTestData.session(8)
	add_child_autofree(s)
	var before: Array[Dictionary] = s.auction.buy_book(GRIP)
	var volume: int = s.auction.available(GRIP)
	TestFactory.give(s, GRIP, 50)
	s.wallet.add_gold(1000000)
	assert_true(s.auction.list_item(GRIP, 50, 1, &"short").ok)
	assert_eq(s.auction.buy_book(GRIP), before, "the book to buy ignores the player's listing")
	assert_eq(s.auction.available(GRIP), volume)


func test_the_taken_does_not_change_the_player_listings() -> void:
	# F-216: `taken` does not touch `ahead`, `D` nor the book of F-178/F-179: the sale of a listing is the same with taken 0 and 1.000.
	var results: Array = []
	for taken_n: int in [0, 1000]:
		var s: GameSession = AuctionTestData.session(8)
		add_child_autofree(s)
		TestFactory.give(s, GRIP, 300)
		s.wallet.add_gold(100000000)
		assert_true(s.auction.list_item(GRIP, 300, 300, &"short").ok)
		if taken_n > 0:
			assert_true(s.auction.buy(GRIP, taken_n).ok)
		s.auction.advance(6 * 3600000)
		results.append([s.auction.my_listings(), s.auction.history().size(), s.mail.count()])
	assert_eq(results[0][0], results[1][0], "the same listings left")
	assert_eq(results[0][1], results[1][1], "the same history")
	assert_eq(results[0][2], results[1][2], "the same mail")


# --- pure helpers --------------------------------------------------------------------------------------------------

func test_cost_and_max_qty_walk_the_book() -> void:
	var book: Array[Vector2i] = [Vector2i(350, 69), Vector2i(359, 169)]
	assert_eq(AuctionBuy.cost(book, 0, 70), 69 * 350 + 359)
	assert_eq(AuctionBuy.cost(book, 60, 20), 9 * 350 + 11 * 359, "positions 60-79")
	assert_eq(AuctionBuy.cost(book, 69, 1), 359)
	assert_eq(AuctionBuy.cost(book, 0, 239), 0, "more than V - taken")
	assert_eq(AuctionBuy.max_qty(book, 0, 10000), 28)
	assert_eq(AuctionBuy.max_qty(book, 0, 36000), 102, "69 * 350 + 33 * 359 = 35.997")
	assert_eq(AuctionBuy.max_qty(book, 0, 349), 0)
	assert_eq(AuctionBuy.max_qty(book, 238, 100000), 0, "nothing left")
	assert_eq(AuctionBuy.max_qty(book, 0, 100000000), 238, "huge gold: everything")
	assert_eq(AuctionBuy.left_of(book, 100) as Array, [0, 138])
	assert_eq(AuctionBuy.best_unit(book, 69), 359)
	assert_eq(AuctionBuy.best_unit(book, 238), 0)


func test_max_qty_examples_on_the_real_book() -> void:
	var pieces: Array[Vector2i] = _pricing().buy_pieces(GRIP)
	assert_eq(AuctionBuy.max_qty(pieces, 0, 10000), 28)
	assert_eq(AuctionBuy.max_qty(pieces, 0, 36000), 102)
	assert_eq(AuctionBuy.max_qty(pieces, 1193, 100000000), 0)


func test_scarce_index() -> void:
	assert_eq(AuctionBuy.scarce_index(1201052, 0, 200, 1050000), 1201052)
	assert_eq(AuctionBuy.scarce_index(1201052, 400, 200, 1050000), 1281052)
	assert_eq(AuctionBuy.scarce_index(700000, 0, 200, 1050000), 1050000, "the floor")


# --- F-216: additivity of the clock --------------------------------------------------------------------------------

func test_advance_is_additive_with_taken_in_every_band() -> void:
	var ids: Array[StringName] = [GRIP, &"shardcedar_grip", &"seared_riftmaw", PLATE]
	for step: Array in [[1, 1], [7, 90], [63, 61], [100, 130], [1, 143]]:
		var split: AuctionPricing = _pricing()
		var whole: AuctionPricing = _pricing()
		for id: StringName in ids:
			split.record_purchase(id, 100)
			whole.record_purchase(id, 100)
		split.advance(int(step[0]) * BLOCK_MS)
		split.advance(int(step[1]) * BLOCK_MS)
		whole.advance((int(step[0]) + int(step[1])) * BLOCK_MS)
		assert_eq(split.to_save(), whole.to_save(), str(step))


func test_12_hours_empty_every_taken() -> void:
	var pricing: AuctionPricing = _pricing()
	for id: StringName in [GRIP, &"shardcedar_grip", &"seared_riftmaw", PLATE]:
		pricing.record_purchase(id, 100000)  # capped at KMAX * stack
	pricing.advance(144 * BLOCK_MS)
	assert_eq(pricing.to_save()["taken"], {})
