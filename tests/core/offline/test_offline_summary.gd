extends GutTest
## OfflineSummary.from_snapshots: differences, levels as (from, to), stop reasons, is_empty.


func _snapshot() -> SessionSnapshot:
	return SessionSnapshot.new()


func test_empty_snapshots_give_an_empty_summary() -> void:
	var summary: OfflineSummary = OfflineSummary.from_snapshots(_snapshot(), _snapshot(), 90000, false, [] as Array[StringName])
	assert_true(summary.is_empty())
	assert_eq(summary.elapsed_ms, 90000)
	assert_false(summary.capped)


func test_differences_levels_and_counters() -> void:
	var before: SessionSnapshot = _snapshot()
	var after: SessionSnapshot = _snapshot()
	before.xp = {&"forestry": 100, &"angling": 5}
	after.xp = {&"forestry": 450, &"angling": 5, &"character": 20}
	before.levels = {&"forestry": 3, &"angling": 1}
	after.levels = {&"forestry": 5, &"angling": 1, &"character": 1}
	before.bank = {&"log": 10, &"ore": 8, &"fish": 2}
	after.bank = {&"log": 25, &"ore": 0, &"plank": 4, &"fish": 2}
	before.gold = 50
	after.gold = 20
	before.kills = {&"boar": 1}
	after.kills = {&"boar": 7, &"rat": 2}
	before.deaths = 1
	after.deaths = 3
	before.food_eaten = 4
	after.food_eaten = 9
	var stops: Array[StringName] = [Reasons.MISSING_INPUTS]
	var summary: OfflineSummary = OfflineSummary.from_snapshots(before, after, 43200000, true, stops)
	assert_true(summary.capped)
	assert_eq(summary.xp, {&"forestry": 350, &"character": 20} as Dictionary[StringName, int], "unchanged xp left out")
	assert_eq(summary.levels, {&"forestry": Vector2i(3, 5)} as Dictionary[StringName, Vector2i], "only changed levels, x = from, y = to")
	assert_eq(summary.items, {&"log": 15, &"ore": -8, &"plank": 4} as Dictionary[StringName, int], "negative = consumed")
	assert_eq(summary.gold_delta, -30)
	assert_eq(summary.kills, {&"boar": 6, &"rat": 2} as Dictionary[StringName, int])
	assert_eq(summary.deaths, 2)
	assert_eq(summary.food_eaten, 5)
	assert_eq(summary.stop_reasons, stops)
	assert_false(summary.is_empty())


func test_an_item_that_left_the_bank_entirely_is_a_negative_difference() -> void:
	var before: SessionSnapshot = _snapshot()
	before.bank = {&"ore": 6}
	var summary: OfflineSummary = OfflineSummary.from_snapshots(before, _snapshot(), 1, false, [] as Array[StringName])
	assert_eq(summary.items, {&"ore": -6} as Dictionary[StringName, int])


func test_stop_reason_or_piece_counters_alone_make_it_not_empty() -> void:
	var with_stop: OfflineSummary = OfflineSummary.from_snapshots(_snapshot(), _snapshot(), 1, false,
		[Reasons.BANK_FULL] as Array[StringName])
	assert_false(with_stop.is_empty())
	var with_pieces: OfflineSummary = OfflineSummary.new()
	with_pieces.pieces_dismantled = 1
	assert_false(with_pieces.is_empty())
