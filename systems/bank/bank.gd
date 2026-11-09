class_name Bank
extends RefCounted
## The container of owned items (docs/01_GDD.md §7): one box per item type, unlimited quantity, insertion order.
##
## The capacity is the Deposit's (F-100), shared with the Armory: a new item type needs `deposit.has_room()`. Signals go
## to the session EventBus, after the state changed: `bank_changed(item_id, new_count, delta)` for every change of a stack
## (delta = signed change of that operation; 0 when only its lock or position changed), `deposit_changed` (through
## `Deposit.notify_changed`) when the boxes used change, `bank_rejected` when `add` fails for a full Deposit.
## `equip_bag` / `unequip_bag` move a bag between a box and a bag slot (docs/05_INTERFACES.md §5.20).
## `new_game` and `from_save` set the state without signals.

const SAVE_KEY: StringName = &"bank"
const LOG_CATEGORY: String = "bank"
const START_ITEMS_KEY: String = "start.items"
## docs/05_INTERFACES.md §5.5: category order of `sort_stacks`.
const SORT_CATEGORIES: Array[StringName] = [&"material", &"bag", &"contract", &"food", &"infusion", &"misc", &"stone",
		&"currency"]
## Categories held by the Armory as unique pieces: the bank rejects them (M4-05).
const PIECE_CATEGORIES: Array[StringName] = [&"equipment", &"tool", &"map"]  # M13: Cards live in the CardStore
const OCCUPANT_ID: StringName = &"bank"

var _data: GameData
var _events: GameEvents
var _deposit: Deposit
# Item ids in box order; _counts and _locked hold only the ids in _order.
var _order: Array[StringName] = []
var _counts: Dictionary[StringName, int] = {}
var _locked: Dictionary[StringName, bool] = {}


func _init(session: GameSession) -> void:
	assert(session != null, "Bank needs a session")
	_data = session.data
	_events = session.events
	_deposit = session.deposit
	_deposit.register_occupant(OCCUPANT_ID, used)


func get_count(item_id: StringName) -> int:
	return _counts.get(item_id, 0)


func has(item_id: StringName, qty: int) -> bool:
	return get_count(item_id) >= qty


## True when the item is already in the bank or a box is free (unknown items: false).
func can_add(item_id: StringName) -> bool:
	if _counts.has(item_id):
		return true
	return _data.has_item(item_id) and not _is_piece(item_id) and _deposit.has_room(1)


func add(item_id: StringName, qty: int) -> CommandResult:
	if not _data.has_item(item_id):
		return CommandResult.fail(Reasons.UNKNOWN_ID)
	if _is_piece(item_id):
		return CommandResult.fail(Reasons.NOT_STACKABLE)
	if qty <= 0:
		return CommandResult.fail(Reasons.INVALID_AMOUNT)
	var is_new: bool = not _counts.has(item_id)
	if is_new and not _deposit.has_room(1):
		_events.bank_rejected.emit(item_id, qty)
		return CommandResult.fail(Reasons.BANK_FULL)
	if is_new:
		_order.append(item_id)
		_counts[item_id] = 0
		_locked[item_id] = false
	_counts[item_id] += qty
	_events.bank_changed.emit(item_id, _counts[item_id], qty)
	_events.item_obtained.emit(item_id, qty)
	if is_new:
		_deposit.notify_changed()
	return CommandResult.success()


## Removing the last unit frees the box (and its lock).
func remove(item_id: StringName, qty: int) -> CommandResult:
	var result: CommandResult = _remove(item_id, qty)
	if result.ok and not _counts.has(item_id):
		_deposit.notify_changed()
	return result


## F-100: the capacity is the Deposit's.
func capacity() -> int:
	return _deposit.capacity()


## Free boxes of the shared Deposit (what a new item type or piece can still use).
func free_boxes() -> int:
	return _deposit.free_slots()


## Boxes used by the bank: the item types.
func used() -> int:
	return _order.size()


## Copies of the stacks in box order: [{"item": StringName, "count": int, "locked": bool}].
func stacks() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item_id: StringName in _order:
		result.append({"item": item_id, "count": _counts[item_id], "locked": _locked[item_id]})
	return result


func is_locked(item_id: StringName) -> bool:
	return _locked.get(item_id, false)


func set_locked(item_id: StringName, locked: bool) -> CommandResult:
	if not _counts.has(item_id):
		return CommandResult.fail(Reasons.UNKNOWN_ID)
	if _locked[item_id] != locked:
		_locked[item_id] = locked
		_events.bank_changed.emit(item_id, _counts[item_id], 0)
	return CommandResult.success()


## Moves a stack to `new_index` (0..used()-1), shifting the others. unknown_id if absent, invalid_amount if out
## of range.
func move_stack(item_id: StringName, new_index: int) -> CommandResult:
	var old_index: int = _order.find(item_id)
	if old_index < 0:
		return CommandResult.fail(Reasons.UNKNOWN_ID)
	if new_index < 0 or new_index >= _order.size():
		return CommandResult.fail(Reasons.INVALID_AMOUNT)
	if new_index == old_index:
		return CommandResult.success()
	var before: Array[StringName] = _order.duplicate()
	_order.remove_at(old_index)
	_order.insert(new_index, item_id)
	_emit_moved(before)
	return CommandResult.success()


## Category (SORT_CATEGORIES), then the item's sort_order, then id.
func sort_stacks() -> void:
	var before: Array[StringName] = _order.duplicate()
	_order.sort_custom(_sorts_before)
	_emit_moved(before)


## Puts one bag from the bank into a bag slot. invalid_amount (slot out of range), unknown_id, not_a_bag,
## bag_slot_occupied (take the bag out first), not_enough_items (in this order).
func equip_bag(slot_index: int, item_id: StringName) -> CommandResult:
	if slot_index < 0 or slot_index >= _deposit.bag_slot_count():
		return CommandResult.fail(Reasons.INVALID_AMOUNT)
	if not _data.has_item(item_id):
		return CommandResult.fail(Reasons.UNKNOWN_ID)
	if not _deposit.is_bag(item_id):
		return CommandResult.fail(Reasons.NOT_A_BAG)
	if _deposit.get_bag(slot_index) != &"":
		return CommandResult.fail(Reasons.BAG_SLOT_OCCUPIED)
	var removed: CommandResult = _remove(item_id, 1)
	if not removed.ok:
		return removed
	_deposit.assign_bag(slot_index, item_id)
	_deposit.notify_changed()
	return CommandResult.success()


## Takes the bag out of a slot and back into a bank box. invalid_amount (slot out of range), slot_empty,
## deposit_not_empty (after the operation the boxes used would exceed the capacity, F-100: nothing changes).
func unequip_bag(slot_index: int) -> CommandResult:
	if slot_index < 0 or slot_index >= _deposit.bag_slot_count():
		return CommandResult.fail(Reasons.INVALID_AMOUNT)
	var bag_id: StringName = _deposit.get_bag(slot_index)
	if bag_id == &"":
		return CommandResult.fail(Reasons.SLOT_EMPTY)
	var used_after: int = _deposit.used() + (0 if _counts.has(bag_id) else 1)
	if used_after > _deposit.capacity() - _data.item(bag_id).bag_slots:
		return CommandResult.fail(Reasons.DEPOSIT_NOT_EMPTY)
	_deposit.assign_bag(slot_index, &"")
	_put(bag_id, 1, false)
	_events.bank_changed.emit(bag_id, _counts[bag_id], 1)
	_deposit.notify_changed()
	return CommandResult.success()


func new_game() -> void:
	_clear()
	var start: Array = _data.balance_value(START_ITEMS_KEY) as Array
	for entry: Variant in start:
		var d: Dictionary = entry as Dictionary
		_put(StringName(str(d["item"])), int(d["qty"]), false)
	_deposit.sync_known()


func to_save() -> Dictionary:
	var saved: Array[Dictionary] = []
	for item_id: StringName in _order:
		saved.append({"item": String(item_id), "count": _counts[item_id], "locked": _locked[item_id]})
	return {"stacks": saved}


## Unknown items, duplicates and malformed stacks are reported with Log.warn and dropped; the order is kept.
func from_save(d: Dictionary) -> void:
	_clear()
	var list: Variant = d.get("stacks")
	if not list is Array:
		Log.warn(LOG_CATEGORY, "'stacks' is not a list: empty bank")
		_deposit.sync_known()
		return
	for entry: Variant in list:
		var stack: Dictionary = entry if entry is Dictionary else {}
		var item_id: StringName = StringName(str(stack.get("item", "")))
		var count: Variant = stack.get("count")
		if _is_piece(item_id):
			Log.warn(LOG_CATEGORY, "stack %s dropped (equipment and tools live in the Armory)" % str(entry))
			continue
		if not _data.has_item(item_id) or _counts.has(item_id) or not _is_positive_int(count):
			Log.warn(LOG_CATEGORY, "stack %s dropped (unknown, duplicate or bad count)" % str(entry))
			continue
		var locked: Variant = stack.get("locked", false)
		_put(item_id, int(count), locked is bool and locked)
	_deposit.sync_known()


# remove() without the deposit notification (equip_bag notifies once, when its own state is final).
func _remove(item_id: StringName, qty: int) -> CommandResult:
	if qty <= 0:
		return CommandResult.fail(Reasons.INVALID_AMOUNT)
	if get_count(item_id) < qty:
		return CommandResult.fail(Reasons.NOT_ENOUGH_ITEMS)
	var left: int = _counts[item_id] - qty
	if left == 0:
		_order.erase(item_id)
		_counts.erase(item_id)
		_locked.erase(item_id)
	else:
		_counts[item_id] = left
	_events.bank_changed.emit(item_id, left, -qty)
	return CommandResult.success()


func _clear() -> void:
	_order.clear()
	_counts.clear()
	_locked.clear()


# Adds without signals or capacity check (new game, load, bag back from its slot).
func _put(item_id: StringName, qty: int, locked: bool) -> void:
	if not _counts.has(item_id):
		_order.append(item_id)
		_counts[item_id] = 0
		_locked[item_id] = locked
	_counts[item_id] += qty


# One bank_changed (delta 0) per stack whose index changed.
func _emit_moved(before: Array[StringName]) -> void:
	for index: int in _order.size():
		if before[index] != _order[index]:
			var item_id: StringName = _order[index]
			_events.bank_changed.emit(item_id, _counts[item_id], 0)


func _sorts_before(a: StringName, b: StringName) -> bool:
	var item_a: ItemDef = _data.item(a)
	var item_b: ItemDef = _data.item(b)
	var cat_a: int = SORT_CATEGORIES.find(item_a.category)
	var cat_b: int = SORT_CATEGORIES.find(item_b.category)
	if cat_a != cat_b:
		return cat_a < cat_b
	if item_a.sort_order != item_b.sort_order:
		return item_a.sort_order < item_b.sort_order
	return String(a) < String(b)


static func _is_positive_int(v: Variant) -> bool:
	if v is int:
		return int(v) > 0
	if v is float:
		var f: float = v
		return f > 0.0 and f == floorf(f)
	return false


# True for an existing equipment or tool item: it is never stacked in the bank.
func _is_piece(item_id: StringName) -> bool:
	return _data.has_item(item_id) and _data.item(item_id).category in PIECE_CATEGORIES
