extends GutTest
## The helpers work offline (same engine, phase _PHASE_HELPERS) and while combat is active. Real data, a Master helper
## on Betulla put in place with `from_save` (the contract items come with the data of M12-05). No slot is written.

const SKILL: StringName = &"forestry"
const LOG_ITEM: StringName = &"redbirch_log"
const AREA: StringName = &"redrock_plains"
const HOUR_MS: int = 3600000
const MASTER_INTERVAL_MS: int = 4500

var _session: GameSession
var _cycles: int = 0


func before_each() -> void:
	_session = autofree(TestFactory.session_no_kit(31, TestFactory.real_data()))
	_session.helpers.from_save({"forestry": {"grade": "master", "action": "cut_redbirch", "elapsed_ms": 0}})
	_cycles = 0
	_session.events.helper_completed.connect(func(_s: StringName, _a: StringName, _o: Dictionary) -> void: _cycles += 1)


func test_offline_hours_run_the_expected_number_of_cycles() -> void:
	assert_eq(_session.helpers.interval_ms(SKILL), MASTER_INTERVAL_MS)
	var summary: OfflineSummary = await OfflineSimulator.new().run(_session, 2 * HOUR_MS, false, false)
	assert_not_null(summary)
	assert_eq(_cycles, 2 * HOUR_MS / MASTER_INTERVAL_MS)
	assert_gte(_session.bank.get_count(LOG_ITEM), _cycles)


func test_silent_offline_is_the_same() -> void:
	OfflineSimulator.advance_silently(_session, HOUR_MS)
	assert_eq(_cycles, HOUR_MS / MASTER_INTERVAL_MS)


func test_the_helper_produces_while_combat_is_active() -> void:
	assert_true(_session.combat.start(AREA).ok)
	assert_true(_session.combat.is_active())
	_session.advance(HOUR_MS / 10)
	assert_eq(_cycles, (HOUR_MS / 10) / MASTER_INTERVAL_MS)
	assert_gt(_session.bank.get_count(LOG_ITEM), 0)


func test_partial_progress_survives_a_save_load() -> void:
	_session.advance(2000)
	var saved: Dictionary = _session.to_save(1)
	var other: GameSession = autofree(TestFactory.session_no_kit(31, TestFactory.real_data()))
	assert_true(other.from_save(JSON.parse_string(JSON.stringify(saved))).ok)
	assert_almost_eq(other.helpers.get_progress(SKILL), 2000.0 / MASTER_INTERVAL_MS, 0.0001)
