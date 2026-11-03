class_name GameWindow
extends PanelContainer
## Movable in-game window with a title bar (Cinzel title, close button) dragged to move it.
##
## Ported from the previous game's HUD window, unchanged except for snake_case, full typing, exported texts and the
## layout constants, which are `UiStyle.WINDOW_*`.
## In its scene the window has a `VBox` child holding the page; the title bar and a separator are added on top of
## it here. The owner screen opens and closes it with `toggle()` (and closes the last opened one on Esc).

signal opened
signal closed

@export var title: String = "Finestra"
@export var close_tooltip: String = "Chiudi (Esc)"
@export var default_size: Vector2 = Vector2(900, 620)

var _drag_from: Vector2 = Vector2.INF
var _placed: bool = false


func _ready() -> void:
	theme_type_variation = &"WindowPanel"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var vb: VBoxContainer = $VBox as VBoxContainer
	vb.add_theme_constant_override("separation", UiStyle.WINDOW_HEADER_SEPARATION)
	var header := HBoxContainer.new()
	header.name = "Header"
	header.mouse_filter = Control.MOUSE_FILTER_STOP
	header.mouse_default_cursor_shape = Control.CURSOR_MOVE
	header.gui_input.connect(_on_header_gui_input)
	var title_label := Label.new()
	title_label.theme_type_variation = &"TitleLabel"
	title_label.text = title.to_upper()
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(title_label)
	var close: Button = UiStyle.icon_button("x", close_tooltip, UiStyle.WINDOW_CLOSE_BUTTON_SIDE)
	close.flat = true
	close.pressed.connect(close_window)
	header.add_child(close)
	vb.add_child(header)
	vb.move_child(header, 0)
	var sep := HSeparator.new()
	vb.add_child(sep)
	vb.move_child(sep, 1)


func toggle() -> void:
	if visible:
		close_window()
	else:
		open_window()


func open_window() -> void:
	if not _placed:
		_place_default()
	visible = true
	move_to_front()
	opened.emit()


func close_window() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func _gui_input(event: InputEvent) -> void:
	# A click inside the window brings it in front of the others.
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.pressed:
		move_to_front()


## First opening: centered, at most as large as the free space.
func _place_default() -> void:
	_placed = true
	var area: Vector2 = get_parent_area_size()
	var free_area: Vector2 = area - Vector2(UiStyle.WINDOW_PLACE_MARGIN, UiStyle.WINDOW_PLACE_MARGIN)
	size = Vector2(minf(default_size.x, free_area.x), minf(default_size.y, free_area.y))
	size = size.max(get_combined_minimum_size())
	position = ((area - size) * 0.5).floor()
	position.y = maxf(position.y, UiStyle.WINDOW_PLACE_TOP)


func _on_header_gui_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null:
		if button.button_index != MOUSE_BUTTON_LEFT:
			return
		if button.pressed:
			_drag_from = button.global_position - global_position
			move_to_front()
		else:
			_drag_from = Vector2.INF
		return
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null and _drag_from != Vector2.INF:
		var area: Vector2 = get_parent_area_size()
		var p: Vector2 = motion.global_position - _drag_from - get_parent_control().global_position
		var keep: Vector2 = UiStyle.WINDOW_DRAG_KEEP_VISIBLE
		position = p.clamp(Vector2(-size.x + keep.x, 0), area - keep)
