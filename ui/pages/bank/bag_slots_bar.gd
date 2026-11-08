class_name BagSlotsBar
extends HBoxContainer
## Bag slots of the Deposit (docs/05_INTERFACES.md §7.w, docs/01_GDD.md §7): one node `BagSlot_<i>` per slot of
## `deposit.bag_slots`, empty ones visible. A full slot shows the bag and its boxes and, clicked, asks to take it out
## (`unequip_requested`); an empty slot offers the bags in the Deposit (`bank.stacks` with `is_bag`) and asks to put
## the chosen one in (`equip_requested`). The page sends the commands and shows the refusals. No state: every
## `redraw` reads the session.

signal equip_requested(slot_index: int, item_id: StringName)
signal unequip_requested(slot_index: int)

const SLOT_NAME: String = "BagSlot_%d"
const SLOT_ICON_MAX_WIDTH: int = 28

var _menu: PopupMenu = null
var _menu_slot: int = -1
var _menu_items: Array[StringName] = []
var _title: Label = null
## Reference of the last `redraw` (read-only, used to list the owned bags when a slot opens the menu).
var _session_ref: GameSession = null


func _ready() -> void:
	add_theme_constant_override("separation", UiStyle.BAG_BAR_SEPARATION)
	_title = Label.new()
	_title.name = "TitleLabel"
	_title.text = BagTexts.TITLE_TEXT
	_title.theme_type_variation = &"HeaderLabel"
	add_child(_title)
	_menu = PopupMenu.new()
	_menu.name = "BagMenu"
	_menu.id_pressed.connect(_on_menu_id_pressed)
	add_child(_menu)


## Draws every slot from `session.deposit.bags()`.
func redraw(session: GameSession) -> void:
	_session_ref = session
	var bags: Array[StringName] = session.deposit.bags()
	for index: int in bags.size():
		var slot: Button = _slot(index)
		var bag: ItemDef = session.data.item(bags[index]) if bags[index] != &"" else null
		if bag == null:
			slot.text = BagTexts.EMPTY_SLOT_TEXT
			slot.icon = null
			slot.tooltip_text = BagTexts.EMPTY_TOOLTIP
		else:
			slot.text = BagTexts.FILLED_TEXT % [bag.name, NumberFormat.format_int(bag.bag_slots)]
			slot.icon = ItemSlotView.icon_of(bag.icon)
			slot.tooltip_text = "%s\n%s" % [bag.description, BagTexts.FILLED_TOOLTIP]
		slot.set_meta(&"bag", bags[index])
	var extra: Array[Node] = []
	for child: Node in get_children():
		if child is Button and child.name.begins_with("BagSlot_") and int(String(child.name).trim_prefix("BagSlot_")) >= bags.size():
			extra.append(child)
	for child: Node in extra:
		remove_child(child)
		child.queue_free()


## Owned bags offered by an empty slot: item ids in the bank's order.
func owned_bags(session: GameSession) -> Array[StringName]:
	var result: Array[StringName] = []
	for stack: Dictionary in session.bank.stacks():
		var item: ItemDef = session.data.item(stack["item"] as StringName)
		if item != null and item.is_bag():
			result.append(item.id)
	return result


func _slot(index: int) -> Button:
	var existing: Node = get_node_or_null(SLOT_NAME % index)
	if existing != null:
		return existing as Button
	var slot: Button = Button.new()
	slot.name = SLOT_NAME % index
	slot.custom_minimum_size = UiStyle.BAG_SLOT_SIZE
	slot.focus_mode = Control.FOCUS_NONE
	slot.expand_icon = true
	slot.add_theme_constant_override("icon_max_width", SLOT_ICON_MAX_WIDTH)
	slot.clip_text = true
	slot.pressed.connect(_on_slot_pressed.bind(index))
	add_child(slot)
	move_child(slot, index + 1)
	return slot


func _on_slot_pressed(index: int) -> void:
	var slot: Button = _slot(index)
	var bag: StringName = slot.get_meta(&"bag", &"") as StringName
	if bag != &"":
		unequip_requested.emit(index)
		return
	_open_menu(index)


## Fills the menu with the bags the session owns.
func _open_menu(index: int) -> void:
	_menu_slot = index
	_menu.clear()
	_menu_items.clear()
	var session: GameSession = _session_ref
	if session != null:
		for bag_id: StringName in owned_bags(session):
			var item: ItemDef = session.data.item(bag_id)
			_menu_items.append(bag_id)
			_menu.add_item(BagTexts.PICK_TEXT % [item.name, NumberFormat.format_int(item.bag_slots)], _menu_items.size() - 1)
	if _menu_items.is_empty():
		_menu.add_item(BagTexts.NO_BAGS_TEXT, 0)
		_menu.set_item_disabled(0, true)
	var slot: Control = _slot(index)
	_menu.position = Vector2i(slot.get_screen_position() + Vector2(0, slot.size.y))
	_menu.popup()


func _on_menu_id_pressed(id: int) -> void:
	if id >= 0 and id < _menu_items.size() and _menu_slot >= 0:
		equip_requested.emit(_menu_slot, _menu_items[id])

