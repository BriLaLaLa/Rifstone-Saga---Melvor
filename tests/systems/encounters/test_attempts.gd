extends GutTest
## F-161 (difficulty, attempts, instants) and F-162 (yield and units of an attempt) with the numbers of docs/02_FORMULAS_M25.md.
## Real data (the numbers of §9c are in `balance.json`; a test that needs other numbers changes them on its own copy).

const RES: Dictionary = {"action": "cut_redbirch", "weight": 100}
const M35Data := preload("res://tests/systems/armory/m35_data.gd")
const AREA: StringName = &"redrock_plains"
const FORESTRY: StringName = &"forestry"


func _session() -> GameSession:
	return autofree(TestFactory.session_no_kit(5, GameData.load_from_dirs(TestFactory.REAL_CONTENT_ROOT, TestFactory.CONFIG_ROOT)))


func _enc(s: GameSession, key: String, value: Variant) -> void:
	((s.data.get("_balance") as Dictionary)["encounters"] as Dictionary)[key] = value


func _times(duration: int, attempts: int) -> Array[int]:
	var result: Array[int] = []
	for k: int in range(1, attempts + 1):
		result.append(EncounterCycle.attempt_time_ms(duration, attempts, k))
	return result


func _units(s: GameSession, attempts: int, rich: bool, yield_percent: int) -> Array[int]:
	var result: Array[int] = []
	for k: int in range(1, attempts + 1):
		result.append(EncounterCycle.attempt_units(s, k, attempts, rich, yield_percent))
	return result


# --- F-161 ---------------------------------------------------------------------------------------------------------

func test_the_instants_of_the_attempts() -> void:
	assert_eq(_times(12000, 3), [4000, 8000, 12000] as Array[int])
	assert_eq(_times(10800, 3), [3600, 7200, 10800] as Array[int])
	assert_eq(_times(10000, 3), [3333, 6667, 10000] as Array[int])
	assert_eq(_times(18000, 5), [3600, 7200, 10800, 14400, 18000] as Array[int])
	assert_eq(_times(3000, 3), [1000, 2000, 3000] as Array[int])


func test_the_attempts_of_a_normal_and_of_a_rich_node() -> void:
	var s: GameSession = _session()
	assert_eq(EncounterCycle.attempts_for(s, false), 3)
	assert_eq(EncounterCycle.attempts_for(s, true), 5)


func test_the_duration_of_a_rich_node_is_one_and_a_half_times() -> void:
	var s: GameSession = _session()
	assert_eq(EncounterCycle.rich_duration_ms(s, 12000), 18000)
	assert_eq(EncounterCycle.rich_duration_ms(s, 3001), 4502, "round half up")


func test_the_difficulty_is_the_cap_of_the_area_unless_the_data_says_otherwise() -> void:
	var s: GameSession = _session()
	var nodes: AreaNodesDef = s.data.area_nodes(AREA)
	assert_eq(EncounterCycle.difficulty(s, AREA, FORESTRY), nodes.max_level)
	assert_eq(nodes.min_level_of(FORESTRY), 1)
	assert_eq(EncounterCycle.difficulty(s, &"no_such_area", FORESTRY), 0)
	var entry: NodeEntryDef = NodeEntryDef.from_dict({"skill": "forestry", "weight": 10, "difficulty": 30, "min_level": 12, "resources": [RES]})
	assert_eq([entry.difficulty, entry.min_level], [30, 12])
	var area: AreaNodesDef = AreaNodesDef.from_dict({"area": "x", "max_level": 40, "nodes": [{"skill": "forestry", "weight": 10, "min_level": 5, "resources": [RES]}]})
	assert_eq([area.difficulty_of(FORESTRY), area.min_level_of(FORESTRY), area.difficulty_of(&"angling")], [40, 5, 0])


# --- F-162 ---------------------------------------------------------------------------------------------------------

func test_the_yield_by_level_gap() -> void:
	var s: GameSession = _session()
	var cases: Array = [[30, 27, 100], [30, 25, 100], [30, 24, 96], [30, 20, 80], [30, 5, 25], [30, 1, 25], [10, 1, 84], [10, 40, 100]]
	for c: Array in cases:
		assert_eq(EncounterCycle.yield_pct(s, c[1], c[0]), c[2], "D %d, L %d" % [c[0], c[1]])


func test_the_units_of_each_attempt_sum_to_the_share_of_the_yield() -> void:
	var s: GameSession = _session()
	assert_eq(_units(s, 3, false, 100), [26, 27, 27] as Array[int])
	assert_eq(_units(s, 3, false, 80), [21, 21, 22] as Array[int])
	assert_eq(_units(s, 3, false, 25), [6, 7, 7] as Array[int])
	assert_eq(_units(s, 5, true, 100), [24, 24, 24, 24, 24] as Array[int], "rich: 120 planned units in 5 attempts")


func test_every_attempt_gives_at_least_one_unit() -> void:
	var s: GameSession = _session()
	_enc(s, "node_units", 2)
	assert_eq(_units(s, 3, false, 25), [1, 1, 1] as Array[int])


# --- M35-D F-198: the units of a node with `node_units_pct` -------------------------------------------------------------

func _with_ne(s: GameSession, attempts: int, rich: bool, ne: int) -> Array[int]:
	var result: Array[int] = []
	for k: int in range(1, attempts + 1):
		result.append(EncounterCycle.attempt_units(s, k, attempts, rich, 100, ne))
	return result


## The examples of F-198 (N 80, A 3, y 100) and the effect through a real node on the M35-D2 content.
func test_node_units_pct() -> void:
	var s: GameSession = _session()
	assert_eq(EncounterCycle.planned_units(s.data, false, 0), 80)
	assert_eq(EncounterCycle.planned_units(s.data, false, 9), 87)
	assert_eq(EncounterCycle.planned_units(s.data, false, 24), 99)
	assert_eq(EncounterCycle.planned_units(s.data, true, 0), 120, "N x 150%")
	assert_eq(EncounterCycle.planned_units(s.data, true, 24), 148)
	assert_eq(_with_ne(s, 3, false, 80), [26, 27, 27] as Array[int])
	assert_eq(_with_ne(s, 3, false, 87), [29, 29, 29] as Array[int])
	assert_eq(_with_ne(s, 3, false, 99), [33, 33, 33] as Array[int])
	assert_eq(_with_ne(s, 5, true, 148), [29, 30, 29, 30, 30] as Array[int])
	assert_eq(_units(s, 3, false, 100), [26, 27, 27] as Array[int], "without `ne`: the old rule")
	var m35: GameSession = autofree(TestFactory.session_no_kit(9, M35Data.fresh()))
	m35.disciplines.new_game()
	((m35.data.get("_balance") as Dictionary)["encounters"] as Dictionary)["rich_chance_pct"] = 0
	TestFactory.learn_discipline(m35, &"quarrying")
	TestFactory.set_level(m35, &"quarrying", 45)
	var base: NodeWork = NodeWork.begin(m35, &"ash_marsh", &"quarrying")
	assert_eq(base.ne, 80)
	m35.modifiers.set_source(&"test:units", [Modifier.make(&"node_units_pct", 24.0)] as Array[Modifier])
	var work: NodeWork = NodeWork.begin(m35, &"ash_marsh", &"quarrying")
	assert_eq(work.ne, 99)
	assert_eq(work.duration_ms, base.duration_ms, "the speed of the node does not change")
	assert_eq(work.attempts, base.attempts)
	var seen: Array[int] = []
	while not work.is_complete():
		seen.append(work.resolve_attempt(m35).units)
	assert_eq(seen, [33, 33, 33] as Array[int])


func test_ne_is_fixed_at_the_start_and_saved() -> void:
	var m35: GameSession = autofree(TestFactory.session_no_kit(9, M35Data.fresh()))
	m35.disciplines.new_game()
	((m35.data.get("_balance") as Dictionary)["encounters"] as Dictionary)["rich_chance_pct"] = 0
	TestFactory.learn_discipline(m35, &"quarrying")
	TestFactory.set_level(m35, &"quarrying", 45)
	m35.modifiers.set_source(&"test:units", [Modifier.make(&"node_units_pct", 9.0)] as Array[Modifier])
	var work: NodeWork = NodeWork.begin(m35, &"ash_marsh", &"quarrying")
	m35.modifiers.set_source(&"test:units", [Modifier.make(&"node_units_pct", 24.0)] as Array[Modifier])
	assert_eq(work.ne, 87, "a later change of the stat does not move the node in progress")
	assert_eq(work.units_planned(m35), 87 * work.yield_pct(m35) / 100)
	var saved: Dictionary = work.to_save()
	assert_eq(saved["ne"], 87)
	assert_eq(NodeWork.from_save(saved, m35.data, &"ash_marsh").ne, 87)
	saved.erase("ne")
	assert_eq(NodeWork.from_save(saved, m35.data, &"ash_marsh").ne, 80, "an old node: N without node_units_pct")
