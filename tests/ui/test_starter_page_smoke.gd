extends GutTest
## Smoke test of the Primi passi page (M30-04): groups and rows from the data, a claimable quest and one that is not,
## Riscuoti is a command that delivers ONE Mail message (clicked for real), unbind disconnects everything. No exact texts.

const SCENE: PackedScene = preload("res://ui/screens/main/main_screen.tscn")

var _s: GameSession = null
var _screen: MainScreen = null


func before_each() -> void:
	_s = TestFactory.session(80, TestFactory.real_data())  # tutorial completed: the quests are active
	TestFactory.set_character_level(_s, 3)
	_screen = SCENE.instantiate() as MainScreen
	_screen.session = _s
	add_child(_screen)
	for layer: Node in get_tree().root.find_children("GutLayer", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	await wait_process_frames(3)


func after_each() -> void:
	if is_instance_valid(_screen):
		_screen.free()
	if is_instance_valid(_s):
		_s.free()
	await wait_physics_frames(1)


func test_rows_follow_the_data_and_riscuoti_sends_one_message_with_a_real_click() -> void:
	var host: PageHost = _screen.find_child("PageHost", true, false) as PageHost
	host.show_page(&"starter")
	await wait_process_frames(3)
	var page: StarterPage = _screen.find_child("Page", true, false) as StarterPage
	assert_not_null(page)
	var rows: Array[Node] = page.find_children("*", "StarterRow", true, false)
	assert_eq(rows.size(), _s.tutorial.starter.total(), "one row per quest")
	var claimable: Array[StarterQuestDef] = _s.tutorial.starter.claimable()
	assert_false(claimable.is_empty(), "level 3 reached: something to claim")
	var button: Button = page.find_child("Row_%s" % claimable[0].id, true, false).find_child("ClaimButton", true, false) as Button
	assert_false(button.disabled)
	for def: StarterQuestDef in _s.tutorial.starter.quests():
		if not _s.tutorial.starter.is_complete(def.id):
			var locked: Button = page.find_child("Row_%s" % def.id, true, false).find_child("ClaimButton", true, false) as Button
			assert_true(locked.disabled, "an unfinished quest cannot be claimed")
			break
	var mail_before: int = _s.mail.count()
	var claimed_before: int = _s.tutorial.starter.claimed_count()
	await _click(button)
	assert_eq(_s.mail.count(), mail_before + 1, "one command, one message")
	assert_eq(_s.tutorial.starter.claimed_count(), claimed_before + 1)
	assert_true(_s.tutorial.starter.is_claimed(claimable[0].id))
	assert_false(button.visible, "the row shows it as claimed")


func test_unbind_disconnects_everything() -> void:
	var host: PageHost = _screen.find_child("PageHost", true, false) as PageHost
	host.show_page(&"starter")
	var page: StarterPage = _screen.find_child("Page", true, false) as StarterPage
	var before: int = _s.events.starter_quests_changed.get_connections().size()
	page.unbind()
	assert_eq(_s.events.starter_quests_changed.get_connections().size(), before - 1)


func _click(control: Control) -> void:
	var at: Vector2 = control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	get_viewport().push_input(motion, true)
	await wait_process_frames(1)
	assert_eq(get_viewport().gui_get_hovered_control(), control, "the click lands on the control")
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.position = at
		event.global_position = at
		get_viewport().push_input(event, true)
		await wait_process_frames(1)
	await wait_process_frames(3)
