extends GutTest
## M24-07: the offline run uses the same engine as the game (docs/01_GDD_M24.md §35.9, Q109). On the real data, with fights, journeys,
## nodes worked and skipped and a production queue in parallel, the same seconds give the same state whether they pass in one block,
## in ticks of 100 ms or in blocks of `offline.chunk_ms`; and the real `OfflineSimulator` (one hour) gives the same state as its silent
## twin and counts the nodes of the summary.

const AREA: StringName = &"redrock_plains"
const SEED: int = 2412
const HOUR_MS: int = 3_600_000
const TICK_MS: int = 100


# `rich_pct` >= 0: the chance of a rich node (F-164) of a copy of the real data (M25): 0 = every node has the 3 attempts, 100 = the 5 of a rich one.
func _session(with_queue: bool = false, rich_pct: int = -1, seed_value: int = SEED) -> GameSession:
	var data: GameData = TestFactory.real_data()
	if rich_pct >= 0:
		data = GameData.load_from_dirs(TestFactory.REAL_CONTENT_ROOT, TestFactory.CONFIG_ROOT)
		((data.get("_balance") as Dictionary)["encounters"] as Dictionary)["rich_chance_pct"] = rich_pct
	var s: GameSession = autofree(TestFactory.session_no_kit(seed_value, data))
	s.events.node_attempt_done.connect(_count_attempt.bind(s))
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


# Per session: [attempts resolved, units of those attempts, the largest `attempts` of a node seen] (M25).
var _seen: Dictionary = {}


func _count_attempt(_skill: StringName, _action: StringName, _attempt: int, attempts: int, units: int, _total: int, _color: StringName,
		s: GameSession) -> void:
	var row: Array = _seen.get(s.get_instance_id(), [0, 0, 0])
	_seen[s.get_instance_id()] = [int(row[0]) + 1, int(row[1]) + units, maxi(int(row[2]), attempts)]


func _attempts_of(s: GameSession) -> Array:
	return _seen.get(s.get_instance_id(), [0, 0, 0])


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


# --- M25: nodes with attempts (F-161..F-165, Q124) --------------------------------------------------------------------

func test_three_attempt_nodes_with_a_queue_are_the_same_in_a_block_in_ticks_and_in_blocks() -> void:
	var one: GameSession = _session(true, 0)
	var ticks: GameSession = _session(true, 0)
	var blocks: GameSession = _session(true, 0)
	one.advance(HOUR_MS)
	_in_ticks(ticks, HOUR_MS)
	_in_blocks(blocks, HOUR_MS, 60_000)
	assert_eq(_attempts_of(one)[2], 3, "no rich node: three attempts")
	assert_gt(_attempts_of(one)[0], 10)
	_assert_same(one, ticks, "3 attempts, block vs ticks")
	_assert_same(one, blocks, "3 attempts, block vs blocks")
	assert_eq(_attempts_of(ticks), _attempts_of(one), "the same attempts, in the same number")
	assert_eq(_attempts_of(blocks), _attempts_of(one))


func test_rich_nodes_with_a_queue_twelve_hours_are_the_same_whole_state() -> void:
	var one: GameSession = _session(true, 100)
	var ticks: GameSession = _session(true, 100)
	var blocks: GameSession = _session(true, 100)
	var twelve: int = 12 * HOUR_MS
	one.advance(twelve)
	_in_ticks(ticks, twelve)
	_in_blocks(blocks, twelve, 60_000)
	assert_eq(_attempts_of(one)[2], 5, "every node is rich: five attempts")
	assert_gt(int(one.combat.node_counts()["worked"]), 50)
	_assert_same(one, ticks, "rich 12 h block vs ticks")
	_assert_same(one, blocks, "rich 12 h block vs blocks")
	assert_eq(_attempts_of(ticks), _attempts_of(one))
	assert_eq(_attempts_of(blocks), _attempts_of(one))


func test_save_and_reload_in_the_middle_of_rich_nodes_continues_the_same_evolution() -> void:
	var straight: GameSession = _session(true, 100)
	var half: GameSession = _session(true, 100)
	straight.advance(HOUR_MS)
	half.advance(HOUR_MS / 2 + 7000)  # a cut inside a node
	var loaded: GameSession = _session(true, 100, SEED + 1)
	var saved: Dictionary = SaveCodec.decode(SaveCodec.encode(half.to_save(0)))
	assert_true(loaded.from_save(saved).ok)
	_boost(loaded)
	loaded.combat.from_save(saved["modules"]["combat"])
	_assert_same(half, loaded, "right after the load")
	var again: Dictionary = loaded.to_save(0)
	var first: Dictionary = half.to_save(0)
	assert_eq(again["modules"]["combat"], first["modules"]["combat"], "save, load, save is identical")
	loaded.advance(HOUR_MS / 2 - 7000)
	_assert_same(straight, loaded, "straight vs save-reload (rich nodes)")


# --- M26-03: colored recipes keep the equivalence (F-168, Q124) -------------------------------------------------------------

# A forging queue on a copy of the real data where two recipes have colors (yellow and green around the start level).
func _colored_session(seed_value: int = SEED) -> GameSession:
	var data: GameData = GameData.load_from_dirs(TestFactory.REAL_CONTENT_ROOT, TestFactory.CONFIG_ROOT)
	data.action(&"smelt_emberbronze").colors = {&"yellow": 5, &"green": 13, &"grey": 30}
	data.action(&"forge_emberbronze_plate").colors = {&"yellow": 3, &"green": 8, &"grey": 25}
	var s: GameSession = autofree(TestFactory.session_no_kit(seed_value, data))
	s.disciplines.new_game()
	TestFactory.set_character_level(s, 55)
	TestFactory.make_roomy(s)
	s.wallet.add_gold(1000)
	assert_true(s.disciplines.learn(&"forging").ok)
	TestFactory.set_level(s, &"forging", 10)
	TestFactory.give(s, &"emberbronze_ore", 1_000_000)
	assert_true(s.actions.enqueue(&"forging", &"smelt_emberbronze", 400, false).ok)
	assert_true(s.actions.enqueue(&"forging", &"forge_emberbronze_plate", 300, false).ok)
	assert_true(s.actions.enqueue(&"forging", &"smelt_emberbronze", 9999, false).ok)
	assert_true(s.actions.enqueue(&"forging", &"forge_emberbronze_plate", 1, true).ok)
	return s


func test_colored_recipes_twelve_hours_are_the_same_whole_state() -> void:
	var one: GameSession = _colored_session()
	var ticks: GameSession = _colored_session()
	var blocks: GameSession = _colored_session()
	var twelve: int = 12 * HOUR_MS
	one.advance(twelve)
	_in_ticks(ticks, twelve)
	_in_blocks(blocks, twelve, 60_000)
	assert_gt(one.skills.get_xp(&"forging"), 0)
	_assert_same(one, ticks, "colored 12 h block vs ticks")
	_assert_same(one, blocks, "colored 12 h block vs blocks")


func test_colored_recipes_save_and_reload_in_the_middle_is_the_same_whole_state() -> void:
	var straight: GameSession = _colored_session()
	var half: GameSession = _colored_session()
	straight.advance(12 * HOUR_MS)
	half.advance(6 * HOUR_MS)
	var loaded: GameSession = _colored_session(SEED + 1)
	var saved: Dictionary = SaveCodec.decode(SaveCodec.encode(half.to_save(0)))
	assert_true(loaded.from_save(saved).ok)
	assert_eq(loaded.to_save(0)["modules"]["professions"], half.to_save(0)["modules"]["professions"], "save, load, save is identical")
	_assert_same(half, loaded, "right after the load")
	loaded.advance(6 * HOUR_MS)
	_assert_same(straight, loaded, "colored straight vs save-reload")
