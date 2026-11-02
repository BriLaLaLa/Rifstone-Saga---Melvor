extends GutTest
## GameClock: accumulation into fixed ticks, bounded catch-up, pause, replaceable time source.
##
## The clock is a private instance outside the tree, so frames are simulated by calling _process(delta)
## directly with exact binary fractions of a second.

const GameClockScript := preload("res://core/autoload/game_clock.gd")

var _clock: GameClockScript
var _ticks: Array[int] = []


func before_each() -> void:
	_clock = autofree(GameClockScript.new())
	_ticks.clear()
	_clock.ticked.connect(_on_clock_ticked)


func test_250_ms_with_100_ms_tick_emits_twice_and_keeps_50_ms() -> void:
	_clock.configure(100, 5000)
	_clock._process(0.25)
	assert_eq(_ticks, [100, 100] as Array[int])
	# The 50 ms remainder is kept: 50 more ms complete the third tick.
	_clock._process(0.0625)
	assert_eq(_ticks.size(), 3)


func test_remainder_below_one_tick_does_not_emit() -> void:
	_clock.configure(100, 5000)
	_clock._process(0.25)
	_clock._process(0.03125)
	assert_eq(_ticks.size(), 2, "50 + 31.25 ms < 100 ms")


func test_small_frames_accumulate() -> void:
	_clock.configure(100, 5000)
	for i: int in 8:
		_clock._process(0.015625)
	assert_eq(_ticks.size(), 1, "8 x 15.625 ms = 125 ms")


func test_catch_up_is_limited_and_excess_discarded() -> void:
	_clock.configure(100, 300)
	_clock._process(2.0)
	assert_eq(_ticks.size(), 3, "at most max_catchup_ms per frame")
	_clock._process(0.0625)
	assert_eq(_ticks.size(), 3, "the discarded 1700 ms do not come back")


func test_paused_clock_does_not_emit_nor_accumulate() -> void:
	_clock.configure(100, 5000)
	_clock.set_paused(true)
	assert_true(_clock.is_paused())
	_clock._process(0.5)
	assert_eq(_ticks.size(), 0)
	_clock.set_paused(false)
	assert_false(_clock.is_paused())
	_clock._process(0.0625)
	assert_eq(_ticks.size(), 0, "time spent paused is not accumulated")


func test_not_paused_by_default() -> void:
	assert_false(_clock.is_paused())


func test_unconfigured_clock_does_not_emit() -> void:
	_clock._process(1.0)
	assert_eq(_ticks.size(), 0)


func test_invalid_configuration_is_rejected() -> void:
	_clock.configure(0, 5000)
	_clock.configure(100, 50)
	assert_push_error(2)
	_clock._process(1.0)
	assert_eq(_ticks.size(), 0)


func test_time_source_is_replaceable() -> void:
	_clock.time_source = func() -> int: return 1_700_000_000_123
	assert_eq(_clock.now_unix_ms(), 1_700_000_000_123)


func test_default_time_source_is_system_unix_ms() -> void:
	var expected: int = int(Time.get_unix_time_from_system() * 1000.0)
	assert_almost_eq(_clock.now_unix_ms(), expected, 1000)


func _on_clock_ticked(delta_ms: int) -> void:
	_ticks.append(delta_ms)
