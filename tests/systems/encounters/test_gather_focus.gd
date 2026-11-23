extends GutTest
## M35-D F-195: the resource of a node with the choice of the player (EncounterCycle.worked_action, NodeWork.begin, the state of the node).
## Real data (Minatore: Rame 1, Ferro 10, Ferro scuro 20, Ferro nero 30, Argento runico 45, Ossidiana 60; areas dry_uplands M 30, ash_marsh M 50).

const QUARRYING: StringName = &"quarrying"
const COPPER: StringName = &"quarry_emberbronze"
const IRON: StringName = &"quarry_ashlead"
const BLACK_IRON: StringName = &"quarry_duskcobalt"
const SILVER: StringName = &"quarry_glimmerite"
const OBSIDIAN: StringName = &"quarry_palecinnabar"

var _s: GameSession = null


func before_each() -> void:
	_s = autofree(TestFactory.session_no_kit(41, TestFactory.real_data()))
	_s.disciplines.new_game()


func _action(level: int, max_level: int, focus: StringName = &"") -> StringName:
	return EncounterCycle.worked_action(_s.data, QUARRYING, level, max_level, focus).id


func _color(level: int, action_id: StringName) -> StringName:
	return EncounterCycle.color(_s.data, level, _s.data.action(action_id).level)["id"]


# --- the resource ---------------------------------------------------------------------------------------------------

func test_automatico_is_the_old_rule() -> void:
	assert_eq(_action(45, 60), SILVER)
	assert_eq(_action(45, 30), BLACK_IRON)


func test_the_choice_is_worked_when_the_node_allows_it() -> void:
	assert_eq(_action(45, 50, COPPER), COPPER)
	assert_eq(_color(45, COPPER), &"grey", "d 44: grey")
	assert_eq(_action(27, 30, IRON), IRON)
	assert_eq(_color(27, IRON), &"yellow", "d 17")
	assert_eq(_action(30, 99, IRON), IRON)
	assert_eq(_color(30, IRON), &"green", "d 20")


func test_a_choice_above_the_cap_of_the_area_falls_back_to_automatico() -> void:
	assert_eq(_action(45, 30, SILVER), BLACK_IRON, "limit = min(45, 30)")


func test_a_choice_above_the_level_falls_back_too() -> void:
	assert_eq(_action(20, 99, OBSIDIAN), &"quarry_stormzinc")


func test_a_choice_of_another_skill_is_not_a_resource() -> void:
	assert_eq(_action(45, 60, &"cut_redbirch"), SILVER)


# --- the node ----------------------------------------------------------------------------------------------------------

func _learn(level: int) -> void:
	TestFactory.learn_discipline(_s, QUARRYING)
	TestFactory.set_level(_s, QUARRYING, level)


func test_the_node_works_the_choice() -> void:
	_learn(45)
	assert_true(_s.disciplines.set_focus(QUARRYING, COPPER).ok)
	var work: NodeWork = NodeWork.begin(_s, &"ash_marsh", QUARRYING)
	assert_eq(work.action_id, COPPER)
	assert_true(work.focused)
	assert_false(work.focus_blocked)
	assert_eq(work.color(_s)["id"], &"grey")
	assert_eq(work.color(_s)["xp_pct"], 0.0, "grey: XP 0%, the product stays")


func test_the_node_that_does_not_allow_it_is_automatico_and_says_so() -> void:
	_learn(45)
	assert_true(_s.disciplines.set_focus(QUARRYING, SILVER).ok)
	var work: NodeWork = NodeWork.begin(_s, &"dry_uplands", QUARRYING)
	assert_eq(work.action_id, BLACK_IRON)
	assert_false(work.focused)
	assert_true(work.focus_blocked)
	assert_false(work.skipped, "a node is never skipped for this")


func test_without_a_choice_nothing_is_flagged() -> void:
	_learn(45)
	var work: NodeWork = NodeWork.begin(_s, &"ash_marsh", QUARRYING)
	assert_eq(work.action_id, SILVER)
	assert_false(work.focused)
	assert_false(work.focus_blocked)


func test_the_resource_is_fixed_at_the_start_and_the_new_choice_counts_from_the_next_node() -> void:
	_learn(45)
	assert_true(_s.disciplines.set_focus(QUARRYING, COPPER).ok)
	var work: NodeWork = NodeWork.begin(_s, &"ash_marsh", QUARRYING)
	assert_true(_s.disciplines.set_focus(QUARRYING, IRON).ok)
	assert_eq(work.action_id, COPPER, "the node in progress keeps its resource")
	var again: ActionOutcome = work.resolve_attempt(_s)
	assert_true(again.ok)
	assert_eq(NodeWork.begin(_s, &"ash_marsh", QUARRYING).action_id, IRON, "the next node")


func test_the_state_of_the_node_for_the_ui() -> void:
	_learn(45)
	assert_true(_s.disciplines.set_focus(QUARRYING, SILVER).ok)
	var cycle := CycleState.new(_s)
	cycle.node = NodeWork.begin(_s, &"dry_uplands", QUARRYING)
	var node: Dictionary = cycle.view(CombatState.STATE_NODE)["node"]
	assert_eq(node["action"], BLACK_IRON)
	assert_eq(node["focused"], false)
	assert_eq(node["focus_blocked"], true)
	assert_eq(node["ne"], 80, "no node_units_pct: N")
	cycle.node = NodeWork.begin(_s, &"ash_marsh", QUARRYING)
	node = cycle.view(CombatState.STATE_NODE)["node"]
	assert_eq(node["focused"], true)
	assert_eq(node["focus_blocked"], false)


func test_a_skipped_node_ignores_the_choice() -> void:
	var work: NodeWork = NodeWork.begin(_s, &"ash_marsh", QUARRYING)
	assert_true(work.skipped, "not learned")
	assert_false(work.focused)
