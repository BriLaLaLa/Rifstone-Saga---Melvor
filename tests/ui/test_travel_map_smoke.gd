extends GutTest
## TravelMap (V27): the little map shows only while travelling and the icon follows `1 - travel_ms / travel_total_ms`.
## Fake combat state (CombatCycleStub); nothing else is needed, no session.

var _map: TravelMap


func before_each() -> void:
	_map = add_child_autofree(TravelMap.new()) as TravelMap
	_map.size = Vector2(800, 300)


func test_progress_follows_the_travel_and_the_map_draws() -> void:
	_map.refresh(CombatCycleStub.travel_state(1000, 4000))
	assert_true(_map.visible)
	assert_almost_eq(_map.progress(), 0.75, 0.0001)
	var start: Vector2 = TravelMap.path_point(0.0, _map.size)
	var end: Vector2 = TravelMap.path_point(1.0, _map.size)
	assert_lt(start.x, end.x)
	await wait_process_frames(2)  # _draw runs without errors


func test_map_hides_outside_its_state() -> void:
	var node_state: Dictionary = CombatCycleStub.node_state(&"forestry", &"cut_redbirch", 3000, 12000, false, &"yellow", 20)
	_map.refresh(node_state)
	assert_false(_map.visible)
