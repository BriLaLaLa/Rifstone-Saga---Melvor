class_name AuctionHistory
extends RefCounted
## The sales history of the Auction House (docs/02_FORMULAS_M37.md F-209, F-212; docs/05_INTERFACES_M37.md §5.49): the last
## `history_max` things that happened to the player's listings, newest first. Not money (it goes through the Mail). No signals:
## AuctionHouse is the only writer and emits its own signals.
##
## An entry is `{"kind","item","qty","unit","net","block","listing"}`.

const LOG_CATEGORY: String = "auction"
const KINDS: Array[StringName] = [&"listing_sold", &"instant_sold", &"expired", &"cancelled"]

var _max: int
var _data: GameData
var _entries: Array[Dictionary] = []  # newest first


func _init(params: AuctionParams, data: GameData) -> void:
	_max = params.history_max
	_data = data


## Copies, newest first.
func entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in _entries:
		result.append(entry.duplicate())
	return result


func count() -> int:
	return _entries.size()


## F-209: a sale of a listing; a later sale of the same listing merges into its entry (qty, net, block) and moves it to the top.
func record_listing_sold(item_id: StringName, qty: int, unit: int, net: int, block: int, listing: int) -> void:
	for i: int in _entries.size():
		var entry: Dictionary = _entries[i]
		if entry["kind"] == &"listing_sold" and int(entry["listing"]) == listing:
			entry["qty"] = int(entry["qty"]) + qty
			entry["net"] = int(entry["net"]) + net
			entry["block"] = block
			_entries.remove_at(i)
			_entries.push_front(entry)
			return
	_push(&"listing_sold", item_id, qty, unit, net, block, listing)


## F-209: Vendi subito of `qty` pieces for `net` money; `unit = floor(net / qty)`; never merged.
@warning_ignore("integer_division")
func record_instant_sold(item_id: StringName, qty: int, net: int, block: int) -> void:
	_push(&"instant_sold", item_id, qty, net / maxi(qty, 1), net, block, 0)


## F-209: an expired or cancelled listing with `qty` pieces back in the Mail (`unit` = the listing price, `net` 0).
func record_closed(kind: StringName, item_id: StringName, qty: int, unit: int, block: int, listing: int) -> void:
	if kind != &"expired" and kind != &"cancelled":
		push_error("AuctionHistory.record_closed: kind '%s' is not expired or cancelled" % kind)
		return
	_push(kind, item_id, qty, unit, 0, block, listing)


func clear() -> void:
	_entries.clear()


func to_save() -> Array:
	var rows: Array = []
	for entry: Dictionary in _entries:
		rows.append({"k": String(entry["kind"]), "item": String(entry["item"]), "qty": entry["qty"], "unit": entry["unit"],
				"net": entry["net"], "block": entry["block"], "listing": entry["listing"]})
	return rows


## Tolerant load (04_DATA_SCHEMA_M37.md §38.2): a bad entry is dropped with a warning, the list is cut to `history_max`.
func from_save(raw: Variant) -> void:
	_entries.clear()
	if raw == null:
		return
	if not raw is Array:
		Log.warn(LOG_CATEGORY, "history is not a list: empty")
		return
	for row: Variant in raw as Array:
		var entry: Dictionary = _read(row)
		if entry.is_empty():
			continue
		if _entries.size() >= _max:
			Log.warn(LOG_CATEGORY, "history longer than %d: the oldest entries are dropped" % _max)
			break
		_entries.append(entry)


## F-212: the age of an entry in ms (0 for an entry from the future).
static func age_ms(entry_block: int, block_now: int, pending_ms: int, block_ms: int) -> int:
	if block_now < entry_block:
		return 0
	return (block_now - entry_block) * block_ms + pending_ms


func _push(kind: StringName, item_id: StringName, qty: int, unit: int, net: int, block: int, listing: int) -> void:
	_entries.push_front({"kind": kind, "item": item_id, "qty": qty, "unit": unit, "net": net, "block": block, "listing": listing})
	while _entries.size() > _max:
		_entries.pop_back()


func _read(row: Variant) -> Dictionary:
	if not row is Dictionary:
		Log.warn(LOG_CATEGORY, "history entry is not an object: dropped")
		return {}
	var d: Dictionary = row as Dictionary
	var kind: StringName = StringName(str(d.get("k", "")))
	var item_id: StringName = StringName(str(d.get("item", "")))
	if not KINDS.has(kind) or not _data.has_item(item_id):
		Log.warn(LOG_CATEGORY, "history entry '%s' of '%s' is unknown: dropped" % [kind, item_id])
		return {}
	var fields: Dictionary[String, int] = {}
	for key: String in ["qty", "unit", "net", "block", "listing"]:
		var value: Variant = _to_int(d.get(key))
		if value == null or int(value) < (1 if key == "qty" else 0):
			Log.warn(LOG_CATEGORY, "history entry has an invalid '%s': dropped" % key)
			return {}
		fields[key] = int(value)
	return {"kind": kind, "item": item_id, "qty": fields["qty"], "unit": fields["unit"], "net": fields["net"],
			"block": fields["block"], "listing": fields["listing"]}


# int from an int or an integral float (JSON); null otherwise.
func _to_int(v: Variant) -> Variant:
	if v is int:
		return v
	if v is float and is_finite(v as float) and (v as float) == floorf(v as float):
		return int(v as float)
	return null
