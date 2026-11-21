extends GutTest
## M32-04: with the two production slots full, the Cucina (`free_slot`) is learned with a REAL mouse click on its Learn button
## and the slot counter of the Produzione box does not change. No exact texts.

const SCENE: PackedScene = preload("res://ui/screens/main/main_screen.tscn")
const COOKING: StringName = &"hearthcraft"

var _s: GameSession = null
var _screen: MainScreen = null


func before_each() -> void:
	_s = TestFactory.session(77, TestFactory.real_data())
	TestFactory.make_roomy(_s)
	_s.disciplines._grades.erase(COOKING)  # the factory teaches it: start from the Cucina not learned, two other crafts learned
	for skill_id: StringName in [&"forging", &"woodwright"]:
		TestFactory.learn_discipline(_s, skill_id)
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


func test_cooking_is_learned_by_click_with_production_slots_full() -> void:
	assert_eq(_s.disciplines.free_slots(&"artisan"), 0, "the two production slots are full")
	assert_false(_s.disciplines.is_learned(COOKING))
	var host: PageHost = _screen.find_child("PageHost", true, false) as PageHost
	host.show_page(&"trainers")
	await wait_process_frames(3)
	var page: TrainersPage = _screen.find_child("Page", true, false) as TrainersPage
	var button: Button = page.find_child("TrainerHearthcraft", true, false).find_child("LearnButton", true, false) as Button
	assert_false(button.disabled, "learnable with full slots")
	await _click(button)
	assert_true(_s.disciplines.is_learned(COOKING))
	assert_eq(_s.disciplines.free_slots(&"artisan"), 0, "still no free slot, the Cucina does not use one")


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
