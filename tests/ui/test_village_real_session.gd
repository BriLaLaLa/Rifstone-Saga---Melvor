extends GutTest
## M21-04: VillagePage on the real GameSession and real data: 7 map nodes at the positions of buildings.json, states,
## selection, "Apri" disabled at level 0 and enabled after the build, and page_requested reaching the page host.

var _session: GameSession
var _host: PageHost


func before_each() -> void:
	_session = TestFactory.session_no_kit(7, TestFactory.real_data())
	_host = PageHost.new()
	add_child(_host)
	_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_host.setup(_session)
	_host.show_page(&"village")


func after_each() -> void:
	if is_instance_valid(_host):
		_host.free()
	if is_instance_valid(_session):
		_session.free()
	await wait_physics_frames(1)


func _page() -> VillagePage:
	return _host.find_child("Page", false, false) as VillagePage


func _build(id: StringName) -> void:
	var cost: Dictionary = _session.village.next_cost(id)
	_session.wallet.add_gold(int(cost["gold"]))
	for row: Dictionary in cost["items"]:
		TestFactory.give(_session, StringName(row["item"]), int(row["qty"]))
	assert_true(_session.village.upgrade(id).ok, "build %s" % id)


func test_seven_nodes_at_data_positions_and_coherent_states() -> void:
	var map: VillageMap = _page().find_child("Map", true, false) as VillageMap
	var ids: Array[StringName] = _session.village.buildings()
	assert_eq(ids.size(), 7)
	for id: StringName in ids:
		var def: VillageBuildingDef = _session.data.village_building(id)
		var node: Button = map.node(id)
		assert_not_null(node, "node %s" % id)
		assert_almost_eq(node.anchor_left, def.map_pos.x, 0.001)
		assert_almost_eq(node.anchor_top, def.map_pos.y, 0.001)
		var state: StringName = map.state_of(id)
		assert_true(state == VillageNodeState.UNBUILT or state == VillageNodeState.LOCKED, "%s: %s" % [id, state])
		var reason: StringName = _session.village.can_upgrade(id).reason
		assert_eq(state == VillageNodeState.LOCKED, reason == Reasons.LEVEL_TOO_LOW, "state of %s follows the woodwright" % id)


func test_open_follows_the_level_and_reaches_the_pages() -> void:
	var map: VillageMap = _page().find_child("Map", true, false) as VillageMap
	for pair: Array in [[&"market", &"shop"], [&"noticeboard", &"noticeboard"]]:
		var id: StringName = pair[0]
		map.node(id).pressed.emit()
		var open: Button = _page().find_child("OpenButton", true, false) as Button
		assert_not_null(open, "open %s" % id)
		assert_true(open.disabled)
		_build(id)
		open = _page().find_child("OpenButton", true, false) as Button
		assert_false(open.disabled)
		open.pressed.emit()
		assert_eq(_host.current_page_id(), pair[1])
		_host.show_page(&"village")
		map = _page().find_child("Map", true, false) as VillageMap
