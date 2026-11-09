class_name CardRow
extends PanelContainer
## One Fracture Card of the Fractures page (docs/05_INTERFACES.md §7.v): icon, name, grade, rarity, recommended level, the
## modifiers with their risk and reward (the values of `MapCardRoller.effects`, F-109) and the buttons. It only emits
## the requests; the page sends the commands. It is built in `show_card` from a copy of the Card and keeps nothing else.

signal open_requested(uid: int)
signal lock_requested(uid: int, locked: bool)
signal salvage_requested(uid: int)
signal currency_requested(uid: int)

const ICON_SIZE: int = 48
const SEPARATION: int = 12
const BUTTON_WIDTH: int = 110
const MOD_SEPARATION: int = 16
const MOD_NAME_WIDTH: int = 150


## Draws `card` for `session`; `can_open` is false while a Fracture is in progress or loot is pending.
func show_card(session: GameSession, card: MapCard, can_open: bool) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	name = "Card%d" % card.uid
	theme_type_variation = &"HudPanel"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", SEPARATION)
	add_child(row)
	row.add_child(_icon(session.data, card))
	row.add_child(_info(session, card))
	row.add_child(_buttons(card, can_open))


func _icon(data: GameData, card: MapCard) -> TextureRect:
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = ItemSlotView.icon_of(data.item(card.base_id).icon)
	return icon


func _info(session: GameSession, card: MapCard) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := Label.new()
	title.name = "TitleLabel"
	title.theme_type_variation = &"HeaderLabel"
	title.add_theme_color_override("font_color", UiStyle.rarity_color(card.rarity))
	title.text = "%s - %s" % [session.data.item(card.base_id).name, FractureTexts.rarity_name(card.rarity)]
	if card.locked:
		title.text += " (%s)" % FractureTexts.LOCKED_TAG_TEXT
	box.add_child(title)
	var sub := Label.new()
	sub.name = "GradeLabel"
	sub.theme_type_variation = &"MutedLabel"
	sub.text = "%s   |   %s   |   %s" % [FractureTexts.CARD_GRADE_TEXT % card.grade,
			FractureTexts.RECOMMENDED_TEXT % session.fractures.recommended_level(card.grade),
			FractureTexts.risk_total_text(card, session.data)]
	box.add_child(sub)
	var effects: Array[Dictionary] = MapCardRoller.effects(card, session.data)
	if effects.is_empty():
		var none := Label.new()
		none.name = "NoMods"
		none.theme_type_variation = &"MutedLabel"
		none.text = FractureTexts.CARD_NO_MODS_TEXT
		box.add_child(none)
	for effect: Dictionary in effects:
		box.add_child(_mod_block(session.data, effect))
	return box


func _mod_block(data: GameData, effect: Dictionary) -> HBoxContainer:
	var block := HBoxContainer.new()
	block.add_theme_constant_override("separation", MOD_SEPARATION)
	block.name = "Mod_%s" % effect["mod"]
	var def: MapModDef = data.map_mod(effect["mod"] as StringName)
	var name_label := Label.new()
	name_label.name = "ModName"
	name_label.custom_minimum_size.x = MOD_NAME_WIDTH
	name_label.text = def.name if def != null else String(effect["mod"])
	if def != null:
		name_label.tooltip_text = def.description
	block.add_child(name_label)
	var risk := Label.new()
	risk.name = "Risk"
	risk.text = FractureTexts.RISK_PREFIX + FractureTexts.risk_line(effect)
	risk.add_theme_color_override("font_color", UiStyle.BAD)
	block.add_child(risk)
	var reward := Label.new()
	reward.name = "Reward"
	reward.text = FractureTexts.REWARD_PREFIX + FractureTexts.reward_line(effect)
	reward.add_theme_color_override("font_color", UiStyle.GOOD)
	block.add_child(reward)
	return block


func _buttons(card: MapCard, can_open: bool) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = "Buttons"
	var open: Button = _button("OpenButton", FractureTexts.OPEN_TEXT)
	open.disabled = not can_open
	open.pressed.connect(func() -> void: open_requested.emit(card.uid))
	box.add_child(open)
	var lock: Button = _button("LockButton", FractureTexts.UNLOCK_TEXT if card.locked else FractureTexts.LOCK_TEXT)
	lock.pressed.connect(func() -> void: lock_requested.emit(card.uid, not card.locked))
	box.add_child(lock)
	var crystals: Button = _button("CurrencyButton", FractureTexts.CRYSTALS_TEXT)
	crystals.pressed.connect(func() -> void: currency_requested.emit(card.uid))
	box.add_child(crystals)
	var salvage: Button = _button("SalvageButton", FractureTexts.SALVAGE_TEXT)
	salvage.pressed.connect(func() -> void: salvage_requested.emit(card.uid))
	box.add_child(salvage)
	return box


func _button(node_name: String, text: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(BUTTON_WIDTH, UiStyle.MENU_BUTTON_HEIGHT)
	return button
