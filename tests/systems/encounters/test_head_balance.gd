extends GutTest
## M35-D F-199: the closed form of F-165 with `u` and `p` read from the modifiers of the heads, and the balance rule of the heads: a Piccone +9
## gives at most +30% of units per hour over +0, and the two heads differ by at most 10% (the double product of Ricchezza counts).
## M35-D2 content (`m35_data.gd`); the same closed form is what `tools/sim_encounters.gd` compares with the run (+-5%).

const M35 := preload("res://tests/systems/armory/m35_data.gd")
const QUARRYING: StringName = &"quarrying"
const AREA: StringName = &"redrock_plains"

var _s: GameSession = null


func before_each() -> void:
	_s = autofree(TestFactory.session(21, M35.fresh()))
	_s.disciplines.new_game()
	TestFactory.learn_discipline(_s, QUARRYING)
	TestFactory.set_level(_s, QUARRYING, 30)
	_s.wallet.add_gold(100_000_000)  # changing a head pays


func _pick(upgrade: int, head: StringName) -> void:
	var uid: int = _s.armory.tool_uid(&"tool_quarrying")
	_s.armory._items[uid].upgrade = upgrade
	for step: int in [3, 6, 9]:
		if head != &"" and step <= upgrade:
			assert_true(_s.armory.choose_tool_head(uid, step, head).ok)
	_s.rebuild_modifiers()


## The closed form of F-156/F-165 on the real encounter numbers, the units per hour of the Minatore, times the double product of the tool.
func _units_per_hour() -> float:
	var nodes: AreaNodesDef = _s.data.area_nodes(AREA)
	var weights: Dictionary = {}
	for entry: NodeEntryDef in nodes.entries:
		weights[entry.skill] = entry.weight
	var action: ActionDef = _s.data.action(&"quarry_ashlead")  # the resource of the area at L 30 before M35B (cap 10)
	var enc: Callable = func(key: String) -> int: return int(_s.data.balance_value("encounters." + key))
	var p: Dictionary = {"travel_ms": enc.call("travel_ms"), "node_chance_pct": enc.call("node_chance_pct"), "fight_ms": 30000,
		"skip_ms": enc.call("skip_ms"), "node_units": enc.call("node_units"), "weights": weights, "learned": [QUARRYING],
		"node_ms": {QUARRYING: EncounterCycle.node_duration_ms(_s, QUARRYING, action)}, "rich_ms_pct": enc.call("rich_ms_pct"),
		"rich_units_pct": enc.call("rich_units_pct"), "rich_chance_pct": enc.call("rich_chance_pct"),
		"unit_bonus_pct": {QUARRYING: EncounterCycle.units_bonus_pct(_s, QUARRYING, action)},
		"rich_by_skill": {QUARRYING: EncounterCycle.rich_chance(_s, QUARRYING, action)}}
	var per_hour: float = float(EncounterCycle.expected(p)["units_per_hour"][QUARRYING])
	return per_hour * (1.0 + _s.modifiers.total(&"double_item_chance", ModifierContext.for_action(QUARRYING, action.id)) / 100.0)


func test_the_per_node_examples() -> void:
	_pick(9, &"pick_vein")
	var action: ActionDef = _s.data.action(&"quarry_duskcobalt")  # the step of level 30
	assert_eq(EncounterCycle.units_bonus_pct(_s, QUARRYING, action), 24)
	assert_eq(EncounterCycle.rich_chance(_s, QUARRYING, action), 10.0)
	assert_almost_eq(80.0 * 1.24 * (1.0 + 0.10 * 0.5), 104.16, 0.001, "F-199: 104,16 units per node against 84")
	_pick(9, &"pick_quarry")
	assert_eq(EncounterCycle.units_bonus_pct(_s, QUARRYING, action), 9)
	assert_eq(EncounterCycle.rich_chance(_s, QUARRYING, action), 28.0)
	assert_almost_eq(80.0 * 1.09 * (1.0 + 0.28 * 0.5), 99.408, 0.001, "99,41")


func test_a_rich_chance_of_28_gives_a_multiplier_of_1_14() -> void:
	var p: Dictionary = {"rich_chance_pct": 28, "rich_units_pct": 150, "rich_ms_pct": 150}
	assert_almost_eq(EncounterCycle._rich_mult(p, QUARRYING, "rich_units_pct"), 1.14, 0.0001)
	assert_almost_eq(EncounterCycle._rich_mult(p, QUARRYING, "rich_ms_pct"), 1.14, 0.0001)
	p["rich_by_skill"] = {QUARRYING: 10.0}
	assert_almost_eq(EncounterCycle._rich_mult(p, QUARRYING, "rich_units_pct"), 1.05, 0.0001, "the chance of the skill wins")


func test_a_plus_nine_pick_is_at_most_thirty_percent_and_the_heads_are_equivalent() -> void:
	_pick(0, &"")
	var base: float = _units_per_hour()
	_pick(9, &"pick_vein")
	var yield_head: float = _units_per_hour()
	_pick(9, &"pick_quarry")
	var rich_head: float = _units_per_hour()
	assert_gt(yield_head, base)
	assert_lte(yield_head / base, 1.30, "Piccone +9, Resa: at most +30%")
	assert_lte(rich_head / base, 1.30, "Piccone +9, Ricchezza: at most +30%")
	assert_lte(absf(yield_head - rich_head) / maxf(yield_head, rich_head), 0.10, "the two heads differ by at most 10%")
