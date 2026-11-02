extends Node
## Game clock (autoload `GameClock`): turns real frame time into fixed steps of `tick_ms`.
##
## Every whole `tick_ms` accumulated emits `ticked(tick_ms)`, several times per frame if needed. At most
## `max_catchup_ms` are processed per frame: the excess (long freeze, debugger break) is discarded, the remainder
## below one tick is kept for the next frame. Until `configure` is called (by Game, with the values of balance.json)
## the clock emits nothing. `time_source` gives wall-clock Unix ms and can be replaced by tests.

signal ticked(delta_ms: int)

const MS_PER_SECOND: float = 1000.0

var time_source: Callable

var _tick_ms: int = 0
var _max_catchup_ms: int = 0
var _accumulated_ms: float = 0.0
var _paused: bool = false


func _init() -> void:
	time_source = _system_unix_ms


func _process(delta: float) -> void:
	if _paused or _tick_ms <= 0:
		return
	_accumulated_ms = minf(_accumulated_ms + delta * MS_PER_SECOND, float(_max_catchup_ms))
	while _accumulated_ms >= float(_tick_ms):
		_accumulated_ms -= float(_tick_ms)
		ticked.emit(_tick_ms)


func set_paused(paused: bool) -> void:
	_paused = paused


func is_paused() -> bool:
	return _paused


func now_unix_ms() -> int:
	var value: Variant = time_source.call()
	return int(value)


func configure(tick_ms: int, max_catchup_ms: int) -> void:
	if tick_ms <= 0 or max_catchup_ms < tick_ms:
		push_error("GameClock.configure: invalid tick_ms=%d max_catchup_ms=%d" % [tick_ms, max_catchup_ms])
		return
	_tick_ms = tick_ms
	_max_catchup_ms = max_catchup_ms
	_accumulated_ms = 0.0


func _system_unix_ms() -> int:
	return int(Time.get_unix_time_from_system() * MS_PER_SECOND)
