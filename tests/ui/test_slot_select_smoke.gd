extends GutTest
## Smoke test of the slot screen (M1-13) with a fake coordinator: rows from list_slots, the three slot states,
## Continue only on saved slots, overwrite and delete confirmations, name errors, game_started only on ok.
##
## FakeGame extends game.gd but is never added to the tree: no clock, no SaveService, no slot file.

const SCENE_PATH := "res://ui/screens/slot_select/slot_select.tscn"


class FakeGame:
	extends "res://core/autoload/game.gd"
	var slots: Array[SlotInfo] = []
	var calls: Array[String] = []
	var new_game_result: CommandResult = CommandResult.success()
	var continue_result: CommandResult = CommandResult.success()
	var delete_result: CommandResult = CommandResult.success()
	var hold_continue: bool = false
	signal released

	func list_slots() -> Array[SlotInfo]:
		return slots.duplicate()

	func new_game(slot: int, player_name: String) -> CommandResult:
		calls.append("new_game:%d:%s" % [slot, player_name])
		return new_game_result

	# Like the real continue_game (a coroutine since M9-01): with hold_continue it waits for `released`, as the offline
	# simulation does between blocks; otherwise it finishes at once.
	func continue_game(slot: int) -> CommandResult:
		calls.append("continue_game:%d" % slot)
		if hold_continue:
			await released
		return continue_result

	func delete_slot(slot: int) -> CommandResult:
		calls.append("delete_slot:%d" % slot)
		if delete_result.ok:
			for i: int in slots.size():
				if slots[i].slot == slot:
					slots[i] = FakeGame.info(slot, &"empty")
		return delete_result

	static func info(slot: int, state: StringName, player_name: String = "") -> SlotInfo:
		var result := SlotInfo.new()
		result.slot = slot
		result.state = state
		if state == &"ok":
			result.player_name = player_name
			result.saved_at_unix_ms = 1_700_000_000_000
			result.play_time_ms = 3_900_000
			result.total_level = 1250
		return result


var _game: FakeGame
var _select: SlotSelect
var _started: int = 0
var _closed: int = 0


func before_each() -> void:
	_started = 0
	_closed = 0
	_game = FakeGame.new()
	_game.slots = [
		FakeGame.info(1, &"ok", "Aria"),
		FakeGame.info(2, &"empty"),
		FakeGame.info(3, &"corrupted"),
		FakeGame.info(4, &"unsupported"),
	] as Array[SlotInfo]
	_select = (load(SCENE_PATH) as PackedScene).instantiate() as SlotSelect
	_select.game = _game
	add_child_autofree(_select)
	_select.game_started.connect(func() -> void: _started += 1)
	_select.closed.connect(func() -> void: _closed += 1)


func after_each() -> void:
	_game.free()


func test_continue_lists_every_slot_with_its_state() -> void:
	_select.open(SlotSelect.MODE_CONTINUE)
	assert_eq(_rows().size(), 4)
	assert_string_contains(_title(1), "Aria")
	assert_string_contains(_details(1), "Livello totale 1.250")
	assert_string_contains(_details(1), "1 h 05 min")
	assert_eq(_details(2), "Slot vuoto")
	assert_string_contains(_details(3), "danneggiato")
	assert_string_contains(_details(4), "Versione non supportata")


func test_continue_only_saved_slot_is_clickable() -> void:
	_select.open(SlotSelect.MODE_CONTINUE)
	assert_false(_choose(1).disabled)
	assert_true(_choose(2).disabled, "empty")
	assert_true(_choose(3).disabled, "corrupted")
	assert_true(_choose(4).disabled, "unsupported")


func test_choosing_empty_slot_does_not_call_continue_game() -> void:
	_select.open(SlotSelect.MODE_CONTINUE)
	for slot: int in [2, 3, 4]:
		_row(slot).chosen.emit(slot)
	assert_eq(_game.calls, [] as Array[String])
	assert_eq(_started, 0)


func test_continue_ok_emits_game_started() -> void:
	_select.open(SlotSelect.MODE_CONTINUE)
	_choose(1).pressed.emit()
	assert_eq(_game.calls, ["continue_game:1"] as Array[String])
	assert_eq(_started, 1)


func test_second_click_during_the_offline_wait_is_ignored() -> void:
	_game.hold_continue = true
	_select.open(SlotSelect.MODE_CONTINUE)
	_choose(1).pressed.emit()
	_choose(1).pressed.emit()
	assert_eq(_game.calls, ["continue_game:1"] as Array[String], "one call while the first is running")
	assert_eq(_started, 0, "not started before continue_game returns")
	_game.released.emit()
	assert_eq(_started, 1)
	_choose(1).pressed.emit()
	assert_eq(_game.calls.size(), 2, "clicks work again afterwards")
	_game.released.emit()


func test_continue_error_shows_reason_and_does_not_start() -> void:
	for reason: StringName in [Reasons.CORRUPTED, Reasons.VERSION_UNSUPPORTED, Reasons.IO_ERROR, Reasons.SLOT_ACTIVE]:
		_game.continue_result = CommandResult.fail(reason)
		_select.open(SlotSelect.MODE_CONTINUE)
		_choose(1).pressed.emit()
		assert_eq(_message(), SlotTexts.reason_text(reason), String(reason))
	assert_eq(_started, 0)


func test_new_game_on_empty_slot_asks_name_then_starts() -> void:
	_select.open(SlotSelect.MODE_NEW)
	_choose(2).pressed.emit()
	assert_null(_dialog(), "no confirmation for an empty slot")
	assert_true((_select.get_node("%NamePanel") as Control).visible)
	(_select.get_node("%NameEdit") as LineEdit).text = "Brannoc"
	(_select.get_node("%StartButton") as Button).pressed.emit()
	assert_eq(_game.calls, ["new_game:2:Brannoc"] as Array[String])
	assert_eq(_started, 1)


func test_new_game_damaged_and_unsupported_not_choosable() -> void:
	_select.open(SlotSelect.MODE_NEW)
	assert_false(_choose(1).disabled)
	assert_false(_choose(2).disabled)
	assert_true(_choose(3).disabled)
	assert_true(_choose(4).disabled)
	assert_true(_delete(3).visible, "damaged slot can be deleted")
	assert_false(_delete(2).visible, "empty slot has no delete")


func test_invalid_name_shows_message() -> void:
	_game.new_game_result = CommandResult.fail(Reasons.INVALID_NAME)
	_select.open(SlotSelect.MODE_NEW)
	_choose(2).pressed.emit()
	(_select.get_node("%StartButton") as Button).pressed.emit()
	assert_eq(_message(), SlotTexts.reason_text(Reasons.INVALID_NAME))
	assert_string_contains(_message(), "da 1 a 24 caratteri")
	assert_string_contains(_message(), "da %d a %d caratteri" % [
		int(DataRegistry.data.balance_value("player_name.min_length")),
		int(DataRegistry.data.balance_value("player_name.max_length"))], "limits read from balance.json")
	assert_true((_select.get_node("%NamePanel") as Control).visible, "still on the name step")
	assert_eq(_started, 0)


func test_overwrite_needs_confirmation() -> void:
	_select.open(SlotSelect.MODE_NEW)
	_choose(1).pressed.emit()
	var dialog: ConfirmDialog = _dialog()
	assert_not_null(dialog, "overwrite asks first")
	assert_string_contains(dialog.dialog_text, "Aria")
	assert_false((_select.get_node("%NamePanel") as Control).visible)
	dialog.canceled.emit()
	await wait_process_frames(1)
	assert_false((_select.get_node("%NamePanel") as Control).visible, "cancel keeps the list")
	_choose(1).pressed.emit()
	_dialog().confirmed.emit()
	await wait_process_frames(1)
	assert_true((_select.get_node("%NamePanel") as Control).visible, "confirm goes to the name")
	assert_eq(_game.calls, [] as Array[String], "nothing commanded before the name")


func test_delete_asks_and_redraws() -> void:
	_select.open(SlotSelect.MODE_CONTINUE)
	_delete(1).pressed.emit()
	_dialog().canceled.emit()
	await wait_process_frames(1)
	assert_eq(_game.calls, [] as Array[String], "cancel deletes nothing")
	_delete(1).pressed.emit()
	_dialog().confirmed.emit()
	await wait_process_frames(1)
	assert_eq(_game.calls, ["delete_slot:1"] as Array[String])
	assert_eq(_details(1), "Slot vuoto")
	assert_true(_choose(1).disabled)


func test_delete_error_shows_reason() -> void:
	_game.delete_result = CommandResult.fail(Reasons.SLOT_ACTIVE)
	_select.open(SlotSelect.MODE_CONTINUE)
	_delete(1).pressed.emit()
	_dialog().confirmed.emit()
	await wait_process_frames(1)
	assert_eq(_message(), SlotTexts.reason_text(Reasons.SLOT_ACTIVE))


func test_back_emits_closed() -> void:
	_select.open(SlotSelect.MODE_NEW)
	(_select.get_node("%BackButton") as Button).pressed.emit()
	assert_eq(_closed, 1)
	assert_false(_select.visible)


func _rows() -> Array[SlotRow]:
	var rows: Array[SlotRow] = []
	for child: Node in _select.get_node("%SlotList").get_children():
		if not child.is_queued_for_deletion():
			rows.append(child as SlotRow)
	return rows


# Rows follow list_slots order: the fake lists slots 1..4.
func _row(slot: int) -> SlotRow:
	return _rows()[slot - 1]


func _choose(slot: int) -> Button:
	return _row(slot).get_node("%ChooseButton") as Button


func _delete(slot: int) -> Button:
	return _row(slot).get_node("%DeleteButton") as Button


func _title(slot: int) -> String:
	return (_row(slot).get_node("%TitleLabel") as Label).text


func _details(slot: int) -> String:
	return (_row(slot).get_node("%DetailsLabel") as Label).text


func _message() -> String:
	return (_select.get_node("%MessageLabel") as Label).text


func _dialog() -> ConfirmDialog:
	for child: Node in _select.get_children():
		if child is ConfirmDialog and not child.is_queued_for_deletion():
			return child as ConfirmDialog
	return null
