class_name SocketBox
extends VBoxContainer
## Sockets of the piece panel (docs/01_GDD.md §26, F-89): the number of sockets, the stones set in them (the ones beyond
## the active sockets are shown grey), "Togli pietra" with a confirmation (the stone is destroyed) and "Incastona" with
## the choice among the stones of the bank. Everything is read from the session at every `show_for`; the box only emits
## `stone_requested` / `clear_requested`, the page sends `armory.socket_stone` / `armory.clear_socket`.
## It keeps presentation state only: the stone chosen in the list and the socket waiting for the removal confirmation.

signal stone_requested(stone_id: StringName)
signal clear_requested(index: int)

const SEPARATION: int = 4

var _selected_stone: StringName = &""
var _removing: int = -1
var _uid: int = 0


func _ready() -> void:
	add_theme_constant_override("separation", SEPARATION)


## Draws the sockets of the piece `uid` of `session`.
func show_for(session: GameSession, uid: int) -> void:
	if uid != _uid:
		_removing = -1
	_uid = uid
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	var inst: ItemInstance = session.armory.get_instance(uid)
	if inst == null:
		return
	var count: int = session.armory.socket_count(uid)
	var title: String = SocketTexts.SOCKETS_TITLE_TEXT % count
	if inst.sockets.size() > count:
		title += "  (%s)" % (SocketTexts.INACTIVE_TITLE_TEXT % (inst.sockets.size() - count))
	add_child(_label(title, &"HeaderLabel", "TitleLabel"))
	if count == 0 and inst.sockets.is_empty():
		add_child(_label(SocketTexts.NO_SOCKETS_TEXT, &"MutedLabel", "NoSockets"))
		return
	for i: int in maxi(count, inst.sockets.size()):
		add_child(_socket_row(session, inst, i, count))
	if inst.sockets.size() < count:
		_add_socket_controls(session)


func _socket_row(session: GameSession, inst: ItemInstance, index: int, count: int) -> Control:
	var row := HBoxContainer.new()
	row.name = "Socket%d" % index
	row.add_theme_constant_override("separation", 8)
	var text := Label.new()
	text.name = "StoneLabel"
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	if index >= inst.sockets.size():
		text.text = SocketTexts.FREE_SOCKET_TEXT
		text.theme_type_variation = &"MutedLabel"
		return row
	var def: ItemDef = session.data.item(inst.sockets[index])
	var mods: String = RiftTexts.modifiers_inline(def.stone_modifiers, session.data)
	text.text = "%s: %s" % [def.name, mods]
	if index >= count:
		text.text += " (%s)" % SocketTexts.INACTIVE_TEXT
		text.add_theme_color_override("font_color", UiStyle.TEXT_DISABLED)
	else:
		text.add_theme_color_override("font_color", UiStyle.GOLD_LIGHT)
	if _removing == index:
		_add_button(row, "ConfirmRemoveButton", SocketTexts.CONFIRM_REMOVE_TEXT, _on_remove_confirmed.bind(index))
		_add_button(row, "CancelRemoveButton", SocketTexts.CANCEL_TEXT, _on_remove_cancelled.bind(session))
	else:
		_add_button(row, "RemoveButton", SocketTexts.REMOVE_TEXT, _on_remove_pressed.bind(index, session))
	return row


func _add_socket_controls(session: GameSession) -> void:
	var owned: Array[Dictionary] = RiftTexts.owned(session, &"stone")
	if owned.is_empty():
		add_child(_label(SocketTexts.NO_STONES_TEXT, &"MutedLabel", "NoStones"))
		return
	var option := OptionButton.new()
	option.name = "StoneOption"
	option.focus_mode = Control.FOCUS_NONE
	var select: int = 0
	for i: int in owned.size():
		var def: ItemDef = owned[i]["item"] as ItemDef
		option.add_item(SocketTexts.STONE_OPTION_TEXT % [def.name, NumberFormat.format_int(int(owned[i]["count"])),
				RiftTexts.modifiers_inline(def.stone_modifiers, session.data)])
		option.set_item_metadata(i, def.id)
		if def.id == _selected_stone:
			select = i
	option.select(select)
	_selected_stone = option.get_item_metadata(select) as StringName
	option.item_selected.connect(func(i: int) -> void: _selected_stone = option.get_item_metadata(i) as StringName)
	add_child(option)
	var button: Button = _add_button(self, "SocketButton", SocketTexts.SOCKET_BUTTON_TEXT, _on_socket_pressed)
	button.size_flags_horizontal = Control.SIZE_FILL


func _on_socket_pressed() -> void:
	if _selected_stone != &"":
		stone_requested.emit(_selected_stone)


func _on_remove_pressed(index: int, session: GameSession) -> void:
	_removing = index
	show_for(session, _uid)


func _on_remove_cancelled(session: GameSession) -> void:
	_removing = -1
	show_for(session, _uid)


func _on_remove_confirmed(index: int) -> void:
	_removing = -1
	clear_requested.emit(index)


func _label(text: String, variation: StringName, node_name: String) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.theme_type_variation = variation
	return label


func _add_button(parent: Control, node_name: String, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size.y = UiStyle.MENU_BUTTON_HEIGHT
	button.pressed.connect(callback)
	parent.add_child(button)
	return button
