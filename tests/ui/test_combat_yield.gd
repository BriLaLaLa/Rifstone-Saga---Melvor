extends GutTest
## CombatYield (M6-00c): sliding window of one hour, rates per hour and per second, log buffer.


func test_rates_use_the_window_really_covered() -> void:
	var tracker := CombatYield.new(0)
	tracker.record(CombatYield.KILLS, 1, 10000)
	tracker.record(CombatYield.KILLS, 1, 20000)
	assert_eq(tracker.per_hour(CombatYield.KILLS, 500), 0, "less than a second: no rate")
	assert_eq(tracker.per_hour(CombatYield.KILLS, 60000), 120, "2 kills in one minute = 120 per hour")
	assert_eq(tracker.window_ms(60000), 60000)


func test_old_samples_leave_the_window() -> void:
	var tracker := CombatYield.new(0)
	tracker.record(CombatYield.XP, 1000, 1000)
	assert_eq(tracker.per_hour(CombatYield.XP, CombatYield.WINDOW_MS), 1000)
	assert_eq(tracker.per_hour(CombatYield.XP, CombatYield.WINDOW_MS * 2), 0, "after two hours the sample is out")
	assert_eq(tracker.window_ms(CombatYield.WINDOW_MS * 2), CombatYield.WINDOW_MS)


func test_damage_per_second() -> void:
	var tracker := CombatYield.new(0)
	tracker.record(CombatYield.DAMAGE, 50, 1000)
	tracker.record(CombatYield.DAMAGE, 150, 4000)
	assert_eq(tracker.per_second(CombatYield.DAMAGE, 10000), 20)


func test_log_keeps_the_last_lines() -> void:
	var tracker := CombatYield.new(0)
	for i: int in UiStyle.COMBAT_LOG_BUFFER + 5:
		tracker.add_log("line %d" % i)
	assert_eq(tracker.line_count(), UiStyle.COMBAT_LOG_BUFFER)
	assert_eq(tracker.last_lines(2)[1], "line %d" % (UiStyle.COMBAT_LOG_BUFFER + 4))
