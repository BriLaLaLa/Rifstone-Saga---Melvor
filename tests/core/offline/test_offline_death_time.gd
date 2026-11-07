extends GutTest
## B3 (M10-07): the offline summary dates a combat stop at the real offline time (blocks done + time inside the block),
## never at the start of the block ("dead after 0 s"). Real data, fixed seed, no slot written.

const SEED: int = 4242
const AREA: StringName = &"redrock_plains"
const HERO: StringName = &"test:hero"
const HOUR_MS: int = 3600000
const STEP_MS: int = 100


func _weak_session(hp_left: int) -> GameSession:
	var s: GameSession = autofree(TestFactory.session(SEED, TestFactory.real_data()))
	s.modifiers.set_source(HERO, [Modifier.make(&"max_hp_flat", -(float(s.combat.player_stats().max_hp) - float(hp_left)))])
	assert_true(s.combat.start(AREA).ok)
	return s


# Death time of the same session advanced in 100 ms steps (the engine gives the same result for any step size).
func _death_time_ms(hp_left: int) -> int:
	var s: GameSession = _weak_session(hp_left)
	var t: int = 0
	while s.combat.is_active() and t < 2 * HOUR_MS:
		s.advance(STEP_MS)
		t += STEP_MS
	return t


func test_death_in_the_first_block_is_not_dated_zero() -> void:
	var s: GameSession = _weak_session(1)
	var summary: OfflineSummary = await OfflineSimulator.new().run(s, HOUR_MS, false, false)
	var index: int = summary.stop_reasons.find(Reasons.PLAYER_DIED)
	assert_gte(index, 0, "the hero died")
	assert_gt(summary.stop_times_ms[index], 0, "not 'after 0 s'")
	assert_almost_eq(float(summary.stop_times_ms[index]), float(_death_time_ms(1)), float(STEP_MS), "real time of the death")


func test_death_in_a_later_block_adds_the_blocks_done() -> void:
	var hp: int = 40
	var expected: int = _death_time_ms(hp)
	var s: GameSession = _weak_session(hp)
	var summary: OfflineSummary = await OfflineSimulator.new().run(s, 2 * HOUR_MS, false, false)
	var index: int = summary.stop_reasons.find(Reasons.PLAYER_DIED)
	assert_gte(index, 0, "the hero died")
	assert_almost_eq(float(summary.stop_times_ms[index]), float(expected), float(STEP_MS))
	assert_lt(summary.stop_times_ms[index], 2 * HOUR_MS)
	assert_eq(s.combat.advance_offset_ms, 0, "the offset is 0 outside advance")
