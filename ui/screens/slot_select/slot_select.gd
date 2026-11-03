class_name SlotSelect
extends Control
## Slot choice for New game and Continue, with Delete (docs/01_GDD.md §1). Shown inside the main menu.
##
## Every redraw reads `Game.list_slots()`; every action is a Game command and a failed command shows its reason in
## Italian. Nothing here writes a file: only the commands new_game and delete_slot (after a confirmation) do.
## - New game: choose an empty slot, or a saved one after confirming the overwrite, then type the name and Start.
##   The name rule (1-24 characters after strip) is Game's: an invalid name comes back as invalid_name.
## - Continue: only a saved slot can be loaded; damaged and unsupported slots can only be deleted.
## - Delete: any non-empty slot, after a confirmation.
## `game_started` is emitted only after new_game/continue_game returned ok: the main menu then changes scene.
##
## Injection point: `game`, the coordinator to read and command; null means the `Game` autoload. Tests pass an
## instance of a subclass of game.gd that is never added to the tree (no slot files, no clock), as ToastManager does
## with `events`. Set it before calling `open`.

signal game_started
signal closed

const GameScript := preload("res://core/autoload/game.gd")
const ROW_SCENE: PackedScene = preload("res://ui/screens/slot_select/slot_row.tscn")
const MODE_NEW := SlotRow.MODE_NEW
const MODE_CONTINUE := SlotRow.MODE_CONTINUE
const TITLES: Dictionary[StringName, String] = {MODE_NEW: "Nuova partita", MODE_CONTINUE: "Continua"}
const NAME_TITLE := "Nuova partita  ·  Slot %d"
const OVERWRITE_TITLE := "Sovrascrivere lo slot?"
const OVERWRITE_TEXT := "Lo slot %d contiene la partita di %s. Iniziando una nuova partita la perderai."
const DELETE_TITLE := "Eliminare lo slot?"
const DELETE_TEXT := "Lo slot %d verrà svuotato. L'operazione non si può annullare."
const DELETED_TEXT := "Slot %d eliminato."

## Coordinator to read and command; null = the `Game` autoload.
var game: GameScript = null

var _mode: StringName = MODE_CONTINUE
var _name_slot: int = -1
var _asking: bool = false

@onready var _title_label: Label = %TitleLabel
@onready var _slot_list: VBoxContainer = %SlotList
@onready var _name_panel: VBoxContainer = %NamePanel
@onready var _name_edit: LineEdit = %NameEdit
@onready var _start_button: Button = %StartButton
@onready var _name_back_button: Button = %NameBackButton
@onready var _message_label: Label = %MessageLabel
@onready var _back_button: Button = %BackButton


func _ready() -> void:
	_start_button.pressed.connect(_on_start_button_pressed)
	_name_edit.text_submitted.connect(_on_name_edit_text_submitted)
	_name_back_button.pressed.connect(_on_name_back_button_pressed)
	_back_button.pressed.connect(_on_back_button_pressed)
	_name_panel.visible = false


## Shows the slot list for `mode` (&"new" or &"continue"), read fresh from the coordinator.
func open(mode: StringName) -> void:
	assert(TITLES.has(mode), "SlotSelect.open: unknown mode '%s'" % mode)
	_mode = mode if TITLES.has(mode) else MODE_CONTINUE
	visible = true
	_show_message("")
	_show_list()


func _coordinator() -> GameScript:
	return game if game != null else Game


func _show_list() -> void:
	_name_slot = -1
	_name_panel.visible = false
	_slot_list.visible = true
	_title_label.text = TITLES[_mode]
	_redraw_rows()


func _redraw_rows() -> void:
	for child: Control in _slot_list.get_children():
		child.hide()
		child.queue_free()
	for info: SlotInfo in _coordinator().list_slots():
		var row: SlotRow = ROW_SCENE.instantiate() as SlotRow
		_slot_list.add_child(row)
		row.setup(info, _mode)
		row.chosen.connect(_on_row_chosen)
		row.delete_requested.connect(_on_row_delete_requested)


func _show_name_step(slot: int) -> void:
	_name_slot = slot
	_slot_list.visible = false
	_name_panel.visible = true
	_title_label.text = NAME_TITLE % slot
	_name_edit.text = ""
	_name_edit.grab_focus.call_deferred()


func _show_message(text: String, is_error: bool = true) -> void:
	_message_label.add_theme_color_override("font_color", UiStyle.BAD if is_error else UiStyle.TEXT_2)
	_message_label.text = text
	_message_label.visible = not text.is_empty()


# The current state of one slot, read from the coordinator (never kept between redraws).
func _slot_info(slot: int) -> SlotInfo:
	for info: SlotInfo in _coordinator().list_slots():
		if info.slot == slot:
			return info
	return null


func _start_new_game() -> void:
	if _name_slot < 0:
		return
	var result: CommandResult = _coordinator().new_game(_name_slot, _name_edit.text)
	if not result.ok:
		_show_message(SlotTexts.reason_text(result.reason))
		return
	game_started.emit()


func _continue_game(slot: int) -> void:
	var result: CommandResult = _coordinator().continue_game(slot)
	if not result.ok:
		_show_message(SlotTexts.reason_text(result.reason))
		_redraw_rows()
		return
	game_started.emit()


func _confirm(title: String, text: String) -> bool:
	_asking = true
	var accepted: bool = await ConfirmDialog.ask(self, title, text)
	_asking = false
	return accepted


func _on_row_chosen(slot: int) -> void:
	if _asking:
		return
	_show_message("")
	var info: SlotInfo = _slot_info(slot)
	if info == null:
		return
	if _mode == MODE_CONTINUE:
		if info.state == SlotTexts.STATE_OK:
			_continue_game(slot)
		return
	if info.state == SlotTexts.STATE_OK:
		if not await _confirm(OVERWRITE_TITLE, OVERWRITE_TEXT % [slot, info.player_name]):
			return
	elif info.state != SlotTexts.STATE_EMPTY:
		return
	_show_name_step(slot)


func _on_row_delete_requested(slot: int) -> void:
	if _asking:
		return
	_show_message("")
	if not await _confirm(DELETE_TITLE, DELETE_TEXT % slot):
		return
	var result: CommandResult = _coordinator().delete_slot(slot)
	_redraw_rows()
	if result.ok:
		_show_message(DELETED_TEXT % slot, false)
	else:
		_show_message(SlotTexts.reason_text(result.reason))


func _on_start_button_pressed() -> void:
	_start_new_game()


func _on_name_edit_text_submitted(_text: String) -> void:
	_start_new_game()


func _on_name_back_button_pressed() -> void:
	_show_message("")
	_show_list()


func _on_back_button_pressed() -> void:
	visible = false
	closed.emit()
