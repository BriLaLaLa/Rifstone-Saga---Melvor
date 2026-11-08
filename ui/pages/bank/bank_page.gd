class_name BankPage
extends Page
## Bank page (docs/01_GDD.md §7), route `bank`: a grid of ItemSlotView cells, one per stack of `bank.stacks()` in the
## bank's order, the counter "used / capacity", a search by name, the "Ordina" button and the item panel.
##
## Every redraw reads the session: the stacks from `bank.stacks()`, the counter from `bank.used()` and
## `deposit.capacity()`, the item panel from the bank. It redraws on `bank_changed` and `deposit_changed`; the
## quantity a cell draws is the one of its last `set_item` (presentation copy of ItemSlotView, never read back).
## Player actions are bank commands: a click on a cell opens the item panel (lock / unlock = `set_locked`); dragging
## a cell onto another moves it to that cell's index (`move_stack`), onto the grid outside the cells to the last
## index; "Ordina" = `sort_stacks`. The grid changes only through the events of the bank: a
## refused command moves nothing and shows its reason. Selling = `shop.sell`,
## "Usa come cibo" = `equipment.set_food` (all from the item panel).
## It keeps no game state: only the session reference, its nodes and presentation state (search text, the item of
## the panel, the hovered cell whose tooltip is refreshed after a redraw).

const ITEM_SLOT_SCENE: PackedScene = preload("res://ui/components/item_slot/item_slot.tscn")
const TITLE_TEXT: String = "Deposito"
const SLOTS_TEXT: String = "Caselle: %s / %s"
const FULL_TEXT: String = "Il deposito è pieno: i nuovi oggetti non entrano."
const EMPTY_TEXT: String = "Il deposito è vuoto."
const NO_MATCH_TEXT: String = "Nessun oggetto corrisponde alla ricerca."
const SEARCH_PLACEHOLDER: String = "Cerca per nome"
const SORT_TEXT: String = "Ordina"
const SORT_TOOLTIP: String = "Ordina per categoria e poi per tipo di oggetto."
## Reason of a refused bank command -> text shown above the grid; other reasons: REFUSED_TEXT_DEFAULT.
const REFUSED_TEXTS: Dictionary[StringName, String] = {
	Reasons.UNKNOWN_ID: "L'oggetto non è più nel deposito.",
	Reasons.INVALID_AMOUNT: "Quantità o posizione non valida.",
	Reasons.ITEM_LOCKED: "L'oggetto è bloccato: sbloccalo per venderlo.",
	Reasons.NOT_SELLABLE: "Questo oggetto non si vende.",
	Reasons.NOT_ENOUGH_ITEMS: "Non ci sono abbastanza oggetti.",
	Reasons.REQUIREMENT_NOT_MET: "Requisiti non soddisfatti.",
	Reasons.COMBAT_ACTIVE: "Non puoi cambiare arma durante il combattimento.",
	Reasons.BANK_FULL: "Il deposito è pieno.",
	Reasons.NOT_FOOD: "Questo oggetto non è un cibo.",
}
const REFUSED_TEXT_DEFAULT: String = "Operazione non riuscita."
const STACK_ITEM_KEY: String = "item"
const STACK_COUNT_KEY: String = "count"
const STACK_LOCKED_KEY: String = "locked"
const CELL_NAME: String = "Cell%d"
const OCCUPIED_CELL_NAME: String = "OccupiedCell%d"
const EMPTY_CELL_NAME: String = "EmptyCell%d"
const OCCUPIED_TOOLTIP: String = "Casella usata da un pezzo dell'Armeria."
## Drag data of a cell: {DRAG_KIND_KEY: DRAG_KIND, DRAG_ITEM_KEY: item id}.
const DRAG_KIND_KEY: String = "kind"
const DRAG_KIND: StringName = &"bank_stack"
const DRAG_ITEM_KEY: String = "item"

var _session: GameSession = null
## Cell under the mouse (presentation): its tooltip is shown again after a redraw.
var _hovered_cell: ItemSlotView = null

@onready var _margin: MarginContainer = %Margin
@onready var _content: VBoxContainer = %Content
@onready var _main: HBoxContainer = %Main
@onready var _title_label: Label = %TitleLabel
@onready var _search_edit: LineEdit = %SearchEdit
@onready var _sort_button: Button = %SortButton
@onready var _slots_label: Label = %SlotsLabel
@onready var _full_label: Label = %FullLabel
@onready var _message_label: Label = %MessageLabel
@onready var _empty_label: Label = %EmptyLabel
@onready var _grid: HFlowContainer = %Grid
@onready var _item_panel: BankItemPanel = %ItemPanel
@onready var _bag_bar: BagSlotsBar = %BagSlotsBar
@onready var _tabs: DepositTabs = %DepositTabs


func _ready() -> void:
	for side: String in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		_margin.add_theme_constant_override(side, UiStyle.BANK_MARGIN)
	_content.add_theme_constant_override("separation", UiStyle.BANK_SECTION_SEPARATION)
	_main.add_theme_constant_override("separation", UiStyle.BANK_SECTION_SEPARATION)
	_grid.add_theme_constant_override("h_separation", UiStyle.BANK_GRID_SEPARATION)
	_grid.add_theme_constant_override("v_separation", UiStyle.BANK_GRID_SEPARATION)
	_title_label.text = TITLE_TEXT
	_full_label.text = FULL_TEXT
	_full_label.add_theme_color_override("font_color", UiStyle.BAD)
	_full_label.visible = false
	_message_label.add_theme_color_override("font_color", UiStyle.BAD)
	_empty_label.text = EMPTY_TEXT
	_search_edit.placeholder_text = SEARCH_PLACEHOLDER
	_search_edit.custom_minimum_size.x = UiStyle.BANK_SEARCH_WIDTH
	_search_edit.text_changed.connect(_on_search_edit_text_changed)
	_sort_button.text = SORT_TEXT
	_sort_button.tooltip_text = SORT_TOOLTIP
	_sort_button.pressed.connect(_on_sort_button_pressed)
	_item_panel.lock_requested.connect(_on_item_panel_lock_requested)
	_item_panel.sell_requested.connect(_on_item_panel_sell_requested)
	_item_panel.food_requested.connect(_on_item_panel_food_requested)
	_item_panel.infusion_socket_requested.connect(_on_item_panel_infusion_socket_requested)
	_item_panel.stone_socket_requested.connect(_on_item_panel_stone_socket_requested)
	_item_panel.close_requested.connect(_on_item_panel_close_requested)
	_item_panel.bag_requested.connect(_on_item_panel_bag_requested)
	_item_panel.hire_requested.connect(_on_item_panel_hire_requested)
	_bag_bar.equip_requested.connect(_on_bag_equip_requested)
	_bag_bar.unequip_requested.connect(_on_bag_unequip_requested)
	_grid.set_drag_forwarding(Callable(), _can_drop_on_grid, _drop_on_grid)


## Draws the bank of `session` and follows its changes.
func bind(session: GameSession) -> void:
	unbind()
	_session = session
	HelpButton.attach(_title_label.get_parent(), session.data, &"bank")
	_session.events.bank_changed.connect(_on_events_bank_changed)
	_session.events.deposit_changed.connect(_on_events_deposit_changed)
	_session.events.bags_changed.connect(_on_events_bags_changed)
	_session.events.equipment_changed.connect(_on_events_equipment_changed)
	_session.events.food_changed.connect(_on_events_food_changed)
	_redraw()


## Disconnects every event connected in `bind`.
func unbind() -> void:
	if _session != null and is_instance_valid(_session):
		var events: GameEvents = _session.events
		for connection: Array in [[events.bank_changed, _on_events_bank_changed],
				[events.deposit_changed, _on_events_deposit_changed], [events.bags_changed, _on_events_bags_changed],
				[events.equipment_changed, _on_events_equipment_changed], [events.food_changed, _on_events_food_changed]]:
			var event: Signal = connection[0]
			if event.is_connected(connection[1]):
				event.disconnect(connection[1])
	_session = null
	if _item_panel != null:
		_item_panel.clear()


func _exit_tree() -> void:
	unbind()


func _redraw() -> void:
	if _session == null:
		return
	_redraw_cells()
	_redraw_counter()
	_bag_bar.redraw(_session)
	_tabs.redraw(_session)
	if _item_panel.item_id() != &"":
		_item_panel.show_item(_session, _item_panel.item_id())
	_refresh_hovered_tooltip()


## One cell per stack that matches the search, in the bank's order, then (with no search) up to the capacity one
## `OccupiedCell` per box the Armory pieces use and one `EmptyCell` per free box: existing cells are reused, extra ones
## removed. Placeholders hold no data (they are decorative drop targets).
func _redraw_cells() -> void:
	var stacks: Array[Dictionary] = _shown_stacks()
	var searching: bool = not _search_edit.text.strip_edges().is_empty()
	var occupied: int = 0 if searching else maxi(0, _session.deposit.used() - stacks.size())
	var empty_slots: int = 0 if searching else _session.deposit.free_slots()
	var total: int = stacks.size() + occupied + empty_slots
	var cells: Array[Node] = _grid.get_children()
	for index: int in range(total, cells.size()):
		_grid.remove_child(cells[index])
		cells[index].queue_free()
	for index: int in total:
		var cell: ItemSlotView = cells[index] as ItemSlotView if index < cells.size() else _new_cell(index)
		cell.modulate = Color.WHITE
		cell.tooltip_text = ""
		if index < stacks.size():
			var stack: Dictionary = stacks[index]
			cell.name = CELL_NAME % index
			cell.set_item(_session.data.item(stack[STACK_ITEM_KEY]), stack[STACK_COUNT_KEY], stack[STACK_LOCKED_KEY])
		else:
			cell.clear()
			if index < stacks.size() + occupied:
				cell.name = OCCUPIED_CELL_NAME % index
				cell.modulate = UiStyle.DEPOSIT_OCCUPIED_MODULATE
				cell.tooltip_text = OCCUPIED_TOOLTIP
			else:
				cell.name = EMPTY_CELL_NAME % index
	_empty_label.text = EMPTY_TEXT if _session.bank.used() == 0 else NO_MATCH_TEXT
	_empty_label.visible = stacks.is_empty()


## The stacks of the bank whose item name contains the search text (case-insensitive); all with an empty search.
func _shown_stacks() -> Array[Dictionary]:
	var stacks: Array[Dictionary] = _session.bank.stacks()
	var query: String = _search_edit.text.strip_edges()
	if query.is_empty():
		return stacks
	var shown: Array[Dictionary] = []
	for stack: Dictionary in stacks:
		var item: ItemDef = _session.data.item(stack[STACK_ITEM_KEY])
		if item != null and item.name.findn(query) != -1:
			shown.append(stack)
	return shown


func _new_cell(index: int) -> ItemSlotView:
	var cell: ItemSlotView = ITEM_SLOT_SCENE.instantiate() as ItemSlotView
	cell.name = CELL_NAME % index
	cell.custom_minimum_size = UiStyle.BANK_CELL_SIZE
	_grid.add_child(cell)
	cell.pressed.connect(_on_cell_pressed)
	cell.mouse_entered.connect(_on_cell_mouse_entered.bind(cell))
	cell.mouse_exited.connect(_on_cell_mouse_exited.bind(cell))
	cell.set_drag_forwarding(_cell_drag_data.bind(cell), _can_drop_on_cell.bind(cell), _drop_on_cell.bind(cell))
	return cell


func _redraw_counter() -> void:
	var used: int = _session.deposit.used()
	var capacity: int = _session.deposit.capacity()
	_slots_label.text = SLOTS_TEXT % [NumberFormat.format_int(used), NumberFormat.format_int(capacity)]
	_full_label.visible = used >= capacity


## The tooltip of the hovered cell shows what the cell holds now (another quantity or, after a move, another item).
func _refresh_hovered_tooltip() -> void:
	if _hovered_cell == null:
		return
	if not is_instance_valid(_hovered_cell) or _hovered_cell.is_queued_for_deletion() \
			or _hovered_cell.item_id() == &"":
		_hovered_cell = null
		Tooltips.hide_tooltip()
		return
	var item_id: StringName = _hovered_cell.item_id()
	Tooltips.show_item(_session.data.item(item_id), _session.bank.get_count(item_id), get_global_mouse_position())


func _show_result(result: CommandResult) -> void:
	var text: String = ""
	if not result.ok:
		text = REFUSED_TEXTS.get(result.reason, REFUSED_TEXT_DEFAULT)
	_message_label.text = text
	_message_label.visible = not result.ok


## Moves the stack of `item_id` to `new_index` through the bank; a refused move changes nothing.
func _move(item_id: StringName, new_index: int) -> void:
	if _session != null:
		_show_result(_session.bank.move_stack(item_id, new_index))


## Index of `item_id` in the bank's order now; -1 if it is not in the bank.
func _bank_index(item_id: StringName) -> int:
	var stacks: Array[Dictionary] = _session.bank.stacks()
	for index: int in stacks.size():
		if stacks[index][STACK_ITEM_KEY] == item_id:
			return index
	return -1


func _cell_drag_data(_at_position: Vector2, cell: ItemSlotView) -> Variant:
	if _session == null or cell.item_id() == &"":
		return null
	Tooltips.hide_tooltip()
	var preview: TextureRect = TextureRect.new()
	preview.texture = ItemSlotView.icon_of(_session.data.item(cell.item_id()).icon)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.size = UiStyle.BANK_CELL_SIZE
	cell.set_drag_preview(preview)
	return {DRAG_KIND_KEY: DRAG_KIND, DRAG_ITEM_KEY: cell.item_id()}


func _can_drop_on_cell(_at_position: Vector2, data: Variant, cell: ItemSlotView) -> bool:
	return _is_stack_drag(data)


func _drop_on_cell(_at_position: Vector2, data: Variant, cell: ItemSlotView) -> void:
	if _session != null:
		var target: int = _bank_index(cell.item_id()) if cell.item_id() != &"" else _session.bank.used() - 1
		_move((data as Dictionary)[DRAG_ITEM_KEY], target)


func _can_drop_on_grid(_at_position: Vector2, data: Variant) -> bool:
	return _is_stack_drag(data)


## Dropped on the grid outside the cells (after the last one, or in the spacing): the stack goes last.
func _drop_on_grid(_at_position: Vector2, data: Variant) -> void:
	if _session != null:
		_move((data as Dictionary)[DRAG_ITEM_KEY], _session.bank.used() - 1)


func _is_stack_drag(data: Variant) -> bool:
	if _session == null or typeof(data) != TYPE_DICTIONARY:
		return false
	var drag: Dictionary = data
	return drag.get(DRAG_KIND_KEY, &"") == DRAG_KIND and drag.get(DRAG_ITEM_KEY) is StringName


func _on_cell_pressed(item_id: StringName) -> void:
	if _session != null:
		_message_label.visible = false
		_item_panel.show_item(_session, item_id)


func _on_cell_mouse_entered(cell: ItemSlotView) -> void:
	_hovered_cell = cell


func _on_cell_mouse_exited(cell: ItemSlotView) -> void:
	if _hovered_cell == cell:
		_hovered_cell = null


func _on_item_panel_lock_requested(item_id: StringName, locked: bool) -> void:
	if _session != null:
		_show_result(_session.bank.set_locked(item_id, locked))


func _on_item_panel_sell_requested(item_id: StringName, qty: int) -> void:
	if _session != null:
		_show_result(_session.shop.sell(item_id, qty))


func _on_item_panel_food_requested(item_id: StringName) -> void:
	if _session != null:
		_show_result(_session.equipment.set_food(item_id))


## "Incastona" on an infusion: the first free socket of the Altar; the reason of a refusal is shown in Italian.
func _on_item_panel_infusion_socket_requested(item_id: StringName) -> void:
	if _session == null:
		return
	for i: int in _session.rift.socket_total():
		if _session.rift.is_unlocked(i) and _session.rift.get_socket(i) == &"":
			_show_text(_session.rift.socket(i, item_id), RiftTexts.refused)
			return
	_message_label.text = RiftTexts.NO_FREE_SOCKET_TEXT
	_message_label.visible = true


## "Incastona" on a stone: the piece chosen in the panel.
func _on_item_panel_stone_socket_requested(item_id: StringName, uid: int) -> void:
	if _session != null:
		_show_text(_session.armory.socket_stone(uid, item_id), SocketTexts.refused)


func _show_text(result: CommandResult, worded: Callable) -> void:
	_message_label.text = "" if result.ok else worded.call(result.reason) as String
	_message_label.visible = not result.ok


func _on_item_panel_close_requested() -> void:
	_item_panel.clear()


func _on_sort_button_pressed() -> void:
	if _session != null:
		_message_label.visible = false
		_session.bank.sort_stacks()


func _on_search_edit_text_changed(_new_text: String) -> void:
	_redraw()


func _on_events_bank_changed(_item_id: StringName, _new_count: int, _delta: int) -> void:
	_redraw()


func _on_events_deposit_changed(_used: int, _capacity: int) -> void:
	_redraw()


func _on_events_equipment_changed(_slot_id: StringName, _uid: int) -> void:
	_redraw()


func _on_events_food_changed(_item_id: StringName) -> void:
	_redraw()


func _on_events_bags_changed() -> void:
	_redraw()


## "Metti nello slot" on a bag: the first free bag slot.
func _on_item_panel_bag_requested(item_id: StringName) -> void:
	if _session != null:
		var slot: int = _session.deposit.bags().find(&"")
		if slot >= 0:
			_on_bag_equip_requested(slot, item_id)
		else:
			_show_text(CommandResult.fail(Reasons.BAG_SLOT_OCCUPIED), func(_r: StringName) -> String: return BagTexts.NO_FREE_SLOT_TEXT)


func _on_bag_equip_requested(slot_index: int, item_id: StringName) -> void:
	if _session != null:
		_show_text(_session.bank.equip_bag(slot_index, item_id), BagTexts.refused)


func _on_bag_unequip_requested(slot_index: int) -> void:
	if _session != null:
		_show_text(_session.bank.unequip_bag(slot_index), BagTexts.refused)


func _on_item_panel_hire_requested(item_id: StringName) -> void:
	if _session != null:
		_show_text(_session.helpers.hire(item_id), HelperTexts.refused)
