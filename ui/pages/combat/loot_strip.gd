class_name LootStrip
extends RefCounted
## Bottom-left strip of the combat page (docs/UI_GDR.md §2): the last icons of the loot bag with the rarity color,
## "Borsa N / M" and the state of "Raccogli tutto". Reads the bag, keeps nothing.

const ITEM_SLOT_SCENE: PackedScene = preload("res://ui/components/item_slot/item_slot.tscn")


static func redraw(session: GameSession, list: HBoxContainer, count_label: Label, collect_button: Button) -> void:
	var bag: LootBag = session.combat.loot
	count_label.text = CombatTexts.LOOT_COUNT_TEXT % [NumberFormat.format_int(bag.used()),
			NumberFormat.format_int(bag.capacity())]
	for child: Node in list.get_children():
		list.remove_child(child)
		child.queue_free()
	var items: Array[Dictionary] = bag.items()
	collect_button.disabled = items.is_empty()
	if items.is_empty():
		var empty := Label.new()
		empty.text = CombatTexts.LOOT_EMPTY_TEXT
		empty.theme_type_variation = &"MutedLabel"
		list.add_child(empty)
		return
	var first: int = maxi(0, items.size() - UiStyle.COMBAT_LOOT_MAX_ICONS)
	for i: int in range(first, items.size()):
		var def: ItemDef = session.data.item(items[i]["item"])
		if def == null:
			continue
		var cell: ItemSlotView = ITEM_SLOT_SCENE.instantiate() as ItemSlotView
		cell.custom_minimum_size = Vector2(UiStyle.COMBAT_LOOT_ICON_SIDE, UiStyle.COMBAT_LOOT_ICON_SIDE)
		cell.add_theme_stylebox_override("panel", UiStyle.flat(UiStyle.BG_FIELD, UiStyle.rarity_color(&"common"),
				UiStyle.COMBAT_FRAME_WIDTH, 2.0))
		list.add_child(cell)
		cell.set_item(def, int(items[i]["qty"]))
	if first > 0:
		var more := Label.new()
		more.text = CombatTexts.LOOT_MORE_TEXT % first
		more.theme_type_variation = &"MutedLabel"
		list.add_child(more)
