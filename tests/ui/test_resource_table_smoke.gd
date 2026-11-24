extends GutTest
## Smoke test of the compact ResourceTable of a gathering page (M36-2, docs/05_INTERFACES_M36.md §7.ae) on the main screen with a real session:
## columns, one row per action, a REAL click on a row opens/closes its detail (one open at a time), "Vai" emits `zone_requested` with the
## right area, the removed widgets and texts are gone. No exact texts.

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


func test_table_has_the_columns_one_row_per_action_and_no_removed_widgets() -> void:
	var page: Node = await _open()
	var table: ResourceTable = page.find_child("ResourceTable", true, false) as ResourceTable
	assert_not_null(table)
	assert_eq(table.row_ids().size(), _s.data.actions_for_skill(SKILL).size())
	assert_eq(ResourceTexts.COLUMNS.size(), 5)
	for column: int in ResourceTexts.COLUMNS.size():
		assert_not_null(table.find_child("Column%d" % column, true, false))
	for node_name: String in ["FilterEdit", "StockOnly", "AutoButton", "FocusHint"]:
		assert_null(table.find_child(node_name, true, false), node_name)
	var first: StringName = table.row_ids()[0]
	assert_false((table.find_child("DetailBox_%s" % first, true, false) as Control).visible, "details start closed")


func test_click_opens_one_detail_at_a_time() -> void:
	var page: Node = await _open()
	var table: ResourceTable = page.find_child("ResourceTable", true, false) as ResourceTable
	var a: StringName = table.row_ids()[0]
	var b: StringName = table.row_ids()[1]
	await _click(table.find_child("Header_%s" % a, true, false) as Control, page)
	assert_true((table.find_child("DetailBox_%s" % a, true, false) as Control).visible)
	await _click(table.find_child("Header_%s" % b, true, false) as Control, page)
	assert_false((table.find_child("DetailBox_%s" % a, true, false) as Control).visible, "the first one closed")
	assert_true((table.find_child("DetailBox_%s" % b, true, false) as Control).visible)
	_s.bank.add(_s.data.actions_for_skill(SKILL)[1].outputs[0].item_id, 3)  # a redraw keeps the row open, no duplicate nodes
	await wait_process_frames(3)
	assert_eq(table.open_id(), b)
	var buttons: int = table.find_children("GoButton_%s_*" % b, "Button", true, false).size()
	assert_eq(buttons, _s.data.zones_of_action(b).size(), "one Vai per zone")
	await _click(table.find_child("Header_%s" % b, true, false) as Control, page)
	assert_eq(table.open_id(), &"")


func test_go_emits_the_zone_of_the_row() -> void:
	var page: Node = await _open()
	var table: ResourceTable = page.find_child("ResourceTable", true, false) as ResourceTable
	var id: StringName = table.row_ids()[0]
	var zones: Array[Dictionary] = _s.data.zones_of_action(id)
	assert_gt(zones.size(), 0)
	watch_signals(table)
	await _click(table.find_child("Header_%s" % id, true, false) as Control, page)
	var area: StringName = StringName(zones[0]["area"])
	var go: Button = table.find_child("GoButton_%s_%s" % [id, area], true, false) as Button
	assert_not_null(go)
	assert_false(go.disabled)
	go.pressed.emit()
	assert_signal_emitted_with_parameters(table, "zone_requested", [area])


func _open() -> Node:
	(_screen.find_child("PageHost", true, false) as PageHost).show_page(StringName("skill:%s" % SKILL))
	await wait_process_frames(4)
	for node: Node in _screen.find_children("*", "", true, false):
		if node is SkillPage:  # the page opens on Panoramica (M36-1): the table lives in the Risorse tab
			(node.find_child("GatherBody", true, false) as GatherBody).show_tab(GatherBody.TAB_RESOURCES)
			await wait_process_frames(2)
			return node
	return null


func _click(control: Control, page: Node) -> void:
	(page.get_node("%Scroll") as ScrollContainer).ensure_control_visible(control)
	await wait_process_frames(2)
	var at: Vector2 = control.get_global_rect().position + Vector2(20, control.size.y / 2.0)
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
