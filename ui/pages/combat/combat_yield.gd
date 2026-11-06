class_name CombatYield
extends RefCounted
## Yield and log of the combat page (docs/UI_GDR.md §2): kills, XP, gold and damage per hour or second over a sliding
## window of one hour, plus the counters and the last lines of the log.
##
## Pure derived reading of the events the page already observes: it is never saved and holds no game state (the
## model's own counters stay in `CombatEngine`). The window starts when the page is opened, so it is shorter than one
## hour until enough time has passed; `window_ms` says how long it really is. Times are `session.play_time_ms`.

const KILLS: StringName = &"kills"
const XP: StringName = &"xp"
const GOLD: StringName = &"gold"
const DAMAGE: StringName = &"damage"
const WINDOW_MS: int = 3600000
const MIN_ELAPSED_MS: int = 1000
const MS_PER_HOUR: int = 3600000
const MS_PER_MINUTE: int = 60000
const MS_PER_SECOND: int = 1000

var hits: int = 0
var blocks: int = 0
var abilities: int = 0

var _start_ms: int = 0
## kind -> Array of Vector2i(time_ms, amount), oldest first.
var _samples: Dictionary[StringName, Array] = {}
var _log: PackedStringArray = PackedStringArray()


func _init(start_ms: int) -> void:
	_start_ms = start_ms
	for kind: StringName in [KILLS, XP, GOLD, DAMAGE]:
		_samples[kind] = []


func record(kind: StringName, amount: int, now_ms: int) -> void:
	if amount > 0 and _samples.has(kind):
		_samples[kind].append(Vector2i(now_ms, amount))


## Length of the window really covered, 0..WINDOW_MS.
func window_ms(now_ms: int) -> int:
	return clampi(now_ms - _start_ms, 0, WINDOW_MS)


## Per hour (kills, XP, gold); 0 until MIN_ELAPSED_MS have passed.
func per_hour(kind: StringName, now_ms: int) -> int:
	return _rate(kind, now_ms, MS_PER_HOUR)


## Per second (damage).
func per_second(kind: StringName, now_ms: int) -> int:
	return _rate(kind, now_ms, MS_PER_SECOND)


func _rate(kind: StringName, now_ms: int, unit_ms: int) -> int:
	var elapsed: int = window_ms(now_ms)
	if elapsed < MIN_ELAPSED_MS:
		return 0
	var samples: Array = _samples[kind]
	while not samples.is_empty() and (samples[0] as Vector2i).x < now_ms - WINDOW_MS:
		samples.pop_front()
	var total: int = 0
	for sample: Vector2i in samples:
		total += sample.y
	return roundi(float(total) * float(unit_ms) / float(elapsed))


func add_log(line: String) -> void:
	_log.append(line)
	while _log.size() > UiStyle.COMBAT_LOG_BUFFER:
		_log.remove_at(0)


## The last `count` lines, newest last.
func last_lines(count: int) -> PackedStringArray:
	return _log.slice(maxi(0, _log.size() - count))


func line_count() -> int:
	return _log.size()
