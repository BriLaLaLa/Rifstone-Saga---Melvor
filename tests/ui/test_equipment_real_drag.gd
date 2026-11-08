extends GutTest
## P-02: drag and drop of a piece from the inventory onto a slot of the doll with real mouse events (button press,
## motion beyond the drag threshold, release) sent through `Input.parse_input_event`, not with direct calls. Also the
## drag of a worn piece back to the inventory (Rimuovi).

const SCENE: PackedScene = preload("res://ui/pages/equipment/equipment_page.tscn")
const BLADE := &"test_blade"
const HELM := &"test_helm"
const STEPS: int = 8

var _session: GameSession
var _page: EquipmentPage
var _host: Control
var _viewport: SubViewport


func before_each() -> void:
	_session = TestFactory.session()


func after_each() -> void:
	if is_instance_valid(_viewport):
		_viewport.free()
	if is_instance_valid(_host):
		_host.free()
	if is_instance_valid(_session):
		_session.free()
	await wait_physics_frames(1)


func test_dragging_a_cell_onto_its_slot_equips_the_piece() -> void:
	var uid: int = TestFactory.give_piece(_session, HELM)
	await _open()
	var from: Vector2 = _center(_page.find_child("Cell%d" % uid, true, false) as Control)
	var to: Vector2 = _center(_doll().slot_view(&"head"))
	await _drag(from, to)
	assert_eq(_session.equipment.get_uid(&"head"), uid, "a real drag equips the piece")


func test_dragging_onto_an_incompatible_slot_does_nothing() -> void:
	var uid: int = TestFactory.give_piece(_session, HELM)
	await _open()
	var from: Vector2 = _center(_page.find_child("Cell%d" % uid, true, false) as Control)
	await _drag(from, _center(_doll().slot_view(&"feet")))
	assert_eq(_session.equipment.get_uid(&"head"), 0)
	assert_eq(_session.equipment.get_uid(&"feet"), 0)
	assert_true(_session.armory.has(uid))


func test_dragging_a_worn_piece_back_to_the_inventory_removes_it() -> void:
	var uid: int = TestFactory.give_piece(_session, HELM)
	assert_true(_session.equipment.equip(uid).ok)
	await _open()
	var from: Vector2 = _center(_doll().slot_view(&"head"))
	var to: Vector2 = _center(_page.get_node("%Scroll") as Control)
	await _drag(from, to)
	assert_eq(_session.equipment.get_uid(&"head"), 0, "dropped on the inventory = Rimuovi")


func _open() -> void:
	_host = Control.new()
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1152, 648)
	add_child(_viewport)
	_host.size = Vector2(1152, 648)
	_viewport.add_child(_host)
	_page = SCENE.instantiate() as EquipmentPage
	_page.page_id = &"equipment"
	_host.add_child(_page)
	_page.bind(_session)
	await wait_process_frames(3)


func _doll() -> EquipmentDoll:
	return _page.get_node("%Doll") as EquipmentDoll


func _center(control: Control) -> Vector2:
	return control.get_global_rect().get_center()


func _button(at: Vector2, pressed: bool) -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = at
	event.global_position = at
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	return event


func _motion(at: Vector2, relative: Vector2) -> InputEventMouseMotion:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.relative = relative
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	return event


## Press on `from`, move in small steps (a frame each) to `to`, release.
func _drag(from: Vector2, to: Vector2) -> void:
	_viewport.push_input(_motion(from, Vector2.ZERO))
	await wait_process_frames(1)
	_viewport.push_input(_button(from, true))
	await wait_process_frames(1)
	var previous: Vector2 = from
	for i: int in range(1, STEPS + 1):
		var point: Vector2 = from.lerp(to, float(i) / STEPS)
		_viewport.push_input(_motion(point, point - previous))
		previous = point
		await wait_process_frames(1)
	_viewport.push_input(_button(to, false))
	await wait_process_frames(2)
