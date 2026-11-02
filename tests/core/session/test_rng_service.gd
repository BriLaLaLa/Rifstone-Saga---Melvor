extends GutTest
## RngService: determinism by seed, save/load continuing the sequence, certain rolls consuming nothing, weights.

const DRAWS: int = 20


func test_same_seed_gives_same_sequence() -> void:
	var a: RngService = RngService.new(918273)
	var b: RngService = RngService.new(918273)
	assert_eq(_sequence(a), _sequence(b))


func test_different_seeds_give_different_sequences() -> void:
	assert_ne(_sequence(RngService.new(1)), _sequence(RngService.new(2)))


func test_save_and_load_continue_the_same_sequence() -> void:
	var a: RngService = RngService.new(918273)
	_sequence(a)
	var saved: Dictionary = SaveCodec.decode(SaveCodec.encode({"rng": a.to_save()}))
	var b: RngService = RngService.new(5)
	b.from_save(saved["rng"])
	assert_eq(_sequence(b), _sequence(a))


func test_to_save_has_seed_and_state() -> void:
	var saved: Dictionary = RngService.new(918273).to_save()
	assert_eq(saved.keys(), ["seed", "state"])
	assert_eq(saved["seed"], 918273)


func test_large_state_is_saved_as_string() -> void:
	var a: RngService = RngService.new(918273)
	for i: int in DRAWS:
		a.randf()
		var state: Variant = a.to_save()["state"]
		if state is String:
			var s: String = state
			assert_gt(absi(s.to_int()), RngService.MAX_EXACT_JSON_INT)
		else:
			assert_true(state is int)
			var n: int = state
			assert_lte(absi(n), RngService.MAX_EXACT_JSON_INT)


func test_from_save_with_invalid_block_keeps_the_generator() -> void:
	var a: RngService = RngService.new(77)
	var b: RngService = RngService.new(77)
	a.from_save({"seed": "not a number", "state": 3})
	a.from_save({"seed": 1})
	assert_eq(_sequence(a), _sequence(b))


func test_roll_pct_zero_or_less_is_false_without_consuming() -> void:
	var a: RngService = RngService.new(31)
	var b: RngService = RngService.new(31)
	assert_false(a.roll_pct(0.0))
	assert_false(a.roll_pct(-5.0))
	assert_eq(a.randf(), b.randf())


func test_roll_pct_hundred_or_more_is_true_without_consuming() -> void:
	var a: RngService = RngService.new(31)
	var b: RngService = RngService.new(31)
	assert_true(a.roll_pct(100.0))
	assert_true(a.roll_pct(250.0))
	assert_eq(a.randf(), b.randf())


func test_roll_pct_between_consumes_one_number() -> void:
	var a: RngService = RngService.new(31)
	var b: RngService = RngService.new(31)
	a.roll_pct(50.0)
	b.randf()
	assert_eq(a.randf(), b.randf())


func test_roll_pct_follows_the_chance() -> void:
	var rng: RngService = RngService.new(4242)
	var hits: int = 0
	for i: int in 1000:
		if rng.roll_pct(30.0):
			hits += 1
	assert_between(hits, 250, 350)


func test_randi_range_stays_in_bounds() -> void:
	var rng: RngService = RngService.new(9)
	for i: int in 200:
		assert_between(rng.randi_range(3, 6), 3, 6)


func test_pick_weighted_never_picks_zero_weight() -> void:
	var rng: RngService = RngService.new(12)
	var weights: Array[int] = [0, 5, 0, 1]
	var counts: Array[int] = [0, 0, 0, 0]
	for i: int in 600:
		counts[rng.pick_weighted(weights)] += 1
	assert_eq(counts[0], 0)
	assert_eq(counts[2], 0)
	assert_gt(counts[1], counts[3])
	assert_gt(counts[3], 0)


func test_pick_weighted_single_weight_is_always_that_index() -> void:
	var rng: RngService = RngService.new(12)
	var weights: Array[int] = [0, 0, 7]
	for i: int in 50:
		assert_eq(rng.pick_weighted(weights), 2)


# Mixed draws of every kind, so the comparison covers each method.
func _sequence(rng: RngService) -> Array:
	var out: Array = []
	var weights: Array[int] = [1, 2, 3]
	for i: int in DRAWS:
		out.append(rng.randf())
		out.append(rng.randi_range(0, 1000))
		out.append(rng.roll_pct(50.0))
		out.append(rng.pick_weighted(weights))
	return out
