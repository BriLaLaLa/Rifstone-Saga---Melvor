class_name RiftPage
extends Page
## Altar of the Rift page (docs/01_GDD.md §11, route `rift`): the sockets with their state (locked with the Riftbinding
## level that unlocks them, free, occupied by an infusion), "Incastona" (choice among the infusions of the bank), "Togli"
## with a confirmation (the infusion is destroyed) and the summary of the active bonuses.
##
## Every redraw reads the session (`rift`, `bank`, `skills`, `data`); the page keeps the session reference, its nodes and
## two presentation indices (which socket is choosing an infusion / asking the removal confirmation). Player actions
## are the commands `rift.socket` / `rift.clear_socket`; a refusal shows its reason in Italian and changes nothing.

var _session: GameSession = null
## Presentation state: the socket that is choosing an infusion and the one waiting for the removal confirmation (-1 = none).
var _picking: int = -1
var _removing: int = -1

@onready var _margin: MarginContainer = %Margin
@onready var _title_label: Label = %TitleLabel
@onready var _intro_label: Label = %IntroLabel
@onready var _message_label: Label = %MessageLabel
@onready var _sockets: VBoxContainer = %Sockets
@onready var _picker: PanelContainer = %Picker
@onready var _picker_box: VBoxContainer = %PickerBox
@onready var _summary_title: Label = %SummaryTitle
@onready var _summary_text: RichTextLabel = %SummaryText


func _ready() -> void:
	for side: String in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		_margin.add_theme_constant_override(side, UiStyle.ARMORY_MARGIN)
	_title_label.text = RiftTexts.TITLE_TEXT
	_intro_label.text = RiftTexts.INTRO_TEXT
	_summary_title.text = RiftTexts.SUMMARY_TITLE_TEXT


func bind(session: GameSession) -> void:
	unbind()
	_session = session
	_picking = -1
	_removing = -1
	_message_label.visible = false
	for sig: Signal in _signals(session.events):
		sig.connect(_redraw_from_event)
	_redraw()


func unbind() -> void:
	if _session != null and is_instance_valid(_session):
		for sig: Signal in _signals(_session.events):
			if sig.is_connected(_redraw_from_event):
				sig.disconnect(_redraw_from_event)
	_session = null


func _exit_tree() -> void:
	unbind()


func _signals(events: GameEvents) -> Array[Signal]:
	return [events.infusion_socketed, events.infusion_removed, events.bank_changed, events.level_up]


func _redraw_from_event(_a: Variant = null, _b: Variant = null, _c: Variant = null) -> void:
	_redraw()


func _redraw() -> void:
	if _session == null:
		return
	for child: Node in _sockets.get_children():
		_sockets.remove_child(child)
		child.queue_free()
	for i: int in _session.rift.socket_total():
		_sockets.add_child(_build_row(i))
	_redraw_picker()
	var lines: PackedStringArray = RiftTexts.summary_lines(_session)
	_summary_text.text = "\n".join(lines) if not lines.is_empty() else RiftTexts.SUMMARY_NONE_TEXT


func _build_row(index: int) -> PanelContainer:
	var rift: RiftAltar = _session.rift
	var panel := PanelContainer.new()
	panel.name = "Socket%d" % index
	panel.theme_type_variation = &"HudPanel"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	var title := Label.new()
	title.theme_type_variation = &"HeaderLabel"
	title.text = RiftTexts.SOCKET_TITLE_TEXT % (index + 1)
	title.custom_minimum_size.x = UiStyle.BANK_PANEL_WIDTH * 0.5
	row.add_child(title)
	var state := RichTextLabel.new()
	state.name = "StateText"
	state.bbcode_enabled = true
	state.fit_content = true
	state.scroll_active = false
	state.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(state)
	var item_id: StringName = rift.get_socket(index)
	if not rift.is_unlocked(index):
		state.text = "[color=#%s]%s[/color]" % [UiStyle.TEXT_DISABLED.to_html(false),
				RiftTexts.LOCKED_TEXT % [RiftTexts.skill_name(_session), RiftTexts.unlock_level(_session, index)]]
	elif item_id == &"":
		state.text = "[color=#%s]%s[/color]" % [UiStyle.TEXT_2.to_html(false), RiftTexts.EMPTY_TEXT]
		_add_button(row, "SocketButton", RiftTexts.SOCKET_BUTTON_TEXT, _on_socket_pressed.bind(index))
	else:
		state.text = _infusion_text(item_id)
		if _removing == index:
			var warn := Label.new()
			warn.text = RiftTexts.REMOVE_WARNING_TEXT
			warn.theme_type_variation = &"MutedLabel"
			row.add_child(warn)
			_add_button(row, "ConfirmRemoveButton", RiftTexts.CONFIRM_REMOVE_TEXT, _on_remove_confirmed.bind(index))
			_add_button(row, "CancelRemoveButton", RiftTexts.CANCEL_TEXT, _on_remove_cancelled)
		else:
			_add_button(row, "RemoveButton", RiftTexts.REMOVE_BUTTON_TEXT, _on_remove_pressed.bind(index))
	return panel


## Name of the infusion in its color plus the modifiers (stat registry labels).
func _infusion_text(item_id: StringName) -> String:
	var def: ItemDef = _session.data.item(item_id)
	var mods: String = RiftTexts.modifiers_inline(def.infusion_modifiers, _session.data)
	return "[b]%s[/b]\n[color=#%s]%s[/color]" % [ItemTooltipLines.escape(def.name), UiStyle.GOLD_LIGHT.to_html(false),
			ItemTooltipLines.escape(mods)]


func _add_button(row: HBoxContainer, node_name: String, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(UiStyle.BANK_PANEL_WIDTH * 0.5, UiStyle.MENU_BUTTON_HEIGHT)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(callback)
	row.add_child(button)
	return button


## The list of infusions the player owns, for the socket that is choosing.
func _redraw_picker() -> void:
	for child: Node in _picker_box.get_children():
		_picker_box.remove_child(child)
		child.queue_free()
	var open: bool = _picking >= 0 and _session.rift.is_unlocked(_picking) and _session.rift.get_socket(_picking) == &""
	if not open:
		_picking = -1
	_picker.visible = open
	if not open:
		return
	var title := Label.new()
	title.theme_type_variation = &"HeaderLabel"
	title.text = RiftTexts.PICK_TITLE_TEXT % (_picking + 1)
	_picker_box.add_child(title)
	var owned: Array[Dictionary] = RiftTexts.owned(_session, &"infusion")
	if owned.is_empty():
		var none := Label.new()
		none.name = "NoInfusions"
		none.text = RiftTexts.NO_INFUSIONS_TEXT
		none.theme_type_variation = &"MutedLabel"
		_picker_box.add_child(none)
	for entry: Dictionary in owned:
		var def: ItemDef = entry["item"] as ItemDef
		var text: String = "%s  x%s  -  %s" % [def.name, NumberFormat.format_int(int(entry["count"])),
				RiftTexts.modifiers_inline(def.infusion_modifiers, _session.data)]
		if def.infusion_unique:
			text += " (%s)" % RiftTexts.UNIQUE_TEXT
		var button := Button.new()
		button.name = "Pick_%s" % def.id
		button.text = text
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size.y = UiStyle.MENU_BUTTON_HEIGHT
		button.pressed.connect(_on_pick_pressed.bind(def.id))
		_picker_box.add_child(button)
	var cancel := Button.new()
	cancel.name = "CancelPickButton"
	cancel.text = RiftTexts.CANCEL_TEXT
	cancel.focus_mode = Control.FOCUS_NONE
	cancel.pressed.connect(_on_pick_cancelled)
	_picker_box.add_child(cancel)


# --- Commands ---------------------------------------------------------------------------------------------------

func _on_socket_pressed(index: int) -> void:
	_picking = index
	_removing = -1
	_message_label.visible = false
	_redraw()


func _on_pick_cancelled() -> void:
	_picking = -1
	_redraw()


func _on_pick_pressed(item_id: StringName) -> void:
	if _session == null or _picking < 0:
		return
	var result: CommandResult = _session.rift.socket(_picking, item_id)
	if result.ok:
		_notify(RiftTexts.SOCKETED_TEXT % _session.data.item(item_id).name, true)
		_picking = -1
	else:
		_notify(RiftTexts.refused(result.reason), false)
	_redraw()


func _on_remove_pressed(index: int) -> void:
	_removing = index
	_picking = -1
	_message_label.visible = false
	_redraw()


func _on_remove_cancelled() -> void:
	_removing = -1
	_redraw()


func _on_remove_confirmed(index: int) -> void:
	if _session == null:
		return
	var item_id: StringName = _session.rift.get_socket(index)
	_removing = -1
	var result: CommandResult = _session.rift.clear_socket(index)
	if result.ok:
		_notify(RiftTexts.REMOVED_TEXT % _session.data.item(item_id).name, true)
	else:
		_notify(RiftTexts.refused(result.reason), false)
	_redraw()


func _notify(text: String, good: bool) -> void:
	_message_label.text = text
	_message_label.add_theme_color_override("font_color", UiStyle.GOOD if good else UiStyle.BAD)
	_message_label.visible = true
