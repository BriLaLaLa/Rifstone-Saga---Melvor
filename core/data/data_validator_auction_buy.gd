class_name DataValidatorAuctionBuy
extends RefCounted
## Buying rules of DataValidatorAuction (M38-1; docs/04_DATA_SCHEMA_M38.md §39, docs/02_FORMULAS_M38.md F-214…F-217): the `buy`, `supply`
## and `reference` keys of balance.json, the no-risk-free-gain constraint (F-217), the restock bound (F-216) and the blueprint cost.

const PPM: int = AuctionMath.PPM
const BUY_KEYS: PackedStringArray = ["markup_pct", "blueprint_margin_pct", "confirm_share_pct", "confirm_premium_pct"]
const MAX_MARKUP_PCT: float = 1000.0


## `auction.buy`, `auction.supply` and `auction.reference` of balance.json (types and ranges); true if every key is valid.
static func validate_params(v: DataValidatorRules, auction: Dictionary) -> bool:
	var buy: Dictionary = v.object(auction, "buy", "auction")
	v.keys(buy, BUY_KEYS, "auction.buy")
	var ok: bool = v.number(buy, "markup_pct", 0.0, DataValidatorRules.NO_LIMIT, "auction.buy")
	if ok and float(buy["markup_pct"]) >= MAX_MARKUP_PCT:
		v.fail("key 'auction.buy.markup_pct' must be below %d" % int(MAX_MARKUP_PCT))
		ok = false
	ok = v.number(buy, "blueprint_margin_pct", 0.0, DataValidatorRules.NO_LIMIT, "auction.buy") and ok
	ok = v.number(buy, "confirm_share_pct", 0.0, 100.0, "auction.buy", true) and ok
	ok = v.number(buy, "confirm_premium_pct", 0.0, DataValidatorRules.NO_LIMIT, "auction.buy") and ok
	var supply: Dictionary = v.object(auction, "supply", "auction")
	v.keys(supply, ["refill_pct_per_block"], "auction.supply")
	if v.number(supply, "refill_pct_per_block", 0.0, DataValidatorRules.NO_LIMIT, "auction.supply", true):
		if AuctionParams.ppm(float(supply["refill_pct_per_block"])) < 1:
			v.fail("key 'auction.supply.refill_pct_per_block' is below 1 ppm (0.0001 %)")
			ok = false
	else:
		ok = false
	var reference: Dictionary = v.object(auction, "reference", "auction")
	v.keys(reference, ["window_epochs"], "auction.reference")
	ok = v.integer(reference, "window_epochs", 1.0, 200.0, "auction.reference") and ok
	return ok


## F-217: `EQMIN * (PPM + MK) * PPM > MAX * (PPM + HI) * (PPM - CUT)`: buying and selling back always loses gold. Written as
## `EQMIN * (PPM + MK) > floor(MAX * (PPM + HI) * (PPM - CUT) / PPM)`, which is the same for integers and cannot overflow.
@warning_ignore("integer_division")
static func no_free_gain(p: AuctionParams, eq_min: int) -> bool:
	return eq_min * (PPM + p.markup_ppm) > p.max_ppm * (PPM + p.book_hi_ppm) * (PPM - p.listing_cut_ppm) / PPM


## F-216, F-217 on the converted parameters with `p.bands` set: the constraint of F-217 and, for every band, a book of `KMAX * stack`
## pieces restocks in at most `offline_blocks` blocks.
static func relations(v: DataValidatorRules, p: AuctionParams, offline_blocks: int) -> void:
	if not no_free_gain(p, AuctionMath.eq_min(p, p.bands)):
		v.fail("key 'auction.buy.markup_pct' is too low: EQMIN * (1 + markup) must stay above max_pct * (1 + ask_max_pct) * (1 - cut_pct) (F-217: buying and selling back must lose gold)")
	for band: AuctionPopulationBand in p.bands:
		var rate: int = AuctionMath.restock_rate(band, p)
		var blocks: int = AuctionMath.ceil_div(p.book_max_listings * band.stack, rate)
		if blocks > offline_blocks:
			v.fail("key 'auction.supply.refill_pct_per_block': a book of %d pieces needs %d blocks to restock, more than the offline cap (%d, F-216)"
					% [p.book_max_listings * band.stack, blocks, offline_blocks])


## F-217: the cost of one part of a blueprint, `ceil_div(floor(v * EQMIN / PPM) * (PPM + MK), PPM)` if it can be bought, else `v`.
@warning_ignore("integer_division")
static func part_cost(value: int, buyable: bool, p: AuctionParams, eq_min: int) -> int:
	return AuctionMath.piece_price(value * eq_min / PPM, p.markup_ppm) if buyable else value
