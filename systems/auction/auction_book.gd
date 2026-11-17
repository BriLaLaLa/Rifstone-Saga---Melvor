class_name AuctionBook
extends RefCounted
## The pure formulas of the Auction House book (docs/02_FORMULAS_M27.md F-178…F-180), on integers (ppm = 1.000.000, divisions
## truncate toward zero). No state and no rolls: the hashes of AuctionMath decide. Used by AuctionPricing and AuctionListings only.

const PPM: int = AuctionMath.PPM


## F-178: number of NPC listings `K = clamp(sellers / SPL, KMIN, KMAX)`.
@warning_ignore("integer_division")
static func listing_count(sellers: int, p: AuctionParams) -> int:
	return clampi(sellers / p.book_sellers_per_listing, p.book_min_listings, p.book_max_listings)


## F-178: mark-up `off_j` of the listing `j` of an epoch, in `LO..HI` ppm.
static func ask_offset(item_id: StringName, seed_value: int, epoch: int, j: int, p: AuctionParams) -> int:
	var h: int = AuctionMath.hash32("%s|ask|%d|%d|%d" % [item_id, seed_value, epoch, j])
	return p.book_lo_ppm + h % (p.book_hi_ppm - p.book_lo_ppm + 1)


## F-178: quantity `q_j` of the listing `j` of an epoch, in `1..stack`.
static func ask_qty(item_id: StringName, seed_value: int, epoch: int, j: int, stack: int) -> int:
	return 1 + AuctionMath.hash32("%s|qty|%d|%d|%d" % [item_id, seed_value, epoch, j]) % stack


## F-178: price per piece `max(1, v * idx * (PPM + off) / PPM^2)`.
@warning_ignore("integer_division")
static func ask_price(value: int, index_ppm: int, offset_ppm: int) -> int:
	return maxi(1, (value * index_ppm * (PPM + offset_ppm)) / (PPM * PPM))


## F-179: pieces the buyers take in a block, `V * min(FMAX, FILL * B / Sv) / PPM`.
@warning_ignore("integer_division")
static func demand(volume: int, buyers: int, sellers: int, p: AuctionParams) -> int:
	var fill: int = p.book_fill_max_ppm if sellers <= 0 else mini(p.book_fill_max_ppm, p.book_fill_ppm * buyers / sellers)
	return volume * fill / PPM


## F-179: pieces sold of a listing with `remaining` pieces and `ahead` pieces in front of it, `clamp(D - ahead, 0, r)`.
static func fill(demand_value: int, ahead: int, remaining: int) -> int:
	return clampi(demand_value - ahead, 0, remaining)


## F-180: deposit `max(1, ceil_div(v * qty * DEP, PPM))`.
static func deposit(value: int, qty: int, deposit_ppm: int) -> int:
	return maxi(1, AuctionMath.ceil_div(value * qty * deposit_ppm, PPM))


## F-180: commission `ceil_div(gross * CUT, PPM)`.
static func cut(gross: int, p: AuctionParams) -> int:
	return AuctionMath.ceil_div(gross * p.listing_cut_ppm, PPM)


## F-180: the highest price of a listing, `max(1, v * MAXP / PPM)`.
@warning_ignore("integer_division")
static func max_price(value: int, p: AuctionParams) -> int:
	return maxi(1, value * p.listing_max_price_ppm / PPM)
