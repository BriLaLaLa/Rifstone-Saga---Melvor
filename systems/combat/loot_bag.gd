class_name LootBag
extends LootSink
## The loot bag (F-33, docs/01_GDD.md §10.6): one slot per item type, unlimited quantity. Lost on death.

var _session: GameSession
# Insertion order is the display order.
var _items: Dictionary[StringName, int] = {}


func _init(session: GameSession) -> void:
	_session = session


func items() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item_id: StringName in _items:
		result.append({"item": item_id, "qty": _items[item_id]})
	return result


func used() -> int:
	return _items.size()


## F-33.
func capacity() -> int:
	var base: int = int(_session.data.balance_value("combat.loot_bag_base_slots"))
	return base + int(floor(_session.modifiers.total(&"loot_bag_slots")))


## With `auto_loot` the bank comes first. False = the items were lost (`loot_lost`): bag full.
func add(item_id: StringName, qty: int) -> bool:
	if qty <= 0:
		return true
	if _session.modifiers.total(&"auto_loot") >= 1.0 and _session.bank.can_add(item_id):
		if _session.bank.add(item_id, qty).ok:
			return true
	if not _items.has(item_id) and used() >= capacity():
		_session.events.loot_lost.emit(item_id, qty)
		return false
	_items[item_id] = _items.get(item_id, 0) + qty
	_session.events.item_obtained.emit(item_id, qty)
	_emit_changed()
	return true


## Outside a Fracture a piece goes to the Armory (through the automatic filter) ...
func add_piece(inst: ItemInstance) -> void:
	_session.armory.add_drop(inst)


## ... and a Card to the CardStore (F-109 rarity with the global `item_rarity_pct`; a full Deposit = `card_rejected`).
func drop_card(grade: int) -> void:
	_session.cards.create(grade, _session.cards.roll_rarity())


## Moves everything it can into the bank; what does not fit stays (`bank_full`).
func collect_all() -> CommandResult:
	var left: bool = false
	for item_id: StringName in _items.keys():
		if _session.bank.add(item_id, _items[item_id]).ok:
			_items.erase(item_id)
		else:
			left = true
	_emit_changed()
	return CommandResult.fail(Reasons.BANK_FULL) if left else CommandResult.success()


## Death: everything is lost, one `loot_lost` per item type.
func lose_all() -> void:
	var lost: Dictionary[StringName, int] = _items.duplicate()
	_items.clear()
	for item_id: StringName in lost:
		_session.events.loot_lost.emit(item_id, lost[item_id])
	_emit_changed()


func to_save() -> Array:
	var result: Array = []
	for entry: Dictionary in items():
		result.append({"item": String(entry["item"]), "qty": entry["qty"]})
	return result


## Tolerant: malformed entries and unknown items are skipped with a warning; duplicates are merged. No signal.
func from_save(a: Array) -> void:
	_items.clear()
	for entry: Variant in a:
		if not entry is Dictionary:
			Log.warn("loot_bag", "entry is not a dictionary, skipped")
			continue
		var item: Variant = (entry as Dictionary).get("item")
		var qty: Variant = (entry as Dictionary).get("qty")
		var qty_ok: bool = qty is int or (qty is float and qty == floorf(qty))
		if not (item is String or item is StringName) or not qty_ok or int(qty) <= 0:
			Log.warn("loot_bag", "malformed entry %s skipped" % [entry])
			continue
		var item_id := StringName(item)
		if not _session.data.has_item(item_id):
			Log.warn("loot_bag", "unknown item '%s' skipped" % item_id)
			continue
		_items[item_id] = _items.get(item_id, 0) + int(qty)


func _emit_changed() -> void:
	_session.events.loot_bag_changed.emit(used(), capacity())
