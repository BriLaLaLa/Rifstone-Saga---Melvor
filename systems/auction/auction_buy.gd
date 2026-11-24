class_name AuctionBuy
extends RefCounted
## The pure formulas of buying from the book (docs/02_FORMULAS_M38.md F-215, F-216, F-218), on integers. A book of pieces is
## `Array[Vector2i]` of `(unit price, qty)` in F-178 order; `taken` is the number of cheapest pieces already bought. No state:
## used by AuctionPricing, AuctionView and the tests.

const PPM: int = AuctionMath.PPM


## F-215: `idx_b = max(idx + taken * STEP_i, EQMIN)`.
static func scarce_index(index_ppm: int, taken: int, step_ppm: int, eq_min_ppm: int) -> int:
	return maxi(index_ppm + taken * step_ppm, eq_min_ppm)


## F-215: the pieces of the book that are still there, `max(0, V - taken)`.
static func available(volume: int, taken: int) -> int:
	return maxi(0, volume - taken)


## F-215: the total number of pieces `V` of a book.
static func volume(book: Array[Vector2i]) -> int:
	var total: int = 0
	for row: Vector2i in book:
		total += row.y
	return total


## F-215: gold for the `qty` cheapest available pieces (positions `taken` ... `taken + qty - 1`); 0 if `qty <= 0` or `qty` > available.
static func cost(book: Array[Vector2i], taken: int, qty: int) -> int:
	if qty <= 0 or qty > available(volume(book), taken):
		return 0
	var skip: int = taken
	var need: int = qty
	var total: int = 0
	for row: Vector2i in book:
		var here: int = row.y
		if skip >= here:
			skip -= here
			continue
		var count: int = mini(need, here - skip)
		skip = 0
		total += count * row.x
		need -= count
		if need == 0:
			break
	return total


## F-215: price of the cheapest available piece; 0 if none is left.
static func best_unit(book: Array[Vector2i], taken: int) -> int:
	var skip: int = taken
	for row: Vector2i in book:
		if skip < row.y:
			return row.x
		skip -= row.y
	return 0


## F-211: the most pieces affordable with `gold` among the available ones (one pass over the book); 0 if none.
@warning_ignore("integer_division")
static func max_qty(book: Array[Vector2i], taken: int, gold: int) -> int:
	var skip: int = taken
	var left: int = gold
	var count: int = 0
	for row: Vector2i in book:
		var here: int = row.y - skip
		skip = maxi(0, skip - row.y)
		if here <= 0:
			continue
		var fit: int = mini(here, left / row.x)
		count += fit
		left -= fit * row.x
		if fit < here:
			break
	return count


## F-215: for each listing of the book the pieces not yet taken, `left` (0..qty).
static func left_of(book: Array[Vector2i], taken: int) -> PackedInt32Array:
	var result: PackedInt32Array = []
	var skip: int = taken
	for row: Vector2i in book:
		result.append(clampi(row.y - skip, 0, row.y))
		skip = maxi(0, skip - row.y)
	return result


## F-216: blocks until at least one piece is available (0 if one is): `ceil_div(taken - V + 1, r_i)`.
static func restock_blocks(volume_value: int, taken: int, rate: int) -> int:
	if volume_value > taken:
		return 0
	return AuctionMath.ceil_div(taken - volume_value + 1, maxi(1, rate))


## F-216: `taken` after `blocks` blocks of restocking, `max(0, taken - blocks * r_i)`.
static func recover(taken: int, blocks: int, rate: int) -> int:
	return maxi(0, taken - blocks * rate)


## F-218: `{"total", "avg", "best", "share_ppm", "premium_ppm", "large"}` for buying `qty` of `avail` pieces at the cost `total`
## with `best` the price of the cheapest piece; `{}` if `qty <= 0` or more than `avail`. `avg` is rounded half up.
@warning_ignore("integer_division")
static func preview(total: int, qty: int, avail: int, best: int, share_ppm: int, premium_ppm: int) -> Dictionary:
	if qty <= 0 or avail <= 0 or qty > avail or best <= 0:
		return {}
	var share: int = qty * PPM / avail
	var premium: int = maxi(0, total * PPM / (qty * best) - PPM)
	var large: bool = qty * PPM >= share_ppm * avail or total * PPM >= qty * best * (PPM + premium_ppm)
	return {"total": total, "avg": (2 * total + qty) / (2 * qty), "best": best, "share_ppm": share, "premium_ppm": premium, "large": large}
