class_name ResourceRow
extends PanelContainer
## One compact row of the ResourceTable (docs/01_GDD_M36.md §44.2, docs/05_INTERFACES_M36.md §7.ae): icon and name, level (red if locked),
## stock, "Zona" (the first entry of `zones_of_action` = the highest nominal percentage) and the colour ball (tooltip: colour name and % XP).
## A click on the header asks the table to toggle the `ResourceDetail` below (one open at a time). `redraw` reads everything from the
## session (nothing is computed here). The open flag is a view setting, not saved.

signal header_clicked(action_id: StringName)
signal zone_requested(area_id: StringName)

const WIDTHS: Array[int] = [240, 56, 90, 0, 40]  # 0 = expands; the header of the table uses the same widths
const ICON_SIZE: Vector2 = Vector2(32, 32)
const BALL_TEXT: String = "●"

var _action: ActionDef = null
var _item: ItemDef = null
var _session: GameSession = null
var _open: bool = false
var _header: HBoxContainer = null
var _level: Label = null
var _stock_label: Label = null
var _zone: Label = null
var _ball: Label = null
var _detail: ResourceDetail = null


## Builds the cells for `action`; `index` is the shared Guide index of the data.
func setup(action: ActionDef, data: GameData, index: GuideIndex) -> void:
	_action = action
	_item = data.item(action.outputs[0].item_id) if not action.outputs.is_empty() else null
	name = "ResourceRow_%s" % action.id
	theme_type_variation = &"HudPanel"
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	add_child(box)
	_header = HBoxContainer.new()
	_header.name = "Header_%s" % action.id
	_header.add_theme_constant_override("separation", 8)
	_header.mouse_filter = Control.MOUSE_FILTER_STOP
	_header.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_header.gui_input.connect(_on_header_input)
	box.add_child(_header)
	var title: HBoxContainer = HBoxContainer.new()
	title.add_theme_constant_override("separation", 6)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon: TextureRect = TextureRect.new()
	icon.texture = ItemSlotView.icon_of(action.icon)
	icon.custom_minimum_size = ICON_SIZE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_child(icon)
	var name_label: Label = Label.new()
	name_label.text = action.name
	name_label.clip_text = true
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title.add_child(name_label)
	_cell(title, 0)
	_level = _label_cell(1)
	_stock_label = _label_cell(2)
	_zone = _label_cell(3)
	_ball = _label_cell(4)
	_ball.text = BALL_TEXT
	_ball.mouse_filter = Control.MOUSE_FILTER_PASS  # keeps the tooltip; the click goes on to the header
	var price: String = ResourceTexts.PRICE_TEXT % Money.text(_item.value, data.currency()) if _item != null else ""
	_detail = ResourceDetail.new()
	box.add_child(_detail)
	_detail.setup(action, data, _uses_text(index), price)
	_detail.visible = false
	_detail.zone_requested.connect(func(area_id: StringName) -> void: zone_requested.emit(area_id))


## Rereads level, stock, zone, colour and (always) the mastery; the zones of the detail only while it is open.
func redraw(session: GameSession) -> void:
	_session = session
	var unlocked: bool = session.skills.meets_requirements({_action.skill_id: _action.level})
	_level.text = ResourceTexts.LEVEL_TEXT % NumberFormat.format_int(_action.level)
	_level.add_theme_color_override("font_color", UiStyle.TEXT if unlocked else UiStyle.BAD)
	_stock_label.text = NumberFormat.format_int(session.bank.get_count(_item.id) if _item != null else 0)
	modulate = Color.WHITE if unlocked else UiStyle.TEXT_DISABLED
	_zone.text = _zone_text(session, unlocked)
	_detail.redraw_mastery(session)
	if _open:
		_detail.redraw_zones(session)
	var preview: Dictionary = NodeColorPreview.of(session, _action)
	_ball.visible = not preview.is_empty()
	if not preview.is_empty():
		var color_id: StringName = CombatTexts.color_id(preview)
		_ball.tooltip_text = ResourceTexts.COLOR_TEXT % [CombatTexts.NODE_COLOR_NAMES.get(color_id, CombatTexts.NODE_COLOR_UNKNOWN_TEXT),
				NumberFormat.format_number(float(preview.get("xp_pct", 0.0)))]
		_ball.add_theme_color_override("font_color", CombatTexts.NODE_COLORS.get(color_id, UiStyle.TEXT))


func set_open(open: bool) -> void:
	_open = open
	_detail.visible = open
	if open and _session != null:
		_detail.redraw_zones(_session)


func is_open() -> bool:
	return _open


func action_id() -> StringName:
	return _action.id


## The text of the colour ball's tooltip (empty while it is hidden), for tests.
func color_text() -> String:
	return _ball.tooltip_text if _ball.visible else ""


func _zone_text(session: GameSession, unlocked: bool) -> String:
	var zones: Array[Dictionary] = session.data.zones_of_action(_action.id)
	if zones.is_empty():
		return ResourceTexts.WHERE_NONE_TEXT
	var first: Dictionary = zones[0]
	var text: String = ResourceTexts.WHERE_LINE_TEXT % [session.data.area(StringName(first["area"])).name, int(first["pct"])]
	return text if unlocked else ResourceTexts.WHERE_LOCKED_TEXT % [text, NumberFormat.format_int(_action.level)]


func _uses_text(index: GuideIndex) -> String:
	if _item == null:
		return ResourceTexts.USES_TEXT % ResourceTexts.NO_USE_TEXT
	var summary: String = index.summary_line(index.uses_of(_item.id), 3)
	return ResourceTexts.USES_TEXT % (summary if not summary.is_empty() else ResourceTexts.NO_USE_TEXT)


func _on_header_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		header_clicked.emit(_action.id)


func _label_cell(column: int) -> Label:
	var label: Label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_cell(label, column)
	return label


func _cell(node: Control, column: int) -> void:
	if WIDTHS[column] > 0:
		node.custom_minimum_size.x = WIDTHS[column]
	else:
		node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_header.add_child(node)
