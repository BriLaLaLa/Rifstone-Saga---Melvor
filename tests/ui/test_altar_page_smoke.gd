extends GutTest
## Altar page smoke test (M35-C): three columns (socket, rune, confirm). A rune is picked and socketed with REAL clicks, a
## locked socket and the rune of a unique infusion show why they cannot be used, the removal needs a confirmation and destroys,
## the page follows the model events and unbind disconnects. Real data, TestFactory session. No exact texts.

const SCENE: PackedScene = preload("res://ui/pages/rift/rift_page.tscn")
const RUNE: StringName = &"inf_swift_hands"

var _s: GameSession = null
var _page: RiftPage = null


func before_each() -> void:
	_s = TestFactory.session(1234, TestFactory.real_data())
	TestFactory.give(_s, RUNE, 3)
	_page = SCENE.instantiate() as RiftPage
	_page.page_id = &"rift"
	add_child(_page)
	_page.size = Vector2(1000, 600)
	_page.bind(_s)
	# the output panel of the GUT runner must not catch the test's clicks
	for layer: Node in get_tree().root.find_children("GutLayer", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	await wait_process_frames(3)


func after_each() -> void:
	if is_instance_valid(_page):
		_page.free()
	if is_instance_valid(_s):
		_s.free()
	await wait_physics_frames(1)


func test_pick_confirm_and_remove_with_real_clicks() -> void:
	for i: int in _s.rift.socket_total():
		assert_not_null(_page.find_child("Socket%d" % i, true, false), "row for socket %d" % i)
	var locked: int = -1
	for i: int in _s.rift.socket_total():
		if not _s.rift.is_unlocked(i):
			locked = i
			break
	assert_gt(locked, 0, "a locked socket exists at level 1")
	var confirm: Button = _page.find_child("SocketButton", true, false) as Button
	assert_not_null(confirm)
	assert_false(confirm.disabled, "free socket + owned rune: ready to confirm, preview shown")
	assert_not_null(_page.find_child("Preview", true, false))
	assert_not_null(_page.find_child("AfterText", true, false), "result preview")
	# a locked socket: no confirm, the reason is on screen
	await _click(_page.find_child("Socket%d" % locked, true, false) as Control)
	assert_null(_page.find_child("SocketButton", true, false))
	assert_not_null(_page.find_child("Prompt", true, false))
	# back to socket 0, confirm the rune with a real click
	await _click(_page.find_child("Socket0", true, false) as Control)
	await _click(_page.find_child("Pick_%s" % RUNE, true, false) as Control)
	var bank_before: int = _s.bank.get_count(RUNE)
	await _click(_page.find_child("SocketButton", true, false) as Control)
	assert_eq(_s.rift.get_socket(0), RUNE)
	assert_eq(_s.bank.get_count(RUNE), bank_before - 1, "one rune consumed")
	# removal asks first, then destroys
	await _click(_page.find_child("Socket0", true, false) as Control)
	await _click(_page.find_child("RemoveButton", true, false) as Control)
	assert_eq(_s.rift.get_socket(0), RUNE, "not yet")
	await _click(_page.find_child("ConfirmRemoveButton", true, false) as Control)
	assert_eq(_s.rift.get_socket(0), &"")
	assert_eq(_s.bank.get_count(RUNE), bank_before - 1, "destroyed, not returned")


func test_page_follows_events_and_unbind_disconnects() -> void:
	assert_null(_page.find_child("RemoveButton", true, false))
	_s.rift.socket(0, RUNE)
	await wait_process_frames(2)
	assert_not_null(_page.find_child("RemoveButton", true, false), "redrawn by infusion_socketed")
	_page.unbind()
	assert_false(_s.events.infusion_socketed.is_connected(_page._redraw_from_event))


## A real left click (press and release) on the centre of `control`.
func _click(control: Control) -> void:
	assert_not_null(control)
	var at: Vector2 = control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	get_viewport().push_input(motion, true)
	await wait_process_frames(1)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.position = at
		event.global_position = at
		get_viewport().push_input(event, true)
	await wait_process_frames(3)
