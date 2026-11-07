class_name HintsSystem
extends RefCounted
## Contextual hints (docs/01_GDD.md §14): each hint of data/hints/hints.json is shown once per slot.
##
## `connect_triggers` listens to `session.events`; when an event matches the `trigger` of a hint that is not seen yet,
## the hint becomes seen and `hint_triggered(hint_id)` is emitted once (the UI shows the card). Seen hints are
## saved per slot. `new_game` and `from_save` are silent.

const SAVE_KEY: StringName = &"hints"
const SEEN_KEY: String = "seen"
const LOG_CATEGORY: String = "hints"
const LEVEL_TARGET: int = 10  # trigger `first_level_10`: a skill or the character reaches this level
const SHARD_ITEM: StringName = &"rift_shard"

var _session: GameSession
var _data: GameData
var _events: GameEvents
var _seen: Dictionary[StringName, bool] = {}
var _pending: Array[StringName] = []  # triggered and not closed yet; volatile, never saved


func _init(session: GameSession) -> void:
	assert(session != null, "HintsSystem needs a session")
	_session = session
	_data = session.data
	_events = session.events


func is_seen(hint_id: StringName) -> bool:
	return _seen.has(hint_id)


## Marks a hint as seen (idempotent). An unknown id is an error and changes nothing.
func mark_seen(hint_id: StringName) -> void:
	if _data.hint(hint_id) == null:
		return
	_seen[hint_id] = true
	_pending.erase(hint_id)


## Ids triggered and not closed yet (mark_seen removes them), in trigger order. Volatile: not saved. A late-bound
## card reads it to show hints that fired before it existed.
func pending() -> Array[StringName]:
	return _pending.duplicate()


## Connects the trigger events once (a second call changes nothing).
func connect_triggers() -> void:
	_connect(_events.session_started, _on_session_started)
	_connect(_events.bank_rejected, _on_bank_rejected)
	_connect(_events.action_stopped, _on_action_stopped)
	_connect(_events.bank_changed, _on_bank_changed)
	_connect(_events.mastery_pool_changed, _on_mastery_pool_changed)
	_connect(_events.player_died, _on_player_died)
	_connect(_events.level_up, _on_level_up)
	_connect(_events.character_level_up, _on_character_level_up)


func new_game() -> void:
	_seen.clear()
	_pending.clear()


func to_save() -> Dictionary:
	var seen: Array = []
	for def: HintDef in _data.hints():
		if _seen.has(def.id):
			seen.append(String(def.id))
	return {SEEN_KEY: seen}


## Tolerant: a bad list means nothing seen; ids that are not hints are dropped with Log.warn.
func from_save(d: Dictionary) -> void:
	_seen.clear()
	_pending.clear()
	var saved: Variant = d.get(SEEN_KEY)
	if not saved is Array:
		Log.warn(LOG_CATEGORY, "'seen' is not a list: no hint seen")
		return
	var known: Dictionary[StringName, bool] = {}
	for def: HintDef in _data.hints():
		known[def.id] = true
	for entry: Variant in saved as Array:
		var hint_id := StringName(str(entry))
		if known.has(hint_id):
			_seen[hint_id] = true
		else:
			Log.warn(LOG_CATEGORY, "unknown seen hint '%s' dropped" % hint_id)


# Marks as seen and emits every unseen hint of the trigger, in file order.
func _fire(trigger: StringName) -> void:
	for def: HintDef in _data.hints():
		if def.trigger == trigger and not _seen.has(def.id):
			_seen[def.id] = true
			_pending.append(def.id)
			_events.hint_triggered.emit(def.id)


static func _connect(sig: Signal, handler: Callable) -> void:
	if not sig.is_connected(handler):
		sig.connect(handler)


func _on_session_started(_slot: int, is_new: bool) -> void:
	if is_new:
		_fire(&"session_started_new")


func _on_bank_rejected(_item_id: StringName, _qty: int) -> void:
	_fire(&"bank_full")


func _on_action_stopped(_lane: StringName, _skill_id: StringName, reason: StringName) -> void:
	if reason == Reasons.BANK_FULL:
		_fire(&"bank_full")


func _on_bank_changed(item_id: StringName, _new_count: int, delta: int) -> void:
	if item_id == SHARD_ITEM and delta > 0:
		_fire(&"first_shard")


func _on_mastery_pool_changed(skill_id: StringName, _pool_xp: int) -> void:
	for node: MasteryNodeDef in _data.mastery_nodes(skill_id):
		if _session.mastery.can_buy_node(node.id).ok:
			_fire(&"mastery_node_affordable")
			return


func _on_player_died() -> void:
	_fire(&"player_died")


func _on_level_up(_skill_id: StringName, new_level: int) -> void:
	if new_level >= LEVEL_TARGET:
		_fire(&"first_level_10")


func _on_character_level_up(new_level: int) -> void:
	if new_level >= LEVEL_TARGET:
		_fire(&"first_level_10")
