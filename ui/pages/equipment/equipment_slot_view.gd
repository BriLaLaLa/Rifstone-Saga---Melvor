class_name EquipmentSlotView
extends PanelContainer
## One slot of the paper doll (docs/UI_GDR.md §3): the icon of the worn piece with a rarity border, or the icon of the
## slot in a muted tone when it is empty, plus the slot label. It is a drag source (a worn piece, to take it off) and
## a drop target (a piece from the inventory).
##
## The page calls `show_piece` / `show_empty` with what it has just read from the session; the view keeps only the
## slot id, the uid it draws and the highlight flag (presentation). It never reads the session and never changes game
## state: it reports left click (`pressed`), right click (`right_clicked`), hover and drops, and the page sends the
## commands. A drop is accepted only while the page has lit the slot (`set_glow`, the compatible slots of the drag).

signal pressed(slot: StringName)
signal right_clicked(slot: StringName)
signal hover_started(slot: StringName)
signal hover_ended
signal piece_dropped(slot: StringName, uid: int)

const SLOT_ICON_DIR: String = "res://assets/icons/slots/%s.svg"
const EMPTY_BORDER := Color("4a4030")
const EMPTY_ICON_TINT := Color(0.55, 0.5, 0.4, 0.8)
const BORDER_WIDTH: int = 2
const GLOW_BORDER_WIDTH: int = 4
const LABEL_FONT_SIZE: int = 11
const LABEL_MIN_FONT_SIZE: int = 7
const LABEL_PADDING: float = 8.0
const RADIUS: float = 3.0

var _slot: StringName = &""
var _uid: int = 0
var _glow: bool = false
var _rarity_color: Color = EMPTY_BORDER
var _icon: TextureRect = null
var _label: Label = null
## Label of the slot without the "+N" of a worn piece.
var _slot_text: String = ""


func _init() -> void:
	theme_type_variation = &"SlotPanel"
	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(box)
	_icon = TextureRect.new()
	_icon.name = "Icon"
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_icon)
	_label = Label.new()
	_label.name = "SlotLabel"
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.theme_type_variation = &"MutedLabel"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", LABEL_FONT_SIZE)
	_label.clip_text = true
	_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	box.add_child(_label)
	resized.connect(_fit_label)
	mouse_entered.connect(func() -> void: hover_started.emit(_slot))
	mouse_exited.connect(func() -> void: hover_ended.emit())


## Sets the slot id and its label (the page reads the label from `EquipmentStatsText.slot_text`).
func setup(slot: StringName, label_text: String) -> void:
	_slot = slot
	_slot_text = label_text
	_label.text = label_text
	_fit_label()
	name = "Slot_%s" % slot
	show_empty()


## Draws a worn piece.
func show_piece(inst: ItemInstance, base: ItemDef) -> void:
	_uid = inst.uid
	_rarity_color = UiStyle.rarity_color(inst.rarity)
	_icon.texture = ItemSlotView.icon_of(base.icon)
	_icon.modulate = Color.WHITE
	_label.text = _slot_text if inst.upgrade <= 0 else "%s %s" % [_slot_text, ArmoryTexts.UPGRADE_TEXT % inst.upgrade]
	_fit_label()
	_restyle()


## Draws the empty slot with its own icon in a muted tone.
func show_empty() -> void:
	_uid = 0
	_rarity_color = EMPTY_BORDER
	var path: String = SLOT_ICON_DIR % _slot
	_icon.texture = load(path) as Texture2D if ResourceLoader.exists(path) else null
	_icon.modulate = EMPTY_ICON_TINT
	_label.text = _slot_text
	_fit_label()
	_restyle()


## Lights the slot as a compatible drop target (or turns the light off).
func set_glow(on: bool) -> void:
	_glow = on
	_restyle()


func slot() -> StringName:
	return _slot


## Uid of the worn piece drawn now; 0 if empty.
func uid() -> int:
	return _uid


func is_glowing() -> bool:
	return _glow


func _restyle() -> void:
	var border: Color = UiStyle.GOOD if _glow else _rarity_color
	var width: int = GLOW_BORDER_WIDTH if _glow else BORDER_WIDTH
	add_theme_stylebox_override("panel", UiStyle.flat(UiStyle.BG_FIELD, border, width, RADIUS))


func _gui_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click == null or not click.pressed:
		return
	if click.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit(_slot)
		accept_event()
	elif click.button_index == MOUSE_BUTTON_RIGHT:
		right_clicked.emit(_slot)
		accept_event()


## The payload of a drag of the worn piece (null if the slot is empty).
func drag_payload() -> Variant:
	return PieceDrag.payload(_uid, _slot) if _uid != 0 else null


func _get_drag_data(_at_position: Vector2) -> Variant:
	var payload: Variant = drag_payload()
	if payload != null:
		hover_ended.emit()
		set_drag_preview(PieceDrag.preview(_icon.texture))
	return payload


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return _glow and PieceDrag.is_piece(data)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	piece_dropped.emit(_slot, PieceDrag.uid_of(data))


## Shrinks the label font until the whole text fits the width of the slot (never cut), down to a readable minimum.
func _fit_label() -> void:
	if _label == null:
		return
	var font: Font = _label.get_theme_font("font")
	var available: float = size.x - LABEL_PADDING
	var font_size: int = LABEL_FONT_SIZE
	while font_size > LABEL_MIN_FONT_SIZE and font.get_string_size(_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			font_size).x > available:
		font_size -= 1
	_label.add_theme_font_size_override("font_size", font_size)


## Font size of the label now, for tests.
func label_font_size() -> int:
	return _label.get_theme_font_size("font_size")
