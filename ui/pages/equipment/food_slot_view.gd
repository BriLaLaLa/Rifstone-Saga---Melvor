class_name FoodSlotView
extends PanelContainer
## The "Cibo" slot of the paper doll: the food chosen for the combat with "×N nel deposito" (N is the Bank count, read
## at every `show_food`: the food is never taken out of the Bank by choosing it) and the button "Togli", which only
## clears the choice. A click opens the list of the foods in the Bank; picking one emits `food_chosen`.
##
## Presentation only: it keeps the id it draws and never reads the session or changes game state; the page sends
## `equipment.set_food`.

signal food_chosen(item_id: StringName)
signal clear_requested
signal open_requested

const SLOT_TEXT: String = "Cibo"
const NONE_TEXT: String = "Nessun cibo"
const COUNT_TEXT: String = "×%s nel deposito"
const CLEAR_TEXT: String = "Togli"
const CLEAR_TOOLTIP: String = "Deseleziona il cibo: resta nel Deposito."
const MENU_ITEM_TEXT: String = "%s (×%s)"
const MENU_EMPTY_TEXT: String = "Nessun cibo nel deposito"
const BORDER_WIDTH: int = 2
const RADIUS: float = 3.0
const LABEL_FONT_SIZE: int = 11

var _food_id: StringName = &""
var _icon: TextureRect = null
var _title: Label = null
var _count: Label = null
var _clear: Button = null
var _menu: PopupMenu = null


func _init() -> void:
	theme_type_variation = &"SlotPanel"
	name = "FoodSlot"
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
	_title = _small_label(box, "SlotLabel")
	_title.text = SLOT_TEXT
	_count = _small_label(box, "CountLabel")
	_clear = Button.new()
	_clear.name = "ClearButton"
	_clear.text = CLEAR_TEXT
	_clear.tooltip_text = CLEAR_TOOLTIP
	_clear.focus_mode = Control.FOCUS_NONE
	_clear.add_theme_font_size_override("font_size", LABEL_FONT_SIZE)
	_clear.pressed.connect(func() -> void: clear_requested.emit())
	box.add_child(_clear)
	_menu = PopupMenu.new()
	_menu.name = "FoodMenu"
	_menu.id_pressed.connect(_on_menu_id_pressed)
	add_child(_menu)
	add_theme_stylebox_override("panel", UiStyle.flat(UiStyle.BG_FIELD, EquipmentSlotView.EMPTY_BORDER, BORDER_WIDTH, RADIUS))


## Draws the chosen food (`food` null = none) with the Bank count `count`.
func show_food(food: ItemDef, count: int) -> void:
	_food_id = food.id if food != null else &""
	_icon.texture = ItemSlotView.icon_of(food.icon) if food != null else null
	_title.text = food.name if food != null else SLOT_TEXT
	_count.text = COUNT_TEXT % NumberFormat.format_int(count) if food != null else NONE_TEXT
	_clear.disabled = food == null


## Opens the list of the foods in the Bank (`foods` = [{"item": ItemDef, "count": int}]) under the slot.
func open_menu(foods: Array[Dictionary]) -> void:
	_menu.clear()
	if foods.is_empty():
		_menu.add_item(MENU_EMPTY_TEXT, 0)
		_menu.set_item_disabled(0, true)
	for i: int in foods.size():
		var item: ItemDef = foods[i]["item"]
		_menu.add_item(MENU_ITEM_TEXT % [item.name, NumberFormat.format_int(int(foods[i]["count"]))], i)
		_menu.set_item_metadata(i, item.id)
	_menu.popup(Rect2i(Vector2i(get_screen_position()) + Vector2i(0, int(size.y)), Vector2i.ZERO))


## Id of the food drawn now (&"" if none), for tests.
func food_id() -> StringName:
	return _food_id


## The popup menu, for tests.
func menu() -> PopupMenu:
	return _menu


func clear_button() -> Button:
	return _clear


func _gui_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		open_requested.emit()
		accept_event()


func _on_menu_id_pressed(id: int) -> void:
	var index: int = _menu.get_item_index(id)
	var item_id: StringName = _menu.get_item_metadata(index) as StringName
	if item_id != &"":
		food_chosen.emit(item_id)


func _small_label(parent: Control, node_name: String) -> Label:
	var label: Label = Label.new()
	label.name = node_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.theme_type_variation = &"MutedLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", LABEL_FONT_SIZE)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label
