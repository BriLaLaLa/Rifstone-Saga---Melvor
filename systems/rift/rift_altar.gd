class_name RiftAltar
extends RefCounted
## The Altar of the Rift (docs/01_GDD.md §11): sockets unlocked by Riftbinding level hold infusions.
##
## Socketing takes one infusion from the bank and activates its modifiers under the source `rift_socket:<i>`;
## clearing a socket destroys the infusion. `unique` infusions fit in one socket only.
## `infusion_socketed` / `infusion_removed` are emitted after the state changed; `new_game` and `from_save` are silent.

const SAVE_KEY: StringName = &"rift"
const SKILL: StringName = &"riftbinding"
const SOURCE_PREFIX: String = "rift_socket:"
const SOCKETS_KEY: String = "sockets"
const BALANCE_KEY: String = "rift.sockets"
const LOG_CATEGORY: String = "rift"

var _data: GameData
var _events: GameEvents
var _modifiers: ModifierService
var _bank: Bank
var _skills: SkillsSystem
# Unlock level of each socket (from balance.json), in order.
var _levels: Array[int] = []
# Infusion id per socket (&"" = empty).
var _sockets: Array[StringName] = []


func _init(session: GameSession) -> void:
	assert(session != null, "RiftAltar needs a session")
	_data = session.data
	_events = session.events
	_modifiers = session.modifiers
	_bank = session.bank
	_skills = session.skills
	for entry: Variant in _data.balance_value(BALANCE_KEY) as Array:
		_levels.append(int((entry as Dictionary)["level"]))
	_sockets.resize(_levels.size())
	_sockets.fill(&"")


func socket_total() -> int:
	return _levels.size()


func is_unlocked(index: int) -> bool:
	return index >= 0 and index < _levels.size() and _skills.get_level(SKILL) >= _levels[index]


## &"" for an empty or unknown socket.
func get_socket(index: int) -> StringName:
	if index < 0 or index >= _sockets.size():
		return &""
	return _sockets[index]


## Checks in order: socket_locked (also for an unknown index), socket_occupied, not_equippable (not an infusion),
## requirement_not_met (unique already socketed), not_enough_items.
func socket(index: int, item_id: StringName) -> CommandResult:
	if not is_unlocked(index):
		return CommandResult.fail(Reasons.SOCKET_LOCKED)
	if _sockets[index] != &"":
		return CommandResult.fail(Reasons.SOCKET_OCCUPIED)
	if not _data.has_item(item_id) or _data.item(item_id).category != &"infusion":
		return CommandResult.fail(Reasons.NOT_EQUIPPABLE)
	var def: ItemDef = _data.item(item_id)
	if def.infusion_unique and _sockets.has(item_id):
		return CommandResult.fail(Reasons.REQUIREMENT_NOT_MET)
	var removed: CommandResult = _bank.remove(item_id, 1)
	if not removed.ok:
		return removed
	_sockets[index] = item_id
	_apply_source(index)
	_events.infusion_socketed.emit(index, item_id)
	return CommandResult.success()


## Destroys the infusion of the socket. Fails with slot_empty when there is none.
func clear_socket(index: int) -> CommandResult:
	if get_socket(index) == &"":
		return CommandResult.fail(Reasons.SLOT_EMPTY)
	var item_id: StringName = _sockets[index]
	_sockets[index] = &""
	_apply_source(index)
	_events.infusion_removed.emit(index, item_id)
	return CommandResult.success()


func rebuild_modifiers() -> void:
	_modifiers.begin_batch()
	for i: int in _sockets.size():
		_apply_source(i)
	_modifiers.end_batch()


func new_game() -> void:
	_sockets.fill(&"")


func to_save() -> Dictionary:
	var saved: Array = []
	for item_id: StringName in _sockets:
		saved.append(String(item_id))
	return {SOCKETS_KEY: saved}


## Tolerant: bad list -> all empty; unknown or non-infusion ids, locked sockets and repeated unique infusions are
## dropped with Log.warn; missing entries are empty, extra entries ignored.
func from_save(d: Dictionary) -> void:
	_sockets.fill(&"")
	var saved: Variant = d.get(SOCKETS_KEY)
	if not saved is Array:
		Log.warn(LOG_CATEGORY, "'sockets' is not a list: all sockets empty")
		return
	var list: Array = saved as Array
	for i: int in mini(list.size(), _sockets.size()):
		var item_id: StringName = StringName(str(list[i]))
		if item_id == &"":
			continue
		if not _data.has_item(item_id) or _data.item(item_id).category != &"infusion":
			Log.warn(LOG_CATEGORY, "socket %d: '%s' is not an infusion, dropped" % [i, item_id])
			continue
		if _data.item(item_id).infusion_unique and _sockets.has(item_id):
			Log.warn(LOG_CATEGORY, "socket %d: unique '%s' repeated, dropped" % [i, item_id])
			continue
		_sockets[i] = item_id


# Sets (or clears, when empty) the source `rift_socket:<index>`.
func _apply_source(index: int) -> void:
	var source_id: StringName = StringName(SOURCE_PREFIX + str(index))
	if _sockets[index] == &"":
		_modifiers.clear_source(source_id)
		return
	_modifiers.set_source(source_id, _data.item(_sockets[index]).infusion_modifiers)
