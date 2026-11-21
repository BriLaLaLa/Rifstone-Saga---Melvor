extends GutTest
## Tutorial overlay with REAL mouse clicks (M30-04, docs/05_INTERFACES_M30.md §7.ab) on the main screen with a real session
## (real data, tutorial on): Avanti moves the model to the next step; while the player must change page only the sidebar row of
## that page is pressable; the menu button and Esc open the settings above the overlay; a click in the page area during a step
## works (the combat map starts the fight and the event step ends). No exact texts.

const SCENE: PackedScene = preload("res://ui/screens/main/main_screen.tscn")
const AREA_ID: StringName = &"redrock_plains"

var _s: GameSession = null
var _screen: MainScreen = null


func after_each() -> void:
	if is_instance_valid(_screen):
		_screen.free()
	if is_instance_valid(_s):
		_s.free()
	await wait_physics_frames(1)


## Opens the main screen on a new tutorial game; `from_step` (a tutorial save) is loaded before the screen exists.
func _open(from_step: Dictionary = {}) -> void:
	_s = TestFactory.session(77, TestFactory.real_data(), true, true)
	if not from_step.is_empty():
		_s.tutorial.from_save(from_step)
	_screen = SCENE.instantiate() as MainScreen
	_screen.session = _s
	add_child(_screen)
	# the output panel of the GUT runner sits over the top right corner of the window: it must not catch the test's clicks
	for layer: Node in get_tree().root.find_children("GutLayer", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	await _settle()


func test_avanti_on_the_first_step_moves_the_model_to_the_second() -> void:
	await _open()
	assert_eq(_s.tutorial.step_index(), 0)
	var overlay: TutorialOverlay = _screen.find_child("TutorialOverlay", true, false) as TutorialOverlay
	assert_not_null(overlay)
	await _click(overlay.find_child("NextButton", true, false) as Button)
	assert_eq(_s.tutorial.step_index(), 1, "the model went on, not only the UI")


func test_while_navigating_only_the_wanted_sidebar_row_works() -> void:
	await _open()
	_s.tutorial.acknowledge()
	await _settle()
	assert_true(_s.tutorial.needs_navigation(), "second step: the page is not the one shown")
	var host: PageHost = _screen.find_child("PageHost", true, false) as PageHost
	var sidebar: Sidebar = _screen.find_child("Sidebar", true, false) as Sidebar
	var shown: StringName = host.current_page_id()
	assert_true((_screen.find_child("GoToLabel", true, false) as Label).visible, "the card says where to go")
	# another sidebar row and the top bar: covered by the blockers, nothing changes
	await _click_blocked(sidebar.nav_row(&"bank").get_global_rect().get_center())
	await _click_blocked(_screen.find_child("TopBar", true, false).get_global_rect().get_center())
	assert_eq(host.current_page_id(), shown, "the page did not change")
	# the wanted row works and the card shows the step
	var wanted: StringName = _s.tutorial.required_route()
	await _click(sidebar.nav_row(wanted))
	assert_eq(PageHost.route_of(host.current_page_id()), wanted)
	assert_false(_s.tutorial.needs_navigation())
	assert_true((_screen.find_child("StepBox", true, false) as Control).visible)
	assert_false((_screen.find_child("GoToLabel", true, false) as Control).visible)


func test_menu_button_and_escape_open_the_settings_above_the_overlay() -> void:
	await _open()
	var overlay: Node = _screen.find_child("TutorialOverlay", true, false)
	await _click(_screen.find_child("MenuButton", true, false) as Button)
	var panels: Array[Node] = _screen.find_children("*", "SettingsPanel", true, false)
	assert_eq(panels.size(), 1, "the menu button is free")
	assert_gt(panels[0].get_index(), overlay.get_index(), "settings are drawn above the overlay")
	panels[0].free()
	var key := InputEventKey.new()
	key.keycode = KEY_ESCAPE
	key.physical_keycode = KEY_ESCAPE
	key.pressed = true
	get_viewport().push_input(key)
	await _settle()
	assert_eq(_screen.find_children("*", "SettingsPanel", true, false).size(), 1, "Esc opens the settings too")


func test_a_click_in_the_page_area_during_a_step_finishes_an_event_step() -> void:
	await _open({"completed": false, "step": "combat_start", "visited": ["character", "equipment"], "since_ms": 0})
	var host: PageHost = _screen.find_child("PageHost", true, false) as PageHost
	assert_eq(host.current_page_id(), &"combat", "loaded on the page of the step")
	assert_false(_s.tutorial.needs_navigation())
	var step_index: int = _s.tutorial.step_index()
	await _click(_screen.find_child("MapButton", true, false) as Button)
	var map: CombatMap = _screen.find_child("CombatMap", true, false) as CombatMap
	assert_true(map.visible, "the map opened with a real click in the page area")
	await _click(map.node(AREA_ID))
	assert_true(_s.combat.is_active(), "the fight started")
	assert_gt(_s.tutorial.step_index(), step_index, "the event step ended")


func _settle() -> void:
	await wait_process_frames(3)


func _move_to(at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()  # the mouse arrives over the control first, as with a real hand
	motion.position = at
	motion.global_position = at
	get_viewport().push_input(motion, true)
	await wait_process_frames(1)


func _press(at: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.position = at
		event.global_position = at
		get_viewport().push_input(event, true)
		await wait_process_frames(1)
	await _settle()


## A real left click on the centre of `control`; the click must land on it.
func _click(control: Control) -> void:
	var at: Vector2 = control.get_global_rect().get_center()
	await _move_to(at)
	assert_eq(get_viewport().gui_get_hovered_control(), control, "the click lands on %s" % control.name)
	await _press(at)


## A real click at `at` that a blocker must catch.
func _click_blocked(at: Vector2) -> void:
	await _move_to(at)
	var hovered: Control = get_viewport().gui_get_hovered_control()
	assert_not_null(hovered)
	assert_true(hovered != null and hovered.get_parent() is TutorialBlockers, "a blocker covers the point")
	await _press(at)
