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


func test_five_buildable_boxes_and_two_placeholders() -> void:
	for id: StringName in VillageStub.BUILDABLE:
		assert_not_null(_page.find_child("Box_%s" % id, true, false), "box %s" % id)
		assert_not_null(_button(id), "button %s" % id)
	for id: StringName in VillageStub.PLACEHOLDERS:
		var box: Node = _page.find_child("Box_%s" % id, true, false)
		assert_not_null(box, "placeholder %s" % id)
		assert_null(box.find_child("UpgradeButton", true, false))
		assert_not_null(box.find_child("ComingSoonLabel", true, false))


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


func _button(id: StringName) -> Button:
	return _page.find_child("Box_%s" % id, true, false).find_child("UpgradeButton", true, false) as Button
