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
const HINT_TEXT: String = "Trascina un pezzo sullo slot. Tasto destro: equipaggia (una spada va nella seconda mano se è libera), " \
		+ "oppure Rimuovi su uno slot pieno. Clic: seleziona."
const FILTER_TEXT: String = "Filtro"
const FILTER_ALL: StringName = EquipmentInventory.FILTER_ALL
const SECTION_SEPARATION: int = 12

var _session: GameSession = null
## Presentation state: filters ("" = all), the piece shown in the panel and whether a tooltip is up.
var _slot_filter: StringName = FILTER_ALL
var _rarity_filter: StringName = FILTER_ALL
var _selected_uid: int = 0
var _hovering: bool = false
## Whether the automatic filter is shown in place of the inventory grid.
var _filter_open: bool = false

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
@onready var _panel: PiecePanel = %PiecePanel
@onready var _filter_toggle: Button = %FilterToggle
@onready var _filter_panel: FilterPanel = %FilterPanel


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
	_panel.salvage_requested.connect(_on_panel_salvage_requested)
	_filter_toggle.text = FILTER_TEXT
	_filter_toggle.toggled.connect(_on_filter_toggled)
	_filter_panel.rule_changed.connect(_on_filter_rule_changed)


## Draws the equipment of `session` and follows its changes.
func bind(session: GameSession) -> void:
	unbind()
	_session = session
	HelpButton.attach(_inventory_title.get_parent(), session.data, &"equipment")
	var events: GameEvents = _session.events
	for sig: Signal in _signals(events):
		sig.connect(_redraw_from_event)
	_session.events.item_salvaged.connect(_on_item_salvaged)
	_build_filters()
	_doll.build(func(slot: StringName) -> String: return EquipmentStatsText.doll_text(slot, _session.data))
	for view: EquipmentSlotView in _doll.slot_views():
		view.pressed.connect(_on_slot_pressed)
		view.right_clicked.connect(_on_slot_right_clicked)
		view.piece_dropped.connect(_on_slot_dropped)
		view.hover_started.connect(_on_slot_hover_started)
		view.hover_ended.connect(_hide_tooltip)
	_doll.food_slot().open_requested.connect(_on_food_open_requested)
	_doll.food_slot().food_chosen.connect(_on_food_chosen)
	_doll.food_slot().clear_requested.connect(_on_clear_food_pressed)
	_redraw()


## Disconnects every event connected in `bind`.
func unbind() -> void:
	if _session != null and is_instance_valid(_session):
		for sig: Signal in _signals(_session.events):
			if sig.is_connected(_redraw_from_event):
				sig.disconnect(_redraw_from_event)
		var events: GameEvents = _session.events
		if events.item_salvaged.is_connected(_on_item_salvaged):
			events.item_salvaged.disconnect(_on_item_salvaged)
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
	EquipmentSide.light_targets(_session, _doll, data)


func clear_drag_targets() -> void:
	for view: EquipmentSlotView in _doll.slot_views():
		view.set_glow(false)


## The events that make the page read the session again.
func _signals(events: GameEvents) -> Array[Signal]:
	return [events.armory_changed, events.deposit_changed, events.equipment_changed,
			events.character_level_up, events.modifiers_changed, events.food_changed, events.bank_changed,
			events.item_upgraded, events.item_salvaged]


# --- Filters ----------------------------------------------------------------------------------------------------

func _build_filters() -> void:
	_slot_filter = FILTER_ALL
	_rarity_filter = FILTER_ALL
	EquipmentInventory.build_filters(_session, _slot_option, _rarity_option)


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
	_capacity_label.text = EquipmentSide.capacity_label_text(_session)
	_full_label.visible = _session.deposit.used() >= _session.deposit.capacity()
	_hide_tooltip()
	EquipmentInventory.rebuild_grid(_session, _grid, _empty_label, _slot_filter, _rarity_filter, _selected_uid, {
		"pressed": _on_cell_pressed, "right_clicked": _on_cell_right_clicked,
		"unequip_dropped": _on_unequip_requested, "hover_started": _on_cell_hover_started,
		"hover_ended": _hide_tooltip})
	EquipmentSide.redraw_doll(_session, _doll, _class_label, _setup_label)
	EquipmentSide.redraw_side(_session, _stats_text)
	EquipmentSide.redraw_food(_session, _doll.food_slot())
	if _selected_uid != 0 and not _panel.show_piece(_session, _selected_uid):
		_selected_uid = 0
	_apply_filter_view()



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
func _send(command: Callable, refused_text: Callable = Callable()) -> void:
	if _session == null:
		return
	_message_label.visible = false
	var result: CommandResult = command.call() as CommandResult
	if not result.ok:
		_message_label.visible = true
		_message_label.add_theme_color_override("font_color", UiStyle.BAD)
		var worded: Callable = EquipmentMessages.refused if refused_text.is_null() else refused_text
		_message_label.text = worded.call(result.reason) as String
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
	var is_tool: bool = slot.begins_with(EquipmentStatsText.TOOL_SLOT_PREFIX)
	if _session != null and _session.equipment.get_uid(slot) != 0 and not is_tool:
		_on_unequip_requested(slot)


func _on_clear_food_pressed() -> void:
	_send(func() -> CommandResult: return _session.equipment.set_food(&""))


# --- Salvage, automatic filter ----------------------------------------------------------------------------------

func _on_panel_salvage_requested(uid: int) -> void:
	_send(func() -> CommandResult: return _session.armory.salvage(uid))


## The filter rules are rewritten from the armory at every opening (no signal, 05 §5.17).
func _on_filter_toggled(open: bool) -> void:
	_filter_open = open
	_redraw()


func _on_filter_rule_changed(slot: StringName, min_rarity: StringName, min_grade: int) -> void:
	_send(func() -> CommandResult: return _session.armory.set_filter(slot, min_rarity, min_grade))


## Shows the filter panel in place of the grid while it is open, rereading the rules.
func _apply_filter_view() -> void:
	_filter_toggle.text = INVENTORY_TITLE_TEXT if _filter_open else FILTER_TEXT
	_filter_toggle.set_pressed_no_signal(_filter_open)
	_filter_panel.visible = _filter_open
	_scroll.visible = not _filter_open
	_hint_label.visible = _scroll.visible
	if _filter_open:
		_empty_label.visible = false
		_filter_panel.refresh(_session)


func _on_item_salvaged(_uid: int, base_id: StringName, auto: bool) -> void:
	_notify(EquipmentMessages.salvaged_text(_session, base_id, auto), true)


func _notify(text: String, good: bool) -> void:
	_message_label.text = text
	_message_label.add_theme_color_override("font_color", UiStyle.GOOD if good else UiStyle.GOLD_LIGHT)
	_message_label.visible = true


# --- Food slot ----------------------------------------------------------------------------------------------------

func _on_food_open_requested() -> void:
	if _session != null:
		_doll.food_slot().open_menu(EquipmentSide.food_choices(_session))


func _on_food_chosen(item_id: StringName) -> void:
	_send(func() -> CommandResult: return _session.equipment.set_food(item_id))
