class_name StarterRewardView
extends RefCounted
## Draws a starter reward (money, items, character XP) into a box: shared by `StarterRow` and `FinalRow`. Presentation only.

const REWARD_ICON_SIDE: int = 24


static func draw(box: HBoxContainer, money: int, items: Array[ItemQty], xp: int, data: GameData) -> void:
	for child: Node in box.get_children():
		box.remove_child(child)
		child.queue_free()
	_label(box, "RewardTitle", StarterTexts.REWARD_TEXT, &"MutedLabel")
	if money > 0:
		var money_label := MoneyLabel.new()
		box.add_child(money_label)
		money_label.set_amount(money, data.currency())
	for entry: ItemQty in items:
		if not data.has_item(entry.item_id):
			continue
		var item: ItemDef = data.item(entry.item_id)
		var icon := TextureRect.new()
		icon.texture = ItemSlotView.icon_of(item.icon)
		icon.custom_minimum_size = Vector2(REWARD_ICON_SIDE, REWARD_ICON_SIDE)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		box.add_child(icon)
		_label(box, "Item_%s" % entry.item_id, StarterTexts.REWARD_ITEM_TEXT % [item.name, NumberFormat.format_int(entry.qty)], &"")
	if xp > 0:
		var xp_label: Label = _label(box, "XpLabel", StarterTexts.REWARD_XP_TEXT % NumberFormat.format_int(xp), &"")
		xp_label.add_theme_color_override("font_color", UiStyle.GOLD_LIGHT)


static func _label(parent: Node, node_name: String, text: String, variation: StringName) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	if variation != &"":
		label.theme_type_variation = variation
	parent.add_child(label)
	return label
