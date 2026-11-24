class_name AuctionMath
extends RefCounted
## The pure formulas of the Auction House (docs/02_FORMULAS.md §5k, F-145…F-152), on integers: indices, saturation and margins
## are ppm (1.000.000 = 100%), divisions truncate toward zero. No state: only AuctionPricing and the tests use it.

const PPM: int = 1000000
const FNV_OFFSET: int = 2166136261
const FNV_PRIME: int = 16777619
const MASK32: int = 0xFFFFFFFF


## F-146: 32-bit FNV-1a of the UTF-8 bytes of `text`.
static func fnv1a32(text: String) -> int:
	var h: int = FNV_OFFSET
	for byte: int in text.to_utf8_buffer():
		h = ((h ^ byte) * FNV_PRIME) & MASK32
	return h


## F-146: `fmix32(fnv1a32(utf8(text)))`, 0..2^32-1.
static func hash32(text: String) -> int:
	var h: int = fnv1a32(text)
	h ^= h >> 16
	h = (h * 0x85EBCA6B) & MASK32
	h ^= h >> 13
	h = (h * 0xC2B2AE35) & MASK32
	h ^= h >> 16
	return h


## F-146: node `i` of the slow variation of an item, in -AMP..+AMP.
static func knot(item_id: StringName, seed_value: int, i: int, p: AuctionParams) -> int:
	return hash32("%s|%d|%d" % [item_id, seed_value, i]) % (2 * p.amp_ppm + 1) - p.amp_ppm


## F-146: linear interpolation between two nodes every `period_blocks` blocks.
@warning_ignore("integer_division")
static func drift(item_id: StringName, seed_value: int, block: int, p: AuctionParams) -> int:
	var i: int = block / p.period_blocks
	var f: int = block % p.period_blocks
	var k0: int = knot(item_id, seed_value, i, p)
	var k1: int = knot(item_id, seed_value, i + 1, p)
	return k0 + ((k1 - k0) * f) / p.period_blocks


## F-147: `clamp(eq - sat, MIN, MAX)`.
static func index_ppm(eq_ppm: int, sat_ppm: int, p: AuctionParams) -> int:
	return clampi(eq_ppm - sat_ppm, p.min_ppm, p.max_ppm)


## `ceil_div(a, b)` for `a >= 0`, `b > 0`.
@warning_ignore("integer_division")
static func ceil_div(a: int, b: int) -> int:
	return (a + b - 1) / b


## F-148/F-175: the sum of the indices of `qty` pieces sold at once, in closed form (piece k has `eq - sat - k*STEP`, floored at MIN);
## `step_ppm` -1 = the base step of the parameters, otherwise the step of the item (STEP_i, F-172).
@warning_ignore("integer_division")
static func sale_sum_ppm(eq_ppm: int, sat_ppm: int, qty: int, p: AuctionParams, step_ppm: int = -1) -> int:
	var step: int = p.step_ppm if step_ppm < 0 else step_ppm
	var x0: int = eq_ppm - sat_ppm
	var above: int = 0 if x0 <= p.min_ppm else mini(qty, ceil_div(x0 - p.min_ppm, step))
	return above * x0 - step * (above * (above - 1) / 2) + (qty - above) * p.min_ppm


## F-148: gold of a sale, `(value * sum) / 1.000.000`.
@warning_ignore("integer_division")
static func gold_of(value: int, sum_ppm: int) -> int:
	return (value * sum_ppm) / PPM


## F-215: price of a piece, `ceil_div(ask * (PPM + MK), PPM)` (the Auction House mark-up on the listing price).
static func piece_price(ask: int, markup_ppm: int) -> int:
	return ceil_div(ask * (PPM + markup_ppm), PPM)


## F-214: the median of `values` (any order): the ascending element of index `n / 2` (the upper one for an even `n`); 0 if empty.
@warning_ignore("integer_division")
static func median(values: PackedInt64Array) -> int:
	if values.is_empty():
		return 0
	var sorted: PackedInt64Array = values.duplicate()
	sorted.sort()
	return sorted[sorted.size() / 2]


## F-174, F-215: `EQMIN = BASE - AMP - PB-`, the lowest equilibrium of any band (`bands` is `p.bands`).
static func eq_min(p: AuctionParams, bands: Array[AuctionPopulationBand]) -> int:
	var minus: int = 0
	for band: AuctionPopulationBand in bands:
		var lo: Vector2i = population(band.buyers, band.sellers, -p.pop_var_ppm, -p.pop_var_ppm)
		var hi: Vector2i = population(band.buyers, band.sellers, p.pop_var_ppm, p.pop_var_ppm)
		minus = maxi(minus, -pressure(lo.x, hi.y, p))
	return p.base_ppm - p.amp_ppm - minus


## F-216: pieces the sellers put back per block, `r_i = max(1, (Vn * REFILL + 500.000) / PPM)` with `Vn = (S0 / SPL) * ((stack + 1) / 2)`.
@warning_ignore("integer_division")
static func restock_rate(band: AuctionPopulationBand, p: AuctionParams) -> int:
	var nominal: int = (band.sellers / p.book_sellers_per_listing) * ((band.stack + 1) / 2)
	return maxi(1, (nominal * p.refill_ppm + PPM / 2) / PPM)


## F-152: `&"up"`, `&"down"` or `&"stable"` from the change of the index.
static func trend_of(now_ppm: int, next_ppm: int, p: AuctionParams) -> StringName:
	var d: int = next_ppm - now_ppm
	if d >= p.trend_threshold_ppm:
		return &"up"
	if d <= -p.trend_threshold_ppm:
		return &"down"
	return &"stable"


# --- M26-08: population (F-172…F-176, docs/02_FORMULAS_M26.md) ---------------------------------------------------------

## F-173: node `j` of the wave `kind` (`"b"` buyers, `"s"` sellers) of an item, in -VAR..+VAR.
static func wave_knot(item_id: StringName, kind: String, seed_value: int, j: int, p: AuctionParams) -> int:
	return hash32("%s|%s|%d|%d" % [item_id, kind, seed_value, j]) % (2 * p.pop_var_ppm + 1) - p.pop_var_ppm


## F-173: `w_k` at `block`, linear interpolation between two nodes every `pop_period_blocks` blocks.
@warning_ignore("integer_division")
static func wave(item_id: StringName, kind: String, seed_value: int, block: int, p: AuctionParams) -> int:
	var j: int = block / p.pop_period_blocks
	var f: int = block % p.pop_period_blocks
	var k0: int = wave_knot(item_id, kind, seed_value, j, p)
	var k1: int = wave_knot(item_id, kind, seed_value, j + 1, p)
	return k0 + ((k1 - k0) * f) / p.pop_period_blocks


## F-172: the first band with `value <= max_value` (the last one, open, if none).
static func band_of(value: int, p: AuctionParams) -> AuctionPopulationBand:
	for band: AuctionPopulationBand in p.bands:
		if band.max_value >= 0 and value <= band.max_value:
			return band
	return p.bands[p.bands.size() - 1]


## F-173: `(B, Sv)` from the base population and the waves (integers).
@warning_ignore("integer_division")
static func population(b0: int, s0: int, wb: int, ws: int) -> Vector2i:
	return Vector2i(b0 * (PPM + wb) / PPM, s0 * (PPM + ws) / PPM)


## F-173: `PRESS * (B - Sv) / (B + Sv)` (ppm).
@warning_ignore("integer_division")
static func pressure(buyers: int, sellers: int, p: AuctionParams) -> int:
	if buyers + sellers <= 0:
		return 0
	return p.pop_press_ppm * (buyers - sellers) / (buyers + sellers)


## F-172: the constants of an item from its band: `{"step", "rec", "refill"}` (ppm per piece, ppm per block, pieces per block).
@warning_ignore("integer_division")
static func liquidity(_value: int, band: AuctionPopulationBand, p: AuctionParams) -> Dictionary:
	return {
		"step": maxi(1, p.step_ppm * p.pop_ref / band.buyers),
		"rec": maxi(1, p.recover_ppm * band.buyers / p.pop_ref),
		"refill": restock_rate(band, p),
	}
