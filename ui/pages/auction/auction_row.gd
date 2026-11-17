class_name AuctionRow
extends HBoxContainer
## One item of the Auction House page (docs/05_INTERFACES.md §7.p): icon, name, owned, price per piece (and the fixed
## Deposit price when selling, stock or required level when buying), trend, quantity, expected total and the
## Vendi / Compra button with the reason when it is disabled. Every number is read from the auction module (`sell_quote`,
## `buy_quote`, `stock`, `stock_max`, `trend`, `buy_level`, `can_sell`, `can_buy`) or `Shop.sell_value` at each `refresh`;
## the only own value is the quantity picked in the SpinBox (presentation) and a reference to the module.

signal trade_requested(item_id: StringName, qty: int)

const SEPARATION: int = 14
const SCROLLBAR_GAP: float = 12.0
const ICON_SIDE: int = 32
const NAME_WIDTH: float = 230.0
const PRICE_WIDTH: float = 170.0
const QTY_WIDTH: float = 250.0
const ACTION_WIDTH: float = 130.0
const SHORTCUTS: Array[int] = [1, 10, 100]

var item_id: StringName = &""
var mode: StringName = &"sell"
## The module read by the row, used through the contract signatures of §5.30 only (also a stub with the same ones).
var _auction: Object = null
var _icon: TextureRect = null
var _name_label: Label = null
var _info_label: Label = null
var _reason_label: Label = null
var _price_label: Label = null
var _extra_label: Label = null
var _trend_label: Label = null
var _spin: SpinBox = null
var _total_label: Label = null
var _button: Button = null
var _max: int = 1


## Builds the nodes of the row of `id` in `trade_mode` (`&"sell"` or `&"buy"`).
func setup(id: StringName, trade_mode: StringName) -> void:
	item_id = id
	mode = trade_mode
	name = "Row_%s" % id
	add_theme_constant_override("separation", SEPARATION)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(ICON_SIDE, ICON_SIDE)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(_icon)
	var names: VBoxContainer = _column(NAME_WIDTH)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_label = _label(names, &"HeaderLabel", "NameLabel")
	_info_label = _label(names, &"MutedLabel", "InfoLabel")
	_reason_label = _label(names, &"", "ReasonLabel")
	_reason_label.add_theme_color_override("font_color", UiStyle.BAD)
	_reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var prices: VBoxContainer = _column(PRICE_WIDTH)
	_price_label = _label(prices, &"", "PriceLabel")
	_price_label.add_theme_color_override("font_color", UiStyle.GOLD_LIGHT)
	_extra_label = _label(prices, &"MutedLabel", "ExtraLabel")
	_trend_label = _label(prices, &"", "TrendLabel")
	var qty: VBoxContainer = _column(QTY_WIDTH)
	_spin = SpinBox.new()
	_spin.name = "QtySpin"
	_spin.min_value = 1
	_spin.step = 1
	_spin.rounded = true
	_spin.value_changed.connect(func(_v: float) -> void: _redraw_trade())
	qty.add_child(_spin)
	var shortcuts: HBoxContainer = HBoxContainer.new()
	qty.add_child(shortcuts)
	for amount: int in SHORTCUTS:
		_shortcut(shortcuts, str(amount), amount)
	_shortcut(shortcuts, AuctionTexts.ALL_TEXT, -1)
	var action: VBoxContainer = _column(ACTION_WIDTH)
	_total_label = _label(action, &"", "TotalLabel")
	_total_label.add_theme_color_override("font_color", UiStyle.GOLD_LIGHT)
	_button = Button.new()
	_button.name = "TradeButton"
	_button.text = AuctionTexts.TAB_SELL_TEXT if mode == &"sell" else AuctionTexts.TAB_BUY_TEXT
	_button.theme_type_variation = &"AccentButton"
	_button.focus_mode = Control.FOCUS_NONE
	_button.pressed.connect(func() -> void: trade_requested.emit(item_id, int(_spin.value)))
	action.add_child(_button)
	var edge: Control = Control.new()  # keeps the button away from the page scrollbar
	edge.name = "ScrollbarGap"
	edge.custom_minimum_size.x = SCROLLBAR_GAP
	add_child(edge)


## Rereads the item from `auction` (an AuctionHouse) and `session`.
func refresh(auction: Object, session: GameSession) -> void:
	_auction = auction
	var def: ItemDef = session.data.item(item_id)
	_icon.texture = ItemSlotView.icon_of(def.icon)
	_name_label.text = def.name
	var owned: int = session.bank.get_count(item_id)
	_info_label.text = AuctionTexts.OWNED_TEXT % NumberFormat.format_int(owned)
	var trend: StringName = auction.trend(item_id)
	_trend_label.text = AuctionTexts.trend_text(trend)
	_trend_label.add_theme_color_override("font_color", _trend_color(trend))
	if mode == &"sell":
		_price_label.text = AuctionTexts.PRICE_TEXT % NumberFormat.format_int(int(auction.sell_quote(item_id, 1)))
		_extra_label.text = AuctionTexts.DEPOSIT_TEXT % NumberFormat.format_int(session.shop.sell_value(item_id, 1))
		_max = maxi(owned, 1)
	else:
		_price_label.text = AuctionTexts.PRICE_TEXT % NumberFormat.format_int(int(auction.buy_quote(item_id, 1)))
		if int(auction.level()) >= int(auction.buy_level(item_id)):
			_extra_label.text = AuctionTexts.STOCK_TEXT % [NumberFormat.format_int(int(auction.stock(item_id))),
					NumberFormat.format_int(int(auction.stock_max(item_id)))]
		else:
			_extra_label.text = AuctionTexts.REQUIRES_TEXT % int(auction.buy_level(item_id))
		_max = maxi(int(auction.stock(item_id)), 1)
	_spin.max_value = _max
	_spin.set_value_no_signal(clampf(_spin.value, 1.0, float(_max)))
	_redraw_trade()


## Total and button for the quantity picked now.
func _redraw_trade() -> void:
	if _auction == null:
		return
	var qty: int = int(_spin.value)
	var selling: bool = mode == &"sell"
	var total: int = int(_auction.sell_quote(item_id, qty) if selling else _auction.buy_quote(item_id, qty))
	_total_label.text = AuctionTexts.TOTAL_TEXT % NumberFormat.format_int(total)
	var can: CommandResult = _auction.can_sell(item_id, qty) if selling else _auction.can_buy(item_id, qty)
	var reason: String = "" if can.ok else AuctionTexts.refused(can.reason)
	_button.disabled = not can.ok
	_button.tooltip_text = reason
	_reason_label.text = reason
	_reason_label.visible = not can.ok


func _shortcut(parent: HBoxContainer, text: String, amount: int) -> void:
	var button: Button = Button.new()
	button.text = text
	button.name = "Shortcut_%s" % ("all" if amount < 0 else str(amount))
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func() -> void: _spin.value = float(_max) if amount < 0 else float(amount))
	parent.add_child(button)


func _trend_color(trend: StringName) -> Color:
	match trend:
		&"up":
			return UiStyle.GOOD
		&"down":
			return UiStyle.BAD
	return UiStyle.GOLD  # readable on the window background (GOLD_DIM was too faint)


func _column(width: float) -> VBoxContainer:
	var column: VBoxContainer = VBoxContainer.new()
	column.custom_minimum_size.x = width
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(column)
	return column


func _label(parent: Node, variation: StringName, node_name: String) -> Label:
	var label: Label = Label.new()
	label.name = node_name
	if variation != &"":
		label.theme_type_variation = variation
	parent.add_child(label)
	return label
