class_name GearCell
extends PanelContainer
## Small slot of the equipment grid of the combat page (docs/UI_GDR.md §2): icon of the worn piece with the border of
## its rarity, or the muted icon of the slot when empty. Hover only (the tooltip is the page's); no drag, no click.

signal hover_started(slot: StringName)
signal hover_ended

var _slot: StringName = &""
var _uid: int = 0
var _icon: TextureRect = null


func _init() -> void:
	theme_type_variation = &"SlotPanel"
	custom_minimum_size = Vector2(UiStyle.COMBAT_GEAR_CELL, UiStyle.COMBAT_GEAR_CELL)
	_icon = TextureRect.new()
	_icon.name = "Icon"
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(_icon)
	mouse_entered.connect(func() -> void: hover_started.emit(_slot))
	mouse_exited.connect(func() -> void: hover_ended.emit())


func setup(slot: StringName) -> void:
	_slot = slot
	name = "Gear_%s" % slot
	show_empty()


func show_piece(inst: ItemInstance, base: ItemDef) -> void:
	_uid = inst.uid
	_icon.texture = ItemSlotView.icon_of(base.icon)
	_icon.modulate = Color.WHITE
	_style(UiStyle.rarity_color(inst.rarity))


func show_empty() -> void:
	_uid = 0
	var path: String = EquipmentSlotView.SLOT_ICON_DIR % _slot
	_icon.texture = load(path) as Texture2D if ResourceLoader.exists(path) else null
	_icon.modulate = EquipmentSlotView.EMPTY_ICON_TINT
	_style(UiStyle.COMBAT_EMPTY_BORDER)


func slot() -> StringName:
	return _slot


## Uid of the worn piece drawn now; 0 if empty.
func uid() -> int:
	return _uid


func _style(border: Color) -> void:
	add_theme_stylebox_override("panel", UiStyle.flat(UiStyle.BG_FIELD, border, UiStyle.COMBAT_FRAME_WIDTH, 2.0))
