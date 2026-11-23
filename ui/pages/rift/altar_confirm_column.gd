class_name AltarConfirmColumn
extends AltarColumn
## Step 3 of the Altar page: what the chosen socket and rune will do. Cost, result (effect and the Altar bonuses before and
## after), the confirm button, and for an occupied socket the removal with its warning. A disabled button always shows why.
## The summary of the active bonuses stays at the bottom. Presentation only: the page runs the commands.

signal socket_pressed
signal remove_pressed
signal remove_confirmed
signal remove_cancelled


func _init() -> void:
	name = "ConfirmColumn"
	custom_minimum_size.x = 300
	size_flags_stretch_ratio = 4.0
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _ready() -> void:
	setup(3, RiftTexts.STEP3_TITLE_TEXT, RiftTexts.STEP3_HINT_TEXT)


## `socket` / `rune` are the choices of the page (-1 / &"" = none); `removing` = the removal asks for confirmation.
func refresh(session: GameSession, socket: int, rune: StringName, removing: bool) -> void:
	_clear_body()
	var rift: RiftAltar = session.rift
	if socket < 0 or socket >= rift.socket_total():
		_muted(RiftTexts.PICK_SOCKET_TEXT, "Prompt")
	elif rift.get_socket(socket) != &"":
		_occupied(session, socket, removing)
	elif not rift.is_unlocked(socket):
		_muted(RiftTexts.LOCKED_LONG_TEXT % [RiftTexts.skill_name(session), RiftTexts.unlock_level(session, socket),
				session.skills.get_level(RiftAltar.SKILL)], "Prompt")
	else:
		_free(session, socket, rune)
	_body.add_child(HSeparator.new())
	_summary_block(session, rune if socket >= 0 and rift.get_socket(socket) == &"" and rift.is_unlocked(socket) else &"")


func _title(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"HeaderLabel"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(label)


func _rich(bbcode: String, node_name: String = "") -> RichTextLabel:
	var rich := RichTextLabel.new()
	if node_name != "":
		rich.name = node_name
	rich.bbcode_enabled = true
	rich.fit_content = true
	rich.scroll_active = false
	rich.text = bbcode
	_body.add_child(rich)
	return rich


func _button(node_name: String, text: String, accent: bool = false) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size.y = UiStyle.MENU_BUTTON_HEIGHT
	if accent:
		button.theme_type_variation = &"AccentButton"
	_body.add_child(button)
	return button


func _free(session: GameSession, socket: int, rune: StringName) -> void:
	_title(RiftTexts.SOCKET_TITLE_TEXT % (socket + 1))
	if rune == &"" or not session.data.has_item(rune):
		var none: String = RiftTexts.NO_INFUSIONS_TEXT if RiftTexts.owned(session, &"infusion").is_empty() \
				else RiftTexts.PICK_RUNE_TEXT
		_muted(none, "Prompt")
		var off := _button("SocketButton", RiftTexts.SOCKET_BUTTON_TEXT, true)
		off.disabled = true
		return
	var def: ItemDef = session.data.item(rune)
	var have: int = session.bank.get_count(rune)
	_rich("[b]%s[/b]\n%s" % [ItemTooltipLines.escape(def.name),
			"\n".join(ItemTooltipLines.modifier_lines(def.infusion_modifiers, session.data))], "Preview")
	_rich(color_text(UiStyle.TEXT_2, RiftTexts.COST_TEXT % [def.name, NumberFormat.format_int(have),
			NumberFormat.format_int(maxi(have - 1, 0))]), "Cost")
	var reason: String = RiftTexts.rune_block_reason(session, rune)
	var button := _button("SocketButton", RiftTexts.SOCKET_BUTTON_TEXT, true)
	button.disabled = reason != ""
	if reason != "":
		_muted(reason, "BlockReason")
	button.pressed.connect(func() -> void: socket_pressed.emit())


func _occupied(session: GameSession, socket: int, removing: bool) -> void:
	var rift: RiftAltar = session.rift
	var def: ItemDef = session.data.item(rift.get_socket(socket))
	_title(RiftTexts.SOCKET_TITLE_TEXT % (socket + 1))
	_rich("[b]%s[/b]\n%s" % [ItemTooltipLines.escape(def.name),
			"\n".join(ItemTooltipLines.modifier_lines(def.infusion_modifiers, session.data))], "Preview")
	if not rift.is_unlocked(socket):
		_muted("%s\n%s" % [RiftTexts.OFF_TEXT, RiftTexts.LOCKED_LONG_TEXT % [RiftTexts.skill_name(session),
				RiftTexts.unlock_level(session, socket), session.skills.get_level(RiftAltar.SKILL)]], "Prompt")
	if removing:
		var warn := _muted(RiftTexts.REMOVE_WARNING_TEXT, "RemoveWarning")
		warn.add_theme_color_override("font_color", UiStyle.BAD)
		_button("ConfirmRemoveButton", RiftTexts.CONFIRM_REMOVE_TEXT).pressed.connect(func() -> void: remove_confirmed.emit())
		_button("CancelRemoveButton", RiftTexts.CANCEL_TEXT).pressed.connect(func() -> void: remove_cancelled.emit())
	else:
		_button("RemoveButton", RiftTexts.REMOVE_BUTTON_TEXT).pressed.connect(func() -> void: remove_pressed.emit())


## Bonuses of the Altar now and, when a rune is ready to be socketed, after socketing it.
func _summary_block(session: GameSession, preview_rune: StringName) -> void:
	_title(RiftTexts.SUMMARY_TITLE_TEXT)
	var lines: PackedStringArray = RiftTexts.summary_lines(session)
	_rich("\n".join(lines) if not lines.is_empty() else color_text(UiStyle.TEXT_2, RiftTexts.SUMMARY_NONE_TEXT), "SummaryText")
	if preview_rune == &"" or not session.data.has_item(preview_rune) or RiftTexts.rune_block_reason(session, preview_rune) != "":
		return
	var after: PackedStringArray = RiftTexts.summary_lines(session, session.data.item(preview_rune).infusion_modifiers)
	_title(RiftTexts.SUMMARY_AFTER_TEXT)
	_rich("\n".join(after), "AfterText")
