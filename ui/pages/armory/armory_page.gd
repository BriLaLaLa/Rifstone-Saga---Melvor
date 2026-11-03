class_name ArmoryPage
extends Page
## Armory page (docs/01_GDD.md §21-22), route `armory`: a grid with one cell per piece of `armory.instances()`
## (rarity border, "+N", lock and worn markers), filters by slot and rarity, the capacity `used / capacity` and the
## piece panel (ArmoryItemPanel) with the buttons that equip, remove, lock and sell the selected piece.
##
## Every redraw reads the session: the pieces from `armory.instances()`, the counter from `armory.used()` and
## `armory.capacity()`, the worn state from `armory.is_worn`. The page keeps only the session reference, its nodes
## and presentation state (the two filters, the uid of the selected piece). Player actions are commands:
## `equipment.equip` / `unequip`, `armory.set_locked`, `shop.sell_instance`; a refused command shows its reason in
## Italian. It redraws on `armory_changed`, `armory_capacity_changed`, `equipment_changed` and `character_level_up`
## (requirements); everything is disconnected in `unbind`.

const TITLE_TEXT: String = "Armeria"
const FULL_TEXT: String = "Armeria piena"
const ALL_SLOTS_TEXT: String = "Tutti gli slot"
const ALL_RARITIES_TEXT: String = "Tutte le rarità"
const EMPTY_TEXT: String = "L'Armeria è vuota: forgia o compra dei pezzi."
const NO_MATCH_TEXT: String = "Nessun pezzo corrisponde ai filtri."
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
}
const REFUSED_TEXT_DEFAULT: String = "Operazione non riuscita."
const CELL_NAME: String = "Cell%d"
const CELL_SCENE: PackedScene = preload("res://ui/pages/armory/armory_cell.tscn")
const FILTER_ALL: StringName = &""

var _session: GameSession = null
## Presentation state: filters ("" = all) and the piece shown in the panel.
var _slot_filter: StringName = FILTER_ALL
var _rarity_filter: StringName = FILTER_ALL
var _selected_uid: int = 0
var _hovering: bool = false

@onready var _margin: MarginContainer = %Margin
@onready var _content: VBoxContainer = %Content
@onready var _main: HBoxContainer = %Main
@onready var _title_label: Label = %TitleLabel
@onready var _slot_option: OptionButton = %SlotFilter
@onready var _rarity_option: OptionButton = %RarityFilter
@onready var _capacity_label: Label = %CapacityLabel
@onready var _full_label: Label = %FullLabel
@onready var _message_label: Label = %MessageLabel
@onready var _grid: HFlowContainer = %Grid
@onready var _empty_label: Label = %EmptyLabel
@onready var _item_panel: ArmoryItemPanel = %ItemPanel


func _ready() -> void:
	for side: String in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		_margin.add_theme_constant_override(side, UiStyle.ARMORY_MARGIN)
	_content.add_theme_constant_override("separation", UiStyle.ARMORY_SECTION_SEPARATION)
	_main.add_theme_constant_override("separation", UiStyle.ARMORY_SECTION_SEPARATION)
	_grid.add_theme_constant_override("h_separation", UiStyle.ARMORY_GRID_SEPARATION)
	_grid.add_theme_constant_override("v_separation", UiStyle.ARMORY_GRID_SEPARATION)
	_title_label.text = TITLE_TEXT
	_full_label.text = FULL_TEXT
	_full_label.add_theme_color_override("font_color", UiStyle.BAD)
	_message_label.add_theme_color_override("font_color", UiStyle.BAD)
	_slot_option.custom_minimum_size.x = UiStyle.ARMORY_FILTER_WIDTH
	_rarity_option.custom_minimum_size.x = UiStyle.ARMORY_FILTER_WIDTH
	_slot_option.item_selected.connect(_on_slot_filter_selected)
	_rarity_option.item_selected.connect(_on_rarity_filter_selected)
	_item_panel.equip_requested.connect(_on_panel_equip_requested)
	_item_panel.unequip_requested.connect(_on_panel_unequip_requested)
	_item_panel.lock_requested.connect(_on_panel_lock_requested)
	_item_panel.sell_requested.connect(_on_panel_sell_requested)
	_item_panel.close_requested.connect(_on_panel_close_requested)


## Draws the Armory of `session` and follows its changes.
func bind(session: GameSession) -> void:
	unbind()
	_session = session
	_session.events.armory_changed.connect(_on_armory_changed)
	_session.events.armory_capacity_changed.connect(_on_armory_capacity_changed)
	_session.events.equipment_changed.connect(_on_equipment_changed)
	_session.events.character_level_up.connect(_on_character_level_up)
	_build_filters()
	_redraw()


## Disconnects every event connected in `bind`.
func unbind() -> void:
	if _session != null and is_instance_valid(_session):
		var events: GameEvents = _session.events
		if events.armory_changed.is_connected(_on_armory_changed):
			events.armory_changed.disconnect(_on_armory_changed)
		if events.armory_capacity_changed.is_connected(_on_armory_capacity_changed):
			events.armory_capacity_changed.disconnect(_on_armory_capacity_changed)
		if events.equipment_changed.is_connected(_on_equipment_changed):
			events.equipment_changed.disconnect(_on_equipment_changed)
		if events.character_level_up.is_connected(_on_character_level_up):
			events.character_level_up.disconnect(_on_character_level_up)
	_hide_tooltip()
	_session = null
	_selected_uid = 0


func _exit_tree() -> void:
	unbind()


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

func _redraw() -> void:
	if _session == null:
		return
	var used: int = _session.armory.used()
	var capacity: int = _session.armory.capacity()
	var worn: int = 0
	for inst: ItemInstance in _session.armory.instances():
		if _session.armory.is_worn(inst.uid):
			worn += 1
	_capacity_label.text = ArmoryTexts.capacity_text(used, capacity, worn)
	_full_label.visible = used >= capacity
	_rebuild_grid()
	_refresh_panel()


func _rebuild_grid() -> void:
	_hide_tooltip()
	for child: Node in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	var all_pieces: Array[ItemInstance] = _session.armory.instances()
	var shown: int = 0
	for inst: ItemInstance in all_pieces:
		var base: ItemDef = _session.data.item(inst.base_id)
		if base == null or base.equip == null or not _passes_filters(inst, base):
			continue
		var cell: ArmoryCell = CELL_SCENE.instantiate() as ArmoryCell
		cell.name = CELL_NAME % inst.uid
		_grid.add_child(cell)
		cell.set_piece(inst, base, _session.armory.is_worn(inst.uid), inst.uid == _selected_uid)
		cell.pressed.connect(_on_cell_pressed)
		cell.hover_started.connect(_on_cell_hover_started)
		cell.hover_ended.connect(_hide_tooltip)
		shown += 1
	_empty_label.visible = shown == 0
	_empty_label.text = EMPTY_TEXT if all_pieces.is_empty() else NO_MATCH_TEXT


func _passes_filters(inst: ItemInstance, base: ItemDef) -> bool:
	if _slot_filter != FILTER_ALL and base.equip.slot != _slot_filter:
		return false
	return _rarity_filter == FILTER_ALL or inst.rarity == _rarity_filter


func _refresh_panel() -> void:
	if _selected_uid != 0 and not _item_panel.show_piece(_session, _selected_uid):
		_selected_uid = 0


# --- Cells and tooltip ------------------------------------------------------------------------------------------

func _on_cell_pressed(uid: int) -> void:
	_selected_uid = uid
	_redraw()


func _on_cell_hover_started(uid: int) -> void:
	var inst: ItemInstance = _session.armory.get_instance(uid) if _session != null else null
	var base: ItemDef = _session.data.item(inst.base_id) if inst != null else null
	if base == null:
		return
	var body: PackedStringArray = ArmoryTexts.affix_lines(inst, _session.data)
	body.append_array(ItemTooltipLines.modifier_lines(_session.armory.instance_modifiers(uid), _session.data))
	_hovering = true
	body.insert(0, ItemTooltipLines.colored_title(ArmoryTexts.piece_name(inst, base),
			UiStyle.rarity_color(inst.rarity)))
	Tooltips.show_text("", "\n".join(body), get_global_mouse_position())


func _hide_tooltip() -> void:
	if _hovering:
		_hovering = false
		Tooltips.hide_tooltip()


# --- Commands ---------------------------------------------------------------------------------------------------

func _show_result(result: CommandResult) -> void:
	_message_label.visible = not result.ok
	if not result.ok:
		_message_label.text = REFUSED_TEXTS.get(result.reason, REFUSED_TEXT_DEFAULT)
	_redraw()


func _on_panel_equip_requested(uid: int, slot: StringName) -> void:
	if _session != null:
		_show_result(_session.equipment.equip(uid, slot))


func _on_panel_unequip_requested(slot: StringName) -> void:
	if _session != null:
		_show_result(_session.equipment.unequip(slot))


func _on_panel_lock_requested(uid: int, locked: bool) -> void:
	if _session != null:
		_show_result(_session.armory.set_locked(uid, locked))


func _on_panel_sell_requested(uid: int) -> void:
	if _session != null:
		_show_result(_session.shop.sell_instance(uid))


func _on_panel_close_requested() -> void:
	_selected_uid = 0
	_item_panel.clear()
	_redraw()


# --- Events -----------------------------------------------------------------------------------------------------

func _on_armory_changed(_uid: int, _change: StringName) -> void:
	_redraw()


func _on_armory_capacity_changed(_used: int, _capacity: int) -> void:
	_redraw()


func _on_equipment_changed(_slot_id: StringName, _uid: int) -> void:
	_redraw()


func _on_character_level_up(_new_level: int) -> void:
	_redraw()
