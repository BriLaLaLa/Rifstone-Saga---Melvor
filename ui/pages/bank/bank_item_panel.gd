class_name BankItemPanel
extends PanelContainer
## Item panel of the bank page (docs/01_GDD.md §7): icon, name, category, quantity, lock state, description, the
## item lines of the tooltip (requirements, modifiers, food, value), the lock / unlock button and the sale section
## (slider, preview of the gold, "Vendi", "Tutti tranne 1", "Tutti").
##
## Internal to BankPage. `show_item` reads everything from the session at every call; the panel keeps only the id
## of the item it shows and the session reference (presentation state, the page's selection). It never changes game
## state: the buttons emit `lock_requested`, `sell_requested`, `equip_requested` and `food_requested`; the page sends
## the command.

signal lock_requested(item_id: StringName, locked: bool)
signal sell_requested(item_id: StringName, qty: int)
signal equip_requested(item_id: StringName)
signal food_requested(item_id: StringName)
signal close_requested

const COUNT_TEXT: String = "Quantità: %s"
const LOCK_TEXT: String = "Blocca"
const UNLOCK_TEXT: String = "Sblocca"
const LOCKED_TEXT: String = "Bloccato: non si vende."
const UNLOCKED_TEXT: String = "Non bloccato."
const EQUIP_TEXT: String = "Equipaggia"
const FOOD_TEXT: String = "Usa come cibo"
const FOOD_ACTIVE_TEXT: String = "Cibo scelto"
const SELL_TEXT: String = "Vendi"
const SELL_ALL_BUT_ONE_TEXT: String = "Tutti tranne 1"
const SELL_ALL_TEXT: String = "Tutti"
const SELL_PREVIEW_TEXT: String = "Vendita di %s: %s oro"
const SELL_LOCKED_TEXT: String = "Sblocca l'oggetto per venderlo."
const SELL_NOT_SELLABLE_TEXT: String = "Questo oggetto non si vende."
const CLOSE_ICON: String = "x"
const CLOSE_TOOLTIP: String = "Chiudi"

var _item_id: StringName = &""
## Session of the last `show_item` (read at every use, never a copy of its state).
var _session: GameSession = null

@onready var _icon: TextureRect = %Icon
@onready var _name_label: Label = %NameLabel
@onready var _category_label: Label = %CategoryLabel
@onready var _count_label: Label = %CountLabel
@onready var _lock_state_label: Label = %LockStateLabel
@onready var _description_label: Label = %DescriptionLabel
@onready var _lines_label: RichTextLabel = %LinesLabel
@onready var _lock_button: Button = %LockButton
@onready var _close_box: HBoxContainer = %CloseBox
@onready var _equip_button: Button = %EquipButton
@onready var _food_button: Button = %FoodButton
@onready var _sell_section: VBoxContainer = %SellSection
@onready var _sell_slider: HSlider = %SellSlider
@onready var _sell_preview: Label = %SellPreview
@onready var _sell_note: Label = %SellNote
@onready var _sell_button: Button = %SellButton
@onready var _sell_but_one_button: Button = %SellButOneButton
@onready var _sell_all_button: Button = %SellAllButton


func _ready() -> void:
	custom_minimum_size.x = UiStyle.BANK_PANEL_WIDTH
	_icon.custom_minimum_size = UiStyle.BANK_PANEL_ICON_SIZE
	var close: Button = UiStyle.icon_button(CLOSE_ICON, CLOSE_TOOLTIP, UiStyle.WINDOW_CLOSE_BUTTON_SIDE)
	close.name = "CloseButton"
	close.flat = true
	close.pressed.connect(_on_close_pressed)
	_close_box.add_child(close)
	_lock_button.pressed.connect(_on_lock_button_pressed)
	_equip_button.text = EQUIP_TEXT
	_equip_button.pressed.connect(_on_equip_button_pressed)
	_food_button.text = FOOD_TEXT
	_food_button.pressed.connect(_on_food_button_pressed)
	_sell_button.text = SELL_TEXT
	_sell_but_one_button.text = SELL_ALL_BUT_ONE_TEXT
	_sell_all_button.text = SELL_ALL_TEXT
	_sell_slider.value_changed.connect(_on_sell_slider_value_changed)
	_sell_button.pressed.connect(_on_sell_button_pressed)
	_sell_but_one_button.pressed.connect(_on_sell_but_one_pressed)
	_sell_all_button.pressed.connect(_on_sell_all_pressed)
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
	var same_item: bool = item_id == _item_id
	_item_id = item_id
	_session = session
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
	_refresh_actions(item)
	_refresh_sell(item, count, locked, same_item)
	visible = true
	return true


## Hides the panel and forgets the item.
func clear() -> void:
	_item_id = &""
	_session = null
	_icon.texture = null
	_name_label.text = ""
	_category_label.text = ""
	_count_label.text = ""
	_lock_state_label.text = ""
	_description_label.text = ""
	_lines_label.text = ""
	_lock_button.text = LOCK_TEXT
	_sell_section.visible = false
	_equip_button.visible = false
	_food_button.visible = false
	visible = false


## Id of the item shown now; `&""` if the panel is closed.
func item_id() -> StringName:
	return _item_id


func _on_lock_button_pressed() -> void:
	if _item_id != &"" and _session != null:
		lock_requested.emit(_item_id, not _session.bank.is_locked(_item_id))


func _on_close_pressed() -> void:
	close_requested.emit()


# --- Equip and food ---------------------------------------------------------------------------------------------

## "Equipaggia" for equippable items, "Usa come cibo" for food (disabled while it is the chosen food).
func _refresh_actions(item: ItemDef) -> void:
	_equip_button.visible = item.is_equippable()
	_food_button.visible = item.is_food()
	var chosen: bool = _session.equipment.get_food() == item.id
	_food_button.text = FOOD_ACTIVE_TEXT if chosen else FOOD_TEXT
	_food_button.disabled = chosen


func _on_equip_button_pressed() -> void:
	if _item_id != &"" and _session != null:
		equip_requested.emit(_item_id)


func _on_food_button_pressed() -> void:
	if _item_id != &"" and _session != null:
		food_requested.emit(_item_id)


# --- Sale section ---------------------------------------------------------------------------------------------

## Enabled only for an unlocked item with a sell value; the slider keeps its value while the same item stays open
## (clamped to the quantity); the gold of the preview is `shop.sell_value`.
func _refresh_sell(item: ItemDef, count: int, locked: bool, keep_value: bool) -> void:
	var can_sell: bool = not locked and item.value > 0
	_sell_note.text = SELL_LOCKED_TEXT if locked else (SELL_NOT_SELLABLE_TEXT if item.value <= 0 else "")
	_sell_note.visible = not can_sell
	_sell_slider.min_value = 1
	_sell_slider.max_value = maxi(count, 2)
	_sell_slider.set_value_no_signal(clampi(int(_sell_slider.value) if keep_value else 1, 1, count))
	_sell_slider.visible = can_sell and count > 1
	_sell_preview.visible = can_sell
	_sell_button.disabled = not can_sell
	_sell_but_one_button.visible = count > 1
	_sell_but_one_button.disabled = not can_sell
	_sell_all_button.disabled = not can_sell
	_update_sell_preview()
	_sell_section.visible = true


func _update_sell_preview() -> void:
	if _session == null or _item_id == &"":
		return
	var qty: int = int(_sell_slider.value)
	var gold: int = _session.shop.sell_value(_item_id, qty)
	_sell_preview.text = SELL_PREVIEW_TEXT % [NumberFormat.format_int(qty), NumberFormat.format_int(gold)]


func _request_sell(qty: int) -> void:
	if _item_id != &"" and _session != null:
		sell_requested.emit(_item_id, qty)


func _on_sell_slider_value_changed(_value: float) -> void:
	_update_sell_preview()


func _on_sell_button_pressed() -> void:
	_request_sell(int(_sell_slider.value))


func _on_sell_but_one_pressed() -> void:
	if _session != null:
		_request_sell(_session.bank.get_count(_item_id) - 1)


func _on_sell_all_pressed() -> void:
	if _session != null:
		_request_sell(_session.bank.get_count(_item_id))
