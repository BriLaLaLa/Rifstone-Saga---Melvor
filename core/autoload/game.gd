extends Node
## Game coordinator (autoload `Game`): creates and closes the GameSession, autosave, clock wiring.
##
## Lifecycle: `menu` (no session, nothing is ever written) -> `loading` -> (`offline`, M6-01) -> `playing` -> `menu`.
## A session exists only between new_game/continue_game and end_session, so no slot file can be written before the
## player picks or creates a slot (docs/03_ARCHITECTURE.md §7, §12).
##
## Clock and autosave: while `playing`, every GameClock tick advances the session and adds to an autosave
## accumulator; when it reaches `autosave_interval_ms` the slot is saved. The autosave counts game-clock time instead
## of a real-time Timer node so that it stops whenever the clock is paused (menu, offline) and so that tests can
## simulate it with GameClock alone. It starts on entering `playing` and stops in end_session.
##
## Configuration comes from balance.json in _ready (tick, catch-up, autosave interval, slot count, name length).
## Commands that start a game fail with slot_active while a session is open: the caller ends it first.

const LOG_CATEGORY: String = "game"
const TICK_MS_KEY: String = "tick_ms"
const MAX_CATCHUP_MS_KEY: String = "max_catchup_ms"
const AUTOSAVE_INTERVAL_KEY: String = "autosave_interval_ms"
const SLOT_COUNT_KEY: String = "slots.count"
# Player name length after strip_edges (docs/01_GDD.md §1); SlotTexts reads the same keys for its message.
const NAME_MIN_LENGTH_KEY: String = "player_name.min_length"
const NAME_MAX_LENGTH_KEY: String = "player_name.max_length"
const STATE_MENU: StringName = &"menu"
const STATE_LOADING: StringName = &"loading"
const STATE_OFFLINE: StringName = &"offline"
const STATE_PLAYING: StringName = &"playing"
# New seeds: microseconds since start with the slot xor-ed into bits 48+, masked to 53 bits so the seed is a
# non-negative integer that a JSON number (double) holds exactly.
const SEED_SLOT_SHIFT: int = 48
const SEED_MASK: int = (1 << 53) - 1

var session: GameSession = null
var active_slot: int = -1
var state: StringName = STATE_MENU
# Typed OfflineSummary by M6-01 (the class does not exist yet).
var last_offline_summary: RefCounted = null

var _slot_count: int = 0
var _name_min_length: int = 0
var _name_max_length: int = 0
var _autosave_interval_ms: int = 0
var _autosave_elapsed_ms: int = 0


func _ready() -> void:
	GameClock.set_paused(true)
	var data: GameData = DataRegistry.data
	if data == null or not data.is_valid():
		Log.error(LOG_CATEGORY, "game data not valid: clock and saves not configured")
		return
	GameClock.configure(int(data.balance_value(TICK_MS_KEY)), int(data.balance_value(MAX_CATCHUP_MS_KEY)))
	_autosave_interval_ms = int(data.balance_value(AUTOSAVE_INTERVAL_KEY))
	_slot_count = int(data.balance_value(SLOT_COUNT_KEY))
	_name_min_length = int(data.balance_value(NAME_MIN_LENGTH_KEY))
	_name_max_length = int(data.balance_value(NAME_MAX_LENGTH_KEY))
	SaveService.configure(_slot_count)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and session != null:
		save_now()


func _exit_tree() -> void:
	_stop_playing()


func list_slots() -> Array[SlotInfo]:
	return SaveService.list_slots()


## Name length after strip within player_name.min_length-max_length of balance.json (invalid_name); creates the session, new_game(), saves, then `playing`.
## Fails with slot_active while a session is open, io_error for a slot out of range or when the first save fails
## (in that case the session is discarded and nothing changes).
func new_game(slot: int, player_name: String) -> CommandResult:
	var clean_name: String = player_name.strip_edges()
	if clean_name.length() < _name_min_length or clean_name.length() > _name_max_length:
		return CommandResult.fail(Reasons.INVALID_NAME)
	var check: CommandResult = _check_can_start(slot)
	if not check.ok:
		return check
	state = STATE_LOADING
	var new_session: GameSession = _create_session(slot)
	new_session.new_game()
	new_session.player_name = clean_name
	new_session.created_at_unix_ms = GameClock.now_unix_ms()
	_attach(new_session, slot)
	var saved: CommandResult = save_now()
	if not saved.ok:
		_detach()
		return saved
	_start_playing(true)
	return CommandResult.success()


## Reads the migrated slot, from_save (which rebuilds the modifiers), then saves and enters `playing`.
## Fails with the store's reason (io_error, corrupted, version_unsupported) or the session's, changing nothing.
func continue_game(slot: int) -> CommandResult:
	var check: CommandResult = _check_can_start(slot)
	if not check.ok:
		return check
	state = STATE_LOADING
	var d: Dictionary = SaveService.read_slot(slot)
	if d.is_empty():
		state = STATE_MENU
		var reason: StringName = SaveService.last_error if SaveService.last_error != &"" else Reasons.IO_ERROR
		return CommandResult.fail(reason)
	var loaded_session: GameSession = _create_session(slot)
	var loaded: CommandResult = loaded_session.from_save(d)
	if not loaded.ok:
		loaded_session.free()
		state = STATE_MENU
		return loaded
	# The file name decides the slot, whatever the header says.
	loaded_session.slot = slot
	_attach(loaded_session, slot)
	# Offline: M6-01
	var saved: CommandResult = save_now()
	if not saved.ok:
		Log.warn(LOG_CATEGORY, "save after loading slot %d failed (%s): retried by the autosave" % [slot, saved.reason])
	_start_playing(false)
	return CommandResult.success()


## Writes the open session to its slot; save_completed or save_failed on the EventBus.
func save_now() -> CommandResult:
	if session == null:
		return CommandResult.fail(Reasons.SLOT_NOT_SELECTED)
	_autosave_elapsed_ms = 0
	var result: CommandResult = SaveService.write_slot(active_slot, session.to_save(GameClock.now_unix_ms()))
	if result.ok:
		EventBus.save_completed.emit(active_slot)
	else:
		Log.warn(LOG_CATEGORY, "save of slot %d failed (%s)" % [active_slot, result.reason])
		EventBus.save_failed.emit(active_slot, result.reason)
	return result


## Stops the clock and the autosave, saves if asked, emits session_ended, frees the session, back to `menu`.
func end_session(save: bool = true) -> void:
	if session == null:
		return
	_stop_playing()
	if save:
		save_now()
	var slot: int = active_slot
	EventBus.session_ended.emit(slot)
	_detach()


## slot_active if it is the slot of the open session; otherwise the store's result.
func delete_slot(slot: int) -> CommandResult:
	if session != null and slot == active_slot:
		return CommandResult.fail(Reasons.SLOT_ACTIVE)
	return SaveService.delete_slot(slot)


func _check_can_start(slot: int) -> CommandResult:
	if session != null:
		return CommandResult.fail(Reasons.SLOT_ACTIVE)
	if slot < 1 or slot > _slot_count:
		Log.warn(LOG_CATEGORY, "slot %d out of range 1-%d" % [slot, _slot_count])
		return CommandResult.fail(Reasons.IO_ERROR)
	return CommandResult.success()


# A session on the real data and the EventBus, with a new seed (from_save replaces it with the saved one).
func _create_session(slot: int) -> GameSession:
	return GameSession.new(DataRegistry.data, EventBus, _new_seed(slot))


func _new_seed(slot: int) -> int:
	return (Time.get_ticks_usec() ^ (slot << SEED_SLOT_SHIFT)) & SEED_MASK


func _attach(new_session: GameSession, slot: int) -> void:
	new_session.slot = slot
	session = new_session
	active_slot = slot
	add_child(new_session)


func _detach() -> void:
	if session != null:
		remove_child(session)
		session.free()
	session = null
	active_slot = -1
	state = STATE_MENU


func _start_playing(is_new: bool) -> void:
	_autosave_elapsed_ms = 0
	if not GameClock.ticked.is_connected(_on_game_clock_ticked):
		GameClock.ticked.connect(_on_game_clock_ticked)
	GameClock.set_paused(false)
	state = STATE_PLAYING
	EventBus.session_started.emit(active_slot, is_new)


func _stop_playing() -> void:
	if GameClock.ticked.is_connected(_on_game_clock_ticked):
		GameClock.ticked.disconnect(_on_game_clock_ticked)
	GameClock.set_paused(true)
	_autosave_elapsed_ms = 0


func _on_game_clock_ticked(delta_ms: int) -> void:
	if session == null or state != STATE_PLAYING:
		return
	session.advance(delta_ms)
	_autosave_elapsed_ms += delta_ms
	if _autosave_interval_ms > 0 and _autosave_elapsed_ms >= _autosave_interval_ms:
		save_now()
