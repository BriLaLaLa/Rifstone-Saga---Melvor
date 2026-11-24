class_name AuctionDetailSections
extends HBoxContainer
## The "Subito / Inserzione / Mercato" bar of the Auction House detail panel (M37-3). Presentation only: remembers the section
## chosen for each tab (Compra / Vendi) while the page lives; "Inserzione" exists only in Vendi.

signal section_changed(section: StringName)

var _mode: StringName = &"buy"
var _chosen: Dictionary[StringName, StringName] = {&"buy": &"now", &"sell": &"now"}
var _buttons: Dictionary[StringName, Button] = {}


func _ready() -> void:
	name = "SectionBar"
	add_theme_constant_override("separation", 6)
	var group: ButtonGroup = ButtonGroup.new()
	for id: StringName in AuctionDetailTexts.SECTION_IDS:
		var button: Button = Button.new()
		button.name = "SectionButton_%s" % id
		button.text = AuctionDetailTexts.SECTION_NAMES[id]
		button.toggle_mode = true
		button.button_group = group
		button.focus_mode = Control.FOCUS_NONE
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_pressed.bind(id))
		add_child(button)
		_buttons[id] = button
	_sync()


## Switches to the tab's remembered section (Compra has no "Inserzione").
func set_mode(mode: StringName) -> void:
	_mode = mode
	_sync()


func current() -> StringName:
	return _chosen[_mode]


func select(section: StringName) -> void:
	if section == &"list" and _mode != &"sell":
		return
	_chosen[_mode] = section
	_sync()
	section_changed.emit(section)


func _on_pressed(section: StringName) -> void:
	select(section)


func _sync() -> void:
	if _buttons.is_empty():
		return
	_buttons[&"list"].visible = _mode == &"sell"
	_buttons[_chosen[_mode]].set_pressed_no_signal(true)
