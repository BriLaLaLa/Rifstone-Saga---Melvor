class_name ItemSlotView
extends PanelContainer
## One item cell (docs/05_INTERFACES.md §7): icon, quantity at the bottom right (NumberFormat.format_compact, clipped
## so that long numbers never widen the cell; the tooltip shows the full value), lock marker, tooltip on hover.
##
## The owner (bank grid, action card, shop...) calls `set_item` with what it has just read from the session or the
## data; the cell draws it and keeps only the item definition and the quantity it was given, for its tooltip. It never
## reads the session and never changes game state. A left click emits `pressed(item_id)`.
## `set_item` and `clear` work as soon as the scene is instantiated (also before it enters the tree).

signal pressed(item_id: StringName)

const LOG_CATEGORY: String = "ui"
const LOCKED_TEXT: String = "Bloccato"

var _item: ItemDef = null
## Quantity drawn now (the owner's last `set_item`), only for the tooltip.
var _shown_count: int = 0


func _ready() -> void:
	_lock_marker().color = UiStyle.GOLD_LIGHT
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


## Draws `item` with `count` (0 = no quantity shown) and the lock marker if `locked`.
func set_item(item: ItemDef, count: int, locked: bool = false) -> void:
	if item == null:
		push_error("ItemSlotView.set_item: null item")
		clear()
		return
	_item = item
	_shown_count = count
	_icon().texture = icon_of(item.icon)
	_count_label().text = NumberFormat.format_compact(count) if count > 0 else ""
	_lock_marker().visible = locked
	_lock_marker().tooltip_text = LOCKED_TEXT if locked else ""
	LevelBadge.show_on(self, equip_level(item), count > 0)  # M16-04: equipment level, small, bottom right


## Equipment level of an item definition: the character level its `equip.requirements` ask for; 0 for non-equipment.
static func equip_level(item: ItemDef) -> int:
	if item == null or item.equip == null:
		return 0
	return int(item.equip.requirements.get(&"character", 0))


## Empty cell.
func clear() -> void:
	_item = null
	_shown_count = 0
	_icon().texture = null
	_count_label().text = ""
	_lock_marker().visible = false
	LevelBadge.show_on(self, 0)


## Id of the item drawn now; `&""` if the cell is empty.
func item_id() -> StringName:
	return _item.id if _item != null else &""


## Texture at `path` (item, action or skill icon of the data); a missing file is reported and shown as
## UiStyle.MISSING_ICON.
static func icon_of(path: String) -> Texture2D:
	if not path.is_empty() and ResourceLoader.exists(path):
		return load(path) as Texture2D
	Log.warn(LOG_CATEGORY, "icon '%s' not found" % path)
	return load(UiStyle.MISSING_ICON) as Texture2D


func _gui_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT and _item != null:
		pressed.emit(_item.id)
		accept_event()


func _icon() -> TextureRect:
	return get_node("%Icon") as TextureRect


func _count_label() -> Label:
	return get_node("%CountLabel") as Label


func _lock_marker() -> ColorRect:
	return get_node("%LockMarker") as ColorRect


func _on_mouse_entered() -> void:
	if _item != null:
		Tooltips.show_item(_item, _shown_count, get_global_mouse_position())


func _on_mouse_exited() -> void:
	Tooltips.hide_tooltip()
