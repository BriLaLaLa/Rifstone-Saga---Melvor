class_name MailRow
extends Button
## One line of the Mail list: "NUOVO" marker, subject and sender. It draws what `setup` gives it and emits `row_clicked`.

signal row_clicked(message_id: int)

const NEW_COLOR: Color = UiStyle.OFFLINE_WARNING_COLOR

var message_id: int = 0


func setup(id: int, subject: String, sender: String, unread: bool, selected: bool) -> void:
	message_id = id
	toggle_mode = true
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(0, 52)
	set_pressed_no_signal(selected)
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 10
	row.offset_right = -10
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	add_child(row)
	var marker := Label.new()
	marker.name = "NewLabel"
	marker.text = MailTexts.NEW_TEXT
	marker.custom_minimum_size.x = 56
	marker.add_theme_color_override("font_color", NEW_COLOR)
	marker.modulate.a = 1.0 if unread else 0.0
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(marker)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(texts)
	var subject_label := Label.new()
	subject_label.text = subject
	subject_label.clip_text = true
	subject_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_child(subject_label)
	var sender_label := Label.new()
	sender_label.text = sender
	sender_label.theme_type_variation = &"MutedLabel"
	sender_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_child(sender_label)


func is_unread() -> bool:
	return (find_child("NewLabel", true, false) as Label).modulate.a > 0.5


func _pressed() -> void:
	row_clicked.emit(message_id)
