class_name SubTabBar
extends HBoxContainer
## Row of toggle buttons that picks one view of a page (docs/05_INTERFACES.md §7.u): Engraver and Smith sub-tabs. Only a
## view: it keeps the id of the picked tab and nothing else, and the choice is not saved. The page reads `tab_selected`
## and shows the matching section.

signal tab_selected(id: StringName)

const SEPARATION: int = 6
const BUTTON_NAME: String = "Tab_%s"

var _group: ButtonGroup = ButtonGroup.new()
var _buttons: Dictionary[StringName, Button] = {}
var _current: StringName = &""


## Builds one button per `{"id": StringName, "label": String}` and selects the first, without emitting.
func setup(tabs: Array[Dictionary]) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_buttons.clear()
	_current = &""
	add_theme_constant_override("separation", SEPARATION)
	for tab: Dictionary in tabs:
		var id: StringName = tab["id"]
		var button: Button = Button.new()
		button.name = BUTTON_NAME % id
		button.text = str(tab["label"])
		button.toggle_mode = true
		button.button_group = _group
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_on_pressed.bind(id))
		add_child(button)
		_buttons[id] = button
	if not tabs.is_empty():
		_current = tabs[0]["id"]
		_buttons[_current].set_pressed_no_signal(true)


## Picks `id` and emits `tab_selected` (unknown ids are ignored).
func select(id: StringName) -> void:
	if not _buttons.has(id):
		return
	_buttons[id].set_pressed_no_signal(true)
	_on_pressed(id)


## The id of the picked tab ("" without tabs).
func current() -> StringName:
	return _current


## The ids in order (tests).
func ids() -> Array[StringName]:
	var result: Array[StringName] = []
	result.assign(_buttons.keys())
	return result


func label_of(id: StringName) -> String:
	return _buttons[id].text if _buttons.has(id) else ""


func _on_pressed(id: StringName) -> void:
	_current = id
	tab_selected.emit(id)
