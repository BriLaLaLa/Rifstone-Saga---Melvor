class_name Bank
extends RefCounted
## The only container of owned items (docs/01_GDD.md §7): one slot per item type, unlimited quantity, insertion order.
##
## Capacity is F-16: `bank.base_slots + floor(T(bank_slots, global))`. Signals go to the session EventBus, after the
## state changed: `bank_changed(item_id, new_count, delta)` for every change of a stack (delta = signed change of that
## operation; 0 when only its lock or position changed), `bank_capacity_changed` when used slots or capacity change,
## `bank_rejected` when `add` fails for a full bank. `new_game` and `from_save` set the state without signals.

const SAVE_KEY: StringName = &"bank"
const LOG_CATEGORY: String = "bank"
const BASE_SLOTS_KEY: String = "bank.base_slots"
const START_ITEMS_KEY: String = "start.items"
const CAPACITY_STAT: StringName = &"bank_slots"
## docs/05_INTERFACES.md §5.5: category order of `sort_stacks`.
const SORT_CATEGORIES: Array[StringName] = [&"material", &"food", &"equipment", &"tool", &"infusion", &"misc"]

var _data: GameData
var _events: GameEvents
var _modifiers: ModifierService
var _base_slots: int = 0
# Item ids in slot order; _counts and _locked hold only the ids in _order.
var _order: Array[StringName] = []
var _counts: Dictionary[StringName, int] = {}
var _locked: Dictionary[StringName, bool] = {}
# Capacity last announced, to emit bank_capacity_changed only when the modifiers really change it.
var _known_capacity: int = 0


func _init(session: GameSession) -> void:
	assert(session != null, "Bank needs a session")
	_data = session.data
	_events = session.events
	_modifiers = session.modifiers
	_base_slots = int(_data.balance_value(BASE_SLOTS_KEY))
	_known_capacity = capacity()
	_events.modifiers_changed.connect(_on_modifiers_changed)


func get_count(item_id: StringName) -> int:
	return _counts.get(item_id, 0)


func has(item_id: StringName, qty: int) -> bool:
	return get_count(item_id) >= qty


## True when the item is already in the bank or a slot is free (unknown items: false).
func can_add(item_id: StringName) -> bool:
	if _counts.has(item_id):
		return true
	return _data.has_item(item_id) and used() < capacity()


func add(item_id: StringName, qty: int) -> CommandResult:
	if not _data.has_item(item_id):
		return CommandResult.fail(Reasons.UNKNOWN_ID)
	if qty <= 0:
		return CommandResult.fail(Reasons.INVALID_AMOUNT)
	var is_new: bool = not _counts.has(item_id)
	if is_new and used() >= capacity():
		_events.bank_rejected.emit(item_id, qty)
		return CommandResult.fail(Reasons.BANK_FULL)
	if is_new:
		_order.append(item_id)
		_counts[item_id] = 0
		_locked[item_id] = false
	_counts[item_id] += qty
	_events.bank_changed.emit(item_id, _counts[item_id], qty)
	if is_new:
		_emit_capacity()
	return CommandResult.success()


## Removing the last unit frees the slot (and its lock).
func remove(item_id: StringName, qty: int) -> CommandResult:
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
	if left == 0:
		_emit_capacity()
	return CommandResult.success()


## F-16.
func capacity() -> int:
	return _base_slots + floori(_modifiers.total(CAPACITY_STAT))


func used() -> int:
	return _order.size()


## Copies of the stacks in slot order: [{"item": StringName, "count": int, "locked": bool}].
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


func new_game() -> void:
	_clear()
	var start: Array = _data.balance_value(START_ITEMS_KEY) as Array
	for entry: Variant in start:
		var d: Dictionary = entry as Dictionary
		_put(StringName(str(d["item"])), int(d["qty"]), false)
	_known_capacity = capacity()


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
		return
	for entry: Variant in list:
		var stack: Dictionary = entry if entry is Dictionary else {}
		var item_id: StringName = StringName(str(stack.get("item", "")))
		var count: Variant = stack.get("count")
		if not _data.has_item(item_id) or _counts.has(item_id) or not _is_positive_int(count):
			Log.warn(LOG_CATEGORY, "stack %s dropped (unknown, duplicate or bad count)" % str(entry))
			continue
		var locked: Variant = stack.get("locked", false)
		_put(item_id, int(count), locked is bool and locked)
	_known_capacity = capacity()


func _clear() -> void:
	_order.clear()
	_counts.clear()
	_locked.clear()


# Adds without signals or capacity check (new game, load).
func _put(item_id: StringName, qty: int, locked: bool) -> void:
	if not _counts.has(item_id):
		_order.append(item_id)
		_counts[item_id] = 0
		_locked[item_id] = locked
	_counts[item_id] += qty


func _emit_capacity() -> void:
	_known_capacity = capacity()
	_events.bank_capacity_changed.emit(used(), _known_capacity)


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


func _on_modifiers_changed() -> void:
	if capacity() != _known_capacity:
		_emit_capacity()


static func _is_positive_int(v: Variant) -> bool:
	if v is int:
		return int(v) > 0
	if v is float:
		var f: float = v
		return f > 0.0 and f == floorf(f)
	return false
