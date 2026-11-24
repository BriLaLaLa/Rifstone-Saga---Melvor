extends GutTest
## M38: F-210/F-211 (modified), F-218 and the commands on the book (docs/02_FORMULAS_M38.md), on AuctionHouse and AuctionView.
## The market of the examples: seed 12345, block 0 (`from_save` of the house).

const AuctionTestData := preload("res://tests/systems/auction/auction_test_data.gd")
const GRIP: StringName = &"redbirch_grip"
const LOG: StringName = &"redbirch_log"
const PLATE: StringName = &"riftite_plate"
const NO_GAP: int = AuctionHouse.NO_GAP
const BLOCK_MS: int = 300000

var _s: GameSession
var _house: AuctionHouse


func before_each() -> void:
	_s = AuctionTestData.session(8)
	add_child_autofree(_s)
	_house = _s.auction
	_market({})


# The market of the examples (seed 12345, block 0), with `taken` and the saturation as asked.
func _market(taken: Dictionary, items: Dictionary = {}) -> void:
	_house.from_save({"seed": 12345, "block": 0, "pending_ms": 0, "items": items, "taken": taken})


func _set_gold(amount: int) -> void:
	_s.wallet.spend(_s.wallet.get_gold())
	_s.wallet.add_gold(amount)


# --- F-210 -----------------------------------------------------------------------------------------------------

func test_gap_of_the_buy_price_against_the_reference() -> void:
	assert_eq([_house.buy_unit(GRIP), _house.reference_price(GRIP, &"buy")], [350, 350])
	assert_eq(_house.price_gap(GRIP, &"buy"), 0, "was +171 against the base value")
	_market({"redbirch_grip": 1000})
	assert_eq(_house.buy_unit(GRIP), 493)
	assert_eq(_house.price_gap(GRIP, &"buy"), 41)


func test_gap_of_the_sale_against_the_reference() -> void:
	_market({}, {"redbirch_grip": {"sat": 56000}})
	assert_eq(_house.sell_quote(GRIP, 1), 229)
	assert_eq(_house.reference_price(GRIP, &"sell"), 240)
	assert_eq(_house.price_gap(GRIP, &"sell"), -5)


func test_gap_not_available() -> void:
	assert_eq(_house.price_gap(&"no_such_item", &"buy"), NO_GAP)
	assert_eq(_house.price_gap(LOG, &"buy"), NO_GAP, "a material cannot be bought")
	assert_gt(_house.reference_price(LOG, &"sell"), 0)
	assert_eq(_house.reference_price(LOG, &"buy"), 0)
	assert_eq(_house.reference_price(&"no_such_item", &"sell"), 0)
	_market({"redbirch_grip": 1193})
	assert_eq(_house.price_gap(GRIP, &"buy"), NO_GAP, "sold out: no unit")


# --- F-211 -----------------------------------------------------------------------------------------------------

func test_max_buyable_examples() -> void:
	_set_gold(10000)
	assert_eq(_house.max_buyable(GRIP), 28, "28 * 350 = 9.800")
	_set_gold(36000)
	assert_eq(_house.max_buyable(GRIP), 102, "69 * 350 + 33 * 359 = 35.997")
	_set_gold(349)
	assert_eq(_house.max_buyable(GRIP), 0)
	_set_gold(1000000000)
	assert_eq(_house.max_buyable(GRIP), 1193, "huge gold: the pieces available")
	_market({"redbirch_grip": 1193})
	assert_eq(_house.max_buyable(GRIP), 0, "sold out")
	assert_eq(_house.max_buyable(LOG), 0, "not buyable")
	assert_eq(_house.max_buyable(&"no_such_item"), 0)


func test_max_buyable_with_a_full_deposit_is_zero() -> void:
	_set_gold(1000000000)
	var kept: StringName = &"emberbronze_plate"
	assert_gt(_house.max_buyable(kept), 0)
	for def: ItemDef in _s.data.items():
		if _s.bank.free_boxes() <= 0:
			break
		if def.id != kept and def.category != &"equipment" and def.category != &"tool" and def.category != &"map":
			_s.bank.add(def.id, 1)
	assert_eq(_s.bank.free_boxes(), 0)
	assert_eq(_house.max_buyable(kept), 0)


# --- F-218 -----------------------------------------------------------------------------------------------------

func test_buy_preview_examples() -> void:
	var p100: Dictionary = _house.buy_preview(GRIP, 100)
	assert_eq([p100["total"], p100["avg"], p100["best"], p100["large"]], [35279, 353, 350, false])
	assert_eq(p100["share_ppm"], 83822, "8 % of 1.193")
	assert_false(_house.buy_preview(GRIP, 596)["large"], "49,96 %")
	assert_true(_house.buy_preview(GRIP, 597)["large"], "50,04 %")
	assert_true(_house.buy_preview(GRIP, 1000)["large"])
	var all: Dictionary = _house.buy_preview(GRIP, 1193)
	assert_eq([all["total"], all["avg"], all["large"]], [460691, 386, true])
	assert_eq(all["share_ppm"], 1000000)
	assert_eq(all["premium_ppm"], 103319, "+10 % over the best (386,17 / 350)")


func test_buy_preview_with_taken_and_on_the_plate() -> void:
	_market({"redbirch_grip": 1000})
	var big: Dictionary = _house.buy_preview(GRIP, 100)
	assert_true(big["large"], "51,8 % of the 193 that are left")
	assert_eq(big["best"], 493)
	_market({})
	assert_true(_house.buy_preview(PLATE, 14)["large"], "14 of 27")
	assert_false(_house.buy_preview(PLATE, 1)["large"])
	assert_false(_house.buy_preview(PLATE, 13)["large"], "48 %: not the share; the average does not go +25 %")


func test_buy_preview_empty_cases() -> void:
	assert_eq(_house.buy_preview(GRIP, 0), {})
	assert_eq(_house.buy_preview(GRIP, -1), {})
	assert_eq(_house.buy_preview(GRIP, 1194), {}, "more than the book")
	assert_eq(_house.buy_preview(LOG, 1), {}, "not buyable")
	_market({"redbirch_grip": 1193})
	assert_eq(_house.buy_preview(GRIP, 1), {}, "sold out")


func test_a_price_rise_makes_a_buy_large() -> void:
	# The premium rule alone: a total 30 % over `q * best` is large even for a tiny share (F-218).
	assert_true(AuctionBuy.preview(1300, 10, 1000, 100, 500000, 250000)["large"])
	assert_false(AuctionBuy.preview(1249, 10, 1000, 100, 500000, 250000)["large"])
	assert_true(AuctionBuy.preview(1250, 10, 1000, 100, 500000, 250000)["large"], "exactly +25 %: large")
	assert_eq(AuctionBuy.preview(5, 0, 1000, 100, 500000, 250000), {})


# --- the commands ------------------------------------------------------------------------------------------------

func test_can_buy_out_of_stock_when_qty_exceeds_available() -> void:
	_set_gold(1000000000)
	assert_eq(_house.can_buy(GRIP, 1194).reason, Reasons.OUT_OF_STOCK)
	assert_true(_house.can_buy(GRIP, 1193).ok)
	_market({"redbirch_grip": 1193})
	assert_eq(_house.can_buy(GRIP, 1).reason, Reasons.OUT_OF_STOCK)


func test_buy_pays_the_sum_of_the_book_and_updates_taken() -> void:
	_set_gold(100000)
	var seen: Array = []
	_s.events.auction_bought.connect(func(item: StringName, qty: int, gold: int) -> void: seen.append([item, qty, gold]))
	assert_true(_house.buy(GRIP, 100).ok)
	assert_eq(_s.wallet.get_gold(), 100000 - 35279)
	assert_eq(_s.bank.get_count(GRIP), 100)
	assert_eq(seen, [[GRIP, 100, 35279]])
	assert_eq(_house.to_save()["taken"], {"redbirch_grip": 100})
	assert_eq(_house.available(GRIP), 1093)
	assert_gt(_house.buy_unit(GRIP), 350 - 1, "never cheaper than the first piece")
	# the rejected command changes nothing
	var save: Dictionary = _house.to_save()
	assert_false(_house.buy(GRIP, 5000).ok)
	assert_eq(_house.to_save(), save)


func test_buying_everything_leaves_sold_out_and_the_time_to_come_back() -> void:
	_set_gold(1000000000)
	assert_true(_house.buy(GRIP, 1193).ok)
	assert_eq(_s.wallet.get_gold(), 1000000000 - 460691)
	assert_eq(_house.available(GRIP), 0)
	assert_eq(_house.restock_ms(GRIP), BLOCK_MS, "5 minutes at the start of a block")
	_house.advance(120000)
	assert_eq(_house.restock_ms(GRIP), BLOCK_MS - 120000, "the clock inside the block counts")
	_house.advance(BLOCK_MS - 120000)
	assert_eq(_house.available(GRIP), 17)
	assert_eq(_house.restock_ms(GRIP), 0)


func test_restock_ms_when_the_book_shrinks_below_taken() -> void:
	# taken above V (the new epoch has fewer pieces): sold out, back in ceil_div(taken - V + 1, r_i) blocks.
	assert_eq(AuctionBuy.restock_blocks(950, 1000, 17) * 5, 15)
	assert_eq(_house.restock_ms(PLATE), 0)
	assert_eq(_house.restock_ms(LOG), 0)


func test_new_game_empties_taken() -> void:
	_market({"redbirch_grip": 300})
	_house.new_game()
	assert_eq(_house.to_save()["taken"], {})


func test_the_book_rows_carry_the_buy_price_and_the_pieces_left() -> void:
	_market({"redbirch_grip": 100})
	var rows: Array[Dictionary] = _house.book(GRIP)
	assert_eq(rows.size(), 12)
	assert_eq([rows[0]["price"], rows[0]["buy_price"], rows[0]["left"], rows[0]["qty"]], [241, rows[0]["buy_price"], 0, 69], "the first listing is taken")
	assert_eq(rows[1]["left"], 138, "169 - 31 taken")
	assert_eq(rows[2]["left"], rows[2]["qty"])
	TestFactory.give(_s, GRIP, 20)
	_s.wallet.add_gold(100000)
	assert_true(_house.list_item(GRIP, 20, 1, &"short").ok)
	var mine: Array[Dictionary] = _house.book(GRIP).filter(func(r: Dictionary) -> bool: return r["mine"])
	assert_eq(mine.size(), 1)
	assert_eq([mine[0]["buy_price"], mine[0]["left"]], [0, 20])
	assert_eq(_house.buy_book(GRIP).size(), 12, "buy_book has the NPC listings only")
