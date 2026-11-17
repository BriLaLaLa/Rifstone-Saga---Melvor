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
func population(_item_id: StringName) -> Dictionary: return {"buyers": 12, "sellers": 7, "demand": &"high"}


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
