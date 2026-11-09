class_name FractureBag
extends RefCounted
## The bag of a Fracture (docs/01_GDD.md §17.2, docs/05_INTERFACES.md §5.23): everything that drops inside it, with no
## limit of slots. Pieces and Cards keep uid 0 until the delivery (F-116). Lost on death or abandon, delivered on a win.

const LOG_CATEGORY: String = "fracture"

# Insertion order is the delivery order.
var _stacks: Dictionary[StringName, int] = {}
var _pieces: Array[ItemInstance] = []
var _cards: Array[MapCard] = []


func add_stack(item_id: StringName, qty: int) -> void:
	if qty > 0:
		_stacks[item_id] = _stacks.get(item_id, 0) + qty


func add_piece(inst: ItemInstance) -> void:
	_pieces.append(inst)


func add_card(card: MapCard) -> void:
	_cards.append(card)


## `[{"item": StringName, "qty": int}]` in order of insertion.
func stacks() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item_id: StringName in _stacks:
		result.append({"item": item_id, "qty": _stacks[item_id]})
	return result


func pieces() -> Array[ItemInstance]:
	return _pieces.duplicate()


func cards() -> Array[MapCard]:
	return _cards.duplicate()


func is_empty() -> bool:
	return _stacks.is_empty() and _pieces.is_empty() and _cards.is_empty()


func clear() -> void:
	_stacks.clear()
	_pieces.clear()
	_cards.clear()


## What the UI and the events count: `{"stacks": int, "pieces": int, "cards": int}`.
func counts() -> Dictionary:
	return {"stacks": _stacks.size(), "pieces": _pieces.size(), "cards": _cards.size()}


## Removes the stack of `item_id` (delivered).
func remove_stack(item_id: StringName) -> void:
	_stacks.erase(item_id)


func remove_piece(inst: ItemInstance) -> void:
	_pieces.erase(inst)


func remove_card(card: MapCard) -> void:
	_cards.erase(card)


func to_save() -> Dictionary:
	var stacks_out: Array = []
	for entry: Dictionary in stacks():
		stacks_out.append({"item": String(entry["item"]), "qty": entry["qty"]})
	var pieces_out: Array = []
	for inst: ItemInstance in _pieces:
		pieces_out.append(inst.to_dict())
	var cards_out: Array = []
	for card: MapCard in _cards:
		cards_out.append(card.to_dict())
	return {"stacks": stacks_out, "pieces": pieces_out, "cards": cards_out}


## Tolerant: malformed or unknown entries are skipped with `Log.warn`. No signal.
func from_save(d: Dictionary, data: GameData) -> void:
	clear()
	for entry: Variant in _list(d, "stacks"):
		var item: Variant = (entry as Dictionary).get("item") if entry is Dictionary else null
		var qty: Variant = (entry as Dictionary).get("qty") if entry is Dictionary else null
		var qty_ok: bool = qty is int or (qty is float and qty == floorf(qty))
		if not (item is String or item is StringName) or not qty_ok or int(qty) <= 0 or not data.has_item(StringName(item)):
			Log.warn(LOG_CATEGORY, "bag stack skipped: %s" % str(entry))
			continue
		add_stack(StringName(item), int(qty))
	for entry: Variant in _list(d, "pieces"):
		var inst: ItemInstance = ItemInstance.from_dict(entry, data) if entry is Dictionary else null
		if inst == null:
			Log.warn(LOG_CATEGORY, "bag piece skipped: %s" % str(entry))
			continue
		_pieces.append(inst)
	for entry: Variant in _list(d, "cards"):
		var card: MapCard = MapCard.from_dict(entry, data) if entry is Dictionary else null
		if card == null:
			Log.warn(LOG_CATEGORY, "bag Card skipped: %s" % str(entry))
			continue
		_cards.append(card)


static func _list(d: Dictionary, key: String) -> Array:
	var value: Variant = d.get(key)
	return value if value is Array else []
