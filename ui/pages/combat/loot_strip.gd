class_name LootStrip
extends RefCounted
## Bottom-left strip of the combat page (docs/UI_GDR.md §2): the last icons of the loot bag with the rarity color,
## "Borsa N / M" and the state of "Raccogli tutto". Reads the bag, keeps nothing. Inside a Fracture (M29-02) it shows the
## Fracture bag instead (it cannot be collected before the boss), so that every drop appears.

const ITEM_SLOT_SCENE: PackedScene = preload("res://ui/components/item_slot/item_slot.tscn")
const PIECE_CELL_SCENE: PackedScene = preload("res://ui/pages/equipment/inventory_cell.tscn")


static func redraw(session: GameSession, list: HBoxContainer, count_label: Label, collect_button: Button) -> void:
	for child: Node in list.get_children():
		list.remove_child(child)
		child.queue_free()
	count_label.tooltip_text = ""
	var items: Array[Dictionary] = []
	var pieces: Array[ItemInstance] = []
	var cards: Array[MapCard] = []
	if session.fractures.is_active():
		var bag: Dictionary = session.fractures.bag_contents()
		items = bag["stacks"] as Array[Dictionary]
		pieces = bag["pieces"] as Array[ItemInstance]
		cards = bag["cards"] as Array[MapCard]
		count_label.text = FractureTexts.COMBAT_BAG_TEXT % NumberFormat.format_int(items.size() + pieces.size() + cards.size())
		count_label.tooltip_text = FractureTexts.COMBAT_BAG_TOOLTIP
		collect_button.disabled = true
	else:
		var loot: LootBag = session.combat.loot
		count_label.text = CombatTexts.LOOT_COUNT_TEXT % [NumberFormat.format_int(loot.used()),
				NumberFormat.format_int(loot.capacity())]
		items = loot.items()
		pieces = loot.pieces()
		collect_button.disabled = items.is_empty() and pieces.is_empty()
	if items.is_empty() and pieces.is_empty() and cards.is_empty():
		var empty := Label.new()
		empty.text = CombatTexts.LOOT_EMPTY_TEXT
		empty.theme_type_variation = &"MutedLabel"
		list.add_child(empty)
		return
	# Waiting pieces and Cards come first (they are rarer), drawn with their rarity color.
	var room: int = UiStyle.COMBAT_LOOT_MAX_ICONS
	for inst: ItemInstance in pieces:
		var piece_def: ItemDef = session.data.item(inst.base_id)
		if piece_def == null or room <= 0:
			continue
		var piece_cell: InventoryCell = PIECE_CELL_SCENE.instantiate() as InventoryCell
		piece_cell.custom_minimum_size = Vector2(UiStyle.COMBAT_LOOT_ICON_SIDE, UiStyle.COMBAT_LOOT_ICON_SIDE)
		list.add_child(piece_cell)
		piece_cell.set_piece(inst, piece_def, false)
		piece_cell.tooltip_text = piece_def.name
		room -= 1
	for card: MapCard in cards:
		var card_def: ItemDef = session.data.item(card.base_id)
		if card_def != null and room > 0:
			_item_cell(list, card_def, 0, UiStyle.rarity_color(card.rarity))
			room -= 1
	var first: int = maxi(0, items.size() - maxi(room, 0))
	for i: int in range(first, items.size()):
		var def: ItemDef = session.data.item(items[i]["item"])
		if def != null:
			_item_cell(list, def, int(items[i]["qty"]), UiStyle.rarity_color(&"common"))
	if first > 0:
		var more := Label.new()
		more.text = CombatTexts.LOOT_MORE_TEXT % first
		more.theme_type_variation = &"MutedLabel"
		list.add_child(more)


static func _item_cell(list: HBoxContainer, def: ItemDef, qty: int, color: Color) -> void:
	var cell: ItemSlotView = ITEM_SLOT_SCENE.instantiate() as ItemSlotView
	cell.custom_minimum_size = Vector2(UiStyle.COMBAT_LOOT_ICON_SIDE, UiStyle.COMBAT_LOOT_ICON_SIDE)
	cell.add_theme_stylebox_override("panel", UiStyle.flat(UiStyle.BG_FIELD, color, UiStyle.COMBAT_FRAME_WIDTH, 2.0))
	list.add_child(cell)
	cell.set_item(def, qty)
