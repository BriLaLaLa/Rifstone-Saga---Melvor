extends GutTest
## NoticeboardPage (M20-03) bound to the QuestsStub (same signatures as `Quests`, 5.28): two occupied rows and one
## empty, Riscuoti disabled unless `can_claim` is ok, one `claim` / `abandon` per click, only the message when
## `slot_count() == 0`, everything disconnected by unbind. No exact texts checked.

const SCENE: PackedScene = preload("res://ui/pages/noticeboard/noticeboard_page.tscn")

var _session: GameSession
var _stub: QuestsStub
var _page: NoticeboardPage


func before_each() -> void:
	_session = TestFactory.session()
	_stub = QuestsStub.new()
	_page = SCENE.instantiate()
	add_child(_page)
	_page.bind_with(_session, _stub, _stub)


func after_each() -> void:
	if is_instance_valid(_page):
		_page.free()
	if is_instance_valid(_session):
		_session.free()
	await wait_physics_frames(1)


func test_two_occupied_rows_and_one_empty() -> void:
	assert_eq(_rows().size(), 3)
	assert_true(_row(0).find_child("FilledBox", true, false).visible)
	assert_true(_row(1).find_child("FilledBox", true, false).visible)
	assert_false(_row(2).find_child("FilledBox", true, false).visible)
	assert_true(_row(2).find_child("EmptyLabel", true, false).visible)
	assert_false(_page.find_child("NoBoardLabel", true, false).visible)


func test_claim_follows_can_claim_and_commands_are_called_once_per_click() -> void:
	assert_false(_claim(0).disabled)
	assert_true(_claim(1).disabled)
	_stub.forced_reason = &"bank_full"
	_page._rebuild()
	assert_true(_claim(0).disabled)
	assert_true((_row(0).find_child("ReasonLabel", true, false) as Label).visible)
	_stub.forced_reason = &""
	_page._rebuild()
	_claim(0).pressed.emit()
	assert_eq(_stub.claim_calls, 1)
	_row(1).find_child("AbandonButton", true, false).pressed.emit()
	assert_eq(_stub.abandon_calls, 1)
	assert_false(_row(1).find_child("FilledBox", true, false).visible)


func test_no_slots_shows_only_the_message() -> void:
	_stub.slots = 0
	_page._rebuild()
	assert_eq(_rows().size(), 0)
	assert_true(_page.find_child("NoBoardLabel", true, false).visible)


func test_unbind_disconnects_events() -> void:
	_page.unbind()
	assert_false(_session.events.bank_changed.is_connected(_page._on_bank_changed))


func _rows() -> Array[Node]:
	return _page.find_child("Rows", true, false).get_children()


func _row(slot: int) -> Node:
	return _page.find_child("Row_%d" % slot, true, false)


func _claim(slot: int) -> Button:
	return _row(slot).find_child("ClaimButton", true, false) as Button
