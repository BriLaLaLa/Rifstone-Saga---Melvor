extends GutTest
## Smoke test of the ResourceTable of a gathering page (M35-D3, docs/05_INTERFACES_M35.md §7.ac) on the main screen with a real session:
## columns, one row per action, a REAL click on "Raccogli questa" calls `set_focus`, "Automatico" clears it, the filter hides rows.
## No exact texts.

const SCENE: PackedScene = preload("res://ui/screens/main/main_screen.tscn")
const SKILL: StringName = &"quarrying"

var _s: GameSession = null
var _screen: MainScreen = null


func before_each() -> void:
	_s = TestFactory.session(77, TestFactory.real_data())
	TestFactory.learn_discipline(_s, SKILL)
	TestFactory.set_level(_s, SKILL, 30)
	_screen = SCENE.instantiate() as MainScreen
	_screen.session = _s
	add_child(_screen)
	for layer: Node in get_tree().root.find_children("GutLayer", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	(_screen.find_child("HintCard", true, false) as Control).visible = false  # a modal hint card would catch the clicks
	await wait_process_frames(3)


func after_each() -> void:
	if is_instance_valid(_screen):
		_screen.free()
	if is_instance_valid(_s):
		_s.free()
	await wait_physics_frames(1)


func test_table_has_the_columns_and_one_row_per_action() -> void:
	var page: Node = await _open()
	var table: ResourceTable = page.find_child("ResourceTable", true, false) as ResourceTable
	assert_not_null(table)
	assert_eq(table.row_ids().size(), _s.data.actions_for_skill(SKILL).size())
	for column: int in ResourceTexts.COLUMNS.size():
		assert_not_null(table.find_child("Column%d" % column, true, false))
	for node_name: String in ["AutoButton", "FilterEdit", "StockOnly"]:
		assert_not_null(table.find_child(node_name, true, false), node_name)


func test_click_on_focus_button_sets_the_focus_and_auto_clears_it() -> void:
	var page: Node = await _open()
	var table: ResourceTable = page.find_child("ResourceTable", true, false) as ResourceTable
	var action_id: StringName = table.row_ids()[0]
	var button: Button = table.find_child("FocusButton_%s" % action_id, true, false) as Button
	assert_false(button.disabled)
	await _click(button, page)
	assert_eq(_s.disciplines.focus_of(SKILL), action_id)
	assert_true(table.find_child("ResourceRow_%s" % action_id, true, false).find_child("FocusBadge", true, false).visible)
	await _click(table.find_child("AutoButton", true, false) as Button, page)
	assert_eq(_s.disciplines.focus_of(SKILL), &"")


func test_filter_hides_rows_without_stock() -> void:
	var page: Node = await _open()
	var table: ResourceTable = page.find_child("ResourceTable", true, false) as ResourceTable
	(table.find_child("StockOnly", true, false) as CheckBox).button_pressed = true
	await wait_process_frames(2)
	for action_id: StringName in table.row_ids():
		assert_false((table.find_child("ResourceRow_%s" % action_id, true, false) as Control).visible)
	(table.find_child("StockOnly", true, false) as CheckBox).button_pressed = false
	await wait_process_frames(2)
	assert_true((table.find_child("ResourceRow_%s" % table.row_ids()[0], true, false) as Control).visible)


func _open() -> Node:
	(_screen.find_child("PageHost", true, false) as PageHost).show_page(StringName("skill:%s" % SKILL))
	await wait_process_frames(4)
	for node: Node in _screen.find_children("*", "", true, false):
		if node is SkillPage:
			return node
	return null


func _click(control: Control, page: Node) -> void:
	(page.get_node("%Scroll") as ScrollContainer).ensure_control_visible(control)
	await wait_process_frames(2)
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
