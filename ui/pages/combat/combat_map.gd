class_name CombatMap
extends Control
## Clickable map of the combat areas (M17-05, docs/M16_M18.md V3): a dimmed overlay with a panel where every area of the
## data is a node placed at its `map_pos` (0..1), with name, levels and state (locked / available / running). A click on
## an available node emits `area_chosen`; a click outside the panel or Esc closes the map. Display only: it reads the
## definitions of the data, the character requirements and the running area from the session on every `refresh`, and
## keeps nothing else than its nodes. Areas without `map_pos` (old data) are spread in a row by their order.

signal area_chosen(area_id: StringName)

const PANEL_SIZE := Vector2(980.0, 560.0)
const NODE_SIZE := Vector2(150.0, 64.0)
const MAP_PADDING: int = 90

var _panel: PanelContainer = null
var _title: Label = null
var _field: Control = null
var _nodes: Dictionary[StringName, Button] = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.0, 0.0, 0.0, 0.62)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_dim_input)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.custom_minimum_size = PANEL_SIZE
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_theme_stylebox_override("panel", UiStyle.flat(UiStyle.BG_WINDOW_OPAQUE, UiStyle.GOLD, 2, 14.0))
	add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE)
	var box := VBoxContainer.new()
	_panel.add_child(box)
	_title = Label.new()
	_title.theme_type_variation = &"TitleLabel"
	_title.text = CombatTexts.MAP_TITLE
	box.add_child(_title)
	var margin := MarginContainer.new()
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side: String in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, MAP_PADDING / 2)
	box.add_child(margin)
	_field = Control.new()
	_field.name = "Field"
	_field.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(_field)


## Rebuilds the nodes from the session (areas, requirements, running area).
func refresh(session: GameSession) -> void:
	for node: Button in _nodes.values():
		_field.remove_child(node)
		node.queue_free()
	_nodes.clear()
	var running: StringName = session.combat.area_id() if session.combat.is_active() else &""
	var areas: Array = session.data.areas()
	for i: int in areas.size():
		var area: AreaDef = areas[i] as AreaDef
		var unlocked: bool = session.character.meets_requirements(area.requirements)
		var node: Button = _make_node(area, unlocked, area.id == running)
		var pos: Vector2 = area.map_pos if area.map_pos.x >= 0.0 else \
				Vector2((i + 0.5) / maxi(1, areas.size()), 0.5)
		node.anchor_left = pos.x
		node.anchor_right = pos.x
		node.anchor_top = pos.y
		node.anchor_bottom = pos.y
		node.offset_left = -NODE_SIZE.x / 2.0
		node.offset_right = NODE_SIZE.x / 2.0
		node.offset_top = -NODE_SIZE.y / 2.0
		node.offset_bottom = NODE_SIZE.y / 2.0
		_field.add_child(node)
		_nodes[area.id] = node


func open(session: GameSession) -> void:
	refresh(session)
	visible = true


func close() -> void:
	visible = false


## Node of the area `id`, for tests.
func node(id: StringName) -> Button:
	return _nodes.get(id)


func _make_node(area: AreaDef, unlocked: bool, running: bool) -> Button:
	var button := Button.new()
	button.name = "Area_%s" % area.id
	button.clip_text = false
	var state_text: String = CombatTexts.MAP_RUNNING_TEXT if running \
			else (CombatTexts.MAP_AVAILABLE_TEXT if unlocked else CombatTexts.MAP_LOCKED_TEXT)
	var lines: Array[String] = [area.name]
	if area.level_min > 0:
		lines.append(CombatTexts.MAP_LEVELS_TEXT % [area.level_min, area.level_max])
	lines.append(state_text)
	button.text = "\n".join(lines)
	button.disabled = not unlocked
	var border: Color = UiStyle.GOLD_LIGHT if running else (UiStyle.GOLD if unlocked else UiStyle.GOLD_DIM)
	var width: int = 3 if running else 1
	button.add_theme_stylebox_override("normal", UiStyle.flat(UiStyle.BG_BUTTON, border, width, 6.0))
	button.add_theme_stylebox_override("hover", UiStyle.flat(UiStyle.BG_BUTTON_HOVER, UiStyle.GOLD_LIGHT, width, 6.0))
	button.add_theme_stylebox_override("pressed", UiStyle.flat(UiStyle.BG_BUTTON_PRESSED, border, width, 6.0))
	button.add_theme_stylebox_override("disabled", UiStyle.flat(UiStyle.BG_FIELD, border, 1, 6.0))
	if unlocked:
		button.tooltip_text = area.description
		button.pressed.connect(area_chosen.emit.bind(area.id))
	else:
		button.tooltip_text = ItemTooltipLines.CHARACTER_REQUIREMENT_TEXT % area.requirements.get(&"character", 1)
	return button


func _on_dim_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		close()


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
