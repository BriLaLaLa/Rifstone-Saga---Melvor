extends GutTest
## DebugTimeSkip (M25-07): cap, silent path below offline.min_ms, summary above, setting persisted, slot untouched.

const PreRun := preload("res://tests/helpers/gut_pre_run.gd")
const HOUR_MS: int = 3600000

var _dir: String = PreRun.test_dir("test_debug_time_skip")
var _file: String = _dir.path_join("settings.cfg")


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(_dir)
	DirAccess.remove_absolute(_file)
	GameSettings.file_path = _file
	GameSettings.reset()


func after_each() -> void:
	DirAccess.remove_absolute(_file)
	GameSettings.file_path = GameSettings.FILE
	GameSettings.reset()


func _session() -> GameSession:
	return autofree(TestFactory.session(7, TestFactory.real_data()))


func test_max_hours_and_elapsed_follow_the_cap() -> void:
	var s: GameSession = _session()
	var cap_ms: int = int(s.data.balance_value("offline.cap_ms"))
	assert_eq(DebugTimeSkip.max_hours(s), cap_ms / HOUR_MS)
	assert_eq(DebugTimeSkip.elapsed_ms(s, 2), 2 * HOUR_MS)
	assert_eq(DebugTimeSkip.elapsed_ms(s, 1000), cap_ms)
	assert_eq(DebugTimeSkip.elapsed_ms(s, 0), 0)


func test_run_gives_summary_and_flags_cap() -> void:
	var s: GameSession = _session()
	var summary: OfflineSummary = await DebugTimeSkip.new().run(s, 1000, false)
	assert_not_null(summary)
	assert_eq(summary.elapsed_ms, DebugTimeSkip.elapsed_ms(s, 1000))
	assert_true(summary.capped)


func test_run_does_not_change_play_time_or_save_state_shape() -> void:
	var s: GameSession = _session()
	var play: int = s.play_time_ms
	await DebugTimeSkip.new().run(s, 2, false)
	assert_eq(s.play_time_ms, play)
	assert_false(s.to_save(0).has(GameSettings.KEY_DEBUG_SKIP_HOURS))


func test_zero_hours_does_nothing() -> void:
	assert_null(await DebugTimeSkip.new().run(_session(), 0, false))


func test_hours_setting_persists_in_settings_file_only() -> void:
	assert_eq(int(GameSettings.get_value(GameSettings.KEY_DEBUG_SKIP_HOURS)), 1)
	GameSettings.set_value(GameSettings.KEY_DEBUG_SKIP_HOURS, 6)
	GameSettings.save()
	GameSettings.reset()
	assert_eq(int(GameSettings.get_value(GameSettings.KEY_DEBUG_SKIP_HOURS)), 6)
	GameSettings.set_value(GameSettings.KEY_DEBUG_SKIP_HOURS, 0)
	assert_eq(int(GameSettings.get_value(GameSettings.KEY_DEBUG_SKIP_HOURS)), 6)
	assert_push_error(1)
