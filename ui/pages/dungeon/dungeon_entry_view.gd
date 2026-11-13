class_name DungeonEntryView
extends VBoxContainer
## Dungeon page, no run (docs/05_INTERFACES.md §7.q): one box per dungeon of the data (name, description, required and
## recommended level, Tickets owned, "Entra"), the pending loot with "Raccogli" and the outcome of the last run (text only).
## Reads the session and the dungeon system at every `redraw`; keeps no game state, only the nodes it builds.

signal enter_requested(dungeon_id: StringName)
signal collect_requested

const SEPARATION: int = 12
const BOX_SEPARATION: int = 6


func _init() -> void:
	add_theme_constant_override("separation", SEPARATION)


## `dungeon` = `session.dungeon` (or a stub of the same signatures); `last_result` = the text of the last outcome ("" = none).
func redraw(session: GameSession, dungeon: Object, last_result: String) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	if bool(dungeon.call("has_pending")):
		add_child(_pending_box(dungeon.call("pending") as Dictionary))
	if last_result != "":
		add_child(_label("LastResultLabel", DungeonTexts.LAST_RESULT_TEXT % last_result, &"MutedLabel"))
	var dungeons: Array[DungeonDef] = session.data.dungeons()
	if dungeons.is_empty():
		add_child(_label("NoDungeonLabel", DungeonTexts.NO_DUNGEON_TEXT, &"MutedLabel"))
	for def: DungeonDef in dungeons:
		add_child(_dungeon_box(session, dungeon, def))


func _dungeon_box(session: GameSession, dungeon: Object, def: DungeonDef) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "Dungeon_%s" % def.id
	panel.theme_type_variation = &"HudPanel"
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", BOX_SEPARATION)
	panel.add_child(box)
	box.add_child(_label("NameLabel", def.name, &"TitleLabel"))
	box.add_child(_label("DescriptionLabel", def.description, &""))
	var levels: PackedStringArray = PackedStringArray()
	if def.req_character > 0:
		levels.append(DungeonTexts.REQUIRES_TEXT % def.req_character)
	levels.append(DungeonTexts.RECOMMENDED_TEXT % def.recommended_level)
	box.add_child(_label("LevelLabel", ". ".join(levels), &"MutedLabel"))
	var ticket: ItemDef = session.data.item(def.ticket) if session.data.has_item(def.ticket) else null
	var ticket_name: String = ticket.name if ticket != null else String(def.ticket)
	box.add_child(_label("TicketsLabel", DungeonTexts.TICKETS_TEXT % [ticket_name,
			NumberFormat.format_int(int(dungeon.call("tickets", def.id)))], &""))
	var wins: int = int(dungeon.call("wins", def.id))
	if wins > 0:
		box.add_child(_label("WinsLabel", DungeonTexts.WINS_TEXT % NumberFormat.format_int(wins), &"MutedLabel"))
	var button := Button.new()
	button.name = "EnterButton"
	button.text = DungeonTexts.ENTER_TEXT
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size.y = UiStyle.MENU_BUTTON_HEIGHT
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.pressed.connect(func() -> void: enter_requested.emit(def.id))
	box.add_child(button)
	return panel


func _pending_box(pending: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "PendingBox"
	panel.theme_type_variation = &"HudPanel"
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", SEPARATION)
	panel.add_child(box)
	var text: Label = _label("PendingText", "%s: %s" % [DungeonTexts.PENDING_TITLE_TEXT, FractureTexts.bag_text(pending)], &"")
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(text)
	var button := Button.new()
	button.name = "CollectButton"
	button.text = DungeonTexts.COLLECT_TEXT
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func() -> void: collect_requested.emit())
	box.add_child(button)
	return panel


func _label(node_name: String, text: String, variation: StringName) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if variation != &"":
		label.theme_type_variation = variation
	return label
