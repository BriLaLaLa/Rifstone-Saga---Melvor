extends GutTest
## F-153 (kind of the next encounter), F-154 (resource and color), F-155 (duration), F-156 (closed form) with the numbers of
## docs/02_FORMULAS_M24.md. Real data (forestry: steps 1, 10, 20, 30, 45, 60, 75, 90; `redrock_plains` nodes forestry, quarrying,
## angling, herbalism). Fixed seeds through `RngService`; a stub replaces `pick_weighted` where the formula quotes its result.

const AREA: StringName = &"redrock_plains"
const NO_NODES_AREA: StringName = &"no_such_area"
const FORESTRY: StringName = &"forestry"
const SEED: int = 4242


class StubRng extends RngService:
	var picked: int = 0
	var rolls: int = 0

	func _init() -> void:
		super(1)

	func pick_weighted(_weights: Array[int]) -> int:
		return picked

	func roll_pct(chance_pct: float) -> bool:
		rolls += 1
		return chance_pct >= 100.0


func _session(node_chance: float = 25.0) -> GameSession:
	var data: GameData = GameData.load_from_dirs(TestFactory.REAL_CONTENT_ROOT, TestFactory.CONFIG_ROOT)
	((data.get("_balance") as Dictionary)["encounters"] as Dictionary)["node_chance_pct"] = node_chance
	return autofree(TestFactory.session_no_kit(SEED, data))


# --- F-153 ---------------------------------------------------------------------------------------------------------

func test_a_pending_stone_or_miniboss_is_a_fight_and_the_generator_does_not_advance() -> void:
	var s: GameSession = _session(100.0)
	var before: Dictionary = s.rng.to_save()
	var next: Dictionary = EncounterCycle.next_kind(s, AREA, true)
	assert_eq(next["kind"], &"fight")
	assert_eq(s.rng.to_save(), before)


func test_chance_zero_is_always_a_fight_and_one_hundred_always_a_node() -> void:
	var never: GameSession = _session(0.0)
	var always: GameSession = _session(100.0)
	for i: int in 30:
		assert_eq(EncounterCycle.next_kind(never, AREA, false)["kind"], &"fight")
		var next: Dictionary = EncounterCycle.next_kind(always, AREA, false)
		assert_eq(next["kind"], &"node")
		assert_true([&"forestry", &"quarrying", &"angling", &"herbalism"].has(next["skill"]))


func test_the_discipline_is_the_index_picked_by_weight() -> void:
	var s: GameSession = _session(100.0)
	var stub := StubRng.new()
	stub.picked = 2
	s.rng = stub
	var next: Dictionary = EncounterCycle.next_kind(s, AREA, false)
	assert_eq(next["skill"], &"angling", "the third entry of the area")
	assert_eq(stub.rolls, 1)


func test_an_area_without_nodes_is_a_fight_with_no_roll() -> void:
	var s: GameSession = _session(100.0)
	var before: Dictionary = s.rng.to_save()
	assert_eq(EncounterCycle.next_kind(s, NO_NODES_AREA, false)["kind"], &"fight")
	assert_eq(s.rng.to_save(), before)


func test_the_roll_comes_first_then_the_pick_on_the_session_generator() -> void:
	var s: GameSession = _session(25.0)
	var mirror := RngService.new(SEED)
	for i: int in 40:
		var next: Dictionary = EncounterCycle.next_kind(s, AREA, false)
		var expected: StringName = &""
		if mirror.roll_pct(25.0):
			var weights: Array[int] = []
			for entry: NodeEntryDef in s.data.area_nodes(AREA).entries:
				weights.append(entry.weight)
			expected = s.data.area_nodes(AREA).entries[mirror.pick_weighted(weights)].skill
		assert_eq(next["skill"], expected)


# --- F-154 ---------------------------------------------------------------------------------------------------------

func test_resource_and_color_of_the_examples() -> void:
	var s: GameSession = _session()
	# [skill level L, node cap M, resource level, color]
	var cases: Array = [[27, 30, 20, &"orange"], [45, 30, 30, &"yellow"], [90, 10, 10, &"grey"], [74, 80, 60, &"yellow"],
		[75, 80, 75, &"orange"], [52, 50, 45, &"orange"], [1, 99, 1, &"orange"], [1, 10, 1, &"orange"]]
	for c: Array in cases:
		var action: ActionDef = EncounterCycle.worked_action(s.data, FORESTRY, c[0], c[1])
		assert_eq(action.level, c[2], "L %d M %d" % [c[0], c[1]])
		assert_eq(EncounterCycle.color(s.data, c[0], action.level)["id"], c[3], "L %d M %d" % [c[0], c[1]])


func test_the_color_percentages_and_the_edges() -> void:
	var s: GameSession = _session()
	assert_eq(EncounterCycle.color(s.data, 10, 1)["id"], &"orange", "d 9")
	assert_eq(EncounterCycle.color(s.data, 11, 1)["id"], &"yellow", "d 10")
	assert_eq(EncounterCycle.color(s.data, 21, 1)["id"], &"green", "d 20")
	assert_eq(EncounterCycle.color(s.data, 31, 1)["id"], &"grey", "d 30")
	assert_eq([EncounterCycle.color(s.data, 1, 1)["xp_pct"], EncounterCycle.color(s.data, 11, 1)["xp_pct"],
		EncounterCycle.color(s.data, 21, 1)["xp_pct"], EncounterCycle.color(s.data, 99, 1)["xp_pct"]], [100.0, 50.0, 20.0, 0.0])


# --- F-155 ---------------------------------------------------------------------------------------------------------

func test_node_duration_of_the_examples() -> void:
	var s: GameSession = _session()
	var action: ActionDef = s.data.action(&"cut_redbirch")
	assert_eq(EncounterCycle.node_duration_ms(s, FORESTRY, action), 12000)
	var cases: Array = [[-10.0, 10800], [-18.0, 9840], [-80.0, 3000]]
	for c: Array in cases:
		s.modifiers.set_source(&"test:interval", [Modifier.make(&"skill_interval_pct", c[0])])
		assert_eq(EncounterCycle.node_duration_ms(s, FORESTRY, action), c[1], "p %s" % c[0])


# --- F-156 ---------------------------------------------------------------------------------------------------------

func _params(learned: Array) -> Dictionary:
	return {"travel_ms": 2500, "node_chance_pct": 25, "fight_ms": 50000, "skip_ms": 1500, "node_units": 80,
		"weights": {&"a": 25, &"b": 25, &"c": 25, &"d": 25}, "learned": learned, "node_ms": {&"a": 12000, &"b": 12000}}


func test_closed_form_of_the_example() -> void:
	var r: Dictionary = EncounterCycle.expected(_params([&"a", &"b"]))
	assert_almost_eq(float(r["cycle_ms"]), 41687.5, 0.001)
	assert_almost_eq(float(r["per_hour"]), 86.36, 0.01)
	assert_almost_eq(float(r["fights_per_hour"]), 64.77, 0.01)
	assert_almost_eq(float(r["nodes_per_hour"][&"a"]) * 2.0, 10.79, 0.01)
	assert_almost_eq(float(r["nodes_per_hour"][&"a"]), 5.40, 0.01)
	assert_almost_eq(float(r["units_per_hour"][&"a"]), 431.8, 0.1)
	assert_false((r["nodes_per_hour"] as Dictionary).has(&"c"), "an unlearned discipline gives no nodes")


func test_closed_form_with_rich_nodes_of_f165() -> void:
	var p: Dictionary = _params([&"a", &"b"])
	p.merge({"rich_chance_pct": 10, "rich_ms_pct": 150, "rich_units_pct": 150, "yield": {&"a": 100, &"b": 100}})
	var r: Dictionary = EncounterCycle.expected(p)
	assert_almost_eq(float(r["cycle_ms"]), 41762.5, 0.001)
	assert_almost_eq(float(r["per_hour"]), 86.20, 0.01)
	assert_almost_eq(float(r["fights_per_hour"]), 64.65, 0.01)
	assert_almost_eq(float(r["nodes_per_hour"][&"a"]) * 2.0, 10.78, 0.01)
	assert_almost_eq(float(r["nodes_per_hour"][&"a"]), 5.39, 0.01)
	assert_almost_eq(float(r["units_per_hour"][&"a"]), 452.6, 0.1)
	p["yield"] = {&"a": 80, &"b": 100}
	assert_almost_eq(float(EncounterCycle.expected(p)["units_per_hour"][&"a"]), 452.6 * 0.8, 0.1, "the yield of the discipline scales its units")


func test_closed_form_without_disciplines_and_the_old_engine() -> void:
	var none: Dictionary = EncounterCycle.expected(_params([]))
	assert_almost_eq(float(none["cycle_ms"]), 40375.0, 0.001)
	assert_almost_eq(float(none["fights_per_hour"]), 66.87, 0.01)
	var old: Dictionary = EncounterCycle.expected({"travel_ms": 1500, "node_chance_pct": 0, "fight_ms": 50000, "skip_ms": 1500,
		"node_units": 80, "weights": {}, "learned": [], "node_ms": {}})
	assert_almost_eq(float(old["fights_per_hour"]), 69.90, 0.01)
	var cycle: Dictionary = EncounterCycle.expected(_params([&"a", &"b"]))
	assert_almost_eq(float(cycle["fights_per_hour"]) / float(old["fights_per_hour"]) - 1.0, -0.073, 0.001)
