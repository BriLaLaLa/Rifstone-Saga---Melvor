class_name SalvageBox
extends VBoxContainer
## Salvage confirmation of the piece panel (docs/01_GDD.md §25): what the piece pays (`RefineTexts.salvage_lines`,
## F-88) and the buttons "Smantella" / "Annulla". Emits `salvage_confirmed`; the page sends `armory.salvage`.

signal salvage_confirmed
signal cancelled

const CONFIRM_TEXT: String = "Smantella"
const CANCEL_TEXT: String = "Annulla"
const SEPARATION: int = 4

var _title: Label = null
var _yields: Label = null
var _confirm: Button = null


func _ready() -> void:
	add_theme_constant_override("separation", SEPARATION)
	_title = Label.new()
	_title.theme_type_variation = &"HeaderLabel"
	_title.text = RefineTexts.SALVAGE_TITLE
	add_child(_title)
	_yields = Label.new()
	_yields.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_yields)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	_confirm = _button(row, CONFIRM_TEXT)
	_confirm.name = "ConfirmButton"
	_confirm.pressed.connect(func() -> void: salvage_confirmed.emit())
	var cancel: Button = _button(row, CANCEL_TEXT)
	cancel.name = "CancelButton"
	cancel.pressed.connect(func() -> void: cancelled.emit())
	visible = false


func show_for(session: GameSession, uid: int) -> void:
	var lines: PackedStringArray = RefineTexts.salvage_lines(session, uid)
	if lines.is_empty():
		_yields.text = RefineTexts.SALVAGE_NOTHING_TEXT
	else:
		_yields.text = RefineTexts.SALVAGE_YIELD_TEXT + "\n" + "\n".join(lines)


func _button(row: HBoxContainer, text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size.y = UiStyle.MENU_BUTTON_HEIGHT
	row.add_child(button)
	return button


## Text of the yields for tests.
func yields_text() -> String:
	return _yields.text


func confirm_button() -> Button:
	return _confirm
