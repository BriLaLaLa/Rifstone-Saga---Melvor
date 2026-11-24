class_name AuctionDetail
extends PanelContainer
## Right panel of the Auction House page (docs/05_INTERFACES_M37.md §7.af): a fixed top (icon, name, category, unit price, gap against
## the average, base value), the "Subito / Inserzione / Mercato" sections in a scroll, and a fixed footer (total, action button,
## refusal reason, outcome message) that never scrolls away. Every number is read from the auction module at each `refresh`; the only
## own values are the quantity in the SpinBox and the chosen section (presentation). The buttons send signals, the page issues the command.

signal trade_requested(item_id: StringName, qty: int)
signal list_requested(item_id: StringName, qty: int, price: int, duration_id: StringName)

const SEPARATION: int = 8
const MARGIN: int = 14
const ICON_SIDE: int = 48
const SCROLL_PAD: int = 14
const BUTTON_HEIGHT: float = 52.0
const SHORTCUTS: Array[int] = [1, 10, 100]
const SHORTCUT_ALL: int = -1
const SHORTCUT_MAX: int = -2

var _item_id: StringName = &""
var _mode: StringName = &"sell"
var _auction: Object = null
var _currency: CurrencyParams = null
var _session: GameSession = null
var _max: int = 1
var _empty_label: Label = null
var _box: VBoxContainer = null
var _icon: TextureRect = null
var _name_label: Label = null
var _category_label: Label = null
var _info_label: Label = null
var _price_label: Label = null
var _trend_label: Label = null
var _gap_label: Label = null
var _band_label: Label = null
var _sections: AuctionDetailSections = null
var _section_boxes: Dictionary[StringName, Control] = {}
var _market_box: VBoxContainer = null
var _buyers_label: Label = null
var _sellers_label: Label = null
var _demand_label: Label = null
var _demand_hint: Label = null
var _spin: SpinBox = null
var _max_button: Button = null
var _avg_label: Label = null
var _total_label: Label = null
var _trade_footer: VBoxContainer = null
var _button: Button = null
var _reason_label: Label = null
var _message_label: Label = null
var _listings_label: Label = null
var _book: AuctionOffersView = null
var _sell_note: Label = null
var _form: AuctionListForm = null


func _ready() -> void:
	theme_type_variation = &"HudPanel"
	var margin: MarginContainer = MarginContainer.new()
	for side: String in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, MARGIN)
	add_child(margin)
	var stack: VBoxContainer = VBoxContainer.new()
	margin.add_child(stack)
	_empty_label = Label.new()
	_empty_label.name = "EmptyLabel"
	_empty_label.theme_type_variation = &"HeaderLabel"
	_empty_label.text = AuctionTexts.SELECT_ITEM_TEXT
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(_empty_label)
	_box = VBoxContainer.new()
	_box.name = "Detail"
	_box.add_theme_constant_override("separation", SEPARATION)
	_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(_box)
	_build_top()
	_sections = AuctionDetailSections.new()
	_sections.section_changed.connect(func(_id: StringName) -> void: _apply_section())
	_box.add_child(_sections)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_box.add_child(scroll)
	var pad: MarginContainer = MarginContainer.new()  # keeps the content clear of the scroll bar
	pad.add_theme_constant_override("margin_right", SCROLL_PAD)
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(pad)
	var sections: VBoxContainer = VBoxContainer.new()
	sections.add_theme_constant_override("separation", SEPARATION)
	pad.add_child(sections)
	_build_now(_section_box(&"now", sections))
	_form = AuctionListForm.new()
	_form.name = "ListForm"
	_form.list_requested.connect(func(id: StringName, qty: int, price: int, duration: StringName) -> void:
		list_requested.emit(id, qty, price, duration))
	_section_box(&"list", sections).add_child(_form)
	_build_market(_section_box(&"market", sections))
	_build_footer(_box)
	_show_detail(false)


func _build_top() -> void:
	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override("separation", SEPARATION)
	_box.add_child(head)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(ICON_SIDE, ICON_SIDE)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head.add_child(_icon)
	var names: VBoxContainer = VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(names)
	_name_label = _label("NameLabel", &"TitleLabel", names)
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_category_label = _label("CategoryLabel", &"MutedLabel", names)
	var price_row: HBoxContainer = HBoxContainer.new()
	_box.add_child(price_row)
	_price_label = _label("PriceLabel", &"HeaderLabel", price_row)
	_price_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_price_label.add_theme_color_override("font_color", UiStyle.GOLD_LIGHT)
	_trend_label = _label("TrendLabel", &"", price_row)
	_gap_label = _label("PriceGapLabel", &"", _box)
	_band_label = _label("BandLabel", &"MutedLabel", _box)


func _build_now(parent: VBoxContainer) -> void:
	_info_label = _label("InfoLabel", &"MutedLabel", parent)
	_label("QuantityCaption", &"HeaderLabel", parent).text = AuctionTexts.QUANTITY_TEXT
	_spin = SpinBox.new()
	_spin.name = "QtySpin"
	_spin.min_value = 1
	_spin.step = 1
	_spin.rounded = true
	_spin.value_changed.connect(func(_v: float) -> void: _redraw_trade())
	parent.add_child(_spin)
	var shortcuts: HBoxContainer = HBoxContainer.new()
	parent.add_child(shortcuts)
	for amount: int in SHORTCUTS:
		_shortcut(shortcuts, str(amount), amount)
	_shortcut(shortcuts, AuctionTexts.ALL_TEXT, SHORTCUT_ALL)
	_max_button = _shortcut(shortcuts, AuctionDetailTexts.MAX_TEXT, SHORTCUT_MAX)
	_avg_label = _label("AvgLabel", &"MutedLabel", parent)
	_sell_note = _label("SellNowNote", &"MutedLabel", parent)
	_sell_note.text = AuctionTexts.SELL_NOW_NOTE_TEXT


func _build_market(parent: VBoxContainer) -> void:
	_label("BookCaption", &"HeaderLabel", parent).text = AuctionTexts.BOOK_TITLE_TEXT
	_book = AuctionOffersView.new()
	_book.name = "Book"
	parent.add_child(_book)
	_market_box = VBoxContainer.new()
	_market_box.name = "MarketBox"
	parent.add_child(_market_box)
	_label("MarketCaption", &"HeaderLabel", _market_box).text = AuctionTexts.MARKET_TITLE_TEXT
	_buyers_label = _label("BuyersLabel", &"", _market_box)
	_sellers_label = _label("SellersLabel", &"", _market_box)
	_demand_label = _label("DemandLabel", &"", _market_box)
	_demand_hint = _label("DemandHint", &"MutedLabel", _market_box)
	_demand_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_listings_label = _label("ListingsLabel", &"", _market_box)


## Fixed at the bottom, outside the scroll: the total, the action of the section ("Compra" / "Vendi subito" or the form's
## "Metti in vendita"), the reason of a refusal and the outcome of the last command.
func _build_footer(parent: VBoxContainer) -> void:
	parent.add_child(HSeparator.new())
	_trade_footer = VBoxContainer.new()
	_trade_footer.name = "TradeFooter"
	parent.add_child(_trade_footer)
	_total_label = _label("TotalLabel", &"HeaderLabel", _trade_footer)
	_total_label.add_theme_color_override("font_color", UiStyle.GOLD_LIGHT)
	_button = Button.new()
	_button.name = "TradeButton"
	_button.theme_type_variation = &"AccentButton"
	_button.custom_minimum_size.y = BUTTON_HEIGHT
	_button.focus_mode = Control.FOCUS_NONE
	_button.pressed.connect(func() -> void: trade_requested.emit(_item_id, int(_spin.value)))
	_trade_footer.add_child(_button)
	_reason_label = _label("ReasonLabel", &"", _trade_footer)
	_reason_label.add_theme_color_override("font_color", UiStyle.BAD)
	_reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(_form.footer())
	_message_label = _label("MessageLabel", &"", parent)
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_label.visible = false


## Rereads `item_id` (`&""` = nothing selected: the empty state) from `auction` and `session`. The quantity resets when the
## item changes.
func refresh(auction: Object, session: GameSession, mode: StringName, item_id: StringName) -> void:
	_auction = auction
	_session = session
	_currency = session.data.currency()
	_mode = mode
	_show_detail(item_id != &"")
	if item_id == &"":
		_item_id = &""
		return
	if item_id != _item_id:
		_spin.set_value_no_signal(1.0)
		_message_label.visible = false
	_item_id = item_id
	var def: ItemDef = session.data.item(item_id)
	var selling: bool = mode == &"sell"
	_sections.set_mode(mode)
	_icon.texture = ItemSlotView.icon_of(def.icon)
	_name_label.text = def.name
	_category_label.text = AuctionTexts.category_name(def.category)
	var trend: StringName = auction.trend(item_id)
	_trend_label.text = AuctionTexts.trend_arrow_text(trend)
	_trend_label.add_theme_color_override("font_color", AuctionRow.trend_color(trend))
	var gap_mode: StringName = &"sell" if selling else &"buy"
	var gap: int = int(auction.price_gap(item_id, gap_mode))
	_gap_label.visible = gap != AuctionHouse.NO_GAP
	if _gap_label.visible:
		_gap_label.text = AuctionDetailTexts.gap_text(gap)
		_gap_label.add_theme_color_override("font_color", AuctionDetailTexts.gap_color(gap, gap_mode))
	_band_label.text = AuctionDetailTexts.BASE_VALUE_TEXT % Money.text(int(auction.value_of(item_id)), _currency)
	_redraw_market(auction.population(item_id))
	_book.show_book(auction.book(item_id), _currency)
	_sell_note.visible = selling
	_max_button.visible = not selling
	if selling:
		var owned: int = session.bank.get_count(item_id)
		_info_label.text = AuctionTexts.OWNED_TEXT % NumberFormat.format_int(owned) + "\n" + AuctionTexts.DEPOSIT_TEXT % \
				Money.text(session.shop.sell_value(item_id, 1), _currency)
		_max = maxi(owned, 1)
	else:
		if int(auction.level()) >= int(auction.buy_level(item_id)):
			_info_label.text = AuctionTexts.STOCK_TEXT % [NumberFormat.format_int(int(auction.stock(item_id))),
					NumberFormat.format_int(int(auction.stock_max(item_id)))]
		else:
			_info_label.text = AuctionTexts.REQUIRES_TEXT % int(auction.buy_level(item_id))
		_max = maxi(int(auction.stock(item_id)), 1)
	var unit: int = int(auction.sell_quote(item_id, 1) if selling else auction.buy_quote(item_id, 1))
	_price_label.text = AuctionTexts.UNIT_PRICE_VALUE_TEXT % Money.text(unit, _currency)
	_button.text = AuctionTexts.SELL_NOW_TEXT if selling else AuctionTexts.TAB_BUY_TEXT
	_spin.max_value = _max
	_spin.set_value_no_signal(clampf(_spin.value, 1.0, float(_max)))
	_apply_section()
	_redraw_trade()


## Shows the outcome of the last command (success in green, refusal in red) until the item changes.
func show_message(text: String, color: Color) -> void:
	_message_label.text = text
	_message_label.add_theme_color_override("font_color", color)
	_message_label.visible = true


## Puts the suggested price back in the listing form (after a listing).
func reset_price() -> void:
	_form.reset_price()


## Buyers, sellers and demand from `AuctionHouse.population` (empty = item outside the list: block hidden).
func _redraw_market(pop: Dictionary) -> void:
	_market_box.visible = not pop.is_empty()
	if pop.is_empty():
		return
	var demand: StringName = pop["demand"]
	_buyers_label.text = AuctionTexts.BUYERS_TEXT % NumberFormat.format_int(int(pop["buyers"]))
	_sellers_label.text = AuctionTexts.SELLERS_TEXT % NumberFormat.format_int(int(pop["sellers"]))
	_demand_label.text = AuctionTexts.DEMAND_TEXT % AuctionTexts.demand_text(demand)
	var color: Color = UiStyle.GOOD if demand == &"high" else (UiStyle.BAD if demand == &"low" else UiStyle.GOLD_LIGHT)
	_demand_label.add_theme_color_override("font_color", color)
	_demand_hint.text = AuctionTexts.demand_hint(demand)
	_listings_label.text = AuctionTexts.LISTINGS_TEXT % [NumberFormat.format_int(int(pop.get("listings", 0))),
			NumberFormat.format_int(int(pop.get("units", 0)))]


## Shows the chosen section and, in the fixed footer, the button that goes with it ("Inserzione" has its own).
func _apply_section() -> void:
	var section: StringName = _sections.current()
	for id: StringName in _section_boxes:
		_section_boxes[id].visible = id == section
	var listing: bool = section == &"list"
	_trade_footer.visible = not listing
	_form.footer().visible = listing


## Total, average per piece and button for the quantity picked now.
func _redraw_trade() -> void:
	if _auction == null or _item_id == &"":
		return
	var qty: int = int(_spin.value)
	var selling: bool = _mode == &"sell"
	var total: int = int(_auction.sell_quote(_item_id, qty) if selling else _auction.buy_quote(_item_id, qty))
	_total_label.text = AuctionTexts.TOTAL_TEXT % Money.text(total, _currency)
	_avg_label.visible = selling
	if selling:
		_avg_label.text = AuctionDetailTexts.AVG_PER_PIECE_TEXT % Money.text(total / maxi(qty, 1), _currency)
	var can: CommandResult = _auction.can_sell(_item_id, qty) if selling else _auction.can_buy(_item_id, qty)
	var reason: String = "" if can.ok else AuctionTexts.refused(can.reason)
	_button.disabled = not can.ok
	_button.tooltip_text = reason
	_reason_label.text = reason
	_reason_label.visible = not can.ok
	if selling:
		_form.refresh(_auction, _session, _item_id, qty)


func _show_detail(on: bool) -> void:
	_box.visible = on
	_empty_label.visible = not on


func _section_box(id: StringName, parent: VBoxContainer) -> VBoxContainer:
	var section: VBoxContainer = VBoxContainer.new()
	section.name = "Section_%s" % id
	section.add_theme_constant_override("separation", SEPARATION)
	parent.add_child(section)
	_section_boxes[id] = section
	return section


func _shortcut(parent: HBoxContainer, text: String, amount: int) -> Button:
	var button: Button = Button.new()
	button.text = text
	var suffix: String = "max" if amount == SHORTCUT_MAX else ("all" if amount == SHORTCUT_ALL else str(amount))
	button.name = "Shortcut_%s" % suffix
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func() -> void: _spin.value = _shortcut_value(amount))
	parent.add_child(button)
	return button


## 1 / 10 / 100; `SHORTCUT_ALL` = everything the panel allows; `SHORTCUT_MAX` = `AuctionHouse.max_buyable` (at least 1).
func _shortcut_value(amount: int) -> float:
	if amount == SHORTCUT_MAX:
		return float(maxi(int(_auction.max_buyable(_item_id)), 1))
	return float(_max) if amount == SHORTCUT_ALL else float(amount)


func _label(node_name: String, variation: StringName, parent: Node) -> Label:
	var label: Label = Label.new()
	label.name = node_name
	if variation != &"":
		label.theme_type_variation = variation
	parent.add_child(label)
	return label
