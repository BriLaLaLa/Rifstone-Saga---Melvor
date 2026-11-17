extends GutTest
## AuctionPricing (docs/05_INTERFACES.md §5.30): quotes, saturation, stock, the market clock (F-145) and its equivalences.

const SEED: int = 12345
const GRIP: StringName = &"redbirch_grip"
const PLATE: StringName = &"riftite_plate"
const LOG: StringName = &"redbirch_log"
const HOUR_MS: int = 3600000

var _data: GameData
var _p: AuctionPricing


func before_all() -> void:
	_data = TestFactory.real_data()


func before_each() -> void:
	_p = _fresh()


func _fresh() -> AuctionPricing:
	var pricing := AuctionPricing.new(_data)
	pricing.reset(SEED)
	return pricing


func test_listing_and_levels() -> void:
	assert_true(_p.is_listed(LOG))
	assert_false(_p.is_buyable(LOG), "a raw material is sell-only")
	assert_eq(_p.buy_level(LOG), 0)
	assert_true(_p.is_buyable(PLATE))
	assert_eq(_p.buy_level(PLATE), 8)
	assert_eq(_p.buy_level(GRIP), 1)
	assert_false(_p.is_listed(&"test_unknown"))
	assert_eq(_p.buy_level(&"test_unknown"), 0)


func test_quotes_at_rest() -> void:
	var value: int = _data.item(PLATE).value
	assert_eq(_p.sell_quote(PLATE, 1), 71151)
	assert_eq(_p.buy_quote(PLATE, 1), 160402)
	assert_eq(_p.buy_quote(PLATE, 3), 3 * 160402)
	assert_eq(_p.sell_quote(PLATE, 0), 0)
	assert_eq(_p.sell_quote(&"test_unknown", 5), 0)
	assert_eq(_p.buy_quote(LOG, 5), 0, "not for sale")
	assert_eq(_p.buy_quote(PLATE, -1), 0)
	assert_gt(value, 0)


func test_selling_lowers_the_price_of_that_item_only() -> void:
	var other_before: int = _p.sell_quote(GRIP, 1)
	var before: int = _p.sell_quote(PLATE, 1)
	_p.record_sale(PLATE, 400)
	assert_lt(_p.sell_quote(PLATE, 1), before)
	assert_eq(_p.sell_quote(GRIP, 1), other_before)
	assert_eq(_p.buy_quote(PLATE, 1), AuctionMath.buy_unit(_data.item(PLATE).value, 1195823 - 400 * 277, _data.auction_params()), "the buy price follows the index")


func test_saturation_has_a_ceiling_and_the_price_a_floor() -> void:
	_p.record_sale(LOG, 100000)
	var floor_price: int = _p.sell_quote(LOG, 1000)
	_p.record_sale(LOG, 1)
	assert_eq(_p.sell_quote(LOG, 1000), floor_price, "saturation stopped at its cap")
	var save: Dictionary = _p.to_save()
	assert_eq(((save["items"] as Dictionary)["redbirch_log"] as Dictionary)["sat"], _data.auction_params().cap_ppm)


func test_purchases_lower_the_stock_to_zero() -> void:
	assert_eq(_p.stock(PLATE), 10)
	assert_eq(_p.stock_max(PLATE), 10)
	_p.record_purchase(PLATE, 3)
	assert_eq(_p.stock(PLATE), 7)
	_p.record_purchase(PLATE, 100)
	assert_eq(_p.stock(PLATE), 0)
	assert_eq(_p.stock(LOG), 0, "a sell-only item has no stock")
	assert_eq(_p.stock_max(LOG), 0)


func test_stock_refill_examples() -> void:
	_p.record_purchase(PLATE, 7)  # 3 left
	_p.advance(4 * 300000)
	assert_eq(_p.stock(PLATE), 7, "r = 1 per block")
	_p.advance(16 * 300000)
	assert_eq(_p.stock(PLATE), 10, "full again")
	_p.record_purchase(GRIP, 500)
	_p.advance(72 * 300000)
	assert_eq(_p.stock(GRIP), 500, "7 per block: full in 72 blocks (6 h)")


func test_saturation_recovery_examples() -> void:
	_p.record_sale(LOG, 2500)  # 500.000 (STEP_i 200, F-172)
	_p.advance(30 * 300000)
	assert_eq(_sat_of(_p, LOG), 312500)
	_p.advance(80 * 300000)
	assert_eq(_sat_of(_p, LOG), 0, "110 blocks in total")
	_p.record_sale(LOG, 2800)  # the cap, 560.000
	_p.advance(12 * HOUR_MS)
	assert_false((_p.to_save()["items"] as Dictionary).has("redbirch_log"), "12 hours of offline: at rest")


func test_clock_examples() -> void:
	assert_eq(_p.advance(0), 0)
	assert_eq(_p.advance(-5), 0)
	assert_eq(_p.advance(200000), 0)
	assert_eq(_p.advance(1000000), 4, "pending 200.000 + 1.000.000 = 1.200.000 -> 4 blocks")
	assert_eq(_p.to_save()["pending_ms"], 0)
	assert_eq(_p.to_save()["block"], 4)
	assert_eq(_p.advance(12 * HOUR_MS), 144)
	var ticks: AuctionPricing = _fresh()
	for i: int in 10:
		assert_eq(ticks.advance(100), 0)
	assert_eq(ticks.to_save()["pending_ms"], 1000)
	assert_eq(ticks.to_save()["block"], 0)


func test_advance_in_pieces_equals_advance_in_one() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i: int in 50:
		var a: int = rng.randi_range(0, 5000000)
		var b: int = rng.randi_range(0, 5000000)
		var split: AuctionPricing = _dirty()
		var whole: AuctionPricing = _dirty()
		split.advance(a)
		split.advance(b)
		whole.advance(a + b)
		assert_eq(split.to_save(), whole.to_save(), "advance(%d) + advance(%d)" % [a, b])


func test_twelve_hours_in_one_go_in_ticks_and_in_blocks_of_a_minute() -> void:
	var one: AuctionPricing = _dirty()
	one.advance(12 * HOUR_MS + 12345)
	var ticks: AuctionPricing = _dirty()
	for i: int in 432000:
		ticks.advance(100)
	ticks.advance(12345)
	var minutes: AuctionPricing = _dirty()
	for i: int in 720:
		minutes.advance(60000)
	minutes.advance(12345)
	assert_eq(ticks.to_save(), one.to_save())
	assert_eq(minutes.to_save(), one.to_save())


func test_trend_of_the_examples() -> void:
	assert_eq(_p.trend(GRIP), &"down", "F-152: now 1.211.184, in an hour 1.188.552")
	_p.record_sale(GRIP, 400)  # sat 100.000
	assert_eq(_p.trend(GRIP), &"up", "1.111.184 -> 1.148.552")
	var calm: AuctionPricing = _fresh()
	calm.advance(66 * 300000)
	assert_eq(calm.trend(PLATE), &"stable", "1.096.584 -> 1.095.444")
	assert_eq(_p.trend(&"test_unknown"), &"stable")


func test_a_new_seed_gives_another_history() -> void:
	var other := AuctionPricing.new(_data)
	other.reset(SEED + 1)
	assert_ne(other.sell_quote(PLATE, 1), _p.sell_quote(PLATE, 1))


# An advanced market with a few items away from rest.
func _dirty() -> AuctionPricing:
	var pricing: AuctionPricing = _fresh()
	pricing.record_sale(LOG, 1500)
	pricing.record_sale(GRIP, 300)
	pricing.record_purchase(PLATE, 9)
	pricing.record_purchase(GRIP, 450)
	return pricing


func _sat_of(pricing: AuctionPricing, id: StringName) -> int:
	return (((pricing.to_save()["items"] as Dictionary).get(String(id), {}) as Dictionary).get("sat", 0)) as int
