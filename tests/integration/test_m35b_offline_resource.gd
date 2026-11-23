extends GutTest
## M35B-1 (docs/01_GDD_M35B.md §43.4, F-200): the resource of a node is rolled in `NodeWork.begin`, so 12 h in one block = steps of 100 ms
## = blocks of 60 s, with the SAME sequence of resources and the same final state, in a zone with two or more eligible resources.
## The tutorial forced node in zone 1 at level 1 rolls nothing. Tables of F-201 (`zone_tables.gd`).

const ZoneTables := preload("res://tests/systems/encounters/zone_tables.gd")
const AREA: StringName = &"dry_uplands"
const SEED: int = 3536
const HOUR_MS: int = 3_600_000
const TICK_MS: int = 100


class NodeLog extends RefCounted:
	var resources: Array[StringName] = []

	func on_node(_skill: StringName, action: StringName, skipped: bool, _ms: int) -> void:
		if not skipped:
			resources.append(action)


func _session() -> Array:
	var s: GameSession = autofree(TestFactory.session(SEED, ZoneTables.data()))
	s.disciplines.new_game()
	TestFactory.set_character_level(s, 55)
	TestFactory.make_roomy(s)
	for id: StringName in [&"forestry", &"quarrying"]:
		TestFactory.learn_discipline(s, id)
		TestFactory.set_level(s, id, 45)
	s.modifiers.set_source(&"test:hero", [Modifier.make(&"power_bonus", 100000.0), Modifier.make(&"max_hp_flat", 100000.0),
			Modifier.make(&"armor", 100000.0), Modifier.make(&"evasion_bonus", 80000.0)])
	var log := NodeLog.new()
	s.events.node_started.connect(log.on_node)
	assert_true(s.combat.start(AREA).ok)
	return [s, log]


func _state(s: GameSession) -> Dictionary:
	var d: Dictionary = s.to_save(0)
	d.erase("play_time_ms")
	return d


func test_twelve_hours_in_one_block_in_ticks_and_in_blocks_roll_the_same_resources() -> void:
	var one: Array = _session()
	var ticks: Array = _session()
	var blocks: Array = _session()
	(one[0] as GameSession).advance(12 * HOUR_MS)
	for _i: int in 12 * HOUR_MS / TICK_MS:
		(ticks[0] as GameSession).advance(TICK_MS)
	for _i: int in 12 * HOUR_MS / 60_000:
		(blocks[0] as GameSession).advance(60_000)
	var seen: Array[StringName] = (one[1] as NodeLog).resources
	assert_gt(seen.size(), 10, "nodes were worked")
	var kinds: Dictionary = {}
	for action: StringName in seen:
		kinds[action] = true
	assert_gt(kinds.size(), 1, "more than one resource came up: the roll is real")
	assert_eq((ticks[1] as NodeLog).resources, seen, "the same sequence of resources, 100 ms steps")
	assert_eq((blocks[1] as NodeLog).resources, seen, "the same sequence of resources, 60 s blocks")
	var left: Dictionary = _state(one[0])
	for other: Array in [ticks, blocks]:
		var right: Dictionary = _state(other[0])
		for module: Variant in left["modules"]:
			assert_eq((right["modules"] as Dictionary).get(module), (left["modules"] as Dictionary)[module], "module %s" % module)
		assert_eq(right["rng"], left["rng"])


class CountingRng extends RngService:
	var seen: Array = []

	func _init() -> void:
		super(1)

	func pick_weighted(weights: Array[int]) -> int:
		seen.append(weights.duplicate())
		return super(weights)


func test_the_forced_tutorial_node_in_zone_1_at_level_1_rolls_no_resource() -> void:
	var s: GameSession = autofree(TestFactory.session(SEED, ZoneTables.data()))
	s.disciplines.new_game()
	TestFactory.learn_discipline(s, &"forestry")
	var rng := CountingRng.new()
	s.rng = rng
	var log := NodeLog.new()
	s.events.node_started.connect(log.on_node)
	s.modifiers.set_source(&"test:hero", [Modifier.make(&"power_bonus", 100000.0), Modifier.make(&"max_hp_flat", 100000.0), Modifier.make(&"armor", 100000.0)])
	assert_true(s.combat.start(&"redrock_plains").ok)
	s.combat.set_force_node(true)  # the first fight is on: the next journey leads to the forced node
	for _i: int in 400:
		s.advance(500)
		if not log.resources.is_empty():
			break
	assert_eq(log.resources, [&"cut_redbirch"] as Array[StringName], "level 1: only the first step is workable")
	assert_false(rng.seen.has([79, 21]), "no pick_weighted on the table of the zone (fights and kinds pick their own weights)")
