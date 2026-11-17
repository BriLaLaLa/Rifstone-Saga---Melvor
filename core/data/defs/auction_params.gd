class_name AuctionParams
extends RefCounted
## The `auction` section of balance.json (docs/04_DATA_SCHEMA.md §28, docs/02_FORMULAS.md §5k), converted once into
## integers: every `*_pct` key becomes ppm (parts per million, 1.000.000 = 100%) with `roundi(pct * 10000)`.
## `from_dict` returns null (after logging, see DefReader) if a key is missing or mistyped; ranges are the validator's job.

const PPM_PER_PCT: float = 10000.0

var block_ms: int = 0
var base_ppm: int = 0
var min_ppm: int = 0
var max_ppm: int = 0
var amp_ppm: int = 0
var period_blocks: int = 0
var step_ppm: int = 0
var cap_ppm: int = 0
var recover_ppm: int = 0
var spread_ppm: int = 0
var stock_gold: int = 0
var stock_min: int = 0
var stock_max: int = 0
var refill_ppm: int = 0
var trend_blocks: int = 0
var trend_threshold_ppm: int = 0
# M26-08 population (F-172…F-176): `auction.population` and the bands of data/auction/population.json (set by AuctionIndex).
var pop_ref: int = 0
var pop_period_blocks: int = 0
var pop_var_ppm: int = 0
var pop_press_ppm: int = 0
var pop_demand_ppm: int = 0
var bands: Array[AuctionPopulationBand] = []


static func from_dict(d: Dictionary) -> AuctionParams:
	var r := DefReader.new(d, "balance auction")
	var p := AuctionParams.new()
	p.block_ms = r.integer("block_ms")
	var index := DefReader.new(r.dict("index"), "balance auction.index")
	p.base_ppm = ppm(index.number("base_pct"))
	p.min_ppm = ppm(index.number("min_pct"))
	p.max_ppm = ppm(index.number("max_pct"))
	var drift := DefReader.new(r.dict("drift"), "balance auction.drift")
	p.amp_ppm = ppm(drift.number("amplitude_pct"))
	p.period_blocks = drift.integer("period_blocks")
	var sat := DefReader.new(r.dict("saturation"), "balance auction.saturation")
	p.step_ppm = ppm(sat.number("per_unit_pct"))
	p.cap_ppm = ppm(sat.number("max_pct"))
	p.recover_ppm = ppm(sat.number("recover_pct_per_block"))
	var buy := DefReader.new(r.dict("buy"), "balance auction.buy")
	p.spread_ppm = ppm(buy.number("spread_pct"))
	var stock := DefReader.new(r.dict("stock"), "balance auction.stock")
	p.stock_gold = stock.integer("gold")
	p.stock_min = stock.integer("min")
	p.stock_max = stock.integer("max")
	p.refill_ppm = ppm(stock.number("refill_pct_per_block"))
	var trend := DefReader.new(r.dict("trend"), "balance auction.trend")
	p.trend_blocks = trend.integer("blocks")
	p.trend_threshold_ppm = ppm(trend.number("threshold_pct"))
	var pop := DefReader.new(r.dict("population"), "balance auction.population")
	p.pop_ref = pop.integer("ref")
	p.pop_period_blocks = pop.integer("period_blocks")
	p.pop_var_ppm = ppm(pop.number("variation_pct"))
	p.pop_press_ppm = ppm(pop.number("pressure_pct"))
	p.pop_demand_ppm = ppm(pop.number("demand_threshold_pct"))
	for child: DefReader in [index, drift, sat, buy, stock, trend, pop]:
		r.absorb(child.ok)
	return p if r.ok else null


## The single percent-to-ppm conversion (F-145…F-152 convention).
static func ppm(pct: float) -> int:
	return roundi(pct * PPM_PER_PCT)
