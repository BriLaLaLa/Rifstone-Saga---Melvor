extends GutTest
## Smoke test of the main menu (M1-13): buttons, data check, slot screen in both modes, no file written by opening
## and closing the menu, scene change only after an ok command.
##
## The "no file" tests use the real Game autoload: SaveService points at PreRun.save_dir() (gut_pre_run.gd) and
## only list_slots and an invalid new_game (rejected before any write) are called. The others use a fake coordinator
## that is never added to the tree.

const SCENE_PATH := "res://ui/screens/main_menu/main_menu.tscn"
const PreRun := preload("res://tests/helpers/gut_pre_run.gd")
const MAIN_SCREEN_PATH := "res://ui/screens/main/main_screen.tscn"
const BUTTONS: Dictionary[String, String] = {
	"NewGameButton": "Nuova partita",
	"ContinueButton": "Continua",
	"SettingsButton": "Impostazioni",
	"ExitButton": "Esci",
}


class FakeGame:
	extends "res://core/autoload/game.gd"
	var slots: Array[SlotInfo] = []
	var calls: Array[String] = []

	func list_slots() -> Array[SlotInfo]:
		return slots.duplicate()

	func new_game(slot: int, player_name: String) -> CommandResult:
		calls.append("new_game:%d:%s" % [slot, player_name])
		return CommandResult.success()

	func continue_game(slot: int) -> CommandResult:
		calls.append("continue_game:%d" % slot)
		return CommandResult.success()

	func end_session(save: bool = true) -> void:
		calls.append("end_session:%s" % save)


var _test_dir: String = PreRun.save_dir()
var _menu: Control
var _fake: FakeGame = null
var _scene_requests: Array[String] = []
var _scene_result: int = OK


func before_each() -> void:
	_fake = null
	_scene_requests = []
	_scene_result = OK


func after_each() -> void:
	if _fake != null:
		_fake.free()


func test_main_scene_is_main_menu() -> void:
	assert_eq(str(ProjectSettings.get_setting("application/run/main_scene", "")), SCENE_PATH)


func test_has_the_four_buttons_with_italian_texts() -> void:
	_open_menu(null, null)
	assert_eq((_menu.get_node("%Buttons") as Node).get_child_count(), BUTTONS.size())
	for button_name: String in BUTTONS:
		assert_eq(_button(button_name).text, BUTTONS[button_name], button_name)
	assert_true(_button("SettingsButton").disabled, "settings arrive with M1-12")
	assert_gt(_button("ExitButton").pressed.get_connections().size(), 0, "Exit has a pressed handler")


func test_title_and_window_min_size() -> void:
	_open_menu(null, null)
	var title: Label = _menu.get_node("%TitleLabel") as Label
	assert_eq(title.text, "RiftStone Saga: Idle")
	assert_eq(title.theme_type_variation, &"TitleLabel")
	assert_eq(_menu.get_window().min_size, UiStyle.WINDOW_MIN_SIZE)


func test_opening_and_closing_menu_writes_no_file() -> void:
	var before: PackedStringArray = _files()
	_open_menu(null, null)
	assert_false(_button("NewGameButton").disabled, "valid data: New game offered")
	for button_name: String in ["NewGameButton", "ContinueButton"]:
		_button(button_name).pressed.emit()
		(_menu.get_node("%SlotSelect").get_node("%BackButton") as Button).pressed.emit()
	_menu.queue_free()
	await wait_process_frames(2)
	assert_eq(_files(), before)
	assert_null(Game.session)


func test_invalid_name_rejected_with_message_and_no_file() -> void:
	var before: PackedStringArray = _files()
	_open_menu(null, null)
	_button("NewGameButton").pressed.emit()
	var select: SlotSelect = _menu.get_node("%SlotSelect") as SlotSelect
	(select.get_node("%SlotList").get_child(0).get_node("%ChooseButton") as Button).pressed.emit()
	await wait_process_frames(1)
	var dialog: ConfirmDialog = _dialog(select)
	if dialog != null:
		dialog.confirmed.emit()
	(select.get_node("%NameEdit") as LineEdit).text = "   "
	(select.get_node("%StartButton") as Button).pressed.emit()
	assert_eq((select.get_node("%MessageLabel") as Label).text, SlotTexts.reason_text(Reasons.INVALID_NAME))
	assert_null(Game.session)
	assert_eq(_files(), before)


func test_invalid_data_disables_new_game_and_continue() -> void:
	var invalid := GameData.new()
	invalid.errors.append("test: invalid data")
	_fake = FakeGame.new()
	_fake.slots = [_info(1, &"ok")] as Array[SlotInfo]
	_open_menu(_fake, invalid)
	assert_true(_button("NewGameButton").disabled)
	assert_true(_button("ContinueButton").disabled)
	var message: Label = _menu.get_node("%MessageLabel") as Label
	assert_true(message.visible)
	assert_string_contains(message.text, "non sono validi")


func test_continue_disabled_without_saved_slot() -> void:
	_fake = FakeGame.new()
	_fake.slots = [_info(1, &"empty"), _info(2, &"corrupted"), _info(3, &"unsupported")] as Array[SlotInfo]
	_open_menu(_fake, null)
	assert_false(_button("NewGameButton").disabled)
	assert_true(_button("ContinueButton").disabled)


func test_continue_ok_changes_scene_to_main_screen() -> void:
	_fake = FakeGame.new()
	_fake.slots = [_info(1, &"ok")] as Array[SlotInfo]
	_open_menu(_fake, null)
	assert_false(_button("ContinueButton").disabled)
	_button("ContinueButton").pressed.emit()
	assert_true((_menu.get_node("%SlotSelect") as Control).visible)
	assert_eq(_scene_requests, [] as Array[String], "no scene change before the command")
	var select: SlotSelect = _menu.get_node("%SlotSelect") as SlotSelect
	(select.get_node("%SlotList").get_child(0).get_node("%ChooseButton") as Button).pressed.emit()
	assert_eq(_fake.calls, ["continue_game:1"] as Array[String])
	assert_eq(_scene_requests, [MAIN_SCREEN_PATH] as Array[String])


func test_failed_scene_change_closes_session_and_shows_error() -> void:
	_fake = FakeGame.new()
	_fake.slots = [_info(1, &"ok")] as Array[SlotInfo]
	_scene_result = ERR_CANT_OPEN
	_open_menu(_fake, null)
	_button("ContinueButton").pressed.emit()
	var select: SlotSelect = _menu.get_node("%SlotSelect") as SlotSelect
	(select.get_node("%SlotList").get_child(0).get_node("%ChooseButton") as Button).pressed.emit()
	assert_push_error("cannot open %s" % MAIN_SCREEN_PATH)
	assert_eq(_fake.calls, ["continue_game:1", "end_session:true"] as Array[String])
	assert_false(select.visible)
	assert_true((_menu.get_node("%MessageLabel") as Label).visible)


func _open_menu(game: FakeGame, data: GameData) -> void:
	_menu = (load(SCENE_PATH) as PackedScene).instantiate() as Control
	if game != null:
		_menu.set("game", game)
	if data != null:
		_menu.set("data", data)
	_menu.set("scene_changer", _change_scene)
	add_child_autofree(_menu)


func _change_scene(path: String) -> int:
	_scene_requests.append(path)
	return _scene_result


func _button(button_name: String) -> Button:
	return _menu.get_node("%" + button_name) as Button


func _info(slot: int, state: StringName) -> SlotInfo:
	var info := SlotInfo.new()
	info.slot = slot
	info.state = state
	info.player_name = "Aria" if state == &"ok" else ""
	return info


func _dialog(parent: Node) -> ConfirmDialog:
	for child: Node in parent.get_children():
		if child is ConfirmDialog:
			return child as ConfirmDialog
	return null


func _files() -> PackedStringArray:
	if not DirAccess.dir_exists_absolute(_test_dir):
		return PackedStringArray()
	var files: PackedStringArray = DirAccess.get_files_at(_test_dir)
	for sub_dir: String in DirAccess.get_directories_at(_test_dir):
		files.append(sub_dir + "/")
	return files
