class_name EquipmentInventory
extends RefCounted
## Inventory half of the Equipment page: the slot / rarity filter menus and the grid of cells. Static helpers that
## read the session and fill nodes owned by the page; they keep no state (filters and selection live in the page).

const ALL_SLOTS_TEXT: String = "Tutti gli slot"
const ALL_RARITIES_TEXT: String = "Tutte le rarità"
const EMPTY_TEXT: String = "L'Armeria è vuota: forgia o compra dei pezzi."
const NO_MATCH_TEXT: String = "Nessun pezzo corrisponde ai filtri."
const CELL_NAME: String = "Cell%d"
const CELL_SCENE: PackedScene = preload("res://ui/pages/equipment/inventory_cell.tscn")
const FILTER_ALL: StringName = &""


## Fills both menus (first entry "all", metadata = slot / rarity id) and selects the first entry.
static func build_filters(session: GameSession, slot_option: OptionButton, rarity_option: OptionButton) -> void:
	slot_option.clear()
	slot_option.add_item(ALL_SLOTS_TEXT)
	slot_option.set_item_metadata(0, FILTER_ALL)
	for slot: StringName in Equipment.SLOTS:
		slot_option.add_item(EquipmentStatsText.slot_text(slot, session.data))
		slot_option.set_item_metadata(slot_option.item_count - 1, slot)
	rarity_option.clear()
	rarity_option.add_item(ALL_RARITIES_TEXT)
	rarity_option.set_item_metadata(0, FILTER_ALL)
	for rarity: StringName in ItemInstance.RARITIES:
		rarity_option.add_item(ArmoryTexts.rarity_name(rarity))
		rarity_option.set_item_metadata(rarity_option.item_count - 1, rarity)
	slot_option.select(0)
	rarity_option.select(0)


## Rebuilds the cells of `grid` (pieces not worn that pass the filters) and wires them to `page`'s handlers.
static func rebuild_grid(session: GameSession, grid: Container, empty_label: Label, slot_filter: StringName,
		rarity_filter: StringName, selected_uid: int, handlers: Dictionary) -> void:
	for child: Node in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	var all_pieces: Array[ItemInstance] = session.armory.instances()
	var shown: int = 0
	for inst: ItemInstance in all_pieces:
		var base: ItemDef = session.data.item(inst.base_id)
		if session.armory.is_worn(inst.uid) or base == null or base.equip == null \
				or not passes_filters(inst, base, slot_filter, rarity_filter):
			continue
		var cell: InventoryCell = CELL_SCENE.instantiate() as InventoryCell
		cell.name = CELL_NAME % inst.uid
		grid.add_child(cell)
		cell.set_piece(inst, base, inst.uid == selected_uid)
		cell.pressed.connect(handlers["pressed"] as Callable)
		cell.right_clicked.connect(handlers["right_clicked"] as Callable)
		cell.unequip_dropped.connect(handlers["unequip_dropped"] as Callable)
		cell.hover_started.connect(handlers["hover_started"] as Callable)
		cell.hover_ended.connect(handlers["hover_ended"] as Callable)
		shown += 1
	empty_label.visible = shown == 0
	empty_label.text = EMPTY_TEXT if all_pieces.is_empty() else NO_MATCH_TEXT


static func passes_filters(inst: ItemInstance, base: ItemDef, slot_filter: StringName, rarity_filter: StringName) -> bool:
	if slot_filter != FILTER_ALL and base.equip.slot != slot_filter:
		return false
	return rarity_filter == FILTER_ALL or inst.rarity == rarity_filter
