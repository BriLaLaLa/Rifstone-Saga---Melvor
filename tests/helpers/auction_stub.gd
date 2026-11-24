class_name AuctionStub
extends RefCounted
## Stand-in for `AuctionHouse` (docs/05_INTERFACES.md §5.30) with the same read and command signatures, for the UI smoke test:
## `level_value` (0 = not built), the first listed item is "owned" by the test, `forced_reason` makes `can_sell` / `can_buy`
## fail with that reason. Counts the commands it receives.

var level_value: int = 1
var forced_reason: StringName = &""
var sell_calls: int = 0
var buy_calls: int = 0
var last_qty: int = 0
var _listed: Array[StringName] = []
var _buyable: Array[StringName] = []


func _init(listed: Array[StringName], buyable: Array[StringName]) -> void:
	_listed = listed
	_buyable = buyable


func level() -> int: return level_value
func is_open() -> bool: return level_value >= 1
func listed_items() -> Array[StringName]: return _listed.duplicate()
func buyable_items() -> Array[StringName]: return _buyable.duplicate()
func buy_level(item_id: StringName) -> int: return 1 + _buyable.find(item_id) if _buyable.has(item_id) else 0
func sell_quote(_item_id: StringName, qty: int) -> int: return 7 * maxi(qty, 0)
func buy_quote(_item_id: StringName, qty: int) -> int: return 11 * maxi(qty, 0)
func stock(_item_id: StringName) -> int: return 5
func stock_max(_item_id: StringName) -> int: return 9
func trend(_item_id: StringName) -> StringName: return &"up"
func population(_item_id: StringName) -> Dictionary:
	return {"buyers": 12, "sellers": 7, "demand": &"high", "listings": 2, "units": 9}


# M27-08 additions (docs/05_INTERFACES_M27.md §5.39): book, listings, durations, listing commands.
var list_calls: int = 0
var cancel_calls: int = 0


func book(_item_id: StringName) -> Array[Dictionary]:
	return [{"price": 5, "qty": 3, "mine": false, "listing": 0}, {"price": 6, "qty": 2, "mine": true, "listing": 1}]


func suggested_price(_item_id: StringName) -> int: return 6
func max_price(_item_id: StringName) -> int: return 100000
func max_listings() -> int: return 5
func listing_deposit(_item_id: StringName, qty: int, _duration_id: StringName) -> int: return qty
func listing_net(_item_id: StringName, qty: int, price: int) -> int: return qty * price


func durations() -> Array[AuctionDuration]:
	var duration: AuctionDuration = AuctionDuration.new()
	duration.id = &"short"
	duration.hours = 12
	return [duration]


func my_listings() -> Array[Dictionary]:
	return [{"id": 1, "item": _listed[0], "qty": 2, "sold": 0, "earned": 0, "price": 6, "duration": &"short", "ends_in_ms": 3600000,
			"status": &"undercut"}]


func can_list(_item_id: StringName, _qty: int, _price: int, _duration_id: StringName) -> CommandResult:
	return CommandResult.fail(forced_reason) if forced_reason != &"" else CommandResult.success()


func list_item(item_id: StringName, qty: int, price: int, duration_id: StringName) -> CommandResult:
	list_calls += 1
	return can_list(item_id, qty, price, duration_id)


func can_cancel(_listing_id: int) -> CommandResult: return CommandResult.success()


func cancel_listing(_listing_id: int) -> CommandResult:
	cancel_calls += 1
	return CommandResult.success()


func can_sell(_item_id: StringName, _qty: int) -> CommandResult:
	return CommandResult.fail(forced_reason) if forced_reason != &"" else CommandResult.success()


func can_buy(item_id: StringName, qty: int) -> CommandResult:
	return can_sell(item_id, qty)


func sell(item_id: StringName, qty: int) -> CommandResult:
	sell_calls += 1
	last_qty = qty
	return can_sell(item_id, qty)


func buy(item_id: StringName, qty: int) -> CommandResult:
	buy_calls += 1
	last_qty = qty
	return can_buy(item_id, qty)


# M37-4 additions (docs/05_INTERFACES_M37.md §5.49): price gap, summary, history.
var gap_value: int = 12


func price_gap(_item_id: StringName, _mode: StringName) -> int: return gap_value
func listings_summary() -> Dictionary: return {"count": 1, "units": 2, "expected_net": 11}
func max_buyable(_item_id: StringName) -> int: return 3
func value_of(_item_id: StringName) -> int: return 8
func history_max() -> int: return 50
func history_age_ms(_entry: Dictionary) -> int: return 600000


func history() -> Array[Dictionary]:
	return [{"kind": &"listing_sold", "item": _listed[0], "qty": 2, "unit": 6, "net": 11, "block": 1, "listing": 1},
			{"kind": &"instant_sold", "item": _listed[0], "qty": 1, "unit": 7, "net": 7, "block": 1, "listing": 0},
			{"kind": &"cancelled", "item": _listed[0], "qty": 3, "unit": 6, "net": 0, "block": 0, "listing": 2}]


# M38-3 additions (docs/05_INTERFACES_M38.md §5.50): single book, availability, reference, confirmation preview.
var available_value: int = 5
var large_preview: bool = false


func available(_item_id: StringName) -> int: return available_value
func restock_ms(_item_id: StringName) -> int: return 300000 if available_value <= 0 else 0
func reference_price(_item_id: StringName, _mode: StringName) -> int: return 9


func buy_preview(_item_id: StringName, qty: int) -> Dictionary:
	if qty <= 0 or available_value <= 0:
		return {}
	return {"total": 11 * qty, "avg": 11, "best": 11, "share_ppm": 600000, "premium_ppm": 0, "large": large_preview}
