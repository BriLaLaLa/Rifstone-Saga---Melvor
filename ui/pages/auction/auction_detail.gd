class_name AuctionDetail
extends PanelContainer
## Right panel of the Auction House page (docs/05_INTERFACES.md §7.p): the selected item (icon, name, unit price, trend),
## the quantity (field and 1 / 10 / 100 / Tutti), the expected total, the big Compra / Vendi button and the outcome or refusal
## message. Every number is read from the auction module at each `refresh`; the only own value is the quantity picked in the
## SpinBox (presentation). The button sends `trade_requested`, the page issues the command.

signal trade_requested(item_id: StringName, qty: int)
signal list_requested(item_id: StringName, qty: int, price: int, duration_id: StringName)

const SEPARATION: int = 10
const MARGIN: int = 14
const ICON_SIDE: int = 48
const SCROLL_PAD: int = 14
const BUTTON_HEIGHT: float = 52.0
const SHORTCUTS: Array[int] = [1, 10, 100]

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
var _market_box: VBoxContainer = null
var _buyers_label: Label = null
var _sellers_label: Label = null
var _demand_label: Label = null
var _demand_hint: Label = null
var _spin: SpinBox = null
var _total_label: Label = null
var _button: Button = null
var _reason_label: Label = null
var _message_label: Label = null
var _listings_label: Label = null
var _book_caption: Label = null
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
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(scroll)
	var pad: MarginContainer = MarginContainer.new()  # keeps the content clear of the scroll bar
	pad.add_theme_constant_override("margin_right", SCROLL_PAD)
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(pad)
	var inner: VBoxContainer = VBoxContainer.new()
	pad.add_child(inner)
	_empty_label = Label.new()
	_empty_label.name = "EmptyLabel"
	_empty_label.theme_type_variation = &"HeaderLabel"
	_empty_label.text = AuctionTexts.SELECT_ITEM_TEXT
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.add_child(_empty_label)
	_box = VBoxContainer.new()
	_box.name = "Detail"
	_box.add_theme_constant_override("separation", SEPARATION)
	_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.add_child(_box)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(ICON_SIDE, ICON_SIDE)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_box.add_child(_icon)
	_name_label = _label("NameLabel", &"TitleLabel")
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_category_label = _label("CategoryLabel", &"MutedLabel")
	_category_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(HSeparator.new())
	_info_label = _label("InfoLabel", &"MutedLabel")
	var price_row: HBoxContainer = HBoxContainer.new()
	_box.add_child(price_row)
	_price_label = _label("PriceLabel", &"", price_row)
	_price_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_price_label.add_theme_color_override("font_color", UiStyle.GOLD_LIGHT)
	_trend_label = _label("TrendLabel", &"", price_row)
	_box.add_child(HSeparator.new())
	_book_caption = _label("BookCaption", &"HeaderLabel")
	_book_caption.text = AuctionTexts.BOOK_TITLE_TEXT
	_book = AuctionOffersView.new()
	_book.name = "Book"
	_box.add_child(_book)
	_box.add_child(HSeparator.new())
	_label("QuantityCaption", &"HeaderLabel").text = AuctionTexts.QUANTITY_TEXT
	_spin = SpinBox.new()
	_spin.name = "QtySpin"
	_spin.min_value = 1
	_spin.step = 1
	_spin.rounded = true
	_spin.value_changed.connect(func(_v: float) -> void: _redraw_trade())
	_box.add_child(_spin)
	var shortcuts: HBoxContainer = HBoxContainer.new()
	_box.add_child(shortcuts)
	for amount: int in SHORTCUTS:
		_shortcut(shortcuts, str(amount), amount)
	_shortcut(shortcuts, AuctionTexts.ALL_TEXT, -1)
	_total_label = _label("TotalLabel", &"HeaderLabel")
	_total_label.add_theme_color_override("font_color", UiStyle.GOLD_LIGHT)
	_button = Button.new()
	_button.name = "TradeButton"
	_button.theme_type_variation = &"AccentButton"
	_button.custom_minimum_size.y = BUTTON_HEIGHT
	_button.focus_mode = Control.FOCUS_NONE
	_button.pressed.connect(func() -> void: trade_requested.emit(_item_id, int(_spin.value)))
	_box.add_child(_button)
	_reason_label = _label("ReasonLabel", &"")
	_reason_label.add_theme_color_override("font_color", UiStyle.BAD)
	_reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sell_note = _label("SellNowNote", &"MutedLabel")
	_sell_note.text = AuctionTexts.SELL_NOW_NOTE_TEXT
	_box.add_child(HSeparator.new())
	_form = AuctionListForm.new()
	_form.name = "ListForm"
	_form.list_requested.connect(func(id: StringName, qty: int, price: int, duration: StringName) -> void:
		list_requested.emit(id, qty, price, duration))
	_box.add_child(_form)
	_box.add_child(HSeparator.new())
	_market_box = VBoxContainer.new()
	_market_box.name = "MarketBox"
	_box.add_child(_market_box)
	_label("MarketCaption", &"HeaderLabel", _market_box).text = AuctionTexts.MARKET_TITLE_TEXT
	_buyers_label = _label("BuyersLabel", &"", _market_box)
	_sellers_label = _label("SellersLabel", &"", _market_box)
	_demand_label = _label("DemandLabel", &"", _market_box)
	_demand_hint = _label("DemandHint", &"MutedLabel", _market_box)
	_demand_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_listings_label = _label("ListingsLabel", &"", _market_box)
	_message_label = _label("MessageLabel", &"", stack)
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_label.visible = false
	_show_detail(false)


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
	_icon.texture = ItemSlotView.icon_of(def.icon)
	_name_label.text = def.name
	_category_label.text = AuctionTexts.category_name(def.category)
	var trend: StringName = auction.trend(item_id)
	_trend_label.text = AuctionTexts.trend_arrow_text(trend)
	_trend_label.add_theme_color_override("font_color", AuctionRow.trend_color(trend))
	_redraw_market(auction.population(item_id))
	_book.show_book(auction.book(item_id), _currency)
	_sell_note.visible = selling
	_form.visible = selling
	var owned: int = session.bank.get_count(item_id)
	if selling:
		_info_label.text = AuctionTexts.OWNED_TEXT % NumberFormat.format_int(owned) + "\n" + AuctionTexts.DEPOSIT_TEXT % \
				Money.text(session.shop.sell_value(item_id, 1), session.data.currency())
		_max = maxi(owned, 1)
	else:
		if int(auction.level()) >= int(auction.buy_level(item_id)):
			_info_label.text = AuctionTexts.STOCK_TEXT % [NumberFormat.format_int(int(auction.stock(item_id))),
					NumberFormat.format_int(int(auction.stock_max(item_id)))]
		else:
			_info_label.text = AuctionTexts.REQUIRES_TEXT % int(auction.buy_level(item_id))
		_max = maxi(int(auction.stock(item_id)), 1)
	var unit: int = int(auction.sell_quote(item_id, 1) if selling else auction.buy_quote(item_id, 1))
	_price_label.text = AuctionTexts.UNIT_PRICE_VALUE_TEXT % Money.text(unit, session.data.currency())
	_button.text = AuctionTexts.SELL_NOW_TEXT if selling else AuctionTexts.TAB_BUY_TEXT
	_spin.max_value = _max
	_spin.set_value_no_signal(clampf(_spin.value, 1.0, float(_max)))
	_redraw_trade()


## Shows the outcome of the last command (success in green, refusal in red) until the item changes.
func show_message(text: String, color: Color) -> void:
	_message_label.text = text
	_message_label.add_theme_color_override("font_color", color)
	_message_label.visible = true


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


## Total and button for the quantity picked now.
func _redraw_trade() -> void:
	if _auction == null or _item_id == &"":
		return
	var qty: int = int(_spin.value)
	var selling: bool = _mode == &"sell"
	var total: int = int(_auction.sell_quote(_item_id, qty) if selling else _auction.buy_quote(_item_id, qty))
	_total_label.text = AuctionTexts.TOTAL_TEXT % Money.text(total, _currency)
	var can: CommandResult = _auction.can_sell(_item_id, qty) if selling else _auction.can_buy(_item_id, qty)
	var reason: String = "" if can.ok else AuctionTexts.refused(can.reason)
	_button.disabled = not can.ok
	_button.tooltip_text = reason
	_reason_label.text = reason
	_reason_label.visible = not can.ok
	if selling:
		_form.refresh(_auction, _session, _item_id, qty)


## Puts the suggested price back in the listing form (after a listing).
func reset_price() -> void:
	_form.reset_price()


func _show_detail(on: bool) -> void:
	_box.visible = on
	_empty_label.visible = not on


func _shortcut(parent: HBoxContainer, text: String, amount: int) -> void:
	var button: Button = Button.new()
	button.text = text
	button.name = "Shortcut_%s" % ("all" if amount < 0 else str(amount))
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func() -> void: _spin.value = float(_max) if amount < 0 else float(amount))
	parent.add_child(button)


func _label(node_name: String, variation: StringName, parent: Node = null) -> Label:
	var label: Label = Label.new()
	label.name = node_name
	if variation != &"":
		label.theme_type_variation = variation
	(parent if parent != null else _box).add_child(label)
	return label
