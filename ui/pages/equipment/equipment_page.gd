class_name EquipmentPage
extends Page
## Equipment page (docs/UI_GDR.md §3, route `equipment`), the Armory and the equipment in one place: the inventory
## (pieces of `armory.instances()` not worn, filters by slot and rarity, capacity), the paper doll with the 12 slots
## and the stats with the selected piece on the right.
##
## Every redraw reads the session: pieces and capacity from the armory, the worn uids from `equipment`, the final
## values from `modifiers`. The page keeps the session reference, its nodes and presentation state only (the two
## filters, the uid of the selected piece, whether a tooltip is up). Player actions are commands (`equipment.equip` /
## `unequip` / `set_food`, `armory.set_locked`, `shop.sell_instance`); a refused command shows its reason in Italian
## and changes nothing. Interactions: drag a piece from the inventory onto a slot (only the compatible slots light up,
## `EquipTargets`), drag a worn piece back to the inventory (Rimuovi), right click (equip / second hand / Rimuovi),
## left click (select).

const INVENTORY_TITLE_TEXT: String = "Inventario"
const STATS_TITLE_TEXT: String = "Statistiche"
const FULL_TEXT: String = "Armeria piena"
const ALL_SLOTS_TEXT: String = "Tutti gli slot"
const ALL_RARITIES_TEXT: String = "Tutte le rarità"
const EMPTY_TEXT: String = "L'Armeria è vuota: forgia o compra dei pezzi."
const NO_MATCH_TEXT: String = "Nessun pezzo corrisponde ai filtri."
const HINT_TEXT: String = "Trascina un pezzo sullo slot. Tasto destro: equipaggia (una spada va nella seconda mano se è libera), " \
		+ "oppure Rimuovi su uno slot pieno. Clic: seleziona."
const LEVEL_TEXT: String = "Livello %s  ·  Assetto: %s"
const UNARMED_TEXT: String = "Mani nude"
const NO_FOOD_TEXT: String = "Nessun cibo scelto"
const FOOD_TEXT: String = "Cibo: %s (in bank: %s)"
const CLEAR_FOOD_TEXT: String = "Togli"
const REFUSED_TEXTS: Dictionary[StringName, String] = {
	Reasons.UNKNOWN_ID: "Il pezzo non è più nell'Armeria.",
	Reasons.NOT_EQUIPPABLE: "Questo pezzo non si può mettere in quello slot.",
	Reasons.REQUIREMENT_NOT_MET: "Requisiti non soddisfatti.",
	Reasons.COMBAT_ACTIVE: "Non puoi cambiare arma durante il combattimento.",
	Reasons.ARMORY_FULL: "L'Armeria è piena: non c'è posto per i pezzi che tornano indietro.",
	Reasons.SLOT_EMPTY: "Lo slot è già vuoto.",
	Reasons.ITEM_LOCKED: "Il pezzo è bloccato: sbloccalo per venderlo.",
	Reasons.ITEM_EQUIPPED: "Il pezzo è indossato: rimuovilo prima di venderlo.",
	Reasons.NOT_SELLABLE: "Questo pezzo non si vende.",
	Reasons.NOT_FOOD: "Questo oggetto non è un cibo.",
	Reasons.NOT_ENOUGH_ITEMS: "Non ci sono abbastanza oggetti.",
}
const REFUSED_TEXT_DEFAULT: String = "Operazione non riuscita."
const CELL_NAME: String = "Cell%d"
const CELL_SCENE: PackedScene = preload("res://ui/pages/equipment/inventory_cell.tscn")
const FILTER_ALL: StringName = &""
const SECTION_SEPARATION: int = 12

var _session: GameSession = null
## Presentation state: filters ("" = all), the piece shown in the panel and whether a tooltip is up.
var _slot_filter: StringName = FILTER_ALL
var _rarity_filter: StringName = FILTER_ALL
var _selected_uid: int = 0
var _hovering: bool = false

@onready var _margin: MarginContainer = %Margin
@onready var _main: HBoxContainer = %Main
@onready var _inventory_title: Label = %InventoryTitle
@onready var _capacity_label: Label = %CapacityLabel
@onready var _slot_option: OptionButton = %SlotFilter
@onready var _rarity_option: OptionButton = %RarityFilter
@onready var _full_label: Label = %FullLabel
@onready var _empty_label: Label = %EmptyLabel
@onready var _scroll: InventoryScroll = %Scroll
@onready var _grid: HFlowContainer = %Grid
@onready var _hint_label: Label = %HintLabel
@onready var _class_label: Label = %ClassLabel
@onready var _setup_label: Label = %SetupLabel
@onready var _doll: EquipmentDoll = %Doll
@onready var _message_label: Label = %MessageLabel
@onready var _stats_title: Label = %StatsTitle
@onready var _stats_text: RichTextLabel = %StatsText
@onready var _food_label: Label = %FoodLabel
@onready var _clear_food_button: Button = %ClearFoodButton
@onready var _panel: PiecePanel = %PiecePanel


func _ready() -> void:
	for side: String in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		_margin.add_theme_constant_override(side, UiStyle.ARMORY_MARGIN)
	_main.add_theme_constant_override("separation", SECTION_SEPARATION)
	_grid.add_theme_constant_override("h_separation", UiStyle.ARMORY_GRID_SEPARATION)
	_grid.add_theme_constant_override("v_separation", UiStyle.ARMORY_GRID_SEPARATION)
	_inventory_title.text = INVENTORY_TITLE_TEXT
	_stats_title.text = STATS_TITLE_TEXT
	_hint_label.text = HINT_TEXT
	_full_label.text = FULL_TEXT
	_full_label.add_theme_color_override("font_color", UiStyle.BAD)
	_message_label.add_theme_color_override("font_color", UiStyle.BAD)
	_clear_food_button.text = CLEAR_FOOD_TEXT
	_clear_food_button.pressed.connect(_on_clear_food_pressed)
	_slot_option.item_selected.connect(_on_slot_filter_selected)
	_rarity_option.item_selected.connect(_on_rarity_filter_selected)
	_scroll.unequip_dropped.connect(_on_unequip_requested)
	_stats_text.mouse_entered.connect(_on_stats_hover)
	_stats_text.mouse_exited.connect(_hide_tooltip)
	_panel.equip_requested.connect(_on_panel_equip_requested)
	_panel.unequip_requested.connect(_on_unequip_requested)
	_panel.lock_requested.connect(_on_panel_lock_requested)
	_panel.sell_requested.connect(_on_panel_sell_requested)
	_panel.close_requested.connect(_on_panel_close_requested)


## Draws the equipment of `session` and follows its changes.
func bind(session: GameSession) -> void:
	unbind()
	_session = session
	var events: GameEvents = _session.events
	for sig: Signal in _signals(events):
		sig.connect(_redraw_from_event)
	_build_filters()
	_doll.build(func(slot: StringName) -> String: return EquipmentStatsText.slot_text(slot, _session.data))
	for view: EquipmentSlotView in _doll.slot_views():
		view.pressed.connect(_on_slot_pressed)
		view.right_clicked.connect(_on_slot_right_clicked)
		view.piece_dropped.connect(_on_slot_dropped)
		view.hover_started.connect(_on_slot_hover_started)
		view.hover_ended.connect(_hide_tooltip)
	_redraw()


## Disconnects every event connected in `bind`.
func unbind() -> void:
	if _session != null and is_instance_valid(_session):
		for sig: Signal in _signals(_session.events):
			if sig.is_connected(_redraw_from_event):
				sig.disconnect(_redraw_from_event)
	_hide_tooltip()
	_session = null
	_selected_uid = 0


func _exit_tree() -> void:
	unbind()


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN:
		show_drag_targets(get_viewport().gui_get_drag_data())
	elif what == NOTIFICATION_DRAG_END:
		clear_drag_targets()


## Lights the slots that accept the dragged piece `data` (a `PieceDrag` payload from the inventory); none otherwise.
func show_drag_targets(data: Variant) -> void:
	if _session == null:
		return
	_hide_tooltip()
	var targets: Array[StringName] = []
	if PieceDrag.is_piece(data) and PieceDrag.from_of(data) == &"":
		targets = EquipTargets.compatible_slots(_session, PieceDrag.uid_of(data))
	for view: EquipmentSlotView in _doll.slot_views():
		view.set_glow(targets.has(view.slot()))


func clear_drag_targets() -> void:
	for view: EquipmentSlotView in _doll.slot_views():
		view.set_glow(false)


## The events that make the page read the session again.
func _signals(events: GameEvents) -> Array[Signal]:
	return [events.armory_changed, events.armory_capacity_changed, events.equipment_changed,
			events.character_level_up, events.modifiers_changed, events.food_changed, events.bank_changed]


# --- Filters ----------------------------------------------------------------------------------------------------

func _build_filters() -> void:
	_slot_filter = FILTER_ALL
	_rarity_filter = FILTER_ALL
	_slot_option.clear()
	_slot_option.add_item(ALL_SLOTS_TEXT)
	_slot_option.set_item_metadata(0, FILTER_ALL)
	for slot: StringName in Equipment.SLOTS:
		_slot_option.add_item(EquipmentStatsText.slot_text(slot, _session.data))
		_slot_option.set_item_metadata(_slot_option.item_count - 1, slot)
	_rarity_option.clear()
	_rarity_option.add_item(ALL_RARITIES_TEXT)
	_rarity_option.set_item_metadata(0, FILTER_ALL)
	for rarity: StringName in ItemInstance.RARITIES:
		_rarity_option.add_item(ArmoryTexts.rarity_name(rarity))
		_rarity_option.set_item_metadata(_rarity_option.item_count - 1, rarity)
	_slot_option.select(0)
	_rarity_option.select(0)


func _on_slot_filter_selected(index: int) -> void:
	_slot_filter = _slot_option.get_item_metadata(index)
	_redraw()


func _on_rarity_filter_selected(index: int) -> void:
	_rarity_filter = _rarity_option.get_item_metadata(index)
	_redraw()


# --- Redraw (reads the session) ---------------------------------------------------------------------------------

func _redraw_from_event(_a: Variant = null, _b: Variant = null, _c: Variant = null) -> void:
	_redraw()


func _redraw() -> void:
	if _session == null:
		return
	var used: int = _session.armory.used()
	var capacity: int = _session.armory.capacity()
	var worn: int = 0
	for slot: StringName in Equipment.SLOTS:
		worn += 1 if _session.equipment.get_uid(slot) != 0 else 0
	_capacity_label.text = ArmoryTexts.capacity_text(used, capacity, worn)
	_full_label.visible = used >= capacity
	_rebuild_grid()
	_redraw_doll()
	_redraw_side()
	if _selected_uid != 0 and not _panel.show_piece(_session, _selected_uid):
		_selected_uid = 0


func _rebuild_grid() -> void:
	_hide_tooltip()
	for child: Node in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	var all_pieces: Array[ItemInstance] = _session.armory.instances()
	var shown: int = 0
	for inst: ItemInstance in all_pieces:
		var base: ItemDef = _session.data.item(inst.base_id)
		if _session.armory.is_worn(inst.uid) or base == null or base.equip == null or not _passes_filters(inst, base):
			continue
		var cell: InventoryCell = CELL_SCENE.instantiate() as InventoryCell
		cell.name = CELL_NAME % inst.uid
		_grid.add_child(cell)
		cell.set_piece(inst, base, inst.uid == _selected_uid)
		cell.pressed.connect(_on_cell_pressed)
		cell.right_clicked.connect(_on_cell_right_clicked)
		cell.unequip_dropped.connect(_on_unequip_requested)
		cell.hover_started.connect(_on_cell_hover_started)
		cell.hover_ended.connect(_hide_tooltip)
		shown += 1
	_empty_label.visible = shown == 0
	_empty_label.text = EMPTY_TEXT if all_pieces.is_empty() else NO_MATCH_TEXT


func _passes_filters(inst: ItemInstance, base: ItemDef) -> bool:
	if _slot_filter != FILTER_ALL and base.equip.slot != _slot_filter:
		return false
	return _rarity_filter == FILTER_ALL or inst.rarity == _rarity_filter


func _redraw_doll() -> void:
	var class_def: ClassDef = _session.character.class_def()
	_class_label.text = class_def.name if class_def != null else ""
	var setup: SetupDef = _session.equipment.setup_def()
	_setup_label.text = LEVEL_TEXT % [NumberFormat.format_int(_session.character.get_level()),
			setup.name if setup != null else UNARMED_TEXT]
	for view: EquipmentSlotView in _doll.slot_views():
		var inst: ItemInstance = _session.armory.get_instance(_session.equipment.get_uid(view.slot()))
		var base: ItemDef = _session.data.item(inst.base_id) if inst != null else null
		if base == null:
			view.show_empty()
		else:
			view.show_piece(inst, base)


func _redraw_side() -> void:
	_stats_text.text = EquipmentStatsText.totals(_session)
	var food_id: StringName = _session.equipment.get_food()
	var food: ItemDef = _session.data.item(food_id) if food_id != &"" else null
	_clear_food_button.disabled = food == null
	_food_label.text = NO_FOOD_TEXT if food == null else FOOD_TEXT % [food.name,
			NumberFormat.format_int(_session.bank.get_count(food_id))]


# --- Selection, tooltips ----------------------------------------------------------------------------------------

func _on_cell_pressed(uid: int) -> void:
	_select(uid)


func _on_slot_pressed(slot: StringName) -> void:
	_select(_session.equipment.get_uid(slot) if _session != null else 0)


func _select(uid: int) -> void:
	if uid != 0:
		_selected_uid = uid
		_redraw()


func _on_cell_hover_started(uid: int) -> void:
	_show_piece_tooltip(uid)


func _on_slot_hover_started(slot: StringName) -> void:
	if _session != null:
		_show_piece_tooltip(_session.equipment.get_uid(slot))


func _show_piece_tooltip(uid: int) -> void:
	var body: String = ArmoryTexts.tooltip_text(_session, uid) if _session != null and uid != 0 else ""
	if body.is_empty():
		return
	_hovering = true
	Tooltips.show_text("", body, get_global_mouse_position())


func _on_stats_hover() -> void:
	if _session != null:
		_hovering = true
		Tooltips.show_text("", EquipmentStatsText.summary(_session), get_global_mouse_position())


func _hide_tooltip() -> void:
	if _hovering:
		_hovering = false
		Tooltips.hide_tooltip()


# --- Commands ---------------------------------------------------------------------------------------------------

## Sends the command built by `command` and shows its reason if it is refused (nothing changes then).
func _send(command: Callable) -> void:
	if _session == null:
		return
	var result: CommandResult = command.call() as CommandResult
	_message_label.visible = not result.ok
	if not result.ok:
		_message_label.text = REFUSED_TEXTS.get(result.reason, REFUSED_TEXT_DEFAULT)
	_redraw()


func _equip(uid: int, slot: StringName) -> void:
	_send(func() -> CommandResult: return _session.equipment.equip(uid, slot))


func _on_cell_right_clicked(uid: int) -> void:
	if _session != null:
		_equip(uid, EquipTargets.right_click_slot(_session, uid))


func _on_slot_dropped(slot: StringName, uid: int) -> void:
	clear_drag_targets()
	_equip(uid, slot)


func _on_unequip_requested(slot: StringName) -> void:
	_send(func() -> CommandResult: return _session.equipment.unequip(slot))


func _on_panel_equip_requested(uid: int, slot: StringName) -> void:
	_equip(uid, slot)


func _on_panel_lock_requested(uid: int, locked: bool) -> void:
	_send(func() -> CommandResult: return _session.armory.set_locked(uid, locked))


func _on_panel_sell_requested(uid: int) -> void:
	_send(func() -> CommandResult: return _session.shop.sell_instance(uid))


func _on_panel_close_requested() -> void:
	_selected_uid = 0
	_panel.clear()
	_redraw()


func _on_slot_right_clicked(slot: StringName) -> void:
	if _session != null and _session.equipment.get_uid(slot) != 0:
		_on_unequip_requested(slot)


func _on_clear_food_pressed() -> void:
	_send(func() -> CommandResult: return _session.equipment.set_food(&""))
