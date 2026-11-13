class_name Deposit
extends RefCounted
## The single capacity shared by the Bank and the Armory (docs/01_GDD.md §7, F-100) and the bag slots that raise it.
##
## `capacity = deposit.base_slots + Σ bag.slots of the bags in the bag slots + floor(T(deposit_slots))` (M19, F-133: the Village). `used` is the sum of the registered
## occupants (the Bank: item types; the Armory: pieces not worn). Bags in the slots occupy no place. The commands that
## move a bag between the Bank and a slot live in Bank (`equip_bag`, `unequip_bag`); this class never knows Bank.
## Signals go to the session EventBus after the state changed: `bags_changed` when a slot changes, `deposit_changed` from
## `notify_changed` when `used` or `capacity` differ from the last announcement. `new_game` and `from_save` are silent.

const SAVE_KEY: StringName = &"deposit"
const LOG_CATEGORY: String = "deposit"
const BASE_SLOTS_KEY: String = "deposit.base_slots"
const BAG_SLOTS_KEY: String = "deposit.bag_slots"
const BAG_CATEGORY: StringName = &"bag"
const VILLAGE_STAT: StringName = &"deposit_slots"

var _data: GameData
var _events: GameEvents
var _modifiers: ModifierService
var _base_slots: int = 0
var _bag_slots: Array[StringName] = []
# occupant id -> used_fn (() -> int).
var _occupants: Dictionary[StringName, Callable] = {}
# Last announced values; -1 = nothing announced yet (the next notify_changed always emits).
var _known_used: int = -1
var _known_capacity: int = -1


func _init(session: GameSession) -> void:
	assert(session != null, "Deposit needs a session")
	_data = session.data
	_events = session.events
	_modifiers = session.modifiers
	_base_slots = int(_data.balance_value(BASE_SLOTS_KEY))
	_events.modifiers_changed.connect(_on_modifiers_changed)
	_clear()


## F-100 + F-133 (`deposit_slots` of the Village: no place used, never lost).
func capacity() -> int:
	return _base_slots + extra_slots() + floori(_modifiers.total(VILLAGE_STAT))


func used() -> int:
	var total: int = 0
	for used_fn: Callable in _occupants.values():
		total += int(used_fn.call())
	return total


func free_slots() -> int:
	return maxi(0, capacity() - used())


func has_room(count: int = 1) -> bool:
	return free_slots() >= count


func register_occupant(occupant_id: StringName, used_fn: Callable) -> void:
	assert(not _occupants.has(occupant_id), "duplicate Deposit occupant '%s'" % occupant_id)
	assert(used_fn.is_valid(), "Deposit occupant '%s' needs a valid used_fn" % occupant_id)
	_occupants[occupant_id] = used_fn


func bag_slot_count() -> int:
	return _bag_slots.size()


func get_bag(slot_index: int) -> StringName:
	if slot_index < 0 or slot_index >= _bag_slots.size():
		return &""
	return _bag_slots[slot_index]


func bags() -> Array[StringName]:
	return _bag_slots.duplicate()


## Σ bag.slots of the bags in the slots.
func extra_slots() -> int:
	var total: int = 0
	for bag_id: StringName in _bag_slots:
		if bag_id != &"":
			total += _data.item(bag_id).bag_slots
	return total


## INTERNAL: only Bank.equip_bag / unequip_bag. `&""` empties the slot. Emits bags_changed; the caller then calls
## notify_changed once its own state is final.
func assign_bag(slot_index: int, item_id: StringName) -> void:
	assert(slot_index >= 0 and slot_index < _bag_slots.size(), "bag slot %d out of range" % slot_index)
	assert(item_id == &"" or is_bag(item_id), "'%s' is not a bag" % item_id)
	_bag_slots[slot_index] = item_id
	_events.bags_changed.emit()


## Emits deposit_changed(used, capacity) when one of the two differs from the last announcement.
func notify_changed() -> void:
	var now_used: int = used()
	var now_capacity: int = capacity()
	if now_used == _known_used and now_capacity == _known_capacity:
		return
	_known_used = now_used
	_known_capacity = now_capacity
	_events.deposit_changed.emit(now_used, now_capacity)


## Records the current used and capacity as announced, without a signal. Bank and Armory call it after a silent change
## (new_game, from_save, a quiet set_worn), so that the next notify_changed compares with the real state.
func sync_known() -> void:
	_known_used = used()
	_known_capacity = capacity()


func is_bag(item_id: StringName) -> bool:
	return _data.has_item(item_id) and _data.item(item_id).category == BAG_CATEGORY


func new_game() -> void:
	_clear()


func to_save() -> Dictionary:
	var saved: Array[String] = []
	for bag_id: StringName in _bag_slots:
		saved.append(String(bag_id))
	return {"bags": saved}


## Tolerant: a malformed list is empty; an entry that is not a string, unknown or not a bag is an empty slot (Log.warn);
## a longer list is cut, a shorter one is completed with empty slots. The capacity is not checked.
func from_save(d: Dictionary) -> void:
	_clear()
	var list: Variant = d.get("bags")
	if not list is Array:
		Log.warn(LOG_CATEGORY, "'bags' is not a list: empty bag slots")
		return
	var entries: Array = list as Array
	for index: int in mini(entries.size(), _bag_slots.size()):
		var entry: Variant = entries[index]
		var is_text: bool = entry is String or entry is StringName
		if is_text and str(entry).is_empty():
			continue
		if is_text and is_bag(StringName(str(entry))):
			_bag_slots[index] = StringName(str(entry))
		else:
			Log.warn(LOG_CATEGORY, "bag slot %d: %s is not a bag, slot left empty" % [index, str(entry)])


# F-133: a modifier change that moves the capacity is announced (only after a first announcement, so new_game and
# from_save stay silent).
func _on_modifiers_changed() -> void:
	if _known_capacity >= 0 and capacity() != _known_capacity:
		notify_changed()


func _clear() -> void:
	var count: int = int(_data.balance_value(BAG_SLOTS_KEY))
	_bag_slots.clear()
	for i: int in count:
		_bag_slots.append(&"")
	_known_used = -1
	_known_capacity = -1
