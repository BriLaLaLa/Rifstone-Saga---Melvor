class_name SlotRow
extends PanelContainer
## One save slot in the slot list: title, details and the buttons to choose or delete it.
##
## `setup` draws a SlotInfo just read from Game.list_slots(); the row keeps only the slot number it shows.
## In `continue` mode only a saved game can be chosen; in `new` mode an empty or saved slot (overwritten after a
## confirmation). Damaged and unsupported slots can only be deleted (docs/01_GDD.md §1). Empty slots have no Delete.

signal chosen(slot: int)
signal delete_requested(slot: int)

const MODE_NEW := &"new"
const MODE_CONTINUE := &"continue"
const CHOOSE_TEXTS: Dictionary[StringName, String] = {MODE_NEW: "Scegli", MODE_CONTINUE: "Carica"}
const NOT_LOADABLE_TIP := "Questo slot non si può caricare"
const NOT_CHOOSABLE_TIP := "Elimina lo slot prima di usarlo"

var _slot: int = 0

@onready var _title_label: Label = %TitleLabel
@onready var _details_label: Label = %DetailsLabel
@onready var _choose_button: Button = %ChooseButton
@onready var _delete_button: Button = %DeleteButton


func _ready() -> void:
	_choose_button.pressed.connect(_on_choose_button_pressed)
	_delete_button.pressed.connect(_on_delete_button_pressed)


## Call after the row is in the tree.
func setup(info: SlotInfo, mode: StringName) -> void:
	_slot = info.slot
	_title_label.text = SlotTexts.slot_title(info)
	_details_label.text = SlotTexts.slot_details(info)
	_details_label.tooltip_text = _details_label.text
	var is_ok: bool = info.state == SlotTexts.STATE_OK
	var choosable: bool = is_ok or (mode == MODE_NEW and info.state == SlotTexts.STATE_EMPTY)
	_choose_button.text = CHOOSE_TEXTS[mode] if CHOOSE_TEXTS.has(mode) else CHOOSE_TEXTS[MODE_CONTINUE]
	_choose_button.disabled = not choosable
	if not choosable:
		_choose_button.tooltip_text = NOT_LOADABLE_TIP if mode == MODE_CONTINUE else NOT_CHOOSABLE_TIP
	_delete_button.visible = info.state != SlotTexts.STATE_EMPTY
	if not is_ok and info.state != SlotTexts.STATE_EMPTY:
		_details_label.add_theme_color_override("font_color", UiStyle.BAD)


func _on_choose_button_pressed() -> void:
	chosen.emit(_slot)


func _on_delete_button_pressed() -> void:
	delete_requested.emit(_slot)
