class_name HintCard
extends Control
## Modal card of the hints (docs/05_INTERFACES.md: `hint_triggered`, `HintsSystem.mark_seen`). Title and text come
## from `GameData.hint`; closing calls `HintsSystem.mark_seen`. Several hints queue up and are shown one at a time.
##
## While the game is offline (the offline overlay/summary is open) nothing is shown: the ids wait in the queue and
## appear on `session_started` or when `refresh()` is called (the offline summary can call it when it closes).
## The queue holds only ids waiting to be shown (presentation); whether a hint was seen lives in HintsSystem.
##
## Injection points (set them before `bind`): `is_blocked`: `() -> bool`, true while the card must stay hidden;
## the default is "Game.state is offline".

signal shown(hint_id: StringName)
signal closed(hint_id: StringName)

const TITLE_FALLBACK := "Suggerimento"
const CLOSE_TEXT := "Ho capito"
const MORE_TEXT := "Altri suggerimenti in attesa: %d"

## `() -> bool`; invalid means "Game.state == Game.STATE_OFFLINE".
var is_blocked: Callable = Callable()

var _session: GameSession = null
var _queue: Array[StringName] = []
var _current: StringName = &""
var _panel: PanelContainer
var _title: Label
var _body: Label
var _more: Label
var _button: Button


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var dim := ColorRect.new()
	dim.color = UiStyle.HINT_DIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_panel = PanelContainer.new()
	_panel.theme_type_variation = &"WindowPanel"
	_panel.custom_minimum_size = Vector2(UiStyle.HINT_CARD_WIDTH, 0)
	center.add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UiStyle.HINT_CARD_SEPARATION)
	_panel.add_child(box)
	_title = Label.new()
	_title.add_theme_color_override("font_color", UiStyle.GOLD)
	box.add_child(_title)
	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_body)
	_more = Label.new()
	_more.add_theme_color_override("font_color", UiStyle.TEXT_2)
	box.add_child(_more)
	_button = Button.new()
	_button.text = CLOSE_TEXT
	_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	_button.pressed.connect(close_current)
	box.add_child(_button)


func bind(session: GameSession) -> void:
	unbind()
	_session = session
	_session.events.hint_triggered.connect(_on_hint_triggered)
	_session.events.session_started.connect(_on_session_started)
	# Hints fired before the card existed (e.g. session_started_new) wait in HintsSystem.pending().
	for hint_id: StringName in _session.hints.pending():
		if not _queue.has(hint_id):
			_queue.append(hint_id)
	refresh()


func unbind() -> void:
	if _session != null and is_instance_valid(_session):
		if _session.events.hint_triggered.is_connected(_on_hint_triggered):
			_session.events.hint_triggered.disconnect(_on_hint_triggered)
		if _session.events.session_started.is_connected(_on_session_started):
			_session.events.session_started.disconnect(_on_session_started)
	_session = null
	_queue.clear()
	_current = &""
	visible = false


## Id on screen now, empty when the card is closed.
func current_hint() -> StringName:
	return _current


## Ids waiting behind the current one.
func queued() -> Array[StringName]:
	return _queue.duplicate()


## Marks the current hint as seen, closes it and shows the next one, if any.
func close_current() -> void:
	if _current == &"":
		return
	var done: StringName = _current
	_current = &""
	visible = false
	if _session != null:
		_session.hints.mark_seen(done)
	closed.emit(done)
	refresh()


## Shows the next queued hint if nothing is on screen and the game is not blocked (offline).
func refresh() -> void:
	if _session == null or _current != &"" or _queue.is_empty() or _blocked():
		return
	var hint_id: StringName = _queue.pop_front()
	var def: HintDef = _find_def(hint_id)
	if def == null:
		Log.warn("ui", "hint '%s' is not in the data: skipped" % hint_id)
		refresh()
		return
	_current = hint_id
	_title.text = def.title if not def.title.is_empty() else TITLE_FALLBACK
	_body.text = def.text
	_more.text = MORE_TEXT % _queue.size() if not _queue.is_empty() else ""
	_more.visible = not _queue.is_empty()
	visible = true
	shown.emit(hint_id)


func _find_def(hint_id: StringName) -> HintDef:
	for def: HintDef in _session.data.hints():
		if def.id == hint_id:
			return def
	return null


func _blocked() -> bool:
	if is_blocked.is_valid():
		return is_blocked.call() as bool
	return Game.state == Game.STATE_OFFLINE


func _on_hint_triggered(hint_id: StringName) -> void:
	if hint_id == _current or _queue.has(hint_id):
		return
	_queue.append(hint_id)
	if _current != &"":
		_more.text = MORE_TEXT % _queue.size()
		_more.visible = true
	refresh()


func _on_session_started(_slot: int, _is_new: bool) -> void:
	refresh()
