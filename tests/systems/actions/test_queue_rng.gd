extends GutTest
## The production queue's own generator (M24-09, Q124, docs/05_INTERFACES_M24.md §5.32 and §6b): derived from the slot seed, saved in
## `actions.rng`, tolerant of a v8 save without it, and never shared with `session.rng`.


func _session(seed_value: int) -> GameSession:
	var s: GameSession = autofree(TestFactory.session_no_kit(seed_value, TestFactory.real_data()))
	s.disciplines.new_game()
	assert_true(s.disciplines.learn(&"forging").ok)
	TestFactory.set_level(s, &"forging", 20)
	TestFactory.give(s, &"emberbronze_ore", 1000)
	return s


func _run_queue(s: GameSession) -> void:
	assert_true(s.actions.enqueue(&"forging", &"smelt_emberbronze", 20, false).ok)
	s.advance(60_000)


func test_the_queue_does_not_touch_the_session_rng() -> void:
	var s: GameSession = _session(77)
	s.modifiers.set_source(&"test:rolls", [Modifier.make(&"double_item_chance", 50.0), Modifier.make(&"preservation_chance", 50.0)])
	var before: Dictionary = s.rng.to_save()
	_run_queue(s)
	assert_gt(s.skills.get_xp(&"forging"), 0, "the queue worked")
	assert_eq(s.rng.to_save(), before)
	assert_ne(s.actions.to_save()["rng"], ProductionQueueLoader.derive_rng(s).to_save(), "its own generator moved")


func test_the_generator_is_derived_from_the_slot_seed() -> void:
	var a: GameSession = _session(77)
	var b: GameSession = _session(77)
	var c: GameSession = _session(78)
	assert_eq(a.actions.to_save()["rng"], b.actions.to_save()["rng"])
	assert_ne(a.actions.to_save()["rng"]["seed"], c.actions.to_save()["rng"]["seed"])
	assert_ne(a.actions.to_save()["rng"]["seed"], a.rng.seed_value(), "not the stream of the session")


func test_the_derived_seed_is_exact_in_json() -> void:
	for base: int in [0, 1, 77, -5, 9223372036854775807, -9223372036854775807]:
		var seed_value: int = RngService.derive_seed(base, ProductionQueueLoader.RNG_SALT)
		assert_between(seed_value, 0, RngService.MAX_EXACT_JSON_INT, "seed of %d" % base)


func test_save_and_load_keep_the_generator() -> void:
	var s: GameSession = _session(77)
	_run_queue(s)
	var saved: Dictionary = s.actions.to_save()
	var loaded: GameSession = _session(5)
	loaded.actions.from_save(SaveCodec.decode(SaveCodec.encode(saved)))
	assert_eq(loaded.actions.to_save()["rng"], saved["rng"])


func test_a_save_without_the_generator_derives_it_from_the_seed() -> void:
	var s: GameSession = _session(77)
	_run_queue(s)
	var saved: Dictionary = s.actions.to_save()
	saved.erase("rng")
	var other: GameSession = _session(77)
	other.actions.from_save(saved)
	assert_eq(other.actions.to_save()["rng"], ProductionQueueLoader.derive_rng(other).to_save())
