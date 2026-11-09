extends GutTest
## A Fracture open when the player leaves runs on during the absence (docs/01_GDD.md §17.2): it ends (won or lost), the
## fight goes back to the area, and `OfflineSummary.fractures` tells it. 12 hours with a Fracture in progress stay fast.

const HOUR_MS: int = 3_600_000
const AREA: StringName = &"test_area"


func _session(seed_value: int, groups: int = 3) -> GameSession:
	var s: GameSession = autofree(FractureUtil.session(seed_value, groups))
	FractureUtil.hero(s)
	return s


func _run(s: GameSession, ms: int) -> OfflineSummary:
	return await OfflineSimulator.new().run(s, ms, false, false)


func test_a_fracture_won_while_away_is_told_in_the_summary() -> void:
	var s: GameSession = _session(3)
	assert_true(s.fractures.open(FractureUtil.card(s, 1)).ok)
	var summary: OfflineSummary = await _run(s, HOUR_MS)
	assert_eq(summary.fractures.size(), 1)
	var entry: Dictionary = summary.fractures[0]
	assert_eq(entry["grade"], 1)
	assert_eq(entry["outcome"], &"won")
	assert_eq(entry["groups"], 3)
	assert_false(summary.is_empty())
	assert_false(s.fractures.is_active())
	assert_false(s.fractures.has_pending())
	assert_gt(summary.items.get(&"rift_shard", 0), 0, "the bag was delivered")


func test_the_fight_goes_back_to_the_area_and_goes_on() -> void:
	var s: GameSession = _session(4)
	s.combat.start(AREA)
	assert_true(s.fractures.open(FractureUtil.card(s, 1)).ok)
	var summary: OfflineSummary = await _run(s, HOUR_MS)
	assert_eq(summary.fractures.size(), 1)
	assert_true(s.combat.is_active())
	assert_eq(s.combat.area_id(), AREA)
	assert_gt(summary.kills.get(&"test_monster_a", 0), 100, "an hour of kills in the area after the Fracture")
	assert_false(summary.stop_reasons.has(Reasons.FRACTURE_WON), "no stop: the area started again")


func test_without_an_area_the_stop_is_in_the_summary() -> void:
	var s: GameSession = _session(5)
	assert_true(s.fractures.open(FractureUtil.card(s, 1)).ok)
	var summary: OfflineSummary = await _run(s, HOUR_MS)
	assert_eq(summary.stop_reasons, [Reasons.FRACTURE_WON] as Array[StringName])
	assert_false(s.combat.is_active())


func test_a_fracture_lost_while_away() -> void:
	var s: GameSession = _session(6)
	FractureUtil.weakling(s)
	assert_true(s.fractures.open(FractureUtil.card(s, 1)).ok)
	var summary: OfflineSummary = await _run(s, HOUR_MS)
	assert_eq(summary.fractures.size(), 1)
	assert_eq(summary.fractures[0]["outcome"], &"died")
	assert_eq(summary.deaths, 1)
	assert_false(s.fractures.is_active())
	assert_false(s.fractures.has_pending())


func test_the_summary_without_a_fracture_has_none() -> void:
	var s: GameSession = _session(7)
	s.combat.start(AREA)
	var summary: OfflineSummary = await _run(s, 600_000)
	assert_true(summary.fractures.is_empty())


func test_twelve_hours_with_a_fracture_in_progress_take_less_than_ten_seconds() -> void:
	var s: GameSession = _session(8, 30)
	s.combat.start(AREA)
	assert_true(s.fractures.open(FractureUtil.card(s, 1)).ok)
	var started: int = Time.get_ticks_msec()
	var summary: OfflineSummary = await _run(s, 12 * HOUR_MS)
	var took: int = Time.get_ticks_msec() - started
	assert_lt(took, 10_000, "12 h in %d ms" % took)
	assert_eq(summary.fractures.size(), 1)
	assert_eq(summary.fractures[0]["groups"], 30)
	assert_eq(summary.fractures[0]["outcome"], &"won")
