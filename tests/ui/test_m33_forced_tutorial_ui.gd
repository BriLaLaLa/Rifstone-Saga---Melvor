extends GutTest
## M33-03: the forced first fight on the real main screen (real data, real session, real mouse click): after the third kill the engine is
## frozen with an empty enemy zone, the combat page says "In pausa", Avanti of the triangle step unfreezes and moves to the next step.
## The pause line belongs to the combat page only. No exact texts.

const SCENE: PackedScene = preload("res://ui/screens/main/main_screen.tscn")
const VISITED: Array = ["character", "equipment", "combat"]
const MAX_TICKS: int = 6000

var _s: GameSession = null
var _screen: MainScreen = null


func after_each() -> void:
	if is_instance_valid(_screen):
		_screen.free()
	if is_instance_valid(_s):
		_s.free()
	await wait_physics_frames(1)


func _open(step: String) -> void:
	_s = TestFactory.session(77, TestFactory.real_data(), true, true)
	_s.tutorial.from_save({"completed": false, "step": step, "visited": VISITED, "since_ms": 0})
	_screen = SCENE.instantiate() as MainScreen
	_screen.session = _s
	add_child(_screen)
	for layer: Node in get_tree().root.find_children("GutLayer", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	await wait_process_frames(3)


func _fight_until_triangle() -> void:
	_s.combat.start(&"redrock_plains")
	var ticks: int = 0
	while _s.tutorial.current_step().id == &"combat_kills" and ticks < MAX_TICKS:
		_s.advance(100)
		ticks += 1
	await wait_process_frames(4)


func test_the_paused_combat_page_with_an_empty_zone_says_in_pausa() -> void:
	await _open("combat_kills")
	await _fight_until_triangle()
	assert_eq(_s.tutorial.current_step().id, &"combat_triangle", "three kills of the forced pack close the step")
	assert_true(_s.combat.is_frozen())
	var state: Label = _screen.find_child("StateLabel", true, false) as Label
	assert_true(state.text.begins_with("In pausa"), "the pause is shown")
	assert_true((_s.combat.get_state()["enemies"] as Array).is_empty(), "the group is dead: the zone is empty")


func test_avanti_of_the_triangle_step_with_a_real_click_unfreezes_and_advances() -> void:
	await _open("combat_kills")
	await _fight_until_triangle()
	assert_true(_s.combat.is_frozen())
	var next: Button = _screen.find_child("NextButton", true, false) as Button
	assert_true(next.is_visible_in_tree(), "Avanti is offered")
	await _click(next)
	assert_false(_s.combat.is_frozen(), "Avanti unfreezes the engine")
	assert_eq(_s.tutorial.current_step().id, &"combat_eat", "the next step")
	await wait_process_frames(2)
	var state: Label = _screen.find_child("StateLabel", true, false) as Label
	assert_false(state.text.begins_with("In pausa"), "no pause line once unfrozen")


func test_another_page_has_no_pause_line_while_the_combat_is_frozen() -> void:
	await _open("combat_kills")
	await _fight_until_triangle()
	assert_true(_s.combat.is_frozen())
	(_screen.find_child("PageHost", true, false) as PageHost).show_page(&"character")
	await wait_process_frames(3)
	assert_eq(((_screen.find_child("PageHost", true, false) as PageHost).get_node("Page") as Page).page_id, &"character")
	assert_null(_screen.find_child("StateLabel", true, false), "only the combat page has the state line")


func _move_to(at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	get_viewport().push_input(motion, true)
	await wait_process_frames(1)


## A real left click on the centre of `control`; the click must land on it.
func _click(control: Control) -> void:
	var at: Vector2 = control.get_global_rect().get_center()
	await _move_to(at)
	assert_eq(get_viewport().gui_get_hovered_control(), control, "the click lands on %s" % control.name)
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
