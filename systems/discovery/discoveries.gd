class_name Discoveries
extends RefCounted
## F-124 (docs/02_FORMULAS.md, 05_INTERFACES.md §5.24): the items the player has obtained at least once, per slot. The
## Guide unlocks the page of an item (and its source) from here. The set only grows. It listens to `item_obtained`
## (Bank, loot bag, Armory, CardStore) and emits `item_discovered` the first time. Pieces and Cards count by their base id.
## The starting kit counts as obtained (`new_game`; its first `item_discovered` come out of the new game itself).

const SAVE_KEY: StringName = &"discoveries"
const ITEMS_KEY: String = "items"
const LOG_CATEGORY: String = "discoveries"

var _data: GameData
var _events: GameEvents
var _items: Array[StringName] = []
var _known: Dictionary[StringName, bool] = {}


func _init(data: GameData, events: GameEvents) -> void:
	assert(data != null and events != null, "Discoveries needs data and events")
	_data = data
	_events = events
	_events.item_obtained.connect(_on_item_obtained)


## True when `item_id` is new (and `item_discovered` is emitted); an unknown id is reported and ignored.
func note(item_id: StringName) -> bool:
	if not _data.has_item(item_id):
		Log.warn(LOG_CATEGORY, "unknown item '%s' not noted" % item_id)
		return false
	if _known.has(item_id):
		return false
	_known[item_id] = true
	_items.append(item_id)
	_events.item_discovered.emit(item_id)
	return true


func has(item_id: StringName) -> bool:
	return _known.has(item_id)


## Copy, in order of discovery.
func items() -> Array[StringName]:
	return _items.duplicate()


## Empty, then the starting kit (`start.items`, `start.armory`, `start.tools`, `start.food`).
func new_game() -> void:
	_clear()
	var start: Dictionary = _data.balance_value("start") as Dictionary
	for row: Variant in start.get("items", []):
		note(StringName(str((row as Dictionary).get("item", ""))))
	for key: String in ["armory", "tools"]:
		for row: Variant in start.get(key, []):
			note(StringName(str((row as Dictionary).get("base", ""))))
	if start.has("food"):
		note(StringName(str(start["food"])))


func to_save() -> Dictionary:
	var ids: Array[String] = []
	for id: StringName in _items:
		ids.append(String(id))
	return {ITEMS_KEY: ids}


## Tolerant: unknown ids are dropped with a warning; a missing or malformed list is an empty set. Silent.
func from_save(d: Dictionary) -> void:
	_clear()
	var saved: Variant = d.get(ITEMS_KEY, [])
	if not saved is Array:
		Log.warn(LOG_CATEGORY, "discoveries: 'items' is not a list")
		return
	for entry: Variant in saved as Array:
		var id := StringName(str(entry))
		if not _data.has_item(id):
			Log.warn(LOG_CATEGORY, "discoveries: unknown item '%s' dropped" % id)
		elif not _known.has(id):
			_known[id] = true
			_items.append(id)


func _clear() -> void:
	_items.clear()
	_known.clear()


func _on_item_obtained(item_id: StringName, qty: int) -> void:
	if qty > 0:
		note(item_id)
