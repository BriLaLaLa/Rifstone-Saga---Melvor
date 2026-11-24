extends GutTest
## F-214: the reference price ("recent average"): the median of the last epochs of the sell and buy series
## (docs/02_FORMULAS_M38.md), the cache and the properties.

const SEED: int = 12345
const GRIP: StringName = &"redbirch_grip"  # v 200
const PLATE: StringName = &"riftite_plate"  # v 59.500
const LOG: StringName = &"redbirch_log"
const BLOCK_MS: int = 300000

var _data: GameData
var _p: AuctionParams


func before_all() -> void:
	_data = TestFactory.real_data()
	_p = _data.auction_params()


func _pricing(block: int = 0) -> AuctionPricing:
	var pricing := AuctionPricing.new(_data)
	pricing.reset(SEED)
	pricing.advance(block * BLOCK_MS)
	return pricing


func _reference() -> AuctionReference:
	return AuctionReference.new(_p)


func _band(id: StringName) -> AuctionPopulationBand:
	return AuctionMath.band_of(_data.item(id).value, _p)


# --- the median ------------------------------------------------------------------------------------------------

func test_median_with_even_and_odd_counts() -> void:
	assert_eq(AuctionMath.median(PackedInt64Array([100, 120, 90, 110])), 110, "90 100 110 120: index 2")
	assert_eq(AuctionMath.median(PackedInt64Array([5, 9, 7])), 7, "5 7 9: index 1")
	assert_eq(AuctionMath.median(PackedInt64Array([42])), 42)
	assert_eq(AuctionMath.median(PackedInt64Array([3, 1])), 3, "n = 2: the upper one")
	assert_eq(AuctionMath.median(PackedInt64Array()), 0)


func test_median_does_not_change_its_argument() -> void:
	var values := PackedInt64Array([9, 1, 5])
	AuctionMath.median(values)
	assert_eq(values, PackedInt64Array([9, 1, 5]))


# --- the series --------------------------------------------------------------------------------------------------

func test_epoch_zero_values_of_the_real_data() -> void:
	var ref: AuctionReference = _reference()
	assert_eq(ref.price(GRIP, &"sell", 0, SEED, 200, _band(GRIP)), 240, "s_0 = 200 * 1.201.052 / PPM")
	assert_eq(ref.price(GRIP, &"buy", 0, SEED, 200, _band(GRIP)), 350, "a_0 = ceil(241 * 1,45)")
	assert_eq(ref.price(PLATE, &"sell", 0, SEED, 59500, _band(PLATE)), 71151)
	assert_eq(ref.price(PLATE, &"buy", 0, SEED, 59500, _band(PLATE)), 105328)


func test_the_pricing_gives_the_same_values() -> void:
	var pricing: AuctionPricing = _pricing()
	assert_eq([pricing.reference_price(GRIP, &"sell"), pricing.reference_price(GRIP, &"buy")], [240, 350])
	assert_eq(pricing.reference_price(PLATE, &"buy"), 105328)
	assert_eq(pricing.reference_price(LOG, &"buy"), 0, "not buyable")
	assert_gt(pricing.reference_price(LOG, &"sell"), 0)
	assert_eq(pricing.reference_price(&"no_such_item", &"sell"), 0)


func test_negative_epochs_are_skipped_and_the_window_is_at_most_w() -> void:
	var ref: AuctionReference = _reference()
	var band: AuctionPopulationBand = _band(GRIP)
	var series: PackedInt64Array = []
	for e: int in range(0, 4):
		series.append(_epoch_sell(ref, e, band))
	# e_now 3: epochs 0..3 only (W = 24, nothing before 0)
	assert_eq(ref.price(GRIP, &"sell", 3, SEED, 200, band), AuctionMath.median(series))
	# a single epoch: its own value; e_now 0 has a single value
	assert_eq(ref.price(GRIP, &"sell", 0, SEED, 200, band), series[0])
	# e_now 30: the epochs 7..30 (24 values), not the first ones
	var window: PackedInt64Array = []
	for e: int in range(7, 31):
		window.append(_epoch_sell(ref, e, band))
	assert_eq(ref.price(GRIP, &"sell", 30, SEED, 200, band), AuctionMath.median(window))


# The sell series of one epoch through the public function: a window of W = 24 with e_now = e would mix epochs, so the
# value of epoch `e` is read as the reference of a one-epoch window: a fresh object with `reference_epochs` 1.
func _epoch_sell(_ref: AuctionReference, e: int, band: AuctionPopulationBand) -> int:
	var one: AuctionParams = AuctionParams.from_dict(_data.balance_value("auction") as Dictionary)
	one.reference_epochs = 1
	one.bands = _p.bands
	return AuctionReference.new(one).price(GRIP, &"sell", e, SEED, 200, band)


func test_same_inputs_same_value_and_the_cache_does_not_change_it() -> void:
	var a: AuctionReference = _reference()
	var b: AuctionReference = _reference()
	var band: AuctionPopulationBand = _band(PLATE)
	var first: int = a.price(PLATE, &"buy", 50, SEED, 59500, band)
	assert_eq(a.price(PLATE, &"buy", 50, SEED, 59500, band), first, "cached")
	assert_eq(b.price(PLATE, &"buy", 50, SEED, 59500, band), first, "another object")
	a.clear()
	assert_eq(a.price(PLATE, &"buy", 50, SEED, 59500, band), first, "after the cache is dropped")


func test_a_new_seed_drops_the_cache() -> void:
	var ref: AuctionReference = _reference()
	var band: AuctionPopulationBand = _band(PLATE)
	var one: int = ref.price(PLATE, &"sell", 10, 1, 59500, band)
	var two: int = ref.price(PLATE, &"sell", 10, 2, 59500, band)
	assert_eq(ref.price(PLATE, &"sell", 10, 1, 59500, band), one)
	assert_ne(one, two, "two seeds, two markets")


func test_the_reference_follows_the_clock_of_the_pricing() -> void:
	var early: AuctionPricing = _pricing(0)
	var late: AuctionPricing = _pricing(6 * 40)  # epoch 40
	assert_ne(late.reference_price(PLATE, &"sell"), 0)
	assert_eq(_pricing(5).reference_price(GRIP, &"sell"), early.reference_price(GRIP, &"sell"), "same epoch: the same reference")
	assert_eq(_pricing(6).reference_price(GRIP, &"sell") > 0, true)


func test_the_reference_is_not_moved_by_trades() -> void:
	var pricing: AuctionPricing = _pricing()
	var before: Array = [pricing.reference_price(GRIP, &"sell"), pricing.reference_price(GRIP, &"buy")]
	pricing.record_sale(GRIP, 2000)
	pricing.record_purchase(GRIP, 800)
	assert_eq([pricing.reference_price(GRIP, &"sell"), pricing.reference_price(GRIP, &"buy")], before)
