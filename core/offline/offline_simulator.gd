class_name OfflineSimulator
extends RefCounted
## Offline progress (docs/01_GDD.md §12, docs/03_ARCHITECTURE.md §8): the same `GameSession.advance` as online play,
## in blocks of `offline.chunk_ms`, with a snapshot before and after. No formula lives here.
##
## Actions are fast by construction (one loop per cycle) and the combat engine jumps from timer to timer (F-76), so a
## block costs the events it contains, not its milliseconds. Drops go through `Armory.add_drop`, i.e. through the
## automatic filter, exactly as online. `play_time_ms` is restored afterwards: it counts online time only.

const LOG_CATEGORY: String = "offline"
const CAP_KEY: String = "offline.cap_ms"
const CHUNK_KEY: String = "offline.chunk_ms"
const MIN_KEY: String = "offline.min_ms"

var _summary_stops: Array[StringName] = []
var _summary_stop_times: Array[int] = []
var _pieces_stored: int = 0
var _pieces_dismantled: int = 0
var _pieces_rejected: int = 0
var _bank_rejected: Dictionary[StringName, int] = {}
var _chunk_start_ms: int = 0


## F-40: clamp(now - saved_at, 0, cap_ms). A clock set back gives 0.
static func compute_elapsed(saved_at_unix_ms: int, now_unix_ms: int, cap_ms: int) -> int:
	return clampi(now_unix_ms - saved_at_unix_ms, 0, cap_ms)


## F-40: true when the real time away is longer than the cap.
static func is_capped(saved_at_unix_ms: int, now_unix_ms: int, cap_ms: int) -> bool:
	return (now_unix_ms - saved_at_unix_ms) > cap_ms


## F-41: ceil(elapsed / chunk_ms).
static func chunk_count(elapsed_ms: int, chunk_ms: int) -> int:
	if elapsed_ms <= 0 or chunk_ms <= 0:
		return 0
	return (elapsed_ms + chunk_ms - 1) / chunk_ms


## Below offline.min_ms: the same blocks with no signals and no summary (no screen). Play time is restored.
static func advance_silently(session: GameSession, elapsed_ms: int) -> void:
	var chunk_ms: int = int(session.data.balance_value(CHUNK_KEY))
	var play_time_ms: int = session.play_time_ms
	var done_ms: int = 0
	while done_ms < elapsed_ms:
		var step_ms: int = mini(chunk_ms, elapsed_ms - done_ms)
		session.advance(step_ms)
		done_ms += step_ms
	session.play_time_ms = play_time_ms


## Simulates `elapsed_ms` of play (a coroutine). Emits offline_started, offline_progress after every block and
## offline_completed on session.events. With yield_frames the run waits one frame between blocks (the UI redraws).
func run(session: GameSession, elapsed_ms: int, capped: bool, yield_frames: bool = true) -> OfflineSummary:
	assert(session != null, "OfflineSimulator.run needs a session")
	var chunk_ms: int = int(session.data.balance_value(CHUNK_KEY))
	assert(chunk_ms > 0, "offline.chunk_ms must be positive")
	var total_ms: int = maxi(elapsed_ms, 0)
	_reset()
	var before: SessionSnapshot = SessionSnapshot.take(session)
	var play_time_ms: int = session.play_time_ms
	_connect(session.events)
	session.events.offline_started.emit(total_ms, capped)
	var done_ms: int = 0
	while done_ms < total_ms:
		var step_ms: int = mini(chunk_ms, total_ms - done_ms)
		_chunk_start_ms = done_ms
		session.advance(step_ms)
		done_ms += step_ms
		session.events.offline_progress.emit(done_ms, total_ms)
		if yield_frames and done_ms < total_ms:
			await _next_frame()
	_disconnect(session.events)
	session.play_time_ms = play_time_ms
	var summary: OfflineSummary = OfflineSummary.from_snapshots(before, SessionSnapshot.take(session), total_ms,
		capped, _summary_stops)
	summary.stop_times_ms = _summary_stop_times.duplicate()
	summary.pieces_stored = _pieces_stored
	summary.pieces_dismantled = _pieces_dismantled
	summary.pieces_rejected = _pieces_rejected
	summary.bank_rejected = _bank_rejected.duplicate()
	session.events.offline_completed.emit(summary)
	return summary


func _reset() -> void:
	_summary_stops = []
	_summary_stop_times = []
	_pieces_stored = 0
	_pieces_dismantled = 0
	_pieces_rejected = 0
	_bank_rejected = {}
	_chunk_start_ms = 0


func _next_frame() -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	await tree.process_frame


func _connect(events: GameEvents) -> void:
	events.action_stopped.connect(_on_action_stopped)
	events.combat_stopped.connect(_on_combat_stopped)
	events.armory_changed.connect(_on_armory_changed)
	events.armory_rejected.connect(_on_armory_rejected)
	events.item_salvaged.connect(_on_item_salvaged)
	events.bank_rejected.connect(_on_bank_rejected)


func _disconnect(events: GameEvents) -> void:
	events.action_stopped.disconnect(_on_action_stopped)
	events.combat_stopped.disconnect(_on_combat_stopped)
	events.armory_changed.disconnect(_on_armory_changed)
	events.armory_rejected.disconnect(_on_armory_rejected)
	events.item_salvaged.disconnect(_on_item_salvaged)
	events.bank_rejected.disconnect(_on_bank_rejected)


func _on_action_stopped(_lane: StringName, _skill_id: StringName, reason: StringName) -> void:
	_log_stop(reason)


func _on_combat_stopped(reason: StringName) -> void:
	_log_stop(reason)


func _log_stop(reason: StringName) -> void:
	_summary_stops.append(reason)
	_summary_stop_times.append(_chunk_start_ms)


func _on_armory_changed(_uid: int, change: StringName) -> void:
	if change == Armory.CHANGE_ADDED:
		_pieces_stored += 1


func _on_armory_rejected(_base_id: StringName, qty: int) -> void:
	_pieces_rejected += qty


func _on_item_salvaged(_uid: int, _base_id: StringName, auto: bool) -> void:
	if auto:
		_pieces_dismantled += 1


func _on_bank_rejected(item_id: StringName, qty: int) -> void:
	_bank_rejected[item_id] = _bank_rejected.get(item_id, 0) + qty
