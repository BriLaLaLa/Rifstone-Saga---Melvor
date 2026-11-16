extends GutTest
## M24-07: the offline run uses the same engine as the game (docs/01_GDD_M24.md §35.9, Q109). On the real data, with fights, journeys,
## nodes worked and skipped and a production queue in parallel, the same seconds give the same state whether they pass in one block,
## in ticks of 100 ms or in blocks of `offline.chunk_ms`; and the real `OfflineSimulator` (one hour) gives the same state as its silent
## twin and counts the nodes of the summary.

const AREA: StringName = &"redrock_plains"
const SEED: int = 2412
const HOUR_MS: int = 3_600_000
const TICK_MS: int = 100


func _session(with_queue: bool = false) -> GameSession:
	var s: GameSession = autofree(TestFactory.session_no_kit(SEED, TestFactory.real_data()))
	s.disciplines.new_game()
	TestFactory.set_character_level(s, 55)
	TestFactory.make_roomy(s)
	_boost(s)
	s.wallet.add_gold(1000)
	for id: StringName in [&"forestry", &"angling", &"forging", &"hearthcraft"]:
		assert_true(s.disciplines.learn(id).ok)
	TestFactory.give(s, &"emberbronze_ore", 1_000_000)
	if with_queue:
		assert_true(s.actions.enqueue(&"forging", &"smelt_emberbronze", 1, true).ok)
	assert_true(s.combat.start(AREA).ok)
	return s


func _boost(s: GameSession) -> void:
	s.modifiers.set_source(&"test:hero", [Modifier.make(&"power_bonus", 100000.0), Modifier.make(&"max_hp_flat", 100000.0),
			Modifier.make(&"armor", 100000.0), Modifier.make(&"evasion_bonus", 80000.0)])


## The whole state that can differ: the slot file without its clock fields.
func _state(s: GameSession) -> Dictionary:
	var d: Dictionary = s.to_save(0)
	d.erase("play_time_ms")
	return d


func _in_ticks(s: GameSession, ms: int) -> void:
	for _i: int in ms / TICK_MS:
		s.advance(TICK_MS)


func _in_blocks(s: GameSession, ms: int, block_ms: int) -> void:
	for _i: int in ms / block_ms:
		s.advance(block_ms)


func _assert_same(a: GameSession, b: GameSession, what: String) -> void:
	var left: Dictionary = _state(a)
	var right: Dictionary = _state(b)
	var modules_a: Dictionary = left["modules"]
	var modules_b: Dictionary = right["modules"]
	for module: Variant in modules_a:
		assert_eq(modules_b.get(module), modules_a[module], "%s: module %s" % [what, module])
	assert_eq(right["rng"], left["rng"], "%s: the rng" % what)


func test_one_hour_in_one_block_in_ticks_and_in_blocks_is_the_same_state() -> void:
	var one: GameSession = _session()
	var ticks: GameSession = _session()
	var blocks: GameSession = _session()
	one.advance(HOUR_MS)
	_in_ticks(ticks, HOUR_MS)
	_in_blocks(blocks, HOUR_MS, 60_000)
	assert_gt(int(one.combat.node_counts()["worked"]), 0)
	assert_gt(int(one.combat.node_counts()["skipped"]), 0)
	_assert_same(one, ticks, "block vs ticks")
	_assert_same(one, blocks, "block vs blocks")


func test_twelve_hours_in_one_block_in_ticks_and_in_blocks_is_the_same_state() -> void:
	var one: GameSession = _session()
	var ticks: GameSession = _session()
	var blocks: GameSession = _session()
	var twelve: int = 12 * HOUR_MS
	one.advance(twelve)
	_in_ticks(ticks, twelve)
	_in_blocks(blocks, twelve, 60_000)
	assert_gt(int(one.combat.node_counts()["worked"]), 50, "twelve hours work many nodes")
	_assert_same(one, ticks, "12 h block vs ticks")
	_assert_same(one, blocks, "12 h block vs blocks")


func test_a_production_queue_in_parallel_gives_the_same_whole_state_in_every_block_size() -> void:
	# Q124: the queue rolls on its own generator and the block is cut in online steps while it runs: the whole state is the same.
	var one: GameSession = _session(true)
	var ticks: GameSession = _session(true)
	var blocks: GameSession = _session(true)
	one.advance(HOUR_MS)
	_in_ticks(ticks, HOUR_MS)
	_in_blocks(blocks, HOUR_MS, 60_000)
	assert_gt(one.skills.get_xp(&"forging"), 0)
	assert_gt(int(one.combat.node_counts()["worked"]), 0)
	_assert_same(one, ticks, "queue 1 h block vs ticks")
	_assert_same(one, blocks, "queue 1 h block vs blocks")


func test_a_production_queue_in_parallel_twelve_hours_is_the_same_whole_state() -> void:
	var one: GameSession = _session(true)
	var ticks: GameSession = _session(true)
	var blocks: GameSession = _session(true)
	var twelve: int = 12 * HOUR_MS
	one.advance(twelve)
	_in_ticks(ticks, twelve)
	_in_blocks(blocks, twelve, 60_000)
	assert_gt(one.skills.get_xp(&"forging"), 0)
	_assert_same(one, ticks, "queue 12 h block vs ticks")
	_assert_same(one, blocks, "queue 12 h block vs blocks")


func test_save_and_reload_in_the_middle_continues_the_same_evolution_with_a_queue() -> void:
	var straight: GameSession = _session(true)
	var half: GameSession = _session(true)
	straight.advance(HOUR_MS)
	half.advance(HOUR_MS / 2)
	var loaded: GameSession = autofree(TestFactory.session_no_kit(SEED + 1, TestFactory.real_data()))
	var saved: Dictionary = SaveCodec.decode(SaveCodec.encode(half.to_save(0)))
	assert_true(loaded.from_save(saved).ok)
	# The test boost is not part of the save: put it back and read the fight again, so the hit points are not cut to the base maximum.
	_boost(loaded)
	loaded.combat.from_save(saved["modules"]["combat"])
	_assert_same(half, loaded, "right after the load")
	loaded.advance(HOUR_MS / 2)
	_assert_same(straight, loaded, "straight vs save-reload")


func test_the_offline_run_of_one_hour_equals_its_silent_twin_and_counts_the_nodes() -> void:
	var loud: GameSession = _session(true)
	var quiet: GameSession = _session(true)
	var before: Dictionary = loud.combat.node_counts()
	var summary: OfflineSummary = await OfflineSimulator.new().run(loud, HOUR_MS, false, false)
	OfflineSimulator.advance_silently(quiet, HOUR_MS)
	_assert_same(loud, quiet, "run vs advance_silently")
	var after: Dictionary = loud.combat.node_counts()
	assert_eq(summary.nodes_worked, int(after["worked"]) - int(before["worked"]))
	assert_eq(summary.nodes_skipped, int(after["skipped"]) - int(before["skipped"]))
	assert_gt(summary.nodes_worked, 0)
	assert_gt(summary.nodes_skipped, 0)
	assert_gt(int(summary.xp.get(&"forging", 0)), 0, "the queue works offline too")
