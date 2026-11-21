class_name StarterWidget
extends PanelContainer
## Box «Primi passi» at the bottom of the sidebar, outside the scrolling list (docs/01_GDD_M30.md §41.8): the next starter
## quest, "claimed/total", a bar and a gold dot when something can be claimed. A click on it asks for the `starter` page
## (`open_requested`). Hidden while the tutorial is active and when every quest is claimed. It reads everything from
## `session.tutorial.starter` and keeps only references to its own nodes.

signal open_requested

var _session: GameSession = null
var _name_label: Label
var _count_label: Label
var _bar: ProgressBar
var _dot: Panel


func _init() -> void:
	theme_type_variation = &"HudPanel"
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, UiStyle.STARTER_WIDGET_MARGIN)
	add_child(margin)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", UiStyle.STARTER_WIDGET_SEPARATION)
	margin.add_child(box)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(head)
	var title := _label(head, "TitleLabel", StarterTexts.TITLE_TEXT, &"HeaderLabel")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dot = Panel.new()
	_dot.name = "Dot"
	_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dot.custom_minimum_size = Vector2(UiStyle.STARTER_DOT_SIDE, UiStyle.STARTER_DOT_SIDE)
	_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var style := StyleBoxFlat.new()
	style.bg_color = UiStyle.GOLD_LIGHT
	style.set_corner_radius_all(int(UiStyle.STARTER_DOT_SIDE))
	_dot.add_theme_stylebox_override("panel", style)
	head.add_child(_dot)
	_count_label = _label(head, "CountLabel", "", &"MutedLabel")
	_name_label = _label(box, "NameLabel", "", &"")
	_name_label.clip_text = true
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_bar = ProgressBar.new()
	_bar.name = "Bar"
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.show_percentage = false
	_bar.step = 1.0
	_bar.custom_minimum_size.y = UiStyle.STARTER_WIDGET_BAR_HEIGHT
	box.add_child(_bar)
	gui_input.connect(_on_gui_input)


func bind(session: GameSession) -> void:
	unbind()
	_session = session
	_session.events.starter_quests_changed.connect(refresh)
	_session.events.tutorial_completed.connect(refresh)
	refresh()


func unbind() -> void:
	if _session != null and is_instance_valid(_session):
		if _session.events.starter_quests_changed.is_connected(refresh):
			_session.events.starter_quests_changed.disconnect(refresh)
		if _session.events.tutorial_completed.is_connected(refresh):
			_session.events.tutorial_completed.disconnect(refresh)
	_session = null


func _exit_tree() -> void:
	unbind()


## Redraws from the starter quests of the session.
func refresh() -> void:
	if _session == null or _session.tutorial == null:
		visible = false
		return
	var starter: StarterQuests = _session.tutorial.starter
	var next: StarterQuestDef = starter.next_open()
	visible = starter.is_enabled() and next != null
	if not visible:
		return
	_count_label.text = StarterTexts.COUNT_TEXT % [starter.claimed_count(), starter.total()]
	_name_label.text = next.name
	_bar.max_value = maxi(starter.total(), 1)
	_bar.value = starter.claimed_count()
	_dot.visible = not starter.claimable().is_empty()


func _on_gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.button_index == MOUSE_BUTTON_LEFT and click.pressed:
		open_requested.emit()
		accept_event()


func _label(parent: Node, node_name: String, text: String, variation: StringName) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if variation != &"":
		label.theme_type_variation = variation
	parent.add_child(label)
	return label
