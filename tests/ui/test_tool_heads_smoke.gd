extends GutTest
## Smoke test of the "Teste" section of the tool panel (M35-D3, docs/05_INTERFACES_M35.md §7.ac) on the main screen with a real session:
## the four tool skills have a panel, the three head rows exist, a REAL click chooses a head (first choice free), a paid change needs a
## second press, a refusal reaches MessageLabel. No exact texts.

const SCENE: PackedScene = preload("res://ui/screens/main/main_screen.tscn")
const SKILL: StringName = &"quarrying"
const SLOT: StringName = &"tool_quarrying"

var _s: GameSession = null
var _screen: MainScreen = null


func before_each() -> void:
	_s = TestFactory.session(77, TestFactory.real_data())
	TestFactory.learn_discipline(_s, SKILL)
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


func test_every_tool_skill_has_a_panel_with_three_head_rows() -> void:
	assert_eq(GatherBody.TOOL_SKILLS.size(), 4)
	var page: Node = await _open(SKILL)
	for step: int in [3, 6, 9]:
		assert_not_null(page.find_child("HeadRow_%d" % step, true, false), "row %d" % step)


func test_click_chooses_a_head_free_then_a_paid_change_needs_two_presses() -> void:
	var uid: int = _s.armory.tool_uid(SLOT)
	(_s.armory._items[uid] as ItemInstance).upgrade = 3  # test-only: the refinements cost materials, not under test here
	var page: Node = await _open(SKILL)
	var first: Button = page.find_child("HeadButton_3_pick_vein", true, false) as Button
	assert_not_null(first)
	assert_false(first.disabled)
	await _click(first, page)
	assert_eq(_s.armory.tool_heads(uid)[0], &"pick_vein", "the first choice is free")
	_s.wallet.add_gold(1000000)
	var gold: int = _s.wallet.get_gold()
	var other: Button = page.find_child("HeadButton_3_pick_quarry", true, false) as Button
	await _click(other, page)
	assert_eq(_s.armory.tool_heads(uid)[0], &"pick_vein", "the first press only asks to confirm")
	assert_eq(_s.wallet.get_gold(), gold)
	other = page.find_child("HeadButton_3_pick_quarry", true, false) as Button
	await _click(other, page)
	assert_eq(_s.armory.tool_heads(uid)[0], &"pick_quarry")
	assert_lt(_s.wallet.get_gold(), gold)


func test_locked_step_is_disabled_and_a_refusal_shows_in_the_message_label() -> void:
	var page: Node = await _open(SKILL)
	var locked: Button = page.find_child("HeadButton_9_pick_vein", true, false) as Button
	assert_true(locked.disabled)
	page.call("_on_tool_head_chosen", _s.armory.tool_uid(SLOT), 9, &"pick_vein")
	assert_true((page.get_node("%MessageLabel") as Label).visible)


func _open(skill_id: StringName) -> Node:
	(_screen.find_child("PageHost", true, false) as PageHost).show_page(StringName("skill:%s" % skill_id))
	await wait_process_frames(4)
	for node: Node in _screen.find_children("*", "", true, false):
		if node is SkillPage:
			(node.find_child("GatherBody", true, false) as GatherBody).show_tab(GatherBody.TAB_TOOL)  # M36: the Attrezzo tab,
			(node.find_child("HeadsFold", true, false) as FoldableSection).set_collapsed(false)  # with Teste opened
			await wait_process_frames(2)
			return node
	return null


## A real left click (press and release) on the centre of `control`, scrolled into view first.
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
