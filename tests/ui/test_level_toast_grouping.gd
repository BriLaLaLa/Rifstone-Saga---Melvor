extends GutTest
## B5: the level-ups of the same skill in the same frame become one toast ("Skill: livello 2 → 5"); a single level
## keeps the plain text; another skill, or another frame, makes its own toast.

const SKILL := &"test_skill"
const OTHER_SKILL := &"test_other"

var _events: GameEvents
var _manager: ToastManager


func before_each() -> void:
	_events = GameEvents.new()
	_manager = ToastManager.new()
	_manager.events = _events
	add_child(_manager)


func after_each() -> void:
	_manager.free()
	_events.free()


func test_a_jump_from_2_to_5_is_one_toast() -> void:
	for level: int in [3, 4, 5]:
		_events.level_up.emit(SKILL, level)
	assert_eq(_texts(), PackedStringArray(["test_skill: livello 2 → 5"]))


func test_a_single_level_keeps_the_plain_text() -> void:
	_events.level_up.emit(SKILL, 3)
	assert_eq(_texts(), PackedStringArray(["test_skill: livello 3"]))


func test_two_skills_in_the_same_frame_are_two_toasts() -> void:
	_events.level_up.emit(SKILL, 3)
	_events.level_up.emit(OTHER_SKILL, 7)
	_events.level_up.emit(SKILL, 4)
	assert_eq(_texts(), PackedStringArray(["test_skill: livello 2 → 4", "test_other: livello 7"]))


func test_another_frame_makes_a_new_toast() -> void:
	_events.level_up.emit(SKILL, 3)
	await wait_process_frames(1)
	_events.level_up.emit(SKILL, 4)
	assert_eq(_texts(), PackedStringArray(["test_skill: livello 3", "test_skill: livello 4"]))


func test_a_waiting_toast_is_merged_too() -> void:
	for i: int in UiStyle.TOAST_MAX_VISIBLE:
		_manager.push("riempi %d" % i, ToastManager.KIND_INFO)
	_events.level_up.emit(SKILL, 3)
	_events.level_up.emit(SKILL, 5)
	assert_eq(_texts().size(), UiStyle.TOAST_MAX_VISIBLE, "the level toast is waiting")
	assert_eq(_manager._pending_texts, PackedStringArray(["test_skill: livello 2 → 5"]))


func _texts() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for child: Node in _manager.get_node("Stack").get_children():
		var toast: Toast = child as Toast
		if toast != null and not toast.is_queued_for_deletion():
			out.append(toast.text())
	return out
