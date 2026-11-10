class_name LootBag
extends LootSink
## The loot bag (F-33, docs/01_GDD.md §10.6): one slot per item type, unlimited quantity. Lost on death.
## M15-04 (METIN Z1): it also holds the pieces that dropped (uid 0) until `collect_all` moves them to the Armory.

var _session: GameSession
# Insertion order is the display order.
var _items: Dictionary[StringName, int] = {}
var _pieces: Array[ItemInstance] = []


func _init(session: GameSession) -> void:
	_session = session


func items() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item_id: StringName in _items:
		result.append({"item": item_id, "qty": _items[item_id]})
	return result


## The pieces waiting in the bag (not in the Armory); no slot limit.
func pieces() -> Array[ItemInstance]:
	return _pieces.duplicate()


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


## A piece waits in the bag until `collect_all`; with `auto_loot` it goes at once to the Armory (through the filter).
func add_piece(inst: ItemInstance) -> void:
	if inst == null:
		return
	if _session.modifiers.total(&"auto_loot") >= 1.0:
		_session.armory.add_drop(inst)
		return
	_pieces.append(inst)
	_emit_changed()


## A Card goes to the CardStore (F-109 rarity with the global `item_rarity_pct`; a full Deposit = `card_rejected`).
func drop_card(grade: int) -> void:
	_session.cards.create(grade, _session.cards.roll_rarity())


## Moves everything it can into the bank and the pieces into the Armory (`add_drop`: the filter applies); what does not
## fit stays (`bank_full`). Pieces always leave the bag: a full Armory salvages them (`item_salvaged`), a legendary
## is rejected with `armory_rejected` (as `add_drop` always did).
func collect_all() -> CommandResult:
	var left: bool = false
	_move_pieces()
	for item_id: StringName in _items.keys():
		if _session.bank.add(item_id, _items[item_id]).ok:
			_items.erase(item_id)
		else:
			left = true
	_emit_changed()
	return CommandResult.fail(Reasons.BANK_FULL) if left else CommandResult.success()


## Only the pieces (not the stacks) go to the Armory, same rules as `collect_all`. Used by the offline simulator after
## every block, so that the offline summary sees the pieces stored or salvaged.
func collect_pieces() -> void:
	_move_pieces()
	_emit_changed()


func _move_pieces() -> void:
	for inst: ItemInstance in pieces():
		_session.armory.add_drop(inst)
		_pieces.erase(inst)


## Death: everything is lost, one `loot_lost` per item type (a piece counts 1 of its base).
func lose_all() -> void:
	var lost: Dictionary[StringName, int] = _items.duplicate()
	_items.clear()
	for inst: ItemInstance in _pieces:
		lost[inst.base_id] = lost.get(inst.base_id, 0) + 1
	_pieces.clear()
	for item_id: StringName in lost:
		_session.events.loot_lost.emit(item_id, lost[item_id])
	_emit_changed()


## v6: `{"stacks": [{"item", "qty"}], "pieces": [ItemInstance.to_dict()]}`.
func to_save() -> Dictionary:
	var stacks: Array = []
	for entry: Dictionary in items():
		stacks.append({"item": String(entry["item"]), "qty": entry["qty"]})
	var pieces_out: Array = []
	for inst: ItemInstance in _pieces:
		pieces_out.append(inst.to_dict())
	return {"stacks": stacks, "pieces": pieces_out}


## Tolerant: malformed entries and unknown items are skipped with a warning; duplicates are merged. No signal.
## A bare Array is read as the stacks (pre-v6 shape).
func from_save(saved: Variant) -> void:
	_items.clear()
	_pieces.clear()
	var stacks: Variant = saved
	if saved is Dictionary:
		stacks = (saved as Dictionary).get("stacks", [])
		var raw: Variant = (saved as Dictionary).get("pieces", [])
		for entry: Variant in (raw if raw is Array else []):
			var inst: ItemInstance = null
			if entry is Dictionary:
				inst = ItemInstance.from_dict(entry, _session.data)
			if inst == null:
				Log.warn("loot_bag", "malformed piece skipped")
				continue
			_pieces.append(inst)
	if not stacks is Array:
		return
	for entry: Variant in stacks:
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
