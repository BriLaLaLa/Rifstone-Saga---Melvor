class_name AuctionPricing
extends RefCounted
## The small interface of the Auction House prices (docs/05_INTERFACES.md §5.30, V15): given an item and the market state, the
## prices, the stock and the trend. The market state (seed, clock, saturation, stock) and every formula stay behind this class;
## a richer model (population) can replace it with the same API. Only this class uses AuctionMath.
##
## State: `seed`, `block` (whole market blocks since the market was born), `pending_ms` (0..block_ms-1) and, for the items away
## from rest, `sat` (saturation, ppm) and `stock`. An item at rest (sat 0, full stock) has no entry.

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
var _stock: Dictionary[StringName, int] = {}
var _band: Dictionary[StringName, AuctionPopulationBand] = {}  # F-172: constant per item
var _liq: Dictionary[StringName, Dictionary] = {}  # F-172: {"step", "rec", "refill"} per item


func _init(data: GameData) -> void:
	_p = data.auction_params()
	for def: AuctionItemDef in data.auction_items():
		_items[def.item] = def
		_value[def.item] = data.item(def.item).value
		_band[def.item] = AuctionMath.band_of(_value[def.item], _p)
		_liq[def.item] = AuctionMath.liquidity(_value[def.item], _band[def.item], _p)


## New market: block 0, every item at rest (saturation 0, full stock).
func reset(seed_value: int) -> void:
	_seed = seed_value
	_block = 0
	_pending_ms = 0
	_sat.clear()
	_stock.clear()


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


## F-151: `qty * unit`; 0 if the item cannot be bought or `qty <= 0` (the stock is not looked at).
func buy_quote(item_id: StringName, qty: int) -> int:
	if not is_buyable(item_id) or qty <= 0:
		return 0
	return qty * AuctionMath.buy_unit(_value[item_id], _index(item_id), _p)


## F-150: current stock (0 if the item cannot be bought).
func stock(item_id: StringName) -> int:
	if not is_buyable(item_id):
		return 0
	return _stock.get(item_id, stock_max(item_id))


## F-150: maximum stock `S` (0 if the item cannot be bought).
func stock_max(item_id: StringName) -> int:
	return AuctionMath.stock_max(_value[item_id], _p) if is_buyable(item_id) else 0


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
@warning_ignore("integer_division")
func npc_asks(item_id: StringName) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not _items.has(item_id):
		return result
	var epoch: int = _block / _p.book_persist
	var index: int = _index(item_id)
	var rows: Array[Vector3i] = []  # (price, j, qty)
	for j: int in AuctionBook.listing_count(_population(item_id, _block).y, _p):
		var price: int = AuctionBook.ask_price(_value[item_id], index, AuctionBook.ask_offset(item_id, _seed, epoch, j, _p))
		rows.append(Vector3i(price, j, AuctionBook.ask_qty(item_id, _seed, epoch, j, _band[item_id].stack)))
	rows.sort_custom(func(a: Vector3i, b: Vector3i) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y))
	for row: Vector3i in rows:
		result.append(Vector2i(row.x, row.z))
	return result


## F-179: the pieces the buyers take at the current block; 0 if the item is not listed.
func demand(item_id: StringName) -> int:
	if not _items.has(item_id):
		return 0
	var volume: int = 0
	for ask: Vector2i in npc_asks(item_id):
		volume += ask.y
	var pop: Vector2i = _population(item_id, _block)
	return AuctionBook.demand(volume, pop.x, pop.y, _p)


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


## F-150: `stock -= qty`, never below 0.
func record_purchase(item_id: StringName, qty: int) -> void:
	if not is_buyable(item_id) or qty <= 0:
		return
	var left: int = maxi(0, stock(item_id) - qty)
	if left >= stock_max(item_id):
		_stock.erase(item_id)
	else:
		_stock[item_id] = left


## F-145, F-149, F-150: adds `delta_ms` to the market clock; returns the whole blocks that passed (0 if none or `delta_ms <= 0`).
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
	for id: StringName in _stock.keys():
		var cap: int = stock_max(id)
		var refilled: int = mini(cap, _stock[id] + blocks * int(_liq[id]["refill"]))
		if refilled >= cap:
			_stock.erase(id)
		else:
			_stock[id] = refilled
	return blocks


## `{"seed", "block", "pending_ms", "items": {id: {"sat"?, "stock"?}}}`: only the items away from rest, with the keys that differ.
func to_save() -> Dictionary:
	var items: Dictionary = {}
	for id: StringName in _sat:
		items[String(id)] = {"sat": _sat[id]}
	for id: StringName in _stock:
		(items.get_or_add(String(id), {}) as Dictionary)["stock"] = _stock[id]
	return {"seed": _seed, "block": _block, "pending_ms": _pending_ms, "items": items}


## Tolerant load (docs/05_INTERFACES.md §5.30): a bad value is replaced by the rest value with a warning, an unknown item is dropped.
## A bad `seed` keeps the current one (AuctionHouse replaces it before calling).
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
	_stock.clear()
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
	if entry.has("stock") and is_buyable(id):
		var cap: int = stock_max(id)
		var stock_raw: Variant = _to_int(entry["stock"])
		var value: int = clampi(int(stock_raw), 0, cap) if stock_raw != null else cap
		if stock_raw == null or int(stock_raw) < 0 or int(stock_raw) > cap:
			Log.warn(LOG_CATEGORY, "item '%s': stock %s corrected to %d" % [id, str(entry["stock"]), value])
		if value < cap:
			_stock[id] = value


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
