class_name InventoryCell
extends PanelContainer
## One piece of the inventory grid: base icon, rarity border (UiStyle.rarity_color), "+N" of the upgrade and lock
## marker (top left). Internal to EquipmentPage.
##
## The page calls `set_piece` with what it has just read from the session; the cell keeps only the uid it draws
## (to report clicks, hovers and to start a drag) and never reads the session. Left click = `pressed(uid)`,
## right click = `right_clicked(uid)`; dragging it starts a `PieceDrag` payload.

signal pressed(uid: int)
signal right_clicked(uid: int)
signal unequip_dropped(slot: StringName)
signal hover_started(uid: int)
signal hover_ended

const LOCKED_TEXT: String = "Bloccato"

var _uid: int = 0


func _ready() -> void:
	custom_minimum_size = UiStyle.ARMORY_CELL_SIZE
	(%UpgradeLabel as Label).add_theme_font_size_override("font_size", UiStyle.ARMORY_CELL_FONT_SIZE)
	var lock: ColorRect = %LockMarker
	lock.custom_minimum_size = Vector2(UiStyle.ARMORY_MARKER_SIZE, UiStyle.ARMORY_MARKER_SIZE)
	lock.color = UiStyle.GOLD_LIGHT
	lock.tooltip_text = LOCKED_TEXT
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


## Draws `inst` (a copy read from the armory) on top of its base definition.
func set_piece(inst: ItemInstance, base: ItemDef, selected: bool) -> void:
	_uid = inst.uid
	(%Icon as TextureRect).texture = ItemSlotView.icon_of(base.icon)
	(%UpgradeLabel as Label).text = ArmoryTexts.UPGRADE_TEXT % inst.upgrade if inst.upgrade > 0 else ""
	(%LockMarker as ColorRect).visible = inst.locked
	LevelBadge.show_on(self, inst.ilvl)  # M16-04: item level, bottom right ("+N" sits at the top right)
	var bg: Color = UiStyle.GOLD_FAINT if selected else UiStyle.BG_FIELD
	add_theme_stylebox_override("panel", UiStyle.flat(bg, UiStyle.rarity_color(inst.rarity),
			UiStyle.ARMORY_RARITY_BORDER, 3.0))


## Uid of the piece drawn now (0 before the first `set_piece`).
func uid() -> int:
	return _uid


func _gui_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click == null or not click.pressed or _uid == 0:
		return
	if click.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit(_uid)
		accept_event()
	elif click.button_index == MOUSE_BUTTON_RIGHT:
		right_clicked.emit(_uid)
		accept_event()


func _get_drag_data(_at_position: Vector2) -> Variant:
	if _uid == 0:
		return null
	hover_ended.emit()
	set_drag_preview(PieceDrag.preview((%Icon as TextureRect).texture))
	return PieceDrag.payload(_uid, &"")


## A piece dragged from a worn slot and dropped on a cell goes back to the inventory like on the empty area.
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return PieceDrag.is_piece(data) and PieceDrag.from_of(data) != &""


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	unequip_dropped.emit(PieceDrag.from_of(data))


func _on_mouse_entered() -> void:
	if _uid != 0:
		hover_started.emit(_uid)


func _on_mouse_exited() -> void:
	hover_ended.emit()
