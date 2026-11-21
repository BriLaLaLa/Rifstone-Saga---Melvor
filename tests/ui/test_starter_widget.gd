extends GutTest
## The Primi passi box of the sidebar (M30-04): hidden while the tutorial is on, shown when it ends, a click opens the
## `starter` page (real click), the gold dot follows what can be claimed, hidden at the last quest. No exact texts.

const SCENE: PackedScene = preload("res://ui/screens/main/main_screen.tscn")

var _s: GameSession = null
var _screen: MainScreen = null


func after_each() -> void:
	if is_instance_valid(_screen):
		_screen.free()
	if is_instance_valid(_s):
		_s.free()
	await wait_physics_frames(1)


func _open(with_tutorial: bool) -> void:
	_s = TestFactory.session(81, TestFactory.real_data(), true, with_tutorial)
	_screen = SCENE.instantiate() as MainScreen
	_screen.session = _s
	add_child(_screen)
	for layer: Node in get_tree().root.find_children("GutLayer", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	await wait_process_frames(3)


func _widget() -> StarterWidget:
	return _screen.find_child("StarterWidget", true, false) as StarterWidget


func test_hidden_during_the_tutorial_and_shown_when_it_ends() -> void:
	await _open(true)
	assert_false(_widget().visible)
	_s.tutorial.from_save({"completed": true, "step": "", "visited": []})
	_s.events.tutorial_completed.emit()
	await wait_process_frames(2)
	assert_true(_widget().visible)


func test_click_opens_the_page_and_the_dot_follows_the_claimable_quests() -> void:
	await _open(false)
	var dot: Control = _widget().find_child("Dot", true, false) as Control
	assert_eq(dot.visible, not _s.tutorial.starter.claimable().is_empty())
	TestFactory.set_character_level(_s, 3)
	_s.events.starter_quests_changed.emit()
	assert_true(dot.visible, "something to claim")
	var at: Vector2 = _widget().get_global_rect().get_center()
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
		await wait_process_frames(1)
	await wait_process_frames(3)
	assert_eq((_screen.find_child("PageHost", true, false) as PageHost).current_page_id(), &"starter")


func test_hidden_when_every_quest_is_claimed() -> void:
	await _open(false)
	var ids: Array = []
	for def: StarterQuestDef in _s.tutorial.starter.quests():
		ids.append(String(def.id))
	_s.tutorial.starter.from_save({"claimed": ids, "progress": {}})
	_s.events.starter_quests_changed.emit()
	assert_false(_widget().visible)
