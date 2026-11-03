class_name ArmoryCell
extends PanelContainer
## One piece of the Armory grid: base icon, rarity border (UiStyle.rarity_color), "+N" of the upgrade, lock marker
## (top left) and worn marker (top right). Internal to ArmoryPage.
##
## The page calls `set_piece` with what it has just read from the session; the cell keeps only the uid it draws
## (to report clicks and hovers) and never reads the session. A left click emits `pressed(uid)`.

signal pressed(uid: int)
signal hover_started(uid: int)
signal hover_ended

const LOCKED_TEXT: String = "Bloccato"
const WORN_TEXT: String = "Indossato"

var _uid: int = 0


func _ready() -> void:
	custom_minimum_size = UiStyle.ARMORY_CELL_SIZE
	(%UpgradeLabel as Label).add_theme_font_size_override("font_size", UiStyle.ARMORY_CELL_FONT_SIZE)
	for marker: ColorRect in [%LockMarker, %WornMarker]:
		marker.custom_minimum_size = Vector2(UiStyle.ARMORY_MARKER_SIZE, UiStyle.ARMORY_MARKER_SIZE)
	(%LockMarker as ColorRect).color = UiStyle.GOLD_LIGHT
	(%LockMarker as ColorRect).tooltip_text = LOCKED_TEXT
	(%WornMarker as ColorRect).color = UiStyle.GOOD
	(%WornMarker as ColorRect).tooltip_text = WORN_TEXT
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


## Draws `inst` (a copy read from the armory) on top of its base definition.
func set_piece(inst: ItemInstance, base: ItemDef, worn: bool, selected: bool) -> void:
	_uid = inst.uid
	(%Icon as TextureRect).texture = ItemSlotView.icon_of(base.icon)
	(%UpgradeLabel as Label).text = ArmoryTexts.UPGRADE_TEXT % inst.upgrade if inst.upgrade > 0 else ""
	(%LockMarker as ColorRect).visible = inst.locked
	(%WornMarker as ColorRect).visible = worn
	var bg: Color = UiStyle.GOLD_FAINT if selected else UiStyle.BG_FIELD
	add_theme_stylebox_override("panel", UiStyle.flat(bg, UiStyle.rarity_color(inst.rarity),
			UiStyle.ARMORY_RARITY_BORDER, 3.0))


## Uid of the piece drawn now (0 before the first `set_piece`).
func uid() -> int:
	return _uid


func _gui_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT and _uid != 0:
		pressed.emit(_uid)
		accept_event()


func _on_mouse_entered() -> void:
	if _uid != 0:
		hover_started.emit(_uid)


func _on_mouse_exited() -> void:
	hover_ended.emit()
