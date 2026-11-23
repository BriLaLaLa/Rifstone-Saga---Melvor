extends GutTest
## M35-D (docs/01_GDD_M35.md §42.6): the same seconds give the same state in one block, in ticks of 100 ms and in blocks of 60 s, with a
## focused resource, the heads of the tools (`node_units_pct`, `node_rich_pct`, `byproduct_chance_pct`) and rich nodes: the node roll stays one.
## M35-D2 content (`m35_data.gd`): Piccone +9 with the heads of Ricchezza, Accetta +9 with Scure fine, Falcetto +4, the Minatore aimed at Rame.

const M35 := preload("res://tests/systems/armory/m35_data.gd")
const AREA: StringName = &"redrock_plains"
const SEED: int = 3535
const HOUR_MS: int = 3_600_000
const TICK_MS: int = 100


func _session(seed_value: int = SEED) -> GameSession:
	var s: GameSession = autofree(TestFactory.session(seed_value, M35.data()))
	s.disciplines.new_game()
	TestFactory.set_character_level(s, 55)
	TestFactory.make_roomy(s)
	s.wallet.add_gold(10_000_000)
	for id: StringName in [&"forestry", &"quarrying"]:  # two gathering disciplines at most
		TestFactory.learn_discipline(s, id)
	TestFactory.set_level(s, &"quarrying", 30)
	_tools(s)
	_boost(s)  # after _tools: rebuild_modifiers drops the test source
	assert_true(s.disciplines.set_focus(&"quarrying", &"quarry_emberbronze").ok)
	assert_true(s.combat.start(AREA).ok)
	return s


func _tools(s: GameSession) -> void:
	var heads: Dictionary = {&"tool_quarrying": [9, &"pick_quarry"], &"tool_forestry": [9, &"hatchet_fine"], &"tool_herbalism": [4, &"sickle_bundle"]}
	for slot: StringName in heads:
		var uid: int = s.armory.tool_uid(slot)
		s.armory._items[uid].upgrade = int((heads[slot] as Array)[0])
		for step: int in [3, 6, 9]:
			if step <= int((heads[slot] as Array)[0]):
				assert_true(s.armory.choose_tool_head(uid, step, (heads[slot] as Array)[1]).ok)
	s.rebuild_modifiers()


func _boost(s: GameSession) -> void:
	s.modifiers.set_source(&"test:hero", [Modifier.make(&"power_bonus", 100000.0), Modifier.make(&"max_hp_flat", 100000.0),
			Modifier.make(&"armor", 100000.0), Modifier.make(&"evasion_bonus", 80000.0)])


func _state(s: GameSession) -> Dictionary:
	var d: Dictionary = s.to_save(0)
	d.erase("play_time_ms")
	return d


func _assert_same(a: GameSession, b: GameSession, what: String) -> void:
	var left: Dictionary = _state(a)
	var right: Dictionary = _state(b)
	for module: Variant in left["modules"]:
		assert_eq((right["modules"] as Dictionary).get(module), (left["modules"] as Dictionary)[module], "%s: module %s" % [what, module])
	assert_eq(right["rng"], left["rng"], "%s: the rng" % what)


func _ticks(s: GameSession, ms: int) -> void:
	for _i: int in ms / TICK_MS:
		s.advance(TICK_MS)


func _blocks(s: GameSession, ms: int, block_ms: int) -> void:
	for _i: int in ms / block_ms:
		s.advance(block_ms)


func test_one_hour_in_one_block_in_ticks_and_in_blocks_is_the_same_state() -> void:
	var one: GameSession = _session()
	var ticks: GameSession = _session()
	var blocks: GameSession = _session()
	one.advance(HOUR_MS)
	_ticks(ticks, HOUR_MS)
	_blocks(blocks, HOUR_MS, 60_000)
	assert_gt(int(one.combat.node_counts()["worked"]), 0)
	_assert_same(one, ticks, "block vs ticks")
	_assert_same(one, blocks, "block vs blocks")


func test_twelve_hours_in_one_block_in_ticks_and_in_blocks_is_the_same_state() -> void:
	var one: GameSession = _session()
	var ticks: GameSession = _session()
	var blocks: GameSession = _session()
	one.advance(12 * HOUR_MS)
	_ticks(ticks, 12 * HOUR_MS)
	_blocks(blocks, 12 * HOUR_MS, 60_000)
	assert_gt(int(one.combat.node_counts()["worked"]), 10)
	_assert_same(one, ticks, "12 h block vs ticks")
	_assert_same(one, blocks, "12 h block vs blocks")


func test_save_and_reload_in_the_middle_continues_the_same_evolution() -> void:
	var straight: GameSession = _session()
	var half: GameSession = _session()
	straight.advance(HOUR_MS)
	half.advance(HOUR_MS / 2)
	var loaded: GameSession = autofree(TestFactory.session(SEED + 1, M35.data()))
	var saved: Dictionary = SaveCodec.decode(SaveCodec.encode(half.to_save(0)))
	assert_true(loaded.from_save(saved).ok)
	_boost(loaded)
	loaded.combat.from_save(saved["modules"]["combat"])
	assert_eq(loaded.disciplines.focus_of(&"quarrying"), &"quarry_emberbronze", "the choice survives the save")
	assert_eq(loaded.armory.tool_heads(loaded.armory.tool_uid(&"tool_quarrying")), [&"pick_quarry", &"pick_quarry", &"pick_quarry"] as Array[StringName])
	_assert_same(half, loaded, "right after the load")
	loaded.advance(HOUR_MS / 2)
	_assert_same(straight, loaded, "straight vs save-reload")


func test_the_real_offline_run_equals_its_silent_twin() -> void:
	var loud: GameSession = _session()
	var quiet: GameSession = _session()
	var summary: OfflineSummary = await OfflineSimulator.new().run(loud, HOUR_MS, false, false)
	OfflineSimulator.advance_silently(quiet, HOUR_MS)
	_assert_same(loud, quiet, "run vs advance_silently")
	assert_gt(summary.nodes_worked, 0)
