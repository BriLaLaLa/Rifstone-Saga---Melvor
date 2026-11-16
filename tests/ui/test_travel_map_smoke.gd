extends GutTest
## TravelMap (M24-06, 05_INTERFACES_M24.md §7.o) on a fake combat state (CombatCycleStub): the icon moves with
## `1 - travel_ms / travel_total_ms`, the target is swords or the discipline (grey with a lock when not learned). A real
## session is used only for the data
## and for `disciplines.is_learned` (never `Game.session`, never a real slot).

## The test session has the first two disciplines of each category learned (TestFactory.learn_all).
const SKILL: StringName = &"forestry"
const UNLEARNED: StringName = &"angling"

var _session: GameSession
var _map: TravelMap


func before_each() -> void:
	_session = TestFactory.session(1234, TestFactory.real_data())
	_map = add_child_autofree(TravelMap.new()) as TravelMap
	_map.size = Vector2(800, TravelMap.HEIGHT)


func after_each() -> void:
	if is_instance_valid(_session):
		_session.free()
	await wait_physics_frames(1)


func test_icon_follows_the_travel_and_the_target_is_the_discipline() -> void:
	_map.refresh(CombatCycleStub.travel_state(1000, 4000, SKILL), _session.data, _session.disciplines)
	assert_true(_map.visible)
	assert_almost_eq(_map.progress(), 0.75, 0.0001)
	var icon: Control = _map.get_node("TravelIcon") as Control
	var target: Control = _map.get_node("TravelTarget") as Control
	assert_gt(icon.position.x, 0.0)
	assert_lt(icon.position.x, target.position.x, "the icon has not arrived yet")
	assert_false((_map.get_node("TravelLock") as Label).visible, "a learned discipline has no lock")
	_map.refresh(CombatCycleStub.travel_state(0, 4000, SKILL), _session.data, _session.disciplines)
	assert_almost_eq(icon.position.x, target.position.x, 0.01, "arrived")


func test_unlearned_discipline_is_grey_with_a_lock_and_a_fight_has_none() -> void:
	_map.refresh(CombatCycleStub.travel_state(2000, 4000, UNLEARNED), _session.data, _session.disciplines)
	assert_true((_map.get_node("TravelLock") as Label).visible)
	assert_eq((_map.get_node("TravelTarget") as Control).modulate, UiStyle.TEXT_DISABLED)
	_map.refresh(CombatCycleStub.travel_state(2000, 4000), _session.data, _session.disciplines)
	assert_false((_map.get_node("TravelLock") as Label).visible, "swords: nothing to learn")


func test_map_hides_outside_its_state() -> void:
	var node_state: Dictionary = CombatCycleStub.node_state(SKILL, &"cut_redbirch", 3000, 12000, false, &"yellow", 20)
	_map.refresh(node_state, _session.data, _session.disciplines)
	assert_false(_map.visible)
