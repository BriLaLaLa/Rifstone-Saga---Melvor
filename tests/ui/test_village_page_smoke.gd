extends GutTest
## VillagePage (M19-03) bound to the VillageStub (same signatures as `Village`, 5.27): 5 buildable boxes and 2
## placeholders, the button disabled with the reason when `can_upgrade` fails and enabled otherwise, one `upgrade`
## per click, everything disconnected by unbind. No exact texts checked.

const SCENE: PackedScene = preload("res://ui/pages/village/village_page.tscn")

var _session: GameSession
var _stub: VillageStub
var _page: VillagePage


func before_each() -> void:
	_session = TestFactory.session()
	_stub = VillageStub.new(_session)
	_page = SCENE.instantiate()
	add_child(_page)
	_page.bind_with(_session, _stub, _stub)


func after_each() -> void:
	if is_instance_valid(_page):
		_page.free()
	if is_instance_valid(_session):
		_session.free()
	await wait_physics_frames(1)


func test_seven_buildable_boxes_and_no_placeholder() -> void:
	assert_eq(VillageStub.BUILDABLE.size(), 7)
	for id: StringName in VillageStub.BUILDABLE:
		assert_not_null(_page.find_child("Box_%s" % id, true, false), "box %s" % id)
		assert_not_null(_button(id), "button %s" % id)
	assert_null(_page.find_child("ComingSoonLabel", true, false))
	assert_lte(_page.get_combined_minimum_size().x, 1280.0, "layout fits 1280x720")


func test_market_shows_the_fixed_effect_and_noticeboard_the_stat() -> void:
	var market: Node = _page.find_child("Box_market", true, false)
	assert_eq((market.find_child("EffectNowLabel", true, false) as Label).text,
			VillageTexts.EFFECT_NOW_TEXT % VillageTexts.FIXED_EFFECT_TEXT)
	assert_false((market.find_child("EffectNextLabel", true, false) as Label).visible)
	var board: Node = _page.find_child("Box_noticeboard", true, false)
	assert_true((board.find_child("EffectNextLabel", true, false) as Label).visible)


func test_button_follows_can_upgrade_and_upgrade_is_called_once_per_click() -> void:
	var button: Button = _button(&"inn")
	assert_true(button.disabled)
	assert_eq(_stub.can_upgrade(&"inn").reason, Reasons.NOT_ENOUGH_GOLD)
	assert_true((_page.find_child("Box_inn", true, false).find_child("ReasonLabel", true, false) as Label).visible)
	_session.wallet.add_gold(1000)
	_session.bank.add(_stub.cost_item, 10)
	assert_false(_button(&"inn").disabled)
	assert_eq(_stub.upgrade_calls, 0)
	_button(&"inn").pressed.emit()
	assert_eq(_stub.upgrade_calls, 1)
	assert_eq(_stub.level(&"inn"), 1)


func test_forced_reason_disables_the_button() -> void:
	_session.wallet.add_gold(1000)
	_session.bank.add(_stub.cost_item, 10)
	_stub.forced_reason = &"level_too_low"
	_session.wallet.add_gold(1)
	assert_true(_button(&"forge").disabled)


func test_unbind_disconnects_events() -> void:
	_page.unbind()
	assert_false(_session.events.gold_changed.is_connected(_page._on_gold_changed))
	assert_false(_session.events.bank_changed.is_connected(_page._on_bank_changed))


func test_map_view_nodes_states_selection_open_and_views() -> void:
	var map: VillageMap = _page.find_child("Map", true, false) as VillageMap
	for id: StringName in VillageStub.BUILDABLE:
		var node: Button = map.node(id)
		assert_not_null(node, "node %s" % id)
		var pos: Vector2 = VillageStub.MAP_POS[id]
		assert_almost_eq(node.anchor_left, pos.x, 0.001)
		assert_almost_eq(node.anchor_top, pos.y, 0.001)
	assert_eq(map.state_of(&"inn"), VillageNodeState.UNBUILT)
	_stub.forced_reason = &"level_too_low"
	_session.wallet.add_gold(1)
	assert_eq(map.state_of(&"inn"), VillageNodeState.LOCKED)
	_stub.forced_reason = &""
	_session.wallet.add_gold(1000)
	_session.bank.add(_stub.cost_item, 10)
	assert_eq(map.state_of(&"inn"), VillageNodeState.READY)
	# selecting a node changes the detail box; "Apri" is disabled at level 0 and enabled once built
	map.node(&"market").pressed.emit()
	assert_not_null(_page.find_child("Detail_market", true, false))
	var open: Button = _page.find_child("OpenButton", true, false) as Button
	assert_not_null(open)
	assert_true(open.disabled)
	var requested: Array[StringName] = []
	_page.page_requested.connect(func(page_id: StringName) -> void: requested.append(page_id))
	(_page.find_child("Detail_market", true, false).find_child("UpgradeButton", true, false) as Button).pressed.emit()
	assert_false((_page.find_child("OpenButton", true, false) as Button).disabled)
	(_page.find_child("OpenButton", true, false) as Button).pressed.emit()
	assert_eq(requested, [&"shop"] as Array[StringName])
	map.node(&"inn").pressed.emit()
	assert_null(_page.find_child("OpenButton", true, false))
	# view switch
	var map_view: Control = _page.find_child("MapView", true, false)
	var list: Control = _page.find_child("Scroll", true, false)
	assert_true(map_view.visible)
	assert_false(list.visible)
	(_page.find_child("ListButton", true, false) as Button).pressed.emit()
	assert_false(map_view.visible)
	assert_true(list.visible)


func _button(id: StringName) -> Button:
	return _page.find_child("Box_%s" % id, true, false).find_child("UpgradeButton", true, false) as Button


func test_bind_with_the_real_session_village() -> void:
	var real: GameSession = TestFactory.session_no_kit(7, TestFactory.real_data())
	add_child_autofree(real)
	var page: VillagePage = SCENE.instantiate()
	add_child_autofree(page)
	page.bind(real)
	for id: StringName in real.village.buildings():
		assert_not_null(page.find_child("Box_%s" % id, true, false), "box %s" % id)
	real.wallet.add_gold(300)
	TestFactory.give(real, &"redbirch_shieldcore", 20)
	TestFactory.give(real, &"emberbronze_plate", 4)
	var button: Button = page.find_child("Box_storehouse", true, false).find_child("UpgradeButton", true, false) as Button
	assert_false(button.disabled)
	button.pressed.emit()
	assert_eq(real.village.level(&"storehouse"), 1)
	assert_eq(real.deposit.capacity(), 64)
	page.unbind()
