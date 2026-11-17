class_name AuctionListings
extends RefCounted
## The player's listings of the Auction House (docs/02_FORMULAS_M27.md F-179, F-180; docs/05_INTERFACES_M27.md §5.39): the state of
## every active listing and the block cycle that sells, charges the commission and closes them. No wallet, no bank, no mail: the
## AuctionHouse turns the events of `process_block` into messages. No rolls (the NPC book is a function of the market).
##
## A listing is `{"id","item","qty" (pieces left),"sold","earned" (net),"price","duration","start","end"}`, blocks are market blocks.

const LOG_CATEGORY: String = "auction"

var _p: AuctionParams
var _list: Array[Dictionary] = []  # id ascending
var _next: int = 1


func _init(params: AuctionParams) -> void:
	_p = params


func all() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for listing: Dictionary in _list:
		result.append(listing.duplicate())
	return result


## The active listings of the item, ordered by (price, id).
func of_item(item_id: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for listing: Dictionary in _list:
		if listing["item"] == item_id:
			result.append(listing.duplicate())
	result.sort_custom(_before)
	return result


## `{}` if there is none.
func get_listing(listing_id: int) -> Dictionary:
	var index: int = _index_of(listing_id)
	return (_list[index] as Dictionary).duplicate() if index >= 0 else {}


func count() -> int:
	return _list.size()


## F-180: the new listing, from `start_block` to `start_block + duration.blocks`; returns its id.
func add(item_id: StringName, qty: int, price: int, duration: AuctionDuration, start_block: int) -> int:
	var listing_id: int = _next
	_next += 1
	_list.append({"id": listing_id, "item": item_id, "qty": qty, "sold": 0, "earned": 0, "price": price,
			"duration": duration.id, "start": start_block, "end": start_block + duration.blocks})
	return listing_id


## The listing taken away (`{}` if there is none); the pieces left are the caller's business.
func remove(listing_id: int) -> Dictionary:
	var index: int = _index_of(listing_id)
	if index < 0:
		return {}
	var removed: Dictionary = _list[index]
	_list.remove_at(index)
	return removed


## F-179: the NPC pieces priced at or below the listing plus the pieces left of the listings of the same item in front of it.
func ahead_of(listing_id: int, npc: Array[Vector2i]) -> int:
	var index: int = _index_of(listing_id)
	if index < 0:
		return 0
	var listing: Dictionary = _list[index]
	return _ahead(listing, _group(listing["item"], -1), npc)


## F-180 steps 2-4 and 6 at `block` (the market is already there): sales with the commission, one saturation update per item, the
## closing of the sold out listings and the expiry. Events: `sold` (by id) first, then `closed` / `expired` (by id).
func process_block(pricing: AuctionPricing, block: int) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var sold_of: Dictionary[int, int] = {}
	for item_id: StringName in _items_with_sales(block):
		var group: Array[Dictionary] = _group(item_id, block)
		var npc: Array[Vector2i] = pricing.npc_asks(item_id)
		var demand: int = pricing.demand(item_id)
		var total: int = 0
		for listing: Dictionary in group:
			var sold: int = AuctionBook.fill(demand, _ahead(listing, group, npc), int(listing["qty"]))
			sold_of[int(listing["id"])] = sold
			total += sold
		pricing.record_sale(item_id, total)
	for listing: Dictionary in _list:
		var sold: int = sold_of.get(int(listing["id"]), 0)
		if sold <= 0:
			continue
		var gross: int = sold * int(listing["price"])
		var net: int = gross - AuctionBook.cut(gross, _p)
		listing["qty"] = int(listing["qty"]) - sold
		listing["sold"] = int(listing["sold"]) + sold
		listing["earned"] = int(listing["earned"]) + net
		events.append({"kind": &"sold", "id": listing["id"], "item": listing["item"], "qty": sold, "price": listing["price"], "net": net})
	var kept: Array[Dictionary] = []
	var closings: Array[Dictionary] = []
	for listing: Dictionary in _list:
		var left: int = int(listing["qty"])
		if left == 0:
			closings.append({"kind": &"closed", "id": listing["id"], "item": listing["item"], "qty": 0})
		elif block >= int(listing["end"]):
			closings.append({"kind": &"expired", "id": listing["id"], "item": listing["item"], "qty": left})
		else:
			kept.append(listing)
	_list = kept
	events.append_array(closings)
	return events


func clear() -> void:
	_list.clear()
	_next = 1


func to_save() -> Dictionary:
	var rows: Array = []
	for listing: Dictionary in _list:
		var row: Dictionary = listing.duplicate()
		row["item"] = String(listing["item"])
		row["duration"] = String(listing["duration"])
		rows.append(row)
	return {"listings": rows, "next_listing": _next}


## Tolerant load (§5.39): a bad listing is dropped with a warning; the item is checked by the AuctionHouse (`drop_if`).
func from_save(d: Dictionary) -> void:
	_list.clear()
	_next = 1
	var raw: Variant = d.get("listings", [])
	if not raw is Array:
		Log.warn(LOG_CATEGORY, "invalid listings %s: none" % str(raw))
		return
	var seen: Dictionary[int, bool] = {}
	for entry: Variant in raw as Array:
		var listing: Dictionary = _read(entry, seen)
		if not listing.is_empty():
			seen[int(listing["id"])] = true
			_list.append(listing)
	_list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["id"]) < int(b["id"]))
	var highest: int = 0 if _list.is_empty() else int((_list[_list.size() - 1] as Dictionary)["id"])
	var next_raw: Variant = _to_int(d.get("next_listing"))
	if next_raw != null and int(next_raw) > highest:
		_next = int(next_raw)
	else:
		_next = highest + 1
		if d.has("next_listing"):
			Log.warn(LOG_CATEGORY, "next_listing %s corrected to %d" % [str(d.get("next_listing")), _next])


## Takes away the loaded listings whose item `keep` rejects (unknown or not in the list of the Auction House).
func drop_if(rejects: Callable) -> void:
	var kept: Array[Dictionary] = []
	for listing: Dictionary in _list:
		if rejects.call(listing["item"]):
			Log.warn(LOG_CATEGORY, "listing %d dropped: item '%s' is not traded" % [listing["id"], listing["item"]])
		else:
			kept.append(listing)
	_list = kept
	if not _list.is_empty():
		_next = maxi(_next, int((_list[_list.size() - 1] as Dictionary)["id"]) + 1)


# The listing of a save entry, `{}` (with a warning) if it is not valid.
func _read(entry: Variant, seen: Dictionary[int, bool]) -> Dictionary:
	if not entry is Dictionary:
		Log.warn(LOG_CATEGORY, "listing %s dropped: not an object" % str(entry))
		return {}
	var e: Dictionary = entry as Dictionary
	var nums: Dictionary[String, int] = {}
	for key: String in ["id", "qty", "sold", "earned", "price", "start", "end"]:
		var n: Variant = _to_int(e.get(key))
		if n == null:
			Log.warn(LOG_CATEGORY, "listing dropped: '%s' is %s" % [key, str(e.get(key))])
			return {}
		nums[key] = int(n)
	if nums["id"] < 1 or seen.has(nums["id"]) or nums["qty"] < 1 or nums["sold"] < 0 or nums["earned"] < 0 or nums["price"] < 1 \
			or nums["start"] < 0 or nums["end"] <= nums["start"] or not e.get("item") is String:
		Log.warn(LOG_CATEGORY, "listing %s dropped: invalid fields" % str(e.get("id")))
		return {}
	var duration: StringName = StringName(str(e.get("duration")))
	if not _has_duration(duration):
		Log.warn(LOG_CATEGORY, "listing %d: unknown duration '%s', the first one is used" % [nums["id"], duration])
		duration = _p.durations[0].id
	return {"id": nums["id"], "item": StringName(e["item"] as String), "qty": nums["qty"], "sold": nums["sold"], "earned": nums["earned"],
			"price": nums["price"], "duration": duration, "start": nums["start"], "end": nums["end"]}


func _has_duration(duration_id: StringName) -> bool:
	for duration: AuctionDuration in _p.durations:
		if duration.id == duration_id:
			return true
	return false


# The items that have a listing which can sell at `block` (start before it), sorted.
func _items_with_sales(block: int) -> Array[StringName]:
	var result: Array[StringName] = []
	for listing: Dictionary in _list:
		if int(listing["start"]) < block and not result.has(listing["item"]):
			result.append(listing["item"])
	result.sort()
	return result


# The active listings of the item (those that started before `block`, all of them if `block` < 0), by (price, id).
func _group(item_id: StringName, block: int) -> Array[Dictionary]:
	var group: Array[Dictionary] = []
	for listing: Dictionary in _list:
		if listing["item"] == item_id and (block < 0 or int(listing["start"]) < block):
			group.append(listing)
	group.sort_custom(_before)
	return group


# F-179: NPC pieces at or below the price + pieces left of the listings of the group in front of this one.
func _ahead(listing: Dictionary, group: Array[Dictionary], npc: Array[Vector2i]) -> int:
	var ahead: int = 0
	for ask: Vector2i in npc:
		if ask.x <= int(listing["price"]):
			ahead += ask.y
	for other: Dictionary in group:
		if _before(other, listing):
			ahead += int(other["qty"])
	return ahead


func _before(a: Dictionary, b: Dictionary) -> bool:
	return int(a["price"]) < int(b["price"]) or (int(a["price"]) == int(b["price"]) and int(a["id"]) < int(b["id"]))


func _index_of(listing_id: int) -> int:
	for i: int in _list.size():
		if int((_list[i] as Dictionary)["id"]) == listing_id:
			return i
	return -1


# int from an int or an integral float (JSON); null otherwise.
func _to_int(v: Variant) -> Variant:
	if v is int:
		return v
	if v is float and is_finite(v as float) and (v as float) == floorf(v as float):
		return int(v as float)
	return null
