extends GutTest
## M31-03: the touch-ups of the tutorial UI on the real main screen (real data, 1280x720) with real mouse clicks: Ok on the paused
## step unfreezes the engine and moves the step on; the combat page says "In pausa" only while frozen; Riscuoti on a quest and on
## the final bonus sends the Mail message and puts the dot out; the dot of the Primi passi box lights when a measure becomes true
## (a character level, no other event) and the box stays at 20/20 until the bonus is claimed. No exact texts.

const SCENE: PackedScene = preload("res://ui/screens/main/main_screen.tscn")
const VISITED: Array = ["character", "equipment", "combat"]

var _s: GameSession = null
var _screen: MainScreen = null


func after_each() -> void:
	if is_instance_valid(_screen):
		_screen.free()
	if is_instance_valid(_s):
		_s.free()
	await wait_physics_frames(1)


func _open(with_tutorial: bool, from_step: Dictionary = {}) -> void:
	_s = TestFactory.session(77, TestFactory.real_data(), true, with_tutorial)
	if not from_step.is_empty():
		_s.tutorial.from_save(from_step)
	_screen = SCENE.instantiate() as MainScreen
	_screen.session = _s
	add_child(_screen)
	for layer: Node in get_tree().root.find_children("GutLayer", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	await wait_process_frames(3)


func _all_claimed(final_claimed: bool) -> Dictionary:
	var ids: Array = []
	for def: StarterQuestDef in _s.tutorial.starter.quests():
		ids.append(String(def.id))
	return {"claimed": ids, "progress": {}, "final_claimed": final_claimed}


func _starter_page() -> StarterPage:
	(_screen.find_child("PageHost", true, false) as PageHost).show_page(&"starter")
	await wait_process_frames(3)
	return _screen.find_child("Page", true, false) as StarterPage


func _dot() -> Control:
	return _screen.find_child("StarterWidget", true, false).find_child("Dot", true, false) as Control


func test_ok_on_the_paused_step_unfreezes_the_engine_and_advances_the_step() -> void:
	await _open(true, {"completed": false, "step": "combat_food", "visited": VISITED, "since_ms": 0})
	assert_eq(_s.tutorial.current_step().id, &"combat_food")
	assert_true(_s.combat.is_frozen(), "the step pauses the combat")
	var next: Button = _screen.find_child("NextButton", true, false) as Button
	assert_true(next.is_visible_in_tree(), "Ok is offered")
	assert_ne(next.text, TutorialTexts.NEXT_TEXT, "the label comes from the step, not the default")
	var state: Label = _screen.find_child("StateLabel", true, false) as Label
	assert_true(state.text.begins_with("In pausa"), "the combat page says it is paused")
	await _click(next)
	assert_false(_s.combat.is_frozen(), "Ok unfreezes the engine")
	assert_ne(_s.tutorial.current_step().id, &"combat_food", "the step moved on")
	await wait_process_frames(2)
	assert_false(state.text.begins_with("In pausa"), "no pause label once unfrozen")


func test_the_kills_step_shows_the_progress_from_the_data() -> void:
	await _open(true, {"completed": false, "step": "combat_kills", "visited": VISITED, "since_ms": 0})
	var progress: Label = _screen.find_child("ProgressLabel", true, false) as Label
	assert_true(progress.is_visible_in_tree())
	assert_eq(progress.text, _s.tutorial.step_progress_text() % [_s.tutorial.step_progress(), _s.tutorial.step_target_count()])


func test_riscuoti_on_a_quest_with_a_true_measure_sends_the_message_and_puts_the_dot_out() -> void:
	await _open(false)
	TestFactory.set_character_level(_s, 3)
	await wait_process_frames(2)
	assert_true(_dot().visible, "a true measure lights the dot")
	var page: StarterPage = await _starter_page()
	var starter: StarterQuests = _s.tutorial.starter
	var button: Button = page.find_child("Row_%s" % starter.claimable()[0].id, true, false).find_child("ClaimButton", true, false) as Button
	var mail_before: int = _s.mail.count()
	while not starter.claimable().is_empty():  # one real click on the first, the others with the command
		if starter.claimable().size() == 1 or _s.mail.count() > mail_before:
			assert_true(starter.claim(starter.claimable()[0].id).ok)
		else:
			await _click(button)
	assert_gt(_s.mail.count(), mail_before, "the reward went by Mail")
	assert_false(_dot().visible, "nothing left to claim: the dot is out")


func test_the_dot_lights_on_a_measure_without_any_other_event_and_pulses() -> void:
	await _open(false)
	var data: Dictionary = _all_claimed(false)
	(data["claimed"] as Array).erase("level_3")  # only the level quest is left, its measure is false
	_s.tutorial.starter.from_save(data)
	_s.events.starter_quests_changed.emit()
	assert_false(_dot().visible, "nothing to claim yet")
	TestFactory.set_character_level(_s, 3)  # a measure becomes true: no other event is emitted by the test
	await wait_process_frames(2)
	assert_true(_dot().visible)
	var first: float = _dot().modulate.a
	await wait_process_frames(20)
	assert_ne(_dot().modulate.a, first, "the dot pulses")
	assert_eq(_dot().custom_minimum_size.x, UiStyle.STARTER_DOT_SIDE)


func test_at_20_of_20_the_box_stays_with_the_dot_until_the_final_bonus_is_claimed() -> void:
	await _open(false)
	var widget: Control = _screen.find_child("StarterWidget", true, false) as Control
	_s.tutorial.starter.from_save(_all_claimed(false))
	_s.events.starter_quests_changed.emit()
	assert_true(widget.visible, "the box stays at 20/20")
	assert_true(_dot().visible, "the bonus is there to claim")
	var page: StarterPage = await _starter_page()
	var button: Button = page.find_child("FinalRow", true, false).find_child("ClaimButton", true, false) as Button
	assert_false(button.disabled)
	(page.find_child("Scroll", true, false) as ScrollContainer).ensure_control_visible(button)
	await wait_process_frames(2)
	var mail_before: int = _s.mail.count()
	await _click(button)
	assert_true(_s.tutorial.starter.is_final_claimed())
	assert_eq(_s.mail.count(), mail_before + 1, "the bonus went by Mail")
	assert_false(widget.visible, "the box goes away once the bonus is claimed")
	assert_false(_dot().is_visible_in_tree())


func test_the_final_row_is_disabled_before_20_of_20() -> void:
	await _open(false)
	var page: StarterPage = await _starter_page()
	var row: Node = page.find_child("FinalRow", true, false)
	assert_not_null(row)
	assert_true((row.find_child("ClaimButton", true, false) as Button).disabled)
	assert_true((row.find_child("HintLabel", true, false) as Label).visible)


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
