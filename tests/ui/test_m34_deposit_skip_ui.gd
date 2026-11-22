extends GutTest
## M34-02 smoke: the Deposit item panel is always there (fixed width, empty state) and a REAL click on a cell does not move or resize
## the grid; "Salta tutorial" in the tutorial card, the confirmation "No" (nothing happens) and "Sì" (the model completes the tutorial and
## the card goes away), all with real mouse clicks on the main screen. No exact texts.

const SCENE: PackedScene = preload("res://ui/screens/main/main_screen.tscn")
const ITEM: StringName = &"dungeon_ticket_monkey_den"

var _s: GameSession = null
var _screen: MainScreen = null


func after_each() -> void:
	if is_instance_valid(_screen):
		_screen.free()
	if is_instance_valid(_s):
		_s.free()
	await wait_physics_frames(1)


func _open(tutorial: bool) -> void:
	_s = TestFactory.session(77, TestFactory.real_data(), tutorial, tutorial)
	TestFactory.make_roomy(_s)
	TestFactory.give(_s, ITEM, 4)
	_screen = SCENE.instantiate() as MainScreen
	_screen.session = _s
	add_child(_screen)
	# the output panel of the GUT runner sits over the top right corner of the window: it must not catch the test's clicks
	for layer: Node in get_tree().root.find_children("GutLayer", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	await _settle()


func test_deposit_panel_is_always_present_and_a_real_click_does_not_move_the_grid() -> void:
	await _open(false)
	(_screen.find_child("PageHost", true, false) as PageHost).show_page(&"bank")
	await _settle()
	var page: BankPage = _screen.find_child("Page", true, false) as BankPage
	var panel: BankItemPanel = page.find_child("ItemPanel", true, false) as BankItemPanel
	var grid: Control = page.find_child("Grid", true, false) as Control
	assert_true(panel.visible, "present with no selection")
	assert_true(panel.find_child("EmptyLabel", true, false).visible, "empty state")
	var width: float = panel.size.x
	var grid_rect: Rect2 = grid.get_global_rect()
	var body_rect: Rect2 = (grid.get_parent().get_parent() as Control).get_global_rect()
	var cell: ItemSlotView = null
	for child: Node in grid.get_children():
		if child is ItemSlotView and (child as ItemSlotView).item_id() == ITEM:
			cell = child as ItemSlotView
	assert_not_null(cell)
	await _click(cell)
	assert_eq(panel.item_id(), ITEM, "the click selected the item")
	assert_false(panel.find_child("EmptyLabel", true, false).visible)
	assert_eq(panel.size.x, width, "fixed width")
	assert_eq(grid.get_global_rect(), grid_rect, "the grid did not move or resize")
	assert_eq((grid.get_parent().get_parent() as Control).get_global_rect(), body_rect)
	panel.clear()
	await _settle()
	assert_true(panel.visible)
	assert_true(panel.find_child("EmptyLabel", true, false).visible)
	assert_eq(grid.get_global_rect(), grid_rect, "nor on deselecting")


func test_skip_button_no_cancels_and_yes_completes_the_tutorial() -> void:
	await _open(true)
	var card: TutorialPanel = _screen.find_child("Card", true, false) as TutorialPanel
	var skip: Button = card.find_child("SkipTutorialButton", true, false) as Button
	assert_true(skip.is_visible_in_tree())
	assert_true(Rect2(Vector2.ZERO, Vector2(UiStyle.TUTORIAL_PANEL_WIDTH, UiStyle.TUTORIAL_PANEL_MAX_HEIGHT)).encloses(Rect2(Vector2.ZERO, card.size)), "within 440x240")
	await _click(skip)
	assert_true(card.find_child("ConfirmBox", true, false).visible)
	await _click(card.find_child("ConfirmNoButton", true, false) as Button)
	assert_false(_s.tutorial.is_completed(), "No changes nothing")
	assert_false(card.find_child("ConfirmBox", true, false).visible)
	assert_true(skip.is_visible_in_tree())
	await _click(skip)
	await _click(card.find_child("ConfirmYesButton", true, false) as Button)
	assert_true(_s.tutorial.is_completed())
	await _settle()
	assert_null(_screen.find_child("TutorialOverlay", true, false), "the card is gone")


func test_skip_button_is_there_while_navigating_too() -> void:
	await _open(true)
	_s.tutorial.acknowledge()
	await _settle()
	assert_true(_s.tutorial.needs_navigation())
	var card: TutorialPanel = _screen.find_child("Card", true, false) as TutorialPanel
	assert_true((card.find_child("SkipTutorialButton", true, false) as Button).is_visible_in_tree())
	assert_lte(card.size.y, UiStyle.TUTORIAL_PANEL_MAX_HEIGHT)


func _settle() -> void:
	await wait_process_frames(3)


## A real left click (press and release) on the centre of `control`.
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
	await _settle()
