class_name DataValidatorAuctionBook
extends RefCounted
## Book and listing rules of DataValidatorAuction (M27-06; docs/04_DATA_SCHEMA_M27.md §32.3-§32.4, docs/02_FORMULAS_M27.md F-178…F-182):
## `auction.book` and `auction.listing` of balance.json, the `stack` of the population bands and the no-risk-free-gain constraint.

const BOOK_KEYS: PackedStringArray = ["persist_blocks", "ask_min_pct", "ask_max_pct", "sellers_per_listing", "min_listings", "max_listings", "fill_pct", "fill_max_pct"]
const LISTING_KEYS: PackedStringArray = ["max_active", "cut_pct", "max_price_pct", "durations"]
const DURATION_KEYS: PackedStringArray = ["id", "hours", "deposit_pct"]
const MAX_ITEM_VALUE: int = 1000000  # F-178: keeps `v * idx * (PPM + off)` below 2^62
const HOUR_MS: int = 3600000


## `auction.book` and `auction.listing` of balance.json (types and ranges); true if every key is valid.
static func validate_params(v: DataValidatorRules, auction: Dictionary) -> bool:
	var book: Dictionary = v.object(auction, "book", "auction")
	v.keys(book, BOOK_KEYS, "auction.book")
	var ok: bool = v.integer(book, "persist_blocks", 1.0, DataValidatorRules.NO_LIMIT, "auction.book")
	for key: String in ["ask_min_pct", "ask_max_pct", "fill_pct", "fill_max_pct"]:
		ok = v.number(book, key, 0.0, DataValidatorRules.NO_LIMIT, "auction.book") and ok
	ok = v.integer(book, "sellers_per_listing", 1.0, DataValidatorRules.NO_LIMIT, "auction.book") and ok
	ok = v.integer(book, "min_listings", 1.0, 50.0, "auction.book") and ok
	ok = v.integer(book, "max_listings", 1.0, 50.0, "auction.book") and ok
	var listing: Dictionary = v.object(auction, "listing", "auction")
	v.keys(listing, LISTING_KEYS, "auction.listing")
	ok = v.integer(listing, "max_active", 1.0, 50.0, "auction.listing") and ok
	ok = v.number(listing, "cut_pct", 0.0, 99.999, "auction.listing") and ok
	ok = v.number(listing, "max_price_pct", 100.0, DataValidatorRules.NO_LIMIT, "auction.listing") and ok
	var seen: Dictionary[String, bool] = {}
	var rows: Array[Dictionary] = v.object_list(listing, "durations", "auction.listing", 1)
	for index: int in rows.size():
		var row: Dictionary = rows[index]
		v.at_entry("auction duration", index, row)
		v.keys(row, DURATION_KEYS)
		if v.text(row, "id"):
			if seen.has(str(row["id"])):
				v.fail("duplicate duration '%s'" % row["id"])
			seen[str(row["id"])] = true
		ok = v.integer(row, "hours", 1.0) and ok
		ok = v.number(row, "deposit_pct", 0.0, DataValidatorRules.NO_LIMIT) and ok
	return ok and not rows.is_empty()


## F-182 and the ranges that tie the converted parameters together (`p` from `AuctionParams.from_dict`, valid).
static func relations(v: DataValidatorRules, p: AuctionParams) -> void:
	if p.book_lo_ppm >= p.book_hi_ppm:
		v.fail("key 'auction.book.ask_min_pct' must be below 'ask_max_pct'")
	if p.book_fill_ppm <= 0 or p.book_fill_ppm > p.book_fill_max_ppm:
		v.fail("key 'auction.book.fill_pct' must be above 0 and at most 'fill_max_pct'")
	if p.book_fill_max_ppm >= AuctionMath.PPM:
		v.fail("key 'auction.book.fill_max_pct' must be below 100")
	if p.book_min_listings > p.book_max_listings:
		v.fail("key 'auction.book.min_listings' must be at most 'max_listings'")
	if p.listing_cut_ppm >= AuctionMath.PPM:
		v.fail("key 'auction.listing.cut_pct' must be below 100")
	# F-182: a piece bought from the counter costs more than any sale can give (no gain without risk).
	if (p.min_ppm + p.spread_ppm) * AuctionMath.PPM <= p.max_ppm * (AuctionMath.PPM + p.book_hi_ppm):
		v.fail("key 'auction.book.ask_max_pct' is too high: (min_pct + spread_pct) must stay above max_pct * (1 + ask_max_pct) (F-182)")
	for duration: AuctionDuration in p.durations:
		if (duration.hours * HOUR_MS) % maxi(1, p.block_ms) != 0:
			v.fail("duration '%s': %d hours is not a whole number of market blocks" % [duration.id, duration.hours])

