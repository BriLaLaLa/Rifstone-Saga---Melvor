class_name Armory
extends RefCounted
## The Armory (docs/01_GDD.md §21): the only container of unique pieces (equipment and tools), as ItemInstance.
##
## Capacity is F-82: `armory.base_slots + floor(T(armory_slots, global))`; only the pieces that are not worn count.
## `uid` values start from 1, grow and are never reused (`next_uid` is saved). Getters return copies. Signals go to the
## session EventBus after the state changed. `new_game` and `from_save` set the state without signals.

const SAVE_KEY: StringName = &"armory"
const LOG_CATEGORY: String = "armory"
const BASE_SLOTS_KEY: String = "armory.base_slots"
const CAPACITY_STAT: StringName = &"armory_slots"
const CHANGE_ADDED: StringName = &"added"
const CHANGE_REMOVED: StringName = &"removed"
const CHANGE_UPDATED: StringName = &"updated"

var _data: GameData
var _events: GameEvents
var _modifiers: ModifierService
var _rng: RngService
var _base_slots: int = 0
# uid -> instance, in insertion order (Dictionary keeps it).
var _items: Dictionary[int, ItemInstance] = {}
var _worn: Dictionary[int, bool] = {}
var _next_uid: int = 1
# Capacity last announced, to emit armory_capacity_changed when the modifiers change it.
var _known_capacity: int = 0


func _init(session: GameSession) -> void:
	assert(session != null, "Armory needs a session")
	_data = session.data
	_events = session.events
	_modifiers = session.modifiers
	_rng = session.rng
	_base_slots = int(_data.balance_value(BASE_SLOTS_KEY))
	_known_capacity = capacity()
	_events.modifiers_changed.connect(_on_modifiers_changed)


## F-82.
func capacity() -> int:
	return _base_slots + floori(_modifiers.total(CAPACITY_STAT))


## Pieces that are not worn.
func used() -> int:
	return _items.size() - _worn.size()


func can_add(count: int = 1) -> bool:
	return count >= 0 and used() + count <= capacity()


## Takes a copy of `inst`, assigns the next uid and returns it. 0 (and armory_rejected) when the Armory is full,
## 0 when the base is not equipment or tool.
func add(inst: ItemInstance) -> int:
	if inst == null or not _is_piece_base(inst.base_id):
		return 0
	if not can_add(1):
		_events.armory_rejected.emit(inst.base_id, 1)
		return 0
	var stored: ItemInstance = inst.duplicate_instance()
	stored.uid = _next_uid
	_next_uid += 1
	_items[stored.uid] = stored
	_events.armory_changed.emit(stored.uid, CHANGE_ADDED)
	_emit_capacity()
	return stored.uid


## ItemRoller.create + add. 0 when the Armory is full or the base is not equipment/tool (unknown included).
func create(base_id: StringName, rarity: StringName, ilvl: int) -> int:
	if not _is_piece_base(base_id):
		return 0
	if not can_add(1):
		_events.armory_rejected.emit(base_id, 1)
		return 0
	return add(ItemRoller.create(_data.item(base_id), rarity, ilvl, _data, _rng))


func get_instance(uid: int) -> ItemInstance:
	var inst: ItemInstance = _items.get(uid)
	return inst.duplicate_instance() if inst != null else null


func instances() -> Array[ItemInstance]:
	var result: Array[ItemInstance] = []
	for inst: ItemInstance in _items.values():
		result.append(inst.duplicate_instance())
	return result


func has(uid: int) -> bool:
	return _items.has(uid)


func is_worn(uid: int) -> bool:
	return _worn.has(uid)


## Only Equipment calls this. Changes used(). `quiet` (only Equipment.from_save) sets the flag without signals.
func set_worn(uid: int, worn: bool, quiet: bool = false) -> void:
	if not _items.has(uid) or _worn.has(uid) == worn:
		return
	if worn:
		_worn[uid] = true
	else:
		_worn.erase(uid)
	if quiet:
		_known_capacity = capacity()
		return
	_events.armory_changed.emit(uid, CHANGE_UPDATED)
	_emit_capacity()


func set_locked(uid: int, locked: bool) -> CommandResult:
	if not _items.has(uid):
		return CommandResult.fail(Reasons.UNKNOWN_ID)
	if _items[uid].locked != locked:
		_items[uid].locked = locked
		_events.armory_changed.emit(uid, CHANGE_UPDATED)
	return CommandResult.success()


## unknown_id, item_locked, item_equipped (in this order).
func remove(uid: int) -> CommandResult:
	if not _items.has(uid):
		return CommandResult.fail(Reasons.UNKNOWN_ID)
	if _items[uid].locked:
		return CommandResult.fail(Reasons.ITEM_LOCKED)
	if _worn.has(uid):
		return CommandResult.fail(Reasons.ITEM_EQUIPPED)
	_items.erase(uid)
	_events.armory_changed.emit(uid, CHANGE_REMOVED)
	_emit_capacity()
	return CommandResult.success()


func instance_modifiers(uid: int) -> Array[Modifier]:
	if not _items.has(uid):
		var none: Array[Modifier] = []
		return none
	return ItemRoller.instance_modifiers(_items[uid], _data)


func new_game() -> void:
	_clear()
	_known_capacity = capacity()


func to_save() -> Dictionary:
	var saved: Array[Dictionary] = []
	for inst: ItemInstance in _items.values():
		saved.append(inst.to_dict())
	return {"next_uid": _next_uid, "items": saved}


## Invalid entries, unknown or non-piece bases and duplicate uids are reported with Log.warn and dropped.
## The capacity is not checked. `next_uid` is raised above the highest uid if it is not.
func from_save(d: Dictionary) -> void:
	_clear()
	var list: Variant = d.get("items")
	if not list is Array:
		Log.warn(LOG_CATEGORY, "'items' is not a list: empty Armory")
	else:
		for entry: Variant in list:
			_load_entry(entry)
	var highest: int = 0
	for uid: int in _items:
		highest = maxi(highest, uid)
	var saved_next: Variant = d.get("next_uid")
	var next: int = int(saved_next) if (saved_next is int or saved_next is float) else 1
	_next_uid = maxi(next, highest + 1)
	_known_capacity = capacity()


func _load_entry(entry: Variant) -> void:
	if not entry is Dictionary:
		Log.warn(LOG_CATEGORY, "piece dropped (not an object): %s" % str(entry))
		return
	var inst: ItemInstance = ItemInstance.from_dict(entry, _data)
	if inst == null or inst.uid <= 0 or _items.has(inst.uid) or not _is_piece_base(inst.base_id):
		Log.warn(LOG_CATEGORY, "piece dropped (invalid, bad uid or duplicate): %s" % str(entry))
		return
	_items[inst.uid] = inst


func _clear() -> void:
	_items.clear()
	_worn.clear()
	_next_uid = 1


func _is_piece_base(base_id: StringName) -> bool:
	return _data.has_item(base_id) and _data.item(base_id).category in Bank.PIECE_CATEGORIES \
			and _data.item(base_id).equip != null


func _emit_capacity() -> void:
	_known_capacity = capacity()
	_events.armory_capacity_changed.emit(used(), _known_capacity)


func _on_modifiers_changed() -> void:
	if capacity() != _known_capacity:
		_emit_capacity()
