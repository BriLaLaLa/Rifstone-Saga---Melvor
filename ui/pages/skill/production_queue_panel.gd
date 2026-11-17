class_name ProductionQueuePanel
extends PanelContainer
## Production queue of the artisan and Engraver pages (docs/01_GDD_M24.md §35.4, 05_INTERFACES_M24.md §7.o/§5.32): one
## row per job of `actions.jobs()` (`QueueRow_<i>`), the progress bar of the head read every frame from
## `actions.get_progress`, the estimate from `actions.estimate_ms` and the buttons CancelButton / UpButton / DownButton
## (commands `cancel` and `move`). "In attesa: Deposito pieno" while `current().waiting`. It redraws on
## `production_queue_changed`, `action_completed` and `bank_changed`. It keeps no game state: only the session reference.

## A refused command (the owner shows the reason).
signal refused(reason: StringName)

const ROW_PREFIX: String = "QueueRow_"
const BAR_HEIGHT: float = 10.0
const ROWS_HEIGHT: float = 100.0
const HEADER_SEPARATION: int = 16
const LINE_SEPARATION: int = 8

var _session: GameSession = null
var _title: Label = null
var _total: Label = null
var _waiting: Label = null
var _empty: Label = null
var _rows: VBoxContainer = null
var _bar: ProgressBar = null
var _connections: Array[Array] = []


func _ready() -> void:
	theme_type_variation = &"HudPanel"
	var box := VBoxContainer.new()
	box.name = "QueueBox"
	add_child(box)
	var header := HBoxContainer.new()
	header.name = "QueueHeader"
	header.add_theme_constant_override("separation", HEADER_SEPARATION)
	box.add_child(header)
	_title = Label.new()
	_title.name = "QueueTitle"
	_title.theme_type_variation = &"HeaderLabel"
	header.add_child(_title)
	_total = Label.new()
	_total.name = "QueueTotal"
	_total.theme_type_variation = &"MutedLabel"
	_total.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_total.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(_total)
	_waiting = Label.new()
	_waiting.name = "QueueWaiting"
	_waiting.text = QueueTexts.WAITING_TEXT
	_waiting.add_theme_color_override("font_color", UiStyle.BAD)
	_waiting.visible = false
	box.add_child(_waiting)
	_empty = Label.new()
	_empty.name = "QueueEmpty"
	_empty.text = QueueTexts.EMPTY_TEXT
	_empty.theme_type_variation = &"MutedLabel"
	box.add_child(_empty)
	var scroll := ScrollContainer.new()  # a strip at the bottom of the page: a long queue scrolls instead of growing
	scroll.name = "QueueScroll"
	scroll.custom_minimum_size = Vector2(0, ROWS_HEIGHT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.name = "QueueRows"
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rows)
	set_process(false)


## Follows the queue of `session`; `unbind` disconnects everything.
func bind(session: GameSession) -> void:
	unbind()
	_session = session
	var events: GameEvents = session.events
	for pair: Array in [[events.production_queue_changed, _on_queue_changed], [events.action_completed, _on_action_completed],
			[events.bank_changed, _on_bank_changed]]:
		var source: Signal = pair[0]
		var handler: Callable = pair[1]
		source.connect(handler)
		_connections.append([source, handler])
	refresh()
	set_process(true)


func unbind() -> void:
	set_process(false)
	for pair: Array in _connections:
		var source: Signal = pair[0]
		var handler: Callable = pair[1]
		if source.is_connected(handler):
			source.disconnect(handler)
	_connections.clear()
	_session = null


func _exit_tree() -> void:
	unbind()


## Rebuilds the rows from `actions.jobs()`.
func refresh() -> void:
	if _session == null or _rows == null:
		return
	var actions: ActionRunner = _session.actions
	var jobs: Array[Dictionary] = actions.jobs()
	_title.text = QueueTexts.TITLE_TEXT + "  " + QueueTexts.COUNT_TEXT % [jobs.size(), actions.capacity()]
	_total.text = QueueTexts.TOTAL_TEXT % QueueTexts.duration(actions.estimate_ms()) if not jobs.is_empty() else ""
	_empty.visible = jobs.is_empty()
	(_rows.get_parent() as Control).visible = not jobs.is_empty()
	_refresh_waiting()
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	_bar = null
	for index: int in jobs.size():
		_add_row(index, jobs[index], jobs.size())


func _process(_delta: float) -> void:
	if _bar != null and _session != null:
		_bar.value = _session.actions.get_progress()


func _refresh_waiting() -> void:
	_waiting.visible = _session.actions.is_running() and bool(_session.actions.current().get("waiting", false))


func _add_row(index: int, job: Dictionary, count: int) -> void:
	var row := VBoxContainer.new()
	row.name = ROW_PREFIX + str(index)
	_rows.add_child(row)
	var line := HBoxContainer.new()
	line.name = "Line"
	line.add_theme_constant_override("separation", LINE_SEPARATION)
	row.add_child(line)
	var name_label := Label.new()
	name_label.name = "JobLabel"
	name_label.text = _job_text(job)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	line.add_child(name_label)
	var estimate := Label.new()
	estimate.name = "JobEstimate"
	estimate.theme_type_variation = &"MutedLabel"
	estimate.text = QueueTexts.duration(_session.actions.estimate_ms(index))
	line.add_child(estimate)
	var up: Button = _button(line, "UpButton", QueueTexts.UP_TEXT)
	up.disabled = index <= 1  # the head (0) does not move and nothing goes to 0
	up.pressed.connect(_on_move_pressed.bind(index, index - 1))
	var down: Button = _button(line, "DownButton", QueueTexts.DOWN_TEXT)
	down.disabled = index == 0 or index >= count - 1
	down.pressed.connect(_on_move_pressed.bind(index, index + 1))
	var cancel: Button = _button(line, "CancelButton", QueueTexts.CANCEL_TEXT)
	cancel.pressed.connect(_on_cancel_pressed.bind(index))
	if index == 0:
		_bar = ProgressBar.new()
		_bar.name = "QueueProgress"
		_bar.max_value = 1.0
		_bar.step = 0.0
		_bar.show_percentage = false
		_bar.custom_minimum_size = Vector2(0, BAR_HEIGHT)
		_bar.value = _session.actions.get_progress()
		row.add_child(_bar)


func _button(parent: Node, node_name: String, text: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	parent.add_child(button)
	return button


## "Betulla  x10", "Betulla  (ripeti)" or "Progetto: ..." for a blueprint job; names come from the data.
func _job_text(job: Dictionary) -> String:
	var action_id: StringName = StringName(job.get("action", &""))
	if action_id == BlueprintCraft.ACTION:
		var item: ItemDef = _session.data.item(StringName(job.get("blueprint", &"")))
		return QueueTexts.ROW_BLUEPRINT_TEXT % (item.name if item != null else "")
	var action: ActionDef = _session.data.action(action_id)
	var title: String = action.name if action != null else String(action_id)
	if bool(job.get("repeat", false)):
		return QueueTexts.ROW_REPEAT_TEXT % title
	return QueueTexts.ROW_TEXT % [title, NumberFormat.format_int(int(job.get("remaining", 0)))]


func _on_cancel_pressed(index: int) -> void:
	if _session != null:
		_report(_session.actions.cancel(index))


func _on_move_pressed(index: int, new_index: int) -> void:
	if _session != null:
		_report(_session.actions.move(index, new_index))


func _report(result: CommandResult) -> void:
	if not result.ok:
		refused.emit(result.reason)
	refresh()


func _on_queue_changed() -> void:
	refresh()


func _on_action_completed(_lane: StringName, _skill_id: StringName, _action_id: StringName, _outputs: Dictionary) -> void:
	refresh()


func _on_bank_changed(_item_id: StringName, _new_count: int, _delta: int) -> void:
	if _session != null:
		_refresh_waiting()
