extends GutTest
## Auction House population (docs/02_FORMULAS_M26.md F-172…F-176, docs/05_INTERFACES_M26.md §5.37): every example and vector of
## the formulas, the properties (clock additivity on the four bands, the no-gain guarantee) and the data rules.

const SEED: int = 12345
const GRIP: StringName = &"redbirch_grip"  # value 2, band 1
const PLATE: StringName = &"riftite_plate"  # value 595, band 4
const SHARD_GRIP: StringName = &"shardcedar_grip"  # value 36, band 2
const MAW: StringName = &"seared_riftmaw"  # value 170, band 3
const LOG: StringName = &"redbirch_log"  # value 1, band 1
const BLOCK_MS: int = 300000

var _data: GameData
var _params: AuctionParams


func before_all() -> void:
	_data = TestFactory.real_data()
	_params = _data.auction_params()


func _pricing(block: int = 0) -> AuctionPricing:
	var pricing := AuctionPricing.new(_data)
	pricing.reset(SEED)
	pricing.advance(block * BLOCK_MS)
	return pricing


func _wave(id: StringName, kind: String, block: int) -> int:
	return AuctionMath.wave(id, kind, SEED, block, _params)


func _eq(id: StringName, block: int) -> int:
	var band: AuctionPopulationBand = AuctionMath.band_of(_data.item(id).value, _params)
	var pop: Vector2i = AuctionMath.population(band.buyers, band.sellers, _wave(id, "b", block), _wave(id, "s", block))
	return _params.base_ppm + AuctionMath.drift(id, SEED, block, _params) + AuctionMath.pressure(pop.x, pop.y, _params)


# --- data ------------------------------------------------------------------------------------------------------------

func test_parameters_and_bands() -> void:
	assert_eq([_params.pop_ref, _params.pop_period_blocks, _params.pop_var_ppm, _params.pop_press_ppm, _params.pop_demand_ppm],
			[100, 36, 200000, 100000, 5000])
	assert_eq([_params.max_ppm, _params.cap_ppm], [1260000, 560000], "the two values changed in M26")
	var rows: Array = []
	for band: AuctionPopulationBand in _params.bands:
		rows.append([band.max_value, band.buyers, band.sellers])
	assert_eq(rows, [[900, 125, 115], [5900, 110, 105], [24900, 100, 100], [-1, 90, 85]])
	assert_eq(AuctionMath.band_of(900, _params).buyers, 125)
	assert_eq(AuctionMath.band_of(1000, _params).buyers, 110)
	assert_eq(AuctionMath.band_of(24900, _params).buyers, 100)
	assert_eq(AuctionMath.band_of(25000, _params).buyers, 90)
	assert_eq(AuctionMath.band_of(100000000, _params).buyers, 90, "the open band has no ceiling")


# --- F-172 -----------------------------------------------------------------------------------------------------------

func test_liquidity_of_the_bands() -> void:
	var steps: Array = []
	var recs: Array = []
	var full: Array = []
	for band: AuctionPopulationBand in _params.bands:
		var liq: Dictionary = AuctionMath.liquidity(1, band, _params)
		steps.append(liq["step"])
		recs.append(liq["rec"])
		full.append(AuctionMath.ceil_div(_params.cap_ppm, int(liq["rec"])))
	assert_eq(steps, [200, 227, 250, 277])
	assert_eq(recs, [6250, 5500, 5000, 4500])
	assert_eq(full, [90, 102, 112, 125], "full recovery from the cap, in blocks")
	for blocks: int in full:
		assert_lte(blocks, 144, "at most 12 hours")


func test_refill_examples() -> void:
	for row: Array in [[GRIP, 8], [PLATE, 1], [SHARD_GRIP, 2], [MAW, 1]]:
		var id: StringName = row[0]
		var value: int = _data.item(id).value
		var liq: Dictionary = AuctionMath.liquidity(value, AuctionMath.band_of(value, _params), _params)
		assert_eq(liq["refill"], row[1], str(id))
	assert_eq(AuctionMath.stock_max(_data.item(GRIP).value, _params), 500)
	assert_eq(AuctionMath.stock_max(_data.item(PLATE).value, _params), 10)


# --- F-173 -----------------------------------------------------------------------------------------------------------

func test_hash_vector_and_nodes() -> void:
	assert_eq(AuctionMath.hash32("redbirch_grip|b|12345|0"), 1871622662)
	var nodes: Array = []
	for id: StringName in [GRIP, PLATE]:
		for kind: String in ["b", "s"]:
			var row: Array = []
			for j: int in 3:
				row.append(AuctionMath.wave_knot(id, kind, SEED, j, _params))
			nodes.append(row)
	assert_eq(nodes, [[-182017, 93705, 103282], [90166, 28650, 116736], [189615, -168726, 108115], [35745, -97349, -73653]])


func test_waves_population_and_pressure() -> void:
	var cases: Array = [[0, -182017, 90166, 102, 125, -10132], [18, -44156, 59408, 119, 121, -833], [36, 93705, 28650, 136, 118, 7086]]
	for row: Array in cases:
		var block: int = row[0]
		assert_eq(_wave(GRIP, "b", block), row[1], "w_b at %d" % block)
		assert_eq(_wave(GRIP, "s", block), row[2], "w_s at %d" % block)
		var pop: Vector2i = AuctionMath.population(125, 115, row[1], row[2])
		assert_eq([pop.x, pop.y, AuctionMath.pressure(pop.x, pop.y, _params)], [row[3], row[4], row[5]], "block %d" % block)
	var pop: Vector2i = AuctionMath.population(90, 85, _wave(PLATE, "b", 0), _wave(PLATE, "s", 0))
	assert_eq([pop.x, pop.y, AuctionMath.pressure(pop.x, pop.y, _params)], [107, 88, 9743])


func test_waves_are_pure_and_bounded() -> void:
	for block: int in range(0, 400, 7):
		for kind: String in ["b", "s"]:
			var w: int = _wave(GRIP, kind, block)
			assert_eq(w, _wave(GRIP, kind, block), "same inputs, same value")
			assert_lte(absi(w), _params.pop_var_ppm)


# --- F-174 -----------------------------------------------------------------------------------------------------------

func test_equilibrium_examples() -> void:
	assert_eq(_eq(GRIP, 0), 1201052)
	assert_eq(_eq(GRIP, 18), 1176402)
	assert_eq(_eq(GRIP, 36), 1150372)
	assert_eq(_eq(PLATE, 0), 1195823)
	assert_eq(AuctionMath.index_ppm(_eq(GRIP, 0), 560000, _params), 700000, "641.052 -> the minimum")
	assert_eq(AuctionMath.drift(GRIP, SEED, 0, _params), 61184)


func test_the_index_stays_in_bounds_in_every_band() -> void:
	for def: AuctionItemDef in _data.auction_items():
		for block: int in range(0, 300, 11):
			var eq: int = _eq(def.item, block)
			assert_gte(AuctionMath.index_ppm(eq, 0, _params), _params.min_ppm)
			assert_lte(eq, _params.max_ppm, "%s at %d" % [def.item, block])
			assert_gte(AuctionMath.index_ppm(eq, _params.cap_ppm, _params), _params.min_ppm)


# --- F-175 -----------------------------------------------------------------------------------------------------------

func test_sale_examples_with_the_item_step() -> void:
	assert_eq(AuctionMath.sale_sum_ppm(1150000, 0, 100, _params, 200), 114010000)
	assert_eq(AuctionMath.gold_of(2, 114010000), 228)
	assert_eq(AuctionMath.sale_sum_ppm(1150000, 0, 2000, _params, 200), 1900200000)
	assert_eq(AuctionMath.gold_of(1, 1900200000), 1900)
	assert_eq(AuctionMath.gold_of(595, AuctionMath.sale_sum_ppm(1150000, 0, 100, _params, 277)), 67609)
	assert_eq(AuctionMath.gold_of(595, AuctionMath.sale_sum_ppm(1150000, 0, 100, _params, 250)), 67688, "band 3 = M23")
	assert_eq(AuctionMath.sale_sum_ppm(1150000, 0, 100, _params), AuctionMath.sale_sum_ppm(1150000, 0, 100, _params, _params.step_ppm))
	var pricing: AuctionPricing = _pricing()
	pricing.record_sale(GRIP, 100)
	assert_eq((pricing.to_save()["items"] as Dictionary)["redbirch_grip"], {"sat": 20000})
	pricing.record_sale(PLATE, 100)
	assert_eq((pricing.to_save()["items"] as Dictionary)["riftite_plate"], {"sat": 27700})


func test_recovery_examples() -> void:
	var pricing: AuctionPricing = _pricing()
	pricing.record_sale(LOG, 2500)  # band 1: 500.000
	pricing.advance(30 * BLOCK_MS)
	assert_eq(_sat(pricing, LOG), 312500)
	pricing = _pricing()
	pricing.record_sale(PLATE, 2022)  # band 4: the cap (560.000 / 277 rounded up)
	assert_eq(_sat(pricing, PLATE), 560000)
	pricing.advance(124 * BLOCK_MS)
	assert_eq(_sat(pricing, PLATE), 2000)
	pricing.advance(BLOCK_MS)
	assert_eq(_sat(pricing, PLATE), 0)


func test_refill_example() -> void:
	var pricing: AuctionPricing = _pricing()
	pricing.record_purchase(GRIP, 500)
	assert_eq(pricing.stock(GRIP), 0)
	pricing.advance(62 * BLOCK_MS)
	assert_eq(pricing.stock(GRIP), 496)
	pricing.advance(BLOCK_MS)
	assert_eq(pricing.stock(GRIP), 500)


func test_advance_is_additive_in_every_band() -> void:
	var ids: Array[StringName] = [GRIP, SHARD_GRIP, MAW, PLATE]
	for step: Array in [[1, 1], [7, 90], [63, 61], [100, 130], [1, 143]]:
		var a: int = step[0]
		var b: int = step[1]
		var split: AuctionPricing = _pricing()
		var whole: AuctionPricing = _pricing()
		for id: StringName in ids:
			split.record_sale(id, 900)
			whole.record_sale(id, 900)
			split.record_purchase(id, 5)
			whole.record_purchase(id, 5)
		split.advance(a * BLOCK_MS)
		split.advance(b * BLOCK_MS)
		whole.advance((a + b) * BLOCK_MS)
		assert_eq(split.to_save(), whole.to_save(), "advance(%d); advance(%d)" % [a, b])
		for id: StringName in ids:
			assert_eq(split.sell_quote(id, 50), whole.sell_quote(id, 50))
			assert_eq(split.trend(id), whole.trend(id))


# --- F-176 -----------------------------------------------------------------------------------------------------------

func test_trend_examples() -> void:
	var pricing: AuctionPricing = _pricing()
	assert_eq(pricing.trend(GRIP), &"down", "1.201.052 -> 1.184.315")
	assert_eq(_eq(GRIP, 12) - 0, 1184315)
	pricing.record_sale(GRIP, 500)  # sat 100.000
	assert_eq(pricing.trend(GRIP), &"up", "1.101.052 -> 1.159.315")
	var later: AuctionPricing = _pricing(66)
	assert_eq(_eq(PLATE, 66), 1106410)
	assert_eq(_eq(PLATE, 78), 1107803)
	assert_eq(later.trend(PLATE), &"stable")


func test_quotes_examples() -> void:
	var pricing: AuctionPricing = _pricing()
	assert_eq(pricing.buy_quote(PLATE, 1), 160402)
	assert_eq(pricing.sell_quote(PLATE, 1), 71151)
	assert_eq(pricing.buy_quote(PLATE, 3), 3 * 160402)


func test_population_shown() -> void:
	var low: Dictionary = _pricing(0).population(GRIP)
	assert_eq([low["buyers"], low["sellers"], low["demand"]], [102, 125, &"low"])
	assert_eq(_pricing(18).population(GRIP)["demand"], &"normal")
	var high: Dictionary = _pricing(36).population(GRIP)
	assert_eq([high["buyers"], high["sellers"], high["demand"]], [136, 118, &"high"])
	assert_eq(_pricing().population(&"not_listed"), {})


func test_buying_and_selling_back_always_loses_gold() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var buyable: Array[AuctionItemDef] = []
	for def: AuctionItemDef in _data.auction_items():
		if def.buy_level >= 1:
			buyable.append(def)
	assert_eq(buyable.size(), 58)
	for def: AuctionItemDef in buyable:
		var value: int = _data.item(def.item).value
		for i: int in 1000:
			var pricing: AuctionPricing = _pricing(rng.randi_range(0, 2000))
			pricing.record_sale(def.item, rng.randi_range(0, 3000))
			var unit: int = pricing.buy_quote(def.item, 1)
			assert_gt(unit, pricing.sell_quote(def.item, 1), "%s: buying costs more than selling" % def.item)
			assert_gt(unit, value, "%s: buying costs more than the value" % def.item)


func test_the_save_has_no_new_fields() -> void:
	var pricing: AuctionPricing = _pricing(40)
	pricing.record_sale(GRIP, 10)
	var save: Dictionary = pricing.to_save()
	assert_eq((save as Dictionary).keys(), ["seed", "block", "pending_ms", "items"])
	assert_eq(save["items"], {"redbirch_grip": {"sat": 2000}})


# --- validator -------------------------------------------------------------------------------------------------------

func _raw() -> Dictionary:
	var errors: PackedStringArray = []
	var raw: Dictionary = {
		"balance": DataBuildUtil.read_files(["res://data/config/balance.json"], errors),
		"stats": DataBuildUtil.read_files(["res://data/config/stats.json"], errors),
	}
	for section: String in GameData.CONTENT_FILES:
		raw[section] = DataBuildUtil.read_files(["res://data".path_join(GameData.CONTENT_FILES[section])], errors)
	for section: String in GameData.CONTENT_DIRS:
		raw[section] = DataBuildUtil.read_files(JsonLoader.list_json_files("res://data".path_join(GameData.CONTENT_DIRS[section]), errors), errors)
	raw["guide"] = DataBuildUtil.read_files(DataValidatorGuide.list_files("res://data", errors), errors)
	raw["dungeons"] = DataBuildUtil.read_files(DungeonIndex.list_files("res://data", errors), errors)
	raw["encounters"] = DataBuildUtil.read_files(DisciplineIndex.nodes_files("res://data"), errors)
	return raw


func _errors(change: Callable) -> PackedStringArray:
	var raw: Dictionary = _raw()
	change.call(raw)
	var found: PackedStringArray = []
	DataValidator.validate(raw, found)
	return found


func _has(errors: PackedStringArray, text: String) -> bool:
	for message: String in errors:
		if message.contains(text):
			return true
	return false


func _bands(raw: Dictionary) -> Array:
	return (raw["auction_population"].values()[0] as Dictionary)["bands"] as Array


func _auction(raw: Dictionary) -> Dictionary:
	return (raw["balance"].values()[0] as Dictionary)["auction"] as Dictionary


func test_validator_accepts_the_real_data() -> void:
	assert_eq(_errors(func(_raw_data: Dictionary) -> void: pass), PackedStringArray())


func test_validator_rejects_bad_bands() -> void:
	var errors: PackedStringArray = _errors(func(raw: Dictionary) -> void: _bands(raw)[1]["max_value"] = 9)
	assert_true(_has(errors, "strictly increasing"), str(errors))
	errors = _errors(func(raw: Dictionary) -> void: _bands(raw)[3]["max_value"] = 500)
	assert_true(_has(errors, "absent in the last band"), str(errors))
	errors = _errors(func(raw: Dictionary) -> void: _bands(raw)[0]["buyers"] = 0)
	assert_true(_has(errors, "buyers"), str(errors))
	errors = _errors(func(raw: Dictionary) -> void: _bands(raw)[0]["colour"] = 1)
	assert_false(errors.is_empty())
	errors = _errors(func(raw: Dictionary) -> void: (raw["auction_population"].values()[0] as Dictionary)["bands"] = [])
	assert_false(errors.is_empty())


func test_validator_rejects_bad_bounds() -> void:
	var errors: PackedStringArray = _errors(func(raw: Dictionary) -> void: (_auction(raw)["index"] as Dictionary)["max_pct"] = 125)
	assert_true(_has(errors, "highest pressure"), "MAX below BASE + AMP + PB+: %s" % [errors])
	errors = _errors(func(raw: Dictionary) -> void: (_auction(raw)["saturation"] as Dictionary)["max_pct"] = 55)
	assert_true(_has(errors, "saturation.max_pct"), "CAP too small: %s" % [errors])
	errors = _errors(func(raw: Dictionary) -> void: (_auction(raw)["saturation"] as Dictionary)["recover_pct_per_block"] = 0.3)
	assert_true(_has(errors, "offline cap"), "recovery beyond 12 hours: %s" % [errors])
	errors = _errors(func(raw: Dictionary) -> void: (_auction(raw)["population"] as Dictionary)["colour"] = 1)
	assert_true(_has(errors, "population"), "unknown key: %s" % [errors])
	errors = _errors(func(raw: Dictionary) -> void: _auction(raw).erase("population"))
	assert_false(errors.is_empty())


func _sat(pricing: AuctionPricing, id: StringName) -> int:
	return (((pricing.to_save()["items"] as Dictionary).get(String(id), {}) as Dictionary).get("sat", 0)) as int
