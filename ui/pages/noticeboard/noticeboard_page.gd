class_name NoticeboardPage
extends Page
## Noticeboard page (docs/01_GDD.md §31, docs/05_INTERFACES.md §7.s), route `noticeboard`: one `QuestRow` per slot of
## `quests.slot_count()`; with no slot only the message "Costruisci la Bacheca al Villaggio".
## Claim and abandon are the `quests.claim` / `quests.abandon` commands (one call per click); a refusal shows its
## reason in Italian. The page redraws from the quests getters on `quests_changed`, `quest_progress`,
## `village_upgraded`, `character_level_up` and `bank_changed`; it keeps only references to its own nodes.

const ROW_SCENE: PackedScene = preload("res://ui/pages/noticeboard/quest_row.tscn")
const QUESTS_FIELD: StringName = &"quests"
const MARGIN: int = 16
const SECTION_SEPARATION: int = 12
const ROWS_SEPARATION: int = 8

var _session: GameSession = null
## The session's Quests (5.28), used through its contract signatures only; a duck-typed reference so that the page
## can also be bound to a stub with the same signatures.
var _quests: Object = null
var _definitions: Object = null
var _rows: Array[QuestRow] = []

@onready var _margin: MarginContainer = %Margin
@onready var _content: VBoxContainer = %Content
@onready var _title_label: Label = %TitleLabel
@onready var _message_label: Label = %MessageLabel
@onready var _no_board_label: Label = %NoBoardLabel
@onready var _rows_box: VBoxContainer = %Rows


func _ready() -> void:
	for side: String in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		_margin.add_theme_constant_override(side, MARGIN)
	_content.add_theme_constant_override("separation", SECTION_SEPARATION)
	_rows_box.add_theme_constant_override("separation", ROWS_SEPARATION)
	_title_label.text = NoticeboardTexts.TITLE_TEXT
	_no_board_label.text = NoticeboardTexts.NO_BOARD_TEXT
	_message_label.add_theme_color_override("font_color", UiStyle.BAD)


## Draws the board of `session` (nothing if the session has no quests yet) and follows its changes.
func bind(session: GameSession) -> void:
	bind_with(session, session.get(QUESTS_FIELD), session.data)


## Same as `bind`, with the quests module and the source of the definitions (`quest(id)`, `skill(id)`, `item(id)`,
## `has_item(id)`) given: used by `bind` and by the smoke test with a stub of the same signatures.
func bind_with(session: GameSession, quests: Object, definitions: Object) -> void:
	unbind()
	_session = session
	_quests = quests
	_definitions = definitions
	if _quests == null:
		return
	var events: GameEvents = _session.events
	events.bank_changed.connect(_on_bank_changed)
	events.quests_changed.connect(_on_any_signal)
	events.quest_progress.connect(_on_any_signal)
	events.village_upgraded.connect(_on_any_signal)
	events.character_level_up.connect(_on_any_signal)
	_rebuild()


## Disconnects every event connected in `bind`.
func unbind() -> void:
	if _session != null and is_instance_valid(_session):
		var events: GameEvents = _session.events
		if events.bank_changed.is_connected(_on_bank_changed):
			events.bank_changed.disconnect(_on_bank_changed)
		for sig: Signal in [events.quests_changed, events.quest_progress, events.village_upgraded, events.character_level_up]:
			if sig.is_connected(_on_any_signal):
				sig.disconnect(_on_any_signal)
	_session = null
	_quests = null
	_definitions = null


func _exit_tree() -> void:
	unbind()


## Rebuilds the rows when the slot count changed, then rereads every row.
func _rebuild() -> void:
	if _quests == null:
		return
	var count: int = _quests.slot_count()
	if count != _rows.size():
		for child: Node in _rows_box.get_children():
			_rows_box.remove_child(child)
			child.queue_free()
		_rows.clear()
		for slot: int in count:
			var row: QuestRow = ROW_SCENE.instantiate()
			_rows_box.add_child(row)
			row.setup(slot)
			row.claim_requested.connect(_on_claim_requested)
			row.abandon_requested.connect(_on_abandon_requested)
			_rows.append(row)
	_no_board_label.visible = count == 0
	for row: QuestRow in _rows:
		row.refresh(_quests, _definitions)


func _on_claim_requested(slot: int) -> void:
	if _quests != null:
		_show_result(_quests.claim(slot))


func _on_abandon_requested(slot: int) -> void:
	if _quests != null:
		_show_result(_quests.abandon(slot))


func _show_result(result: CommandResult) -> void:
	_message_label.visible = not result.ok
	if not result.ok:
		_message_label.text = NoticeboardTexts.refused(result.reason)
	_rebuild()


func _on_any_signal(_a: Variant = null, _b: Variant = null, _c: Variant = null) -> void:
	_rebuild()


func _on_bank_changed(_item_id: StringName, _new_count: int, _delta: int) -> void:
	_rebuild()
