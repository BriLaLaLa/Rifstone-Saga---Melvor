class_name MerchantPanel
extends VBoxContainer
## "Mercante" tab of a production page (docs/01_GDD_M26.md §38.2): the schemes and the reagents the profession's vendor
## sells (`GameData.shop_entries_of_vendor(Professions.vendor(skill))`). Rows are built once from the data; every redraw
## reads the session (gold, bank, known recipes, `Shop.can_buy_many`). Buying is `Shop.buy_many`, "Impara ora" is
## `Disciplines.learn_recipe`; a refusal shows its reason. It keeps no game state.

const SEPARATION: int = 10
const ROW_SEPARATION: int = 14
const SIDE_WIDTH: float = 250.0
const BUTTON_MIN_WIDTH: float = 64.0

var _data: GameData = null
var _skill_id: StringName = &""
var _session: GameSession = null
var _gold: Label = null
var _message: Label = null
## Entry id -> nodes of its row (presentation references).
var _rows: Dictionary[StringName, Dictionary] = {}


func setup(data: GameData, skill_id: StringName) -> void:
	_data = data
	_skill_id = skill_id
	name = "MerchantPanel"
	add_theme_constant_override("separation", SEPARATION)
	var vendor: StringName = &""
	var trainer: TrainerDef = data.trainer(skill_id)
	if trainer != null:
		vendor = trainer.vendor
	_label(self, MerchantTexts.TITLE_TEXT % ShopPage.VENDOR_TEXTS.get(vendor, String(vendor)), &"HeaderLabel").name = "Title"
	_gold = _label(self, "", &"")
	_gold.name = "GoldLabel"
	_gold.add_theme_color_override("font_color", UiStyle.GOLD_LIGHT)
	_message = _label(self, "", &"")
	_message.name = "MessageLabel"
	_message.add_theme_color_override("font_color", UiStyle.BAD)
	_message.visible = false
	var schemes: Array[ShopEntryDef] = []
	var reagents: Array[ShopEntryDef] = []
	for entry: ShopEntryDef in data.shop_entries_of_vendor(vendor):
		if entry.effect_item == null or not data.has_item(entry.effect_item.item_id):
			continue
		var category: StringName = data.item(entry.effect_item.item_id).category
		if category == &"recipe":
			schemes.append(entry)
		elif category == &"reagent":
			reagents.append(entry)
	_section(MerchantTexts.SCHEMES_TITLE, schemes, true)
	_section(MerchantTexts.REAGENTS_TITLE, reagents, false)
	if _rows.is_empty():
		_label(self, MerchantTexts.NOTHING_TEXT, &"MutedLabel")


## Reads the session into every row.
func redraw(session: GameSession) -> void:
	_session = session
	_gold.text = MerchantTexts.GOLD_TEXT % NumberFormat.format_int(session.wallet.get_gold())
	for entry_id: StringName in _rows:
		var entry: ShopEntryDef = _data.shop_entry(entry_id)
		if _rows[entry_id]["scheme"]:
			_refresh_scheme(entry, _rows[entry_id])
		else:
			_refresh_reagent(entry, _rows[entry_id])


func forget_session() -> void:
	_session = null


func _section(title: String, entries: Array[ShopEntryDef], is_scheme: bool) -> void:
	if entries.is_empty():
		return
	_label(self, title, &"HeaderLabel").name = "SectionTitle_%s" % ("schemes" if is_scheme else "reagents")
	for entry: ShopEntryDef in entries:
		_rows[entry.id] = _new_row(entry, is_scheme)


func _new_row(entry: ShopEntryDef, is_scheme: bool) -> Dictionary:
	var panel := PanelContainer.new()
	panel.name = "Row_%s" % entry.id
	panel.theme_type_variation = &"HudPanel"
	add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", ROW_SEPARATION)
	panel.add_child(row)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	_label(info, entry.name, &"HeaderLabel").name = "NameLabel"
	var description: Label = _label(info, entry.description, &"MutedLabel")
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var state: Label = _label(info, "", &"")
	state.name = "StateLabel"
	var owned: Label = _label(info, "", &"MutedLabel")
	owned.name = "OwnedLabel"
	var side := VBoxContainer.new()
	side.custom_minimum_size.x = SIDE_WIDTH
	side.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(side)
	var price: Label = _label(side, "", &"")
	price.name = "PriceLabel"
	var buttons_box := HBoxContainer.new()
	side.add_child(buttons_box)
	var buttons: Array[Button] = []
	var learn: Button = null
	if is_scheme:
		buttons.append(_button(buttons_box, "BuyButton", MerchantTexts.BUY_TEXT, _on_buy.bind(entry.id, 1)))
		learn = _button(buttons_box, "LearnButton", MerchantTexts.LEARN_TEXT, _on_learn.bind(entry.id))
	else:
		for count: int in MerchantTexts.BUY_MANY_COUNTS:
			buttons.append(_button(buttons_box, "BuyButton_%d" % count,
					MerchantTexts.BUY_MANY_TEXT % NumberFormat.format_int(count), _on_buy.bind(entry.id, count)))
	var reason: Label = _label(side, "", &"")
	reason.name = "ReasonLabel"
	reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reason.add_theme_color_override("font_color", UiStyle.BAD)
	return {"scheme": is_scheme, "state": state, "price": price, "owned": owned, "buttons": buttons,
			"learn": learn, "reason": reason}


func _button(parent: Node, node_name: String, text: String, handler: Callable) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.theme_type_variation = &"AccentButton"
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size.x = BUTTON_MIN_WIDTH
	button.pressed.connect(handler)
	parent.add_child(button)
	return button


func _label(parent: Node, text: String, variation: StringName) -> Label:
	var label := Label.new()
	label.text = text
	if variation != &"":
		label.theme_type_variation = variation
	parent.add_child(label)
	return label


func _refresh_scheme(entry: ShopEntryDef, row: Dictionary) -> void:
	var item: ItemDef = _data.item(entry.effect_item.item_id)
	var known: bool = _session.disciplines.knows_recipe(item.recipe_action)
	var in_bank: bool = _session.bank.get_count(item.id) > 0
	var state: Label = row["state"]
	var buttons: Array[Button] = row["buttons"]
	var buy: Button = buttons[0]
	var reason: Label = row["reason"]
	row["price"].visible = not known and not in_bank
	row["price"].text = MerchantTexts.PRICE_TEXT % NumberFormat.format_int(_session.shop.price(entry.id))
	row["owned"].visible = false
	buy.visible = not known and not in_bank
	(row["learn"] as Button).visible = in_bank and not known
	reason.visible = false
	var color: Color = UiStyle.TEXT
	if known:
		state.text = MerchantTexts.STATE_KNOWN
		color = UiStyle.GOOD
	elif in_bank:
		state.text = MerchantTexts.STATE_LEARN
		color = UiStyle.GOLD_LIGHT
	else:
		var can: CommandResult = _session.shop.can_buy_many(entry.id, 1)
		var locked: bool = can.reason == Reasons.REQUIREMENT_NOT_MET
		state.text = _locked_text(entry) if locked else MerchantTexts.STATE_BUY
		color = UiStyle.BAD if locked else UiStyle.TEXT
		buy.disabled = not can.ok
		buy.tooltip_text = "" if can.ok else _reason_text(can.reason)
		reason.text = buy.tooltip_text
		reason.visible = not can.ok
	state.add_theme_color_override("font_color", color)


func _refresh_reagent(entry: ShopEntryDef, row: Dictionary) -> void:
	row["owned"].visible = true
	row["owned"].text = MerchantTexts.OWNED_TEXT % NumberFormat.format_int(_session.bank.get_count(entry.effect_item.item_id))
	row["price"].text = MerchantTexts.PRICE_EACH_TEXT % NumberFormat.format_int(_session.shop.price(entry.id))
	var locked: bool = _session.shop.can_buy_many(entry.id, 1).reason == Reasons.REQUIREMENT_NOT_MET
	row["state"].text = _locked_text(entry) if locked else MerchantTexts.STATE_BUY
	row["state"].add_theme_color_override("font_color", UiStyle.BAD if locked else UiStyle.TEXT)
	var buttons: Array[Button] = row["buttons"]
	var reason_text: String = ""
	for i: int in MerchantTexts.BUY_MANY_COUNTS.size():
		var can: CommandResult = _session.shop.can_buy_many(entry.id, MerchantTexts.BUY_MANY_COUNTS[i])
		buttons[i].disabled = not can.ok
		buttons[i].tooltip_text = "" if can.ok else _reason_text(can.reason)
		if i == 0 and not can.ok:
			reason_text = buttons[i].tooltip_text
	row["reason"].text = reason_text
	row["reason"].visible = not reason_text.is_empty()


func _locked_text(entry: ShopEntryDef) -> String:
	if entry.req_skills.has(_skill_id):
		return MerchantTexts.STATE_LOCKED_TEXT % NumberFormat.format_int(entry.req_skills[_skill_id])
	return MerchantTexts.STATE_LOCKED_GENERIC


static func _reason_text(reason: StringName) -> String:
	return MerchantTexts.REFUSED_TEXTS.get(reason, MerchantTexts.REFUSED_TEXT_DEFAULT)


func _on_buy(entry_id: StringName, count: int) -> void:
	if _session == null:
		return
	_show(_session.shop.buy_many(entry_id, count))
	redraw(_session)


func _on_learn(entry_id: StringName) -> void:
	if _session == null:
		return
	_show(_session.disciplines.learn_recipe(_data.shop_entry(entry_id).effect_item.item_id))
	redraw(_session)


func _show(result: CommandResult) -> void:
	_message.visible = not result.ok
	if not result.ok:
		_message.text = _reason_text(result.reason)
