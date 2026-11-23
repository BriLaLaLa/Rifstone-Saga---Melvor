class_name AltarColumn
extends PanelContainer
## One column of the Altar page: a numbered step header and a scrolling body. View only, no game state.

const ROW_HEIGHT: int = 68
const ROW_PADDING: int = 8
const ROW_ICON_SIZE := Vector2(40, 40)

var _step_label: Label = null
var _hint_label: Label = null
var _body: VBoxContainer = null


func setup(step: int, title: String, hint: String) -> void:
	theme_type_variation = &"HudPanel"
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UiStyle.ARMORY_SECTION_SEPARATION)
	add_child(box)
	_step_label = Label.new()
	_step_label.name = "StepLabel"
	_step_label.theme_type_variation = &"HeaderLabel"
	_step_label.text = "%d · %s" % [step, title]
	box.add_child(_step_label)
	_hint_label = Label.new()
	_hint_label.name = "HintLabel"
	_hint_label.theme_type_variation = &"MutedLabel"
	_hint_label.text = hint
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_hint_label)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	_body = VBoxContainer.new()
	_body.name = "Body"
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", UiStyle.ARMORY_GRID_SEPARATION)
	scroll.add_child(_body)


func _clear_body() -> void:
	for child: Node in _body.get_children():
		_body.remove_child(child)
		child.queue_free()


func _muted(text: String, node_name: String = "") -> Label:
	var label := Label.new()
	if node_name != "":
		label.name = node_name
	label.text = text
	label.theme_type_variation = &"MutedLabel"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(label)
	return label


static func color_text(color: Color, text: String) -> String:
	return "[color=#%s]%s[/color]" % [color.to_html(false), text]


## A selectable list row: a toggle button with a title, an optional icon and a rich text line under it.
func _row(node_name: String, title: String, detail_bbcode: String, selected: bool, icon: Texture2D = null) -> Button:
	var button := Button.new()
	button.name = node_name
	button.theme_type_variation = &"ListButton"
	button.toggle_mode = true
	button.button_pressed = selected
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size.y = ROW_HEIGHT
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, ROW_PADDING)
	button.add_child(margin)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)
	if icon != null:
		var tex := TextureRect.new()
		tex.texture = icon
		tex.custom_minimum_size = ROW_ICON_SIZE
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(tex)
	var text := VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", 0)
	row.add_child(text)
	var head := Label.new()
	head.text = title
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.clip_text = true
	text.add_child(head)
	var detail := RichTextLabel.new()
	detail.name = "StateText"
	detail.bbcode_enabled = true
	detail.fit_content = true
	detail.scroll_active = false
	detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail.text = detail_bbcode
	text.add_child(detail)
	_body.add_child(button)
	return button
