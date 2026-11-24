extends GutTest
## F-210 (price_gap), F-211 (max_buyable), F-213 (listings_summary) of docs/02_FORMULAS_M37.md, on AuctionView and AuctionHouse.

const AuctionTestData := preload("res://tests/systems/auction/auction_test_data.gd")
const GRIP: StringName = &"redbirch_grip"
const LOG: StringName = &"redbirch_log"
const PLATE: StringName = &"riftite_plate"
const FIRST_PLATE: StringName = &"emberbronze_plate"
const NO_GAP: int = AuctionHouse.NO_GAP

var _s: GameSession
var _house: AuctionHouse


func before_each() -> void:
	_s = AuctionTestData.session(8)
	add_child_autofree(_s)
	_house = _s.auction


func _set_gold(amount: int) -> void:
	_s.wallet.spend(_s.wallet.get_gold())
	_s.wallet.add_gold(amount)


# --- F-210 -----------------------------------------------------------------------------------------------------

func test_gap_examples() -> void:
	assert_eq(AuctionView.gap_pct(1150, 1000), 15)
	assert_eq(AuctionView.gap_pct(940, 1000), -6)
	assert_eq(AuctionView.gap_pct(1005, 1000), 1, "0.5 rounds away from zero")
	assert_eq(AuctionView.gap_pct(995, 1000), -1)
	assert_eq(AuctionView.gap_pct(1000, 1000), 0)
	assert_eq(AuctionView.gap_pct(1004, 1000), 0)
	assert_eq(AuctionView.gap_pct(1000, 0), NO_GAP)
	assert_eq(AuctionView.gap_pct(0, 1000), NO_GAP)


func test_gap_of_the_house_follows_the_unit_and_the_reference() -> void:
	var ref_buy: int = _house.reference_price(PLATE, &"buy")
	assert_gt(ref_buy, 0)
	assert_eq(_house.price_gap(PLATE, &"buy"), AuctionView.gap_pct(_house.buy_unit(PLATE), ref_buy))
	assert_eq(_house.price_gap(PLATE, &"sell"), AuctionView.gap_pct(_house.sell_quote(PLATE, 1), _house.reference_price(PLATE, &"sell")))


func test_gap_not_available_for_an_untraded_item_or_one_that_cannot_be_bought() -> void:
	assert_eq(_house.price_gap(&"no_such_item", &"buy"), NO_GAP)
	assert_eq(_house.price_gap(&"no_such_item", &"sell"), NO_GAP)
	assert_eq(_house.value_of(&"no_such_item"), 0)
	assert_eq(_house.price_gap(LOG, &"buy"), NO_GAP, "a material cannot be bought")


# --- F-211 -----------------------------------------------------------------------------------------------------

func test_max_buy_examples() -> void:
	var book: Array[Vector2i] = [Vector2i(250, 40)]
	assert_eq(AuctionView.max_buy(book, 0, 5000), 20)
	assert_eq(AuctionView.max_buy([Vector2i(250, 12)] as Array[Vector2i], 0, 5000), 12)
	assert_eq(AuctionView.max_buy(book, 0, 249), 0)
	assert_eq(AuctionView.max_buy(book, 40, 5000), 0, "everything taken")
	assert_eq(AuctionView.max_buy([] as Array[Vector2i], 0, 5000), 0)


func test_max_buyable_of_the_house() -> void:
	_set_gold(1000000000)
	var unit: int = _house.buy_unit(PLATE)
	assert_eq(_house.max_buyable(PLATE), _house.available(PLATE), "plenty of gold: all the pieces")
	_set_gold(unit * 3 - 1)
	assert_eq(_house.max_buyable(PLATE), 2, "gold for two and a bit")
	_set_gold(unit - 1)
	assert_eq(_house.max_buyable(PLATE), 0)
	assert_eq(_house.max_buyable(LOG), 0, "not buyable")
	assert_eq(_house.max_buyable(&"no_such_item"), 0)


func test_max_buyable_zero_below_the_level_of_the_item() -> void:
	var gated: StringName = &""
	for item: StringName in _house.buyable_items():
		if _house.buy_level(item) > 1:
			gated = item
			break
	assert_ne(gated, &"", "the data have a gated item")
	_set_gold(1000000000)
	var low: GameSession = AuctionTestData.session(1)
	add_child_autofree(low)
	low.wallet.add_gold(1000000000)
	assert_eq(low.auction.max_buyable(gated), 0)
	assert_gt(_house.max_buyable(gated), 0, "with the building high enough")


func test_max_buyable_zero_with_a_full_deposit() -> void:
	_set_gold(1000000000)
	assert_gt(_house.max_buyable(FIRST_PLATE), 0)
	for def: ItemDef in _s.data.items():
		if _s.bank.free_boxes() <= 0:
			break
		if def.id != FIRST_PLATE and def.category != &"equipment" and def.category != &"tool" and def.category != &"map":
			_s.bank.add(def.id, 1)
	assert_eq(_s.bank.free_boxes(), 0)
	assert_eq(_house.max_buyable(FIRST_PLATE), 0)


# --- F-213 -----------------------------------------------------------------------------------------------------

func test_summary_examples() -> void:
	var net: Callable = func(qty: int, price: int) -> int:
		var gross: int = qty * price
		return gross - gross / 20
	var listings: Array[Dictionary] = [{"qty": 10, "price": 200}, {"qty": 3, "price": 1000}]
	assert_eq(AuctionView.summary(listings, net), {"count": 2, "units": 13, "expected_net": 4750})
	assert_eq(AuctionView.summary([], net), {"count": 0, "units": 0, "expected_net": 0})


func test_summary_of_the_house() -> void:
	assert_eq(_house.listings_summary(), {"count": 0, "units": 0, "expected_net": 0})
	TestFactory.give(_s, GRIP, 10)
	_set_gold(1000000)
	assert_true(_house.list_item(GRIP, 10, 200, &"short").ok)
	assert_eq(_house.listings_summary(), {"count": 1, "units": 10, "expected_net": _house.listing_net(GRIP, 10, 200)})
