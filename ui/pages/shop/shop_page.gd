class_name ShopPage
extends Page
## Shop page (docs/01_GDD.md §8), route `shop`: the entries of `data.shop_entries()` grouped by vendor (stall), each with
## its price, the purchase counter (only for limited entries), the missing requirements and the "Compra" button.
## Selling is done from the item panel of the bank page.
##
## The button is enabled exactly when `shop.can_buy` succeeds; when it fails the reason is shown in Italian next to
## the button (and as its tooltip). Prices, counters and reasons are read from the shop at every refresh, which
## runs on `shop_purchased`, `item_sold`, `gold_changed`, `bank_changed` and `level_up`. The rows are built once per
## bind (the definitions never change); the page keeps only references to its own nodes.

const TITLE_TEXT: String = "Shop"
const GOLD_TEXT: String = "Oro: %s"
const PRICE_TEXT: String = "Prezzo: %s oro"
const COUNT_TEXT: String = "Acquisti: %s / %s"
const BUY_TEXT: String = "Compra"
const REQUIRES_TEXT: String = "Richiede: %s"
const REQ_SKILL_TEXT: String = "%s livello %s"
const REQ_TOTAL_TEXT: String = "livello totale %s"
const REQ_CHARACTER_TEXT: String = "livello del personaggio %s"
const REQ_VILLAGE_TEXT: String = "%s livello %s"
const REQ_SEPARATOR: String = ", "
const MARKET_VENDOR: StringName = &"mercato"
const COMING_SOON_TEXT: String = "In arrivo"
const VENDOR_TEXTS: Dictionary[StringName, String] = {
	&"bottegaia": "Bottegaia",
	&"fabbro": "Fabbro",
	&"deposito": "Deposito",
	&"armaiolo": "Armaiolo",
	&"mercante_armature": "Mercante d'armature",
	&"mercato": "Mercato",
}
## Reason of `can_buy` / `buy` -> text; other reasons: REFUSED_TEXT_DEFAULT.
const REFUSED_TEXTS: Dictionary[StringName, String] = {
	Reasons.UNKNOWN_ID: "Voce non disponibile.",
	Reasons.MAX_PURCHASES: "Hai già acquistato il massimo.",
	Reasons.REQUIREMENT_NOT_MET: "Requisiti non soddisfatti.",
	Reasons.NOT_ENOUGH_GOLD: "Oro insufficiente.",
	Reasons.BANK_FULL: "Il deposito è pieno.",
	Reasons.ARMORY_FULL: "L'Armeria è piena.",
}
const REFUSED_TEXT_DEFAULT: String = "Acquisto non riuscito."
const MARGIN: int = 16
const SECTION_SEPARATION: int = 12
const ROW_SEPARATION: int = 16
const ROW_MIN_HEIGHT: int = 72
const BUTTON_WIDTH: int = 140
const PRICE_WIDTH: int = 220
const ENTRY_ROW_NAME: String = "Row_%s"

var _session: GameSession = null
## Entry id -> the nodes of its row (presentation references).
var _rows: Dictionary[StringName, Dictionary] = {}

@onready var _margin: MarginContainer = %Margin
@onready var _content: VBoxContainer = %Content
@onready var _title_label: Label = %TitleLabel
@onready var _gold_label: Label = %GoldLabel
@onready var _message_label: Label = %MessageLabel
@onready var _list: VBoxContainer = %List


func _ready() -> void:
	for side: String in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		_margin.add_theme_constant_override(side, MARGIN)
	_content.add_theme_constant_override("separation", SECTION_SEPARATION)
	_list.add_theme_constant_override("separation", SECTION_SEPARATION)
	_title_label.text = TITLE_TEXT
	_message_label.add_theme_color_override("font_color", UiStyle.BAD)


## Draws the shop of `session` and follows its changes.
func bind(session: GameSession) -> void:
	unbind()
	_session = session
	HelpButton.attach(_title_label.get_parent(), session.data, &"shop")
	var events: GameEvents = _session.events
	events.shop_purchased.connect(_on_shop_purchased)
	events.item_sold.connect(_on_item_sold)
	events.gold_changed.connect(_on_gold_changed)
	events.bank_changed.connect(_on_bank_changed)
	events.level_up.connect(_on_level_up)
	events.character_level_up.connect(_on_character_level_up)
	events.deposit_changed.connect(_on_deposit_changed)
	_build_rows()
	_refresh()


## Disconnects every event connected in `bind`.
func unbind() -> void:
	if _session != null and is_instance_valid(_session):
		var events: GameEvents = _session.events
		if events.shop_purchased.is_connected(_on_shop_purchased):
			events.shop_purchased.disconnect(_on_shop_purchased)
		if events.item_sold.is_connected(_on_item_sold):
			events.item_sold.disconnect(_on_item_sold)
		if events.gold_changed.is_connected(_on_gold_changed):
			events.gold_changed.disconnect(_on_gold_changed)
		if events.bank_changed.is_connected(_on_bank_changed):
			events.bank_changed.disconnect(_on_bank_changed)
		if events.level_up.is_connected(_on_level_up):
			events.level_up.disconnect(_on_level_up)
		if events.character_level_up.is_connected(_on_character_level_up):
			events.character_level_up.disconnect(_on_character_level_up)
		if events.deposit_changed.is_connected(_on_deposit_changed):
			events.deposit_changed.disconnect(_on_deposit_changed)
	_session = null


func _exit_tree() -> void:
	unbind()


## One section per vendor (always all of them, in the order of `DataValidatorItems.SHOP_VENDORS`), one row per entry;
## a vendor without entries shows "In arrivo".
func _build_rows() -> void:
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_rows.clear()
	var sections: Dictionary[StringName, VBoxContainer] = {}
	var vendors: PackedStringArray = DataValidatorItems.SHOP_VENDORS.duplicate()
	if not vendors.has(MARKET_VENDOR):  # the Market stall is always listed, last (M20-05)
		vendors.append(MARKET_VENDOR)
	for vendor: String in vendors:
		sections[StringName(vendor)] = _new_section(StringName(vendor))
	for entry: ShopEntryDef in _session.data.shop_entries():
		_rows[entry.id] = _new_row(sections[entry.vendor], entry)
	for vendor: StringName in sections:
		if sections[vendor].get_child_count() == 0:
			var soon: Label = _label(sections[vendor], COMING_SOON_TEXT, &"MutedLabel")
			soon.name = "ComingSoon"


func _new_section(vendor: StringName) -> VBoxContainer:
	var title: Label = Label.new()
	title.theme_type_variation = &"HeaderLabel"
	title.text = VENDOR_TEXTS.get(vendor, String(vendor))
	_list.add_child(title)
	var box: VBoxContainer = VBoxContainer.new()
	box.name = "Section_%s" % vendor
	box.add_theme_constant_override("separation", SECTION_SEPARATION)
	_list.add_child(box)
	return box


func _new_row(section: VBoxContainer, entry: ShopEntryDef) -> Dictionary:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = ENTRY_ROW_NAME % entry.id
	panel.theme_type_variation = &"HudPanel"
	panel.custom_minimum_size.y = ROW_MIN_HEIGHT
	section.add_child(panel)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", ROW_SEPARATION)
	panel.add_child(row)
	var info: VBoxContainer = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	_label(info, entry.name, &"HeaderLabel").name = "NameLabel"
	_label(info, entry.description, &"MutedLabel").autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var effect_label: Label = _label(info, ShopTexts.describe(entry, _session.data), &"")
	effect_label.name = "EffectLabel"
	effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect_label.add_theme_color_override("font_color", UiStyle.GOLD_LIGHT)
	effect_label.visible = not effect_label.text.is_empty()
	var requires_label: Label = _label(info, "", &"")
	requires_label.name = "RequiresLabel"
	requires_label.add_theme_color_override("font_color", UiStyle.BAD)
	var side: VBoxContainer = VBoxContainer.new()
	side.custom_minimum_size.x = PRICE_WIDTH
	side.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(side)
	var price_label: Label = _label(side, "", &"")
	price_label.name = "PriceLabel"
	var count_label: Label = _label(side, "", &"MutedLabel")
	count_label.name = "CountLabel"
	var buy: Button = Button.new()
	buy.name = "BuyButton"
	buy.text = BUY_TEXT
	buy.theme_type_variation = &"AccentButton"
	buy.focus_mode = Control.FOCUS_NONE
	buy.custom_minimum_size.x = BUTTON_WIDTH
	buy.pressed.connect(_on_buy_pressed.bind(entry.id))
	side.add_child(buy)
	var reason_label: Label = _label(side, "", &"")
	reason_label.name = "ReasonLabel"
	reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reason_label.add_theme_color_override("font_color", UiStyle.BAD)
	return {"price": price_label, "count": count_label, "requires": requires_label, "buy": buy, "reason": reason_label}


func _label(parent: Node, text: String, variation: StringName) -> Label:
	var label: Label = Label.new()
	label.text = text
	if variation != &"":
		label.theme_type_variation = variation
	parent.add_child(label)
	return label


## Rereads gold, prices, counters, requirements and the state of every Compra button from the session.
func _refresh() -> void:
	if _session == null:
		return
	_gold_label.text = GOLD_TEXT % NumberFormat.format_int(_session.wallet.get_gold())
	for entry_id: StringName in _rows:
		_refresh_row(_session.data.shop_entry(entry_id), _rows[entry_id])


func _refresh_row(entry: ShopEntryDef, row: Dictionary) -> void:
	var shop: Shop = _session.shop
	row["price"].text = PRICE_TEXT % NumberFormat.format_int(shop.price(entry.id))
	var count_label: Label = row["count"]
	count_label.visible = entry.max_purchases > 0
	count_label.text = COUNT_TEXT % [NumberFormat.format_int(shop.purchase_count(entry.id)),
			NumberFormat.format_int(entry.max_purchases)]
	var missing: String = _missing_requirements(entry)
	var requires_label: Label = row["requires"]
	requires_label.text = REQUIRES_TEXT % missing if not missing.is_empty() else ""
	requires_label.visible = not missing.is_empty()
	var can_buy: CommandResult = shop.can_buy(entry.id)
	var buy: Button = row["buy"]
	var reason_label: Label = row["reason"]
	buy.disabled = not can_buy.ok
	var reason_text: String = "" if can_buy.ok else REFUSED_TEXTS.get(can_buy.reason, REFUSED_TEXT_DEFAULT)
	buy.tooltip_text = reason_text
	reason_label.text = reason_text
	reason_label.visible = not can_buy.ok


## The requirements of `entry` not met now, as text; empty if there are none. Compared with the shop's purchase
## counters and the skills of the session (the shop does not expose the list).
func _missing_requirements(entry: ShopEntryDef) -> String:
	var parts: Array[String] = []
	for required: StringName in entry.req_entries:
		if _session.shop.purchase_count(required) < 1:
			var required_entry: ShopEntryDef = _session.data.shop_entry(required)
			parts.append(required_entry.name if required_entry != null else String(required))
	for skill_id: StringName in entry.req_skills:
		var level: int = entry.req_skills[skill_id]
		if _session.skills.get_level(skill_id) < level:
			var skill: SkillDef = _session.data.skill(skill_id)
			parts.append(REQ_SKILL_TEXT % [skill.name if skill != null else String(skill_id), level])
	if _session.skills.total_level() < entry.req_total_level:
		parts.append(REQ_TOTAL_TEXT % entry.req_total_level)
	if entry.req_character > _session.character.get_level():
		parts.append(REQ_CHARACTER_TEXT % entry.req_character)
	parts.append_array(missing_village(entry.req_village))
	return REQ_SEPARATOR.join(parts)


## The Village requirements ({building_id: level}) not met now, each as "<Building name> <level>" (read from
## `session.village.level` and the building definitions).
func missing_village(required: Dictionary) -> Array[String]:
	var parts: Array[String] = []
	for building_id: StringName in required:
		var level: int = int(required[building_id])
		if _session.village != null and _session.village.level(building_id) >= level:
			continue
		var def: VillageBuildingDef = _session.data.village_building(building_id)
		parts.append(REQ_VILLAGE_TEXT % [def.name if def != null else String(building_id), level])
	return parts


func _on_buy_pressed(entry_id: StringName) -> void:
	if _session == null:
		return
	var result: CommandResult = _session.shop.buy(entry_id)
	_message_label.visible = not result.ok
	if not result.ok:
		_message_label.text = REFUSED_TEXTS.get(result.reason, REFUSED_TEXT_DEFAULT)
	_refresh()


func _on_shop_purchased(_entry_id: StringName, _count: int) -> void:
	_refresh()


func _on_item_sold(_item_id: StringName, _qty: int, _gold: int) -> void:
	_refresh()


func _on_gold_changed(_new_amount: int, _delta: int) -> void:
	_refresh()


func _on_bank_changed(_item_id: StringName, _new_count: int, _delta: int) -> void:
	_refresh()


func _on_level_up(_skill_id: StringName, _new_level: int) -> void:
	_refresh()


func _on_character_level_up(_new_level: int) -> void:
	_refresh()


func _on_deposit_changed(_used: int, _capacity: int) -> void:
	_refresh()
