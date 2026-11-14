class_name DungeonChoiceView
extends VBoxContainer
## Dungeon page, between rooms (phases `await` and `event`, docs/05_INTERFACES.md §7.q): progress "Stanza i di N" (the boss is
## "?"), one button per exit (the text of the direction and, if any, the hint; 2-4) or the two buttons of an event, "Esci dal
## Covo" (the page asks the confirmation) and the dungeon bag. It never knows the hidden map: it reads only `state["choices"]`.
## In a paused run the buttons are hidden (the page shows "Riprendi"). It keeps no game state.

signal choice_requested(index: int)
signal leave_requested

const SEPARATION: int = 10
const CHOICE_HEIGHT: int = 64


func _init() -> void:
	add_theme_constant_override("separation", SEPARATION)


## `state` = `DungeonSystem.state()`; `def` = the dungeon of the data (event descriptions).
func setup(state: Dictionary, def: DungeonDef) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	var choices: Array = state.get("choices", []) as Array
	var is_event: bool = not choices.is_empty() and (choices[0] as Dictionary).get("direction", &"") == &""
	var room_kind: StringName = (state.get("room", {}) as Dictionary).get("kind", &"") as StringName
	add_child(_label("ProgressLabel", DungeonTexts.progress_text(state), &"MutedLabel"))
	var title: String = DungeonTexts.EVENT_TRAP_TITLE_TEXT if is_event and room_kind == &"trap" else (
			DungeonTexts.EVENT_REST_TITLE_TEXT if is_event else DungeonTexts.CHOICE_TITLE_TEXT)
	add_child(_label("TitleLabel", title, &"TitleLabel"))
	if not bool(state.get("paused", false)):
		for i: int in choices.size():
			add_child(_choice_button(i, choices[i] as Dictionary, is_event, def))
		var leave := Button.new()
		leave.name = "LeaveButton"
		leave.text = DungeonTexts.LEAVE_TEXT
		leave.focus_mode = Control.FOCUS_NONE
		leave.disabled = not bool(state.get("can_leave", false))
		leave.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		leave.pressed.connect(func() -> void: leave_requested.emit())
		add_child(leave)
	add_child(_label("BagTitle", DungeonTexts.BAG_TITLE_TEXT, &"HeaderLabel"))
	var bag_text: String = FractureTexts.bag_text(state.get("bag", {}) as Dictionary)
	add_child(_label("BagText", bag_text if bag_text != "" else DungeonTexts.BAG_EMPTY_TEXT, &"MutedLabel"))
	add_child(_label("RiskLabel", DungeonTexts.RISK_TEXT, &"MutedLabel"))


func _choice_button(index: int, choice: Dictionary, is_event: bool, def: DungeonDef) -> Control:
	var button := Button.new()
	button.name = "Choice_%d" % index
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size.y = CHOICE_HEIGHT
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.clip_text = false
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if is_event:
		var id: StringName = choice.get("id", &"") as StringName
		button.text = "%s: %s" % [DungeonTexts.event_text(id), DungeonTexts.event_description(id, def)]
	else:
		button.text = DungeonTexts.choice_text(choice)
	button.pressed.connect(func() -> void: choice_requested.emit(index))
	return button



func _label(node_name: String, text: String, variation: StringName) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if variation != &"":
		label.theme_type_variation = variation
	return label
