class_name AuctionParams
extends RefCounted
## The `auction` section of balance.json (docs/04_DATA_SCHEMA.md §28, docs/02_FORMULAS.md §5k), converted once into
## integers: every `*_pct` key becomes ppm (parts per million, 1.000.000 = 100%) with `roundi(pct * 10000)`.
## `from_dict` returns null (after logging, see DefReader) if a key is missing or mistyped; ranges are the validator's job.

const PPM_PER_PCT: float = 10000.0

var block_ms: int = 0
var history_max: int = 0  # M37: the length of the sales history (F-209)
var base_ppm: int = 0
var min_ppm: int = 0
var max_ppm: int = 0
var amp_ppm: int = 0
var period_blocks: int = 0
var step_ppm: int = 0
var cap_ppm: int = 0
var recover_ppm: int = 0
var markup_ppm: int = 0  # M38: the mark-up of the Auction House on a listing price (F-215)
var confirm_share_ppm: int = 0  # F-218
var confirm_premium_ppm: int = 0  # F-218
var reference_epochs: int = 0  # F-214
var refill_ppm: int = 0  # F-216: `auction.supply.refill_pct_per_block`
var trend_blocks: int = 0
var trend_threshold_ppm: int = 0
# M26-08 population (F-172…F-176): `auction.population` and the bands of data/auction/population.json (set by AuctionIndex).
var pop_ref: int = 0
var pop_period_blocks: int = 0
var pop_var_ppm: int = 0
var pop_press_ppm: int = 0
var pop_demand_ppm: int = 0
var bands: Array[AuctionPopulationBand] = []
# M27-06 book and player listings (F-178…F-182): `auction.book`, `auction.listing`.
var book_persist: int = 0
var book_lo_ppm: int = 0
var book_hi_ppm: int = 0
var book_sellers_per_listing: int = 0
var book_min_listings: int = 0
var book_max_listings: int = 0
var book_fill_ppm: int = 0
var book_fill_max_ppm: int = 0
var listing_max_active: int = 0
var listing_cut_ppm: int = 0
var listing_max_price_ppm: int = 0
var durations: Array[AuctionDuration] = []


static func from_dict(d: Dictionary) -> AuctionParams:
	var r := DefReader.new(d, "balance auction")
	var p := AuctionParams.new()
	p.block_ms = r.integer("block_ms")
	p.history_max = r.integer("history_max")
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
	p.markup_ppm = ppm(buy.number("markup_pct"))
	p.confirm_share_ppm = ppm(buy.number("confirm_share_pct"))
	p.confirm_premium_ppm = ppm(buy.number("confirm_premium_pct"))
	var supply := DefReader.new(r.dict("supply"), "balance auction.supply")
	p.refill_ppm = ppm(supply.number("refill_pct_per_block"))
	var reference := DefReader.new(r.dict("reference"), "balance auction.reference")
	p.reference_epochs = reference.integer("window_epochs")
	var trend := DefReader.new(r.dict("trend"), "balance auction.trend")
	p.trend_blocks = trend.integer("blocks")
	p.trend_threshold_ppm = ppm(trend.number("threshold_pct"))
	var pop := DefReader.new(r.dict("population"), "balance auction.population")
	p.pop_ref = pop.integer("ref")
	p.pop_period_blocks = pop.integer("period_blocks")
	p.pop_var_ppm = ppm(pop.number("variation_pct"))
	p.pop_press_ppm = ppm(pop.number("pressure_pct"))
	p.pop_demand_ppm = ppm(pop.number("demand_threshold_pct"))
	var book := DefReader.new(r.dict("book"), "balance auction.book")
	p.book_persist = book.integer("persist_blocks")
	p.book_lo_ppm = ppm(book.number("ask_min_pct"))
	p.book_hi_ppm = ppm(book.number("ask_max_pct"))
	p.book_sellers_per_listing = book.integer("sellers_per_listing")
	p.book_min_listings = book.integer("min_listings")
	p.book_max_listings = book.integer("max_listings")
	p.book_fill_ppm = ppm(book.number("fill_pct"))
	p.book_fill_max_ppm = ppm(book.number("fill_max_pct"))
	var listing := DefReader.new(r.dict("listing"), "balance auction.listing")
	p.listing_max_active = listing.integer("max_active")
	p.listing_cut_ppm = ppm(listing.number("cut_pct"))
	p.listing_max_price_ppm = ppm(listing.number("max_price_pct"))
	for row: Dictionary in listing.dict_list("durations"):
		var duration: AuctionDuration = AuctionDuration.from_dict(row, p.block_ms)
		if duration == null:
			listing.fail("a duration cannot be built")
		else:
			p.durations.append(duration)
	for child: DefReader in [index, drift, sat, buy, supply, reference, trend, pop, book, listing]:
		r.absorb(child.ok)
	return p if r.ok else null


## The single percent-to-ppm conversion (F-145…F-152 convention).
static func ppm(pct: float) -> int:
	return roundi(pct * PPM_PER_PCT)
