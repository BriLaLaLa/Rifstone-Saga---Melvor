class_name DungeonPage
extends Page
## Dungeon page (docs/05_INTERFACES.md §7.q, docs/01_GDD.md §33.7, route `dungeon`): one page, three views chosen by
## `session.dungeon.state()`. ENTRY (no run): DungeonEntryView. CHOICE (phase await/event): DungeonChoiceView. FIGHT (phase
## fight/intro): DungeonFightView. A run in pause shows the view of its phase and only "Riprendi".
##
## Every redraw reads the dungeon system; every action is a command and a refusal shows its reason in Italian. The page never
## reads the hidden map: only `state()`. It keeps its nodes and one presentation text (the outcome of the last run).

## Outcome text of the last run of the session last drawn (presentation only, never saved).
static var _kept_session: GameSession = null
static var _kept_result: String = ""

var _session: GameSession = null
var _dungeon: Object = null
var _connections: Array[Array] = []
var _redraw_queued: bool = false
var _entry: DungeonEntryView = null
var _choice: DungeonChoiceView = null
var _fight: DungeonFightView = null

@onready var _margin: MarginContainer = %Margin
@onready var _header: HBoxContainer = %Header
@onready var _title_label: Label = %TitleLabel
@onready var _intro_label: Label = %IntroLabel
@onready var _message_label: Label = %MessageLabel
@onready var _resume_box: PanelContainer = %ResumeBox
@onready var _paused_label: Label = %PausedLabel
@onready var _resume_button: Button = %ResumeButton
@onready var _content: VBoxContainer = %Content


func _ready() -> void:
	for side: String in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		_margin.add_theme_constant_override(side, UiStyle.ARMORY_MARGIN)
	_title_label.text = DungeonTexts.TITLE_TEXT
	_intro_label.text = DungeonTexts.INTRO_TEXT
	_paused_label.text = DungeonTexts.PAUSED_TEXT
	_resume_button.text = DungeonTexts.RESUME_TEXT
	_resume_button.pressed.connect(_on_resume_pressed)
	_entry = DungeonEntryView.new()
	_entry.name = "EntryView"
	_entry.enter_requested.connect(_on_enter_requested)
	_entry.collect_requested.connect(_on_collect_requested)
	_choice = DungeonChoiceView.new()
	_choice.name = "ChoiceView"
	_choice.choice_requested.connect(_on_choice_requested)
	_choice.leave_requested.connect(_on_leave_requested)
	_fight = DungeonFightView.new()
	_fight.name = "FightView"
	_fight.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_fight.flee_requested.connect(_on_flee_requested)
	_fight.message_requested.connect(_show_error_text)
	for view: Control in [_entry, _choice, _fight]:
		view.visible = false
		_content.add_child(view)
	set_process(false)


func bind(session: GameSession) -> void:
	bind_with(session, session.get(&"dungeon") as Object)


## Same as `bind`, with the dungeon system given: used by `bind` and by the smoke test (a stub of the same signatures).
func bind_with(session: GameSession, dungeon: Object) -> void:
	unbind()
	_session = session
	_dungeon = dungeon
	if _dungeon == null:
		return
	if _kept_session != session:
		_kept_session = session
		_kept_result = ""
	HelpButton.attach(_header, session.data, &"dungeon", _title_label)
	var events: GameEvents = session.events
	var redraw: Callable = _request_redraw
	_connect(events.dungeon_opened, redraw.unbind(1))
	_connect(events.dungeon_room_entered, redraw.unbind(2))
	_connect(events.dungeon_choice_ready, redraw.unbind(2))
	_connect(events.dungeon_room_cleared, redraw.unbind(2))
	_connect(events.dungeon_stage_started, redraw.unbind(2))
	_connect(events.dungeon_stage_cleared, redraw.unbind(1))
	_connect(events.dungeon_paused_changed, redraw.unbind(1))
	_connect(events.dungeon_finished, _on_dungeon_finished)
	_connect(events.dungeon_bag_changed, redraw.unbind(3))
	_connect(events.dungeon_loot_lost, redraw.unbind(3))
	_connect(events.bank_changed, redraw.unbind(3))
	_message_label.visible = false
	_fight.bind(session)
	refresh()
	set_process(true)


func unbind() -> void:
	set_process(false)
	for pair: Array in _connections:
		var source: Signal = pair[0]
		var callable: Callable = pair[1]
		if source.is_connected(callable):
			source.disconnect(callable)
	_connections.clear()
	if _fight != null:
		_fight.unbind()
	_session = null
	_dungeon = null


func _exit_tree() -> void:
	unbind()


func _process(_delta: float) -> void:
	if _dungeon != null and _fight.visible and bool(_dungeon.call("is_active")):
		_fight.tick(_dungeon.call("state") as Dictionary)


func _connect(source: Signal, callable: Callable) -> void:
	source.connect(callable)
	_connections.append([source, callable])


## One redraw per frame at most (several signals arrive in the same instant).
func _request_redraw() -> void:
	if not _redraw_queued:
		_redraw_queued = true
		refresh.call_deferred()


## Chooses the view from `state()` and redraws it.
func refresh() -> void:
	_redraw_queued = false
	if _session == null or _dungeon == null:
		return
	var active: bool = bool(_dungeon.call("is_active"))
	var state: Dictionary = _dungeon.call("state") as Dictionary if active else {}
	var phase: StringName = state.get("phase", &"") as StringName
	var awaiting: bool = phase == &"await" or phase == &"event"
	var fighting: bool = active and not awaiting
	_entry.visible = not active
	_choice.visible = active and awaiting
	_fight.visible = fighting
	_intro_label.visible = not active
	_resume_box.visible = active and bool(state.get("paused", false))
	if not active:
		_entry.redraw(_session, _dungeon, _kept_result)
	elif awaiting:
		_choice.setup(state, _session.data.dungeon(state["dungeon"] as StringName))
	else:
		_fight.tick(state)


# --- Commands -------------------------------------------------------------------------------------------------

func _show_result(result: CommandResult, success_text: String = "") -> void:
	_message_label.visible = not result.ok or success_text != ""
	_message_label.add_theme_color_override("font_color", UiStyle.GOOD if result.ok else UiStyle.BAD)
	_message_label.text = success_text if result.ok else DungeonTexts.refusal(result.reason)
	refresh()


func _show_error_text(text: String) -> void:
	_message_label.visible = text != ""
	_message_label.add_theme_color_override("font_color", UiStyle.BAD)
	_message_label.text = text


func _on_enter_requested(dungeon_id: StringName) -> void:
	if _dungeon != null:
		_show_result(_dungeon.call("open", dungeon_id) as CommandResult)


func _on_collect_requested() -> void:
	if _dungeon != null:
		_show_result(_dungeon.call("collect") as CommandResult, DungeonTexts.COLLECTED_TEXT)


func _on_choice_requested(index: int) -> void:
	if _dungeon != null:
		_show_result(_dungeon.call("choose", index) as CommandResult)


func _on_resume_pressed() -> void:
	if _dungeon != null:
		_show_result(_dungeon.call("resume") as CommandResult)


func _on_leave_requested() -> void:
	var accepted: bool = await ConfirmDialog.ask(self, DungeonTexts.LEAVE_TITLE_TEXT, DungeonTexts.LEAVE_QUESTION_TEXT)
	if accepted and _dungeon != null:
		_show_result(_dungeon.call("leave") as CommandResult)


func _on_flee_requested() -> void:
	var accepted: bool = await ConfirmDialog.ask(self, DungeonTexts.FLEE_TITLE_TEXT, DungeonTexts.FLEE_QUESTION_TEXT)
	if accepted and _dungeon != null:
		_show_result(_dungeon.call("flee") as CommandResult)


func _on_dungeon_finished(outcome: StringName, _rooms: int, _pieces: int) -> void:
	_kept_result = DungeonTexts.outcome_text(outcome)
	_request_redraw()
