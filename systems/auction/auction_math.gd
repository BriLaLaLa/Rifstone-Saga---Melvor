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


## F-148: the sum of the indices of `qty` pieces sold at once, in closed form (piece k has `eq - sat - k*STEP`, floored at MIN).
@warning_ignore("integer_division")
static func sale_sum_ppm(eq_ppm: int, sat_ppm: int, qty: int, p: AuctionParams) -> int:
	var x0: int = eq_ppm - sat_ppm
	var above: int = 0 if x0 <= p.min_ppm else mini(qty, ceil_div(x0 - p.min_ppm, p.step_ppm))
	return above * x0 - p.step_ppm * (above * (above - 1) / 2) + (qty - above) * p.min_ppm


## F-148: gold of a sale, `(value * sum) / 1.000.000`.
@warning_ignore("integer_division")
static func gold_of(value: int, sum_ppm: int) -> int:
	return (value * sum_ppm) / PPM


## F-150: maximum stock `S(v) = clamp(stock.gold / v, stock.min, stock.max)`.
@warning_ignore("integer_division")
static func stock_max(value: int, p: AuctionParams) -> int:
	return clampi(p.stock_gold / maxi(1, value), p.stock_min, p.stock_max)


## F-150: refill per block `r(S) = max(1, (S * REFILL + 500.000) / 1.000.000)`.
@warning_ignore("integer_division")
static func refill_per_block(stock_cap: int, p: AuctionParams) -> int:
	return maxi(1, (stock_cap * p.refill_ppm + PPM / 2) / PPM)


## F-151: price of one piece, `ceil_div(v * (index + SPREAD), 1.000.000)`.
static func buy_unit(value: int, index: int, p: AuctionParams) -> int:
	return ceil_div(value * (index + p.spread_ppm), PPM)


## F-152: `&"up"`, `&"down"` or `&"stable"` from the change of the index.
static func trend_of(now_ppm: int, next_ppm: int, p: AuctionParams) -> StringName:
	var d: int = next_ppm - now_ppm
	if d >= p.trend_threshold_ppm:
		return &"up"
	if d <= -p.trend_threshold_ppm:
		return &"down"
	return &"stable"
