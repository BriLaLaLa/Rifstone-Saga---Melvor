extends GutTest
## F-145…F-152 (docs/02_FORMULAS.md §5k): the examples with their numbers and the properties of the closed forms.

const SEED: int = 12345
const GRIP: StringName = &"redbirch_grip"
const PLATE: StringName = &"riftite_plate"

var _p: AuctionParams


func before_all() -> void:
	_p = TestFactory.real_data().auction_params()


func _value(id: StringName) -> int:
	return TestFactory.real_data().item(id).value


func test_parameters_in_ppm() -> void:
	assert_eq(_p.block_ms, 300000)
	assert_eq([_p.base_ppm, _p.min_ppm, _p.max_ppm, _p.amp_ppm], [1150000, 700000, 1260000, 80000])
	assert_eq([_p.step_ppm, _p.cap_ppm, _p.recover_ppm, _p.spread_ppm, _p.refill_ppm], [250, 560000, 5000, 1500000, 14000])
	assert_eq([_p.period_blocks, _p.stock_gold, _p.stock_min, _p.stock_max], [72, 6000, 5, 500])
	assert_eq([_p.trend_blocks, _p.trend_threshold_ppm], [12, 10000])


func test_hash_vectors() -> void:
	assert_eq(AuctionMath.fnv1a32("a"), 3826002220)
	assert_eq(AuctionMath.hash32("a"), 444641715)
	assert_eq(AuctionMath.hash32("redbirch_grip|12345|0"), 1114708150)


func test_knots_of_the_examples() -> void:
	assert_eq([AuctionMath.knot(GRIP, SEED, 0, _p), AuctionMath.knot(GRIP, SEED, 1, _p), AuctionMath.knot(GRIP, SEED, 2, _p)],
			[61184, -74613, -57080])
	assert_eq([AuctionMath.knot(PLATE, SEED, 0, _p), AuctionMath.knot(PLATE, SEED, 1, _p), AuctionMath.knot(PLATE, SEED, 2, _p)],
			[36080, -61552, 22407])


func test_drift_of_the_examples() -> void:
	assert_eq(AuctionMath.drift(GRIP, SEED, 36, _p), -6714)
	assert_eq(AuctionMath.drift(GRIP, SEED, 72, _p), -74613)
	assert_eq(AuctionMath.drift(PLATE, SEED, 12, _p), 19808)


func test_drift_is_deterministic_and_bounded() -> void:
	for block: int in range(0, 1000, 7):
		var a: int = AuctionMath.drift(GRIP, SEED, block, _p)
		assert_eq(a, AuctionMath.drift(GRIP, SEED, block, _p))
		assert_lte(absi(a), _p.amp_ppm)
	assert_ne(AuctionMath.drift(GRIP, SEED, 0, _p), AuctionMath.drift(GRIP, SEED + 1, 0, _p), "another seed, another history")


func test_index_examples() -> void:
	assert_eq(AuctionMath.index_ppm(_p.base_ppm + AuctionMath.drift(GRIP, SEED, 0, _p), 0, _p), 1211184)
	assert_eq(AuctionMath.index_ppm(_p.base_ppm + AuctionMath.drift(GRIP, SEED, 36, _p), 0, _p), 1143286)
	assert_eq(AuctionMath.index_ppm(_p.base_ppm + AuctionMath.drift(GRIP, SEED, 0, _p), 550000, _p), 700000, "661.184 -> the minimum")
	assert_eq(AuctionMath.index_ppm(_p.base_ppm + AuctionMath.drift(PLATE, SEED, 0, _p), 0, _p), 1186080)


func test_sale_examples() -> void:
	var sum: int = AuctionMath.sale_sum_ppm(1150000, 0, 100, _p)
	assert_eq(sum, 113762500)
	assert_eq(AuctionMath.gold_of(10, sum), 1137, "F-18 would give 1.000")
	assert_eq(AuctionMath.gold_of(10, AuctionMath.sale_sum_ppm(1150000, 0, 60, _p)), 685)
	assert_eq(AuctionMath.gold_of(10, AuctionMath.sale_sum_ppm(1150000, 60 * _p.step_ppm, 40, _p)), 452)
	assert_eq(AuctionMath.sale_sum_ppm(1150000, 0, 2000, _p), 1805225000)
	assert_eq(AuctionMath.gold_of(1, 1805225000), 1805)
	assert_eq(AuctionMath.sale_sum_ppm(1150000, 400000, 10, _p), 7488750)
	assert_eq(AuctionMath.gold_of(70, 7488750), 524, "F-18 would give 700")


func test_closed_form_equals_the_piece_by_piece_sum() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i: int in 1000:
		var eq: int = rng.randi_range(_p.base_ppm - _p.amp_ppm, _p.base_ppm + _p.amp_ppm)
		var sat: int = rng.randi_range(0, _p.cap_ppm)
		var qty: int = rng.randi_range(1, 3000)
		var total: int = 0
		for k: int in qty:
			total += clampi(eq - sat - k * _p.step_ppm, _p.min_ppm, _p.max_ppm)
		assert_eq(AuctionMath.sale_sum_ppm(eq, sat, qty, _p), total, "eq %d sat %d qty %d" % [eq, sat, qty])


func test_stock_examples() -> void:
	assert_eq(AuctionMath.stock_max(_value(GRIP), _p), 500)
	assert_eq(AuctionMath.refill_per_block(500, _p), 7)
	assert_eq(AuctionMath.stock_max(_value(PLATE), _p), 10)
	assert_eq(AuctionMath.refill_per_block(10, _p), 1)
	assert_eq(AuctionMath.stock_max(_value(&"seared_riftmaw"), _p), 35)
	assert_eq(AuctionMath.refill_per_block(35, _p), 1)
	assert_eq(AuctionMath.stock_max(_value(&"shardcedar_grip"), _p), 166)
	assert_eq(AuctionMath.refill_per_block(166, _p), 2)


func test_buy_examples() -> void:
	var plate_value: int = _value(PLATE)
	assert_eq(AuctionMath.buy_unit(plate_value, 1186080, _p), 1599)
	assert_eq(AuctionMath.gold_of(plate_value, AuctionMath.sale_sum_ppm(1186080, 0, 1, _p)), 705)
	assert_eq(AuctionMath.buy_unit(plate_value, 700000, _p), 1309)
	assert_gt(AuctionMath.buy_unit(plate_value, 700000, _p), plate_value * _p.max_ppm / 1000000, "above the best possible sale")
	var grip_unit: int = AuctionMath.buy_unit(_value(GRIP), 1000000, _p)
	assert_between(grip_unit, 5, 6)


func test_buying_always_costs_more_than_any_sale_for_every_buyable_item() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var data: GameData = TestFactory.real_data()
	var checked: int = 0
	for def: AuctionItemDef in data.auction_items():
		if def.buy_level < 1:
			continue
		var value: int = data.item(def.item).value
		for i: int in 1000:
			var index: int = rng.randi_range(_p.min_ppm, _p.max_ppm)
			var unit: int = AuctionMath.buy_unit(value, index, _p)
			assert_gt(unit, AuctionMath.gold_of(value, _p.max_ppm), "%s: unit above the sale at the ceiling" % def.item)
			assert_gt(unit, value, "%s: unit above the fixed price (F-18)" % def.item)
		checked += 1
	assert_eq(checked, 48)


func test_trend_examples() -> void:
	var eq0: int = _p.base_ppm + AuctionMath.drift(GRIP, SEED, 0, _p)
	var eq12: int = _p.base_ppm + AuctionMath.drift(GRIP, SEED, 12, _p)
	assert_eq(AuctionMath.index_ppm(eq12, 0, _p), 1188552)
	assert_eq(AuctionMath.trend_of(1211184, 1188552, _p), &"down")
	assert_eq(AuctionMath.trend_of(eq0 - 100000, AuctionMath.index_ppm(eq12, 100000 - 12 * _p.recover_ppm, _p), _p), &"up")
	assert_eq(AuctionMath.trend_of(1096584, 1095444, _p), &"stable")
	assert_eq(AuctionMath.trend_of(1000000, 1010000, _p), &"up", "the threshold itself counts")
	assert_eq(AuctionMath.trend_of(1000000, 990000, _p), &"down")
	assert_eq(AuctionMath.trend_of(1000000, 1009999, _p), &"stable")
