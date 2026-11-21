extends GutTest
## Smoke test of the tutorial overlay (M30-04): the states (step, navigation, valve, completed), the hidden overlay while
## offline, the hint card waiting for the end of the tutorial, the overlay freeing itself. No exact texts.

const SCENE: PackedScene = preload("res://ui/screens/main/main_screen.tscn")

var _s: GameSession = null
var _screen: MainScreen = null


func after_each() -> void:
	if is_instance_valid(_screen):
		_screen.free()
	if is_instance_valid(_s):
		_s.free()
	await wait_physics_frames(1)


func _open(from_step: Dictionary = {}) -> void:
	_s = TestFactory.session(78, TestFactory.real_data(), true, true)
	if not from_step.is_empty():
		_s.tutorial.from_save(from_step)
	_screen = SCENE.instantiate() as MainScreen
	_screen.session = _s
	add_child(_screen)
	await wait_process_frames(3)


func _overlay() -> TutorialOverlay:
	return _screen.find_child("TutorialOverlay", true, false) as TutorialOverlay


func test_first_step_shows_the_card_with_avanti_and_no_frame() -> void:
	await _open()
	assert_not_null(_overlay())
	assert_true(_overlay().visible)
	assert_true((_overlay().find_child("NextButton", true, false) as Button).visible)
	assert_false((_overlay().find_child("SkipButton", true, false) as Button).visible, "the valve is not there yet")
	assert_false((_overlay().find_child("Frame", true, false) as Control).visible, "no target on the first step")


func test_event_step_has_a_frame_and_the_valve_appears_after_stuck_time() -> void:
	await _open({"completed": false, "step": "combat_start", "visited": ["character"], "since_ms": 0})
	assert_false((_overlay().find_child("NextButton", true, false) as Button).visible, "an event step has no Avanti")
	assert_true((_overlay().find_child("Frame", true, false) as Control).visible, "the target is framed")
	assert_false((_overlay().find_child("SkipButton", true, false) as Button).visible)
	_s.play_time_ms += _s.data.tutorial_stuck_ms()
	await wait_process_frames(2)
	assert_true((_overlay().find_child("SkipButton", true, false) as Button).visible, "Continua comunque after stuck_ms")
	var step: int = _s.tutorial.step_index()
	(_overlay().find_child("SkipButton", true, false) as Button).pressed.emit()
	assert_gt(_s.tutorial.step_index(), step)


func test_navigation_state_shows_only_the_go_to_line() -> void:
	await _open()
	_s.tutorial.acknowledge()  # the next step lives on another page than the one shown
	await wait_process_frames(2)
	assert_true(_s.tutorial.needs_navigation())
	assert_true((_overlay().find_child("GoToLabel", true, false) as Control).visible)
	assert_false((_overlay().find_child("StepBox", true, false) as Control).visible)


func test_blocked_overlay_is_hidden_and_the_hint_card_waits_for_the_end() -> void:
	await _open({"completed": false, "step": "finish", "visited": [], "since_ms": 0})
	_overlay().is_blocked = func() -> bool: return true
	await wait_process_frames(2)
	assert_false(_overlay().visible, "hidden while offline")
	_overlay().is_blocked = func() -> bool: return false
	await wait_process_frames(2)
	assert_true(_overlay().visible)
	var hint: StringName = _s.data.hints()[0].id
	var card: HintCard = _screen.find_child("HintCard", true, false) as HintCard
	_s.events.hint_triggered.emit(hint)
	assert_eq(card.current_hint(), &"", "no hint card while the tutorial is on")
	_s.tutorial.acknowledge()  # the last step: the tutorial ends
	assert_true(_s.tutorial.is_completed())
	await wait_process_frames(2)
	assert_eq(card.current_hint(), hint, "the queued hint appears when the tutorial ends")
	assert_null(_screen.find_child("TutorialOverlay", true, false), "the overlay freed itself")


func test_session_end_frees_the_overlay_without_touching_the_session() -> void:
	await _open()
	var overlay: TutorialOverlay = _overlay()
	_s.events.session_ended.emit(0)
	await wait_process_frames(2)
	assert_false(is_instance_valid(overlay) and overlay.is_inside_tree())
