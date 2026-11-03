class_name MasteryPanel
extends GameWindow
## Mastery window of one skill (docs/01_GDD.md §6), opened from the SkillPage: pool bar with the warning near the cap,
## list of the actions with mastery (level and bar), pool spending on the chosen action (amount from a slider) and the
## node tree laid out by `pos`.
##
## Every redraw reads `session.mastery` and `session.data`; every player action is a MasterySystem command
## (`spend_pool_on_action`, `buy_node`) whose failure reason is shown in Italian (MasteryTexts.reason_text).
## Bound only while open: `bind` connects three signals of `session.events` (`mastery_pool_changed`,
## `mastery_node_purchased`, `mastery_xp_gained`); closing the window, `unbind` or leaving the tree disconnects them.
## It keeps no game state: only the session, the skill definition, its nodes and the chosen action (presentation).

const ROW_SCENE: PackedScene = preload("res://ui/pages/mastery/mastery_action_row.tscn")
const LOG_CATEGORY: String = "ui"

var _session: GameSession = null
var _skill: SkillDef = null
var _rows: Dictionary[StringName, MasteryActionRow] = {}
var _selected_id: StringName = &""

@onready var _pool_bar: ProgressBar = %PoolBar
@onready var _pool_label: Label = %PoolLabel
@onready var _pool_warning: Label = %PoolWarning
@onready var _message_label: Label = %MessageLabel
@onready var _action_list: VBoxContainer = %ActionList
@onready var _spend_target: Label = %SpendTarget
@onready var _spend_slider: HSlider = %SpendSlider
@onready var _spend_amount: Label = %SpendAmount
@onready var _spend_button: Button = %SpendButton
@onready var _node_tree: MasteryNodeTree = %NodeTree
@onready var _empty_label: Label = %EmptyLabel


func _ready() -> void:
	super._ready()
	_pool_warning.text = MasteryTexts.POOL_WARNING_TEXT
	_pool_warning.add_theme_color_override("font_color", UiStyle.BAD)
	_pool_warning.visible = false
	_message_label.add_theme_color_override("font_color", UiStyle.BAD)
	_message_label.visible = false
	UiStyle.style_bar(_pool_bar, UiStyle.PROGRESS)
	_spend_slider.min_value = 1
	_spend_slider.step = 1
	_spend_slider.value_changed.connect(_on_spend_slider_value_changed)
	_spend_button.text = MasteryTexts.SPEND_BUTTON_TEXT
	_spend_button.pressed.connect(_on_spend_button_pressed)
	_node_tree.buy_requested.connect(_on_node_tree_buy_requested)
	closed.connect(unbind)


## Reads the mastery of `skill_id` from `session`, builds rows and node cards and follows the mastery events.
func bind(session: GameSession, skill_id: StringName) -> void:
	unbind()
	var skill: SkillDef = session.data.skill(skill_id)
	if skill == null or not skill.has_mastery:
		Log.warn(LOG_CATEGORY, "mastery panel: skill '%s' has no mastery" % skill_id)
		_empty_label.text = MasteryTexts.NO_MASTERY_TEXT
		_empty_label.visible = true
		return
	_session = session
	_skill = skill
	_build_rows()
	var nodes: Array[MasteryNodeDef] = session.data.mastery_nodes(skill.id)
	_node_tree.setup(nodes, session.data)
	_empty_label.text = MasteryTexts.NO_NODES_TEXT
	_empty_label.visible = nodes.is_empty()
	var events: GameEvents = session.events
	events.mastery_pool_changed.connect(_on_events_mastery_pool_changed)
	events.mastery_node_purchased.connect(_on_events_mastery_node_purchased)
	events.mastery_xp_gained.connect(_on_events_mastery_xp_gained)
	_hide_message()
	_redraw()
	_spend_slider.value = _spend_slider.max_value


## Disconnects every event connected in `bind` and forgets the session.
func unbind() -> void:
	if _session != null and is_instance_valid(_session):
		var events: GameEvents = _session.events
		for connection: Array in [
			[events.mastery_pool_changed, _on_events_mastery_pool_changed],
			[events.mastery_node_purchased, _on_events_mastery_node_purchased],
			[events.mastery_xp_gained, _on_events_mastery_xp_gained],
		]:
			var event: Signal = connection[0]
			var handler: Callable = connection[1]
			if event.is_connected(handler):
				event.disconnect(handler)
	_session = null
	_skill = null
	if is_node_ready():
		_node_tree.clear()


func _exit_tree() -> void:
	unbind()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		close_window()
		get_viewport().set_input_as_handled()


func _build_rows() -> void:
	for child: Node in _action_list.get_children():
		_action_list.remove_child(child)
		child.queue_free()
	_rows.clear()
	var actions: Array[ActionDef] = _session.data.mastery_actions_for_skill(_skill.id)
	for action: ActionDef in actions:
		var row: MasteryActionRow = ROW_SCENE.instantiate() as MasteryActionRow
		_action_list.add_child(row)
		row.setup(action)
		row.select_requested.connect(_on_row_select_requested)
		_rows[action.id] = row
	if not _rows.has(_selected_id):
		_selected_id = actions[0].id if not actions.is_empty() else &""


func _redraw() -> void:
	_redraw_pool()
	for action_id: StringName in _rows:
		_rows[action_id].redraw(_session, action_id == _selected_id)
	_redraw_spend()
	_node_tree.redraw(_session)


func _redraw_pool() -> void:
	var pool: int = _session.mastery.get_pool(_skill.id)
	var cap: int = _session.mastery.get_pool_cap(_skill.id)
	_pool_bar.value = float(pool) / float(cap) if cap > 0 else 0.0
	_pool_label.text = MasteryTexts.POOL_TEXT % [NumberFormat.format_int(pool), NumberFormat.format_int(cap)]
	var warning: bool = cap > 0 and float(pool) >= float(cap) * MasteryTexts.POOL_WARNING_RATIO
	if warning != _pool_warning.visible:
		UiStyle.style_bar(_pool_bar, UiStyle.BAD if warning else UiStyle.PROGRESS)
	_pool_warning.visible = warning
	_spend_slider.max_value = maxi(pool, 1)
	_spend_slider.editable = pool > 1
	_redraw_amount()


func _redraw_spend() -> void:
	if _selected_id == &"":
		_spend_target.text = MasteryTexts.SPEND_NO_TARGET_TEXT
		_spend_button.disabled = true
		return
	_spend_target.text = MasteryTexts.SPEND_TARGET_TEXT % _session.data.action(_selected_id).name
	_spend_button.disabled = false


func _redraw_amount() -> void:
	_spend_amount.text = MasteryTexts.SPEND_AMOUNT_TEXT % NumberFormat.format_int(int(_spend_slider.value))


func _show_result(result: CommandResult) -> void:
	if result.ok:
		_hide_message()
		return
	_message_label.text = MasteryTexts.reason_text(result.reason)
	_message_label.visible = true


func _hide_message() -> void:
	_message_label.text = ""
	_message_label.visible = false


func _on_spend_slider_value_changed(_value: float) -> void:
	_redraw_amount()


func _on_spend_button_pressed() -> void:
	if _session == null or _selected_id == &"":
		return
	_show_result(_session.mastery.spend_pool_on_action(_selected_id, int(_spend_slider.value)))


func _on_node_tree_buy_requested(node_id: StringName) -> void:
	if _session == null:
		return
	_show_result(_session.mastery.buy_node(node_id))


func _on_row_select_requested(action_id: StringName) -> void:
	if _session == null:
		return
	_selected_id = action_id
	_hide_message()
	for id: StringName in _rows:
		_rows[id].redraw(_session, id == _selected_id)
	_redraw_spend()


func _on_events_mastery_pool_changed(skill_id: StringName, _pool_xp: int) -> void:
	if skill_id == _skill.id:
		_redraw_pool()
		_node_tree.redraw(_session)


func _on_events_mastery_node_purchased(skill_id: StringName, _node_id: StringName) -> void:
	if skill_id == _skill.id:
		_node_tree.redraw(_session)


func _on_events_mastery_xp_gained(skill_id: StringName, action_id: StringName, _amount: int) -> void:
	if skill_id == _skill.id and _rows.has(action_id):
		_rows[action_id].redraw(_session, action_id == _selected_id)
