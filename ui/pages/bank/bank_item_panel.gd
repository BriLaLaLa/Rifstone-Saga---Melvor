class_name BankItemPanel
extends PanelContainer
## Item panel of the bank page (docs/01_GDD.md §7): icon, name, category, quantity, lock state, description, the
## item lines of the tooltip (requirements, modifiers, food, value) and the lock / unlock button.
##
## Internal to BankPage. `show_item` reads everything from the session at every call; the panel keeps only the id
## of the item it shows (presentation state, the page's selection). It never changes game state: the lock button
## emits `lock_requested` and the page sends the command. Selling, equipping and food come with M3-06 / M3-07.

signal lock_requested(item_id: StringName, locked: bool)
signal close_requested

const COUNT_TEXT: String = "Quantità: %s"
const LOCK_TEXT: String = "Blocca"
const UNLOCK_TEXT: String = "Sblocca"
const LOCKED_TEXT: String = "Bloccato: non si vende."
const UNLOCKED_TEXT: String = "Non bloccato."
const CLOSE_ICON: String = "x"
const CLOSE_TOOLTIP: String = "Chiudi"

var _item_id: StringName = &""

@onready var _icon: TextureRect = %Icon
@onready var _name_label: Label = %NameLabel
@onready var _category_label: Label = %CategoryLabel
@onready var _count_label: Label = %CountLabel
@onready var _lock_state_label: Label = %LockStateLabel
@onready var _description_label: Label = %DescriptionLabel
@onready var _lines_label: RichTextLabel = %LinesLabel
@onready var _lock_button: Button = %LockButton
@onready var _close_box: HBoxContainer = %CloseBox


func _ready() -> void:
	custom_minimum_size.x = UiStyle.BANK_PANEL_WIDTH
	_icon.custom_minimum_size = UiStyle.BANK_PANEL_ICON_SIZE
	var close: Button = UiStyle.icon_button(CLOSE_ICON, CLOSE_TOOLTIP, UiStyle.WINDOW_CLOSE_BUTTON_SIDE)
	close.name = "CloseButton"
	close.flat = true
	close.pressed.connect(_on_close_pressed)
	_close_box.add_child(close)
	_lock_button.pressed.connect(_on_lock_button_pressed)
	clear()


## Shows `item_id` as it is now in the bank of `session`. Returns false (and clears the panel) if the item is not in
## the bank any more or is unknown.
func show_item(session: GameSession, item_id: StringName) -> bool:
	var item: ItemDef = session.data.item(item_id) if session != null else null
	var count: int = session.bank.get_count(item_id) if item != null else 0
	if count <= 0:
		clear()
		return false
	var locked: bool = session.bank.is_locked(item_id)
	_item_id = item_id
	_icon.texture = ItemSlotView.icon_of(item.icon)
	_name_label.text = item.name
	_category_label.text = ItemTooltipLines.category_name(item.category)
	_count_label.text = COUNT_TEXT % NumberFormat.format_int(count)
	_lock_state_label.text = LOCKED_TEXT if locked else UNLOCKED_TEXT
	_lock_state_label.add_theme_color_override("font_color", UiStyle.GOLD_LIGHT if locked else UiStyle.TEXT_2)
	_description_label.text = item.description
	_description_label.visible = not item.description.is_empty()
	_lines_label.text = "\n".join(ItemTooltipLines.body(item, session.data))
	_lock_button.text = UNLOCK_TEXT if locked else LOCK_TEXT
	visible = true
	return true


## Hides the panel and forgets the item.
func clear() -> void:
	_item_id = &""
	_icon.texture = null
	_name_label.text = ""
	_category_label.text = ""
	_count_label.text = ""
	_lock_state_label.text = ""
	_description_label.text = ""
	_lines_label.text = ""
	_lock_button.text = LOCK_TEXT
	visible = false


## Id of the item shown now; `&""` if the panel is closed.
func item_id() -> StringName:
	return _item_id


func _on_lock_button_pressed() -> void:
	if _item_id != &"":
		lock_requested.emit(_item_id, _lock_button.text == LOCK_TEXT)


func _on_close_pressed() -> void:
	close_requested.emit()
