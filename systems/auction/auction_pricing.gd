class_name AuctionPricing
extends RefCounted
## The small interface of the Auction House prices (docs/05_INTERFACES.md §5.30, V15): given an item and the market state, the
## prices, the pieces on offer and the trend. The market state (seed, clock, saturation, taken) and every formula stay behind this class;
## a richer model (population) can replace it with the same API. Only this class uses AuctionMath.
##
## State: `seed`, `block` (whole market blocks since the market was born), `pending_ms` (0..block_ms-1) and, for the items away
## from rest, `sat` (saturation, ppm) and, for the buyable ones, `taken` (the cheapest pieces of the book already bought, F-216).

const LOG_CATEGORY: String = "auction"
const UP: StringName = &"up"
const DOWN: StringName = &"down"
const STABLE: StringName = &"stable"

var _p: AuctionParams
var _items: Dictionary[StringName, AuctionItemDef] = {}
var _value: Dictionary[StringName, int] = {}
var _seed: int = 1
var _block: int = 0
var _pending_ms: int = 0
var _sat: Dictionary[StringName, int] = {}
var _taken: Dictionary[StringName, int] = {}  # F-216: pieces taken from the book, only the items with taken > 0
var _eq_min: int = 0  # F-215
var _ref: AuctionReference
var _band: Dictionary[StringName, AuctionPopulationBand] = {}  # F-172: constant per item
var _liq: Dictionary[StringName, Dictionary] = {}  # F-172, F-216: {"step", "rec", "refill" (r_i)} per item


func _init(data: GameData) -> void:
	_p = data.auction_params()
	_eq_min = AuctionMath.eq_min(_p, _p.bands)
	_ref = AuctionReference.new(_p)
	for def: AuctionItemDef in data.auction_items():
		_items[def.item] = def
		_value[def.item] = data.item(def.item).value
		_band[def.item] = AuctionMath.band_of(_value[def.item], _p)
		_liq[def.item] = AuctionMath.liquidity(_value[def.item], _band[def.item], _p)


## New market: block 0, every item at rest (saturation 0, nothing taken).
func reset(seed_value: int) -> void:
	_seed = seed_value
	_block = 0
	_pending_ms = 0
	_sat.clear()
	_taken.clear()


func is_listed(item_id: StringName) -> bool:
	return _items.has(item_id)


func is_buyable(item_id: StringName) -> bool:
	return buy_level(item_id) >= 1


func buy_level(item_id: StringName) -> int:
	return (_items[item_id] as AuctionItemDef).buy_level if _items.has(item_id) else 0


## F-148: gold for selling `qty` pieces now; 0 if the item is not listed or `qty <= 0`.
func sell_quote(item_id: StringName, qty: int) -> int:
	if not _items.has(item_id) or qty <= 0:
		return 0
	return AuctionMath.gold_of(_value[item_id], AuctionMath.sale_sum_ppm(_equilibrium(item_id, _block), _sat.get(item_id, 0), qty, _p, _liq[item_id]["step"]))


## F-215: the cost of the `qty` cheapest available pieces of the book; 0 if `qty <= 0`, the item cannot be bought or `qty > available`.
func buy_quote(item_id: StringName, qty: int) -> int:
	return AuctionBuy.cost(buy_pieces(item_id), taken(item_id), qty)


## F-215: the book of the NPC listings as `(unit price, qty)` in F-178 order, with the scarcity of `taken` and the mark-up; `[]` if
## the item cannot be bought.
@warning_ignore("integer_division")
func buy_pieces(item_id: StringName) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not is_buyable(item_id):
		return result
	var idx: int = AuctionBuy.scarce_index(_index(item_id), taken(item_id), int(_liq[item_id]["step"]), _eq_min)
	for row: Vector3i in _npc_rows(item_id):
		var off: int = AuctionBook.ask_offset(item_id, _seed, _block / _p.book_persist, row.y, _p)
		result.append(Vector2i(AuctionMath.piece_price(AuctionBook.ask_price(_value[item_id], idx, off), _p.markup_ppm), row.z))
	return result


## F-215: the NPC listings in order as `{"j", "price" (F-178 ask), "buy_price", "qty", "left"}`; `[]` if the item cannot be bought.
func buy_book(item_id: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var pieces: Array[Vector2i] = buy_pieces(item_id)
	var rows: Array[Vector3i] = _npc_rows(item_id)
	var left: PackedInt32Array = AuctionBuy.left_of(pieces, taken(item_id))
	for i: int in pieces.size():
		result.append({"j": rows[i].y, "price": rows[i].x, "buy_price": pieces[i].x, "qty": pieces[i].y, "left": left[i]})
	return result


## F-215: the price of the cheapest available piece; 0 if none.
func buy_unit(item_id: StringName) -> int:
	return AuctionBuy.best_unit(buy_pieces(item_id), taken(item_id))


## F-178: the pieces on the NPC listings now (`V`); 0 if the item is not listed.
func volume(item_id: StringName) -> int:
	var total: int = 0
	for row: Vector3i in _npc_rows(item_id):
		total += row.z
	return total


## F-216: the pieces already taken from the book (0 if none or if the item cannot be bought).
func taken(item_id: StringName) -> int:
	return _taken.get(item_id, 0)


## F-215: `max(0, V - taken)`; 0 if the item cannot be bought.
func available(item_id: StringName) -> int:
	return AuctionBuy.available(volume(item_id), taken(item_id)) if is_buyable(item_id) else 0


## F-216: blocks until a piece is available (0 if one is, or if the item cannot be bought).
func restock_blocks(item_id: StringName) -> int:
	return AuctionBuy.restock_blocks(volume(item_id), taken(item_id), int(_liq[item_id]["refill"])) if is_buyable(item_id) else 0


## F-214: the median of the last `reference.window_epochs` epochs, `mode` `&"buy"` or `&"sell"`; 0 if not available.
@warning_ignore("integer_division")
func reference_price(item_id: StringName, mode: StringName) -> int:
	if not _items.has(item_id) or (mode == &"buy" and not is_buyable(item_id)):
		return 0
	return _ref.price(item_id, mode, _block / _p.book_persist, _seed, _value[item_id], _band[item_id])


## F-152: the forecast of the price after `trend.blocks` blocks without other trades.
func trend(item_id: StringName) -> StringName:
	if not _items.has(item_id):
		return STABLE
	var ahead: int = _p.trend_blocks
	var sat_next: int = maxi(0, _sat.get(item_id, 0) - ahead * int(_liq[item_id]["rec"]))
	var eq_next: int = _equilibrium(item_id, _block + ahead)
	return AuctionMath.trend_of(_index(item_id), AuctionMath.index_ppm(eq_next, sat_next, _p), _p)


## F-173, F-176: the population of the item now, `{"buyers", "sellers", "demand": &"high"|&"normal"|&"low"}`; `{}` if not listed.
func population(item_id: StringName) -> Dictionary:
	if not _items.has(item_id):
		return {}
	var pop: Vector2i = _population(item_id, _block)
	var press: int = AuctionMath.pressure(pop.x, pop.y, _p)
	var demand: StringName = &"normal"
	if press >= _p.pop_demand_ppm:
		demand = &"high"
	elif press <= -_p.pop_demand_ppm:
		demand = &"low"
	return {"buyers": pop.x, "sellers": pop.y, "demand": demand}


func block() -> int:
	return _block


func pending_ms() -> int:
	return _pending_ms


## Milliseconds to the next market block, 1..block_ms.
func ms_to_next_block() -> int:
	return _p.block_ms - _pending_ms


## `value` of the item in copper; 0 if it is not listed.
func value_of(item_id: StringName) -> int:
	return _value.get(item_id, 0)


## F-178: the NPC listings of the item at the current block with the current saturation, `(price, qty)` by price then `j`;
## `[]` if the item is not listed.
func npc_asks(item_id: StringName) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for row: Vector3i in _npc_rows(item_id):
		result.append(Vector2i(row.x, row.z))
	return result


## F-179: the pieces the buyers take at the current block; 0 if the item is not listed.
func demand(item_id: StringName) -> int:
	if not _items.has(item_id):
		return 0
	var pop: Vector2i = _population(item_id, _block)
	return AuctionBook.demand(volume(item_id), pop.x, pop.y, _p)


## F-180: the highest price of a listing of the item.
func max_price(item_id: StringName) -> int:
	return AuctionBook.max_price(_value.get(item_id, 0), _p)


## F-180: the deposit of a listing.
func deposit(item_id: StringName, qty: int, duration: AuctionDuration) -> int:
	return AuctionBook.deposit(_value.get(item_id, 0), qty, duration.deposit_ppm)


## F-180: `qty * price` minus the commission.
func listing_net(qty: int, price: int) -> int:
	return qty * price - AuctionBook.cut(qty * price, _p)


## F-148: `sat = min(CAP, sat + qty * STEP)`. No checks (AuctionHouse does them).
func record_sale(item_id: StringName, qty: int) -> void:
	if not _items.has(item_id) or qty <= 0:
		return
	_sat[item_id] = mini(_p.cap_ppm, _sat.get(item_id, 0) + qty * int(_liq[item_id]["step"]))


## F-216: `taken += qty`, at most `KMAX * stack` of the item.
func record_purchase(item_id: StringName, qty: int) -> void:
	if not is_buyable(item_id) or qty <= 0:
		return
	_taken[item_id] = mini(taken(item_id) + qty, _taken_max(item_id))


## F-145, F-149, F-216: adds `delta_ms` to the market clock; returns the whole blocks that passed (0 if none or `delta_ms <= 0`).
@warning_ignore("integer_division")
func advance(delta_ms: int) -> int:
	if delta_ms <= 0:
		return 0
	var t: int = _pending_ms + delta_ms
	var blocks: int = t / _p.block_ms
	_pending_ms = t % _p.block_ms
	if blocks == 0:
		return 0
	_block += blocks
	for id: StringName in _sat.keys():
		var left: int = maxi(0, _sat[id] - blocks * int(_liq[id]["rec"]))
		if left == 0:
			_sat.erase(id)
		else:
			_sat[id] = left
	for id: StringName in _taken.keys():
		var left: int = AuctionBuy.recover(_taken[id], blocks, int(_liq[id]["refill"]))
		if left == 0:
			_taken.erase(id)
		else:
			_taken[id] = left
	return blocks


## `{"seed", "block", "pending_ms", "items": {id: {"sat"}}, "taken": {id: n}}`: only the items away from rest.
func to_save() -> Dictionary:
	var items: Dictionary = {}
	for id: StringName in _sat:
		items[String(id)] = {"sat": _sat[id]}
	var taken_out: Dictionary = {}
	for id: StringName in _taken:
		taken_out[String(id)] = _taken[id]
	return {"seed": _seed, "block": _block, "pending_ms": _pending_ms, "items": items, "taken": taken_out}


## Tolerant load (docs/05_INTERFACES.md §5.30): a bad value is replaced by the rest value with a warning, an unknown item is dropped.
## A bad `seed` keeps the current one (AuctionHouse replaces it before calling). A `stock` of a v13 file is ignored.
func from_save(d: Dictionary) -> void:
	var seed_raw: Variant = _to_int(d.get("seed"))
	if seed_raw == null or int(seed_raw) <= 0:
		Log.warn(LOG_CATEGORY, "invalid seed %s: kept %d" % [str(d.get("seed")), _seed])
	else:
		_seed = int(seed_raw)
	var block: Variant = _to_int(d.get("block"))
	_block = int(block) if block != null and int(block) >= 0 else _warn_zero("block", d.get("block"))
	var pending: Variant = _to_int(d.get("pending_ms"))
	_pending_ms = int(pending) if pending != null and int(pending) >= 0 and int(pending) < _p.block_ms \
			else _warn_zero("pending_ms", d.get("pending_ms"))
	_sat.clear()
	_taken.clear()
	_load_taken(d.get("taken"))
	if not d.get("items") is Dictionary:
		Log.warn(LOG_CATEGORY, "invalid items %s: every item at rest" % str(d.get("items")))
		return
	var items: Dictionary = d["items"] as Dictionary
	for key: Variant in items:
		var id := StringName(str(key))
		if not _items.has(id) or not items[key] is Dictionary:
			Log.warn(LOG_CATEGORY, "item '%s' dropped" % str(key))
			continue
		_load_item(id, items[key] as Dictionary)


func _load_item(id: StringName, entry: Dictionary) -> void:
	if entry.has("sat"):
		var sat: Variant = _to_int(entry["sat"])
		var value: int = clampi(int(sat), 0, _p.cap_ppm) if sat != null else 0
		if sat == null or int(sat) < 0 or int(sat) > _p.cap_ppm:
			Log.warn(LOG_CATEGORY, "item '%s': saturation %s corrected to %d" % [id, str(entry["sat"]), value])
		if value > 0:
			_sat[id] = value


# 04_DATA_SCHEMA_M38.md §39.2: `taken` of the buyable items; an unknown or not buyable item or a bad value is dropped, a value over
# `KMAX * stack` is brought back to it.
func _load_taken(raw: Variant) -> void:
	if raw == null:
		return
	if not raw is Dictionary:
		Log.warn(LOG_CATEGORY, "invalid taken %s: nothing taken" % str(raw))
		return
	for key: Variant in raw as Dictionary:
		var id := StringName(str(key))
		var number: Variant = _to_int((raw as Dictionary)[key])
		if not is_buyable(id) or number == null or int(number) < 0:
			Log.warn(LOG_CATEGORY, "taken of '%s' dropped (%s)" % [str(key), str((raw as Dictionary)[key])])
			continue
		var value: int = mini(int(number), _taken_max(id))
		if value != int(number):
			Log.warn(LOG_CATEGORY, "taken of '%s': %d corrected to %d" % [id, int(number), value])
		if value > 0:
			_taken[id] = value


# F-216: `KMAX * stack`, the most pieces a book of the item can hold.
func _taken_max(item_id: StringName) -> int:
	return _p.book_max_listings * _band[item_id].stack


# F-178: the NPC listings as `(ask price, j, qty)` by price then `j`; `[]` if the item is not listed.
@warning_ignore("integer_division")
func _npc_rows(item_id: StringName) -> Array[Vector3i]:
	var rows: Array[Vector3i] = []
	if not _items.has(item_id):
		return rows
	var epoch: int = _block / _p.book_persist
	var index: int = _index(item_id)
	for j: int in AuctionBook.listing_count(_population(item_id, _block).y, _p):
		var price: int = AuctionBook.ask_price(_value[item_id], index, AuctionBook.ask_offset(item_id, _seed, epoch, j, _p))
		rows.append(Vector3i(price, j, AuctionBook.ask_qty(item_id, _seed, epoch, j, _band[item_id].stack)))
	rows.sort_custom(func(a: Vector3i, b: Vector3i) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y))
	return rows


# F-174: equilibrium of the item at `block` (base + slow drift + population pressure), and its index now.
func _equilibrium(item_id: StringName, block: int) -> int:
	var pop: Vector2i = _population(item_id, block)
	return _p.base_ppm + AuctionMath.drift(item_id, _seed, block, _p) + AuctionMath.pressure(pop.x, pop.y, _p)


# F-173: (buyers, sellers) of the item at `block`.
func _population(item_id: StringName, block: int) -> Vector2i:
	var band: AuctionPopulationBand = _band[item_id]
	return AuctionMath.population(band.buyers, band.sellers, AuctionMath.wave(item_id, "b", _seed, block, _p),
			AuctionMath.wave(item_id, "s", _seed, block, _p))


func _index(item_id: StringName) -> int:
	return AuctionMath.index_ppm(_equilibrium(item_id, _block), _sat.get(item_id, 0), _p)


func _warn_zero(key: String, raw: Variant) -> int:
	Log.warn(LOG_CATEGORY, "invalid %s %s: 0" % [key, str(raw)])
	return 0


# int from an int or an integral float (JSON); null otherwise.
func _to_int(v: Variant) -> Variant:
	if v is int:
		return v
	if v is float and is_finite(v as float) and (v as float) == floorf(v as float):
		return int(v as float)
	return null
