class_name LoadoutCard
extends PanelContainer
## Card of one trait or ability of the class in the loadout panel (docs/01_GDD.md §19): name, description and the level
## that unlocks it, plus a line with the slot it occupies. A click is reported with `chosen(id)`; the panel sends the
## command (`Loadout.set_trait` / `set_ability`). The card draws what the panel gives it and keeps no game state.

signal chosen(id: StringName)

const MIN_HEIGHT: int = 84
const PADDING: float = 8.0
const DIM_ALPHA: float = 0.55

var _id: StringName = &""
var _clickable: bool = true
var _name: Label = null
var _description: Label = null
var _unlock: Label = null
var _state: Label = null


func _init() -> void:
	custom_minimum_size = Vector2(0, MIN_HEIGHT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 2)
	add_child(box)
	_name = _label(box, &"")
	_name.add_theme_color_override("font_color", UiStyle.GOLD_LIGHT)
	_description = _label(box, &"MutedLabel")
	_unlock = _label(box, &"MutedLabel")
	_state = _label(box, &"")
	_state.add_theme_color_override("font_color", UiStyle.GOOD)


## Draws the card. `slot_text` is "" when the entry is not chosen; `warning` is an extra line (e.g. setup mismatch).
func show_entry(id: StringName, title: String, description: String, unlock_text: String, slot_text: String,
		warning: String, dimmed: bool, clickable: bool) -> void:
	_id = id
	_clickable = clickable
	name = "Card_%s" % id
	_name.text = title
	_description.text = description
	_unlock.text = unlock_text
	_state.text = slot_text if warning == "" else (slot_text + "\n" + warning).strip_edges()
	_state.visible = _state.text != ""
	modulate.a = DIM_ALPHA if dimmed else 1.0
	var picked: bool = slot_text != ""
	add_theme_stylebox_override("panel", UiStyle.flat(UiStyle.BG_FIELD, UiStyle.GOLD if picked else UiStyle.GOLD_FAINT,
			2 if picked else 1, PADDING))
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if clickable else Control.CURSOR_ARROW


func entry_id() -> StringName:
	return _id


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT and _clickable:
		chosen.emit(_id)
		accept_event()


static func _label(parent: Control, variation: StringName) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if variation != &"":
		label.theme_type_variation = variation
	parent.add_child(label)
	return label


# --- For tests ---

func title_text() -> String:
	return _name.text


func description_text() -> String:
	return _description.text


func unlock_text() -> String:
	return _unlock.text


func state_text() -> String:
	return _state.text if _state.visible else ""


func is_clickable() -> bool:
	return _clickable
