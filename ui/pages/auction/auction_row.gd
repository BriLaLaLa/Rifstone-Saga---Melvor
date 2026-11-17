class_name AuctionRow
extends PanelContainer
## One line of the Auction House list (docs/05_INTERFACES.md §7.p): icon and name, owned (sell) or stock (buy), unit price,
## trend and, when selling, the fixed Deposit price. Zebra background, highlighted when selected; a click only asks the page
## to select the item. Every number is read at each `refresh` from the auction module (`sell_quote`, `buy_quote`, `stock`,
## `stock_max`, `trend`, `buy_level`, `level`) or `Shop.sell_value`; the row keeps no game value.

signal row_clicked(item_id: StringName)

const SEPARATION: int = 8
const ICON_SIDE: int = 28
const PAD_X: int = 6
const PAD_Y: int = 3
const NAME_MIN_WIDTH: float = 140.0
const AVAIL_WIDTH: float = 84.0
const PRICE_WIDTH: float = 70.0
const TREND_WIDTH: float = 92.0
const DEPOSIT_WIDTH: float = 80.0
const ZEBRA_COLOR := Color(1, 1, 1, 0.045)
const HOVER_COLOR := Color(1, 1, 1, 0.09)

var item_id: StringName = &""
var mode: StringName = &"sell"
var _selected: bool = false
var _zebra: bool = false
var _icon: TextureRect = null
var _name_label: Label = null
var _avail_label: Label = null
var _price_label: Label = null
var _trend_label: Label = null
var _deposit_label: Label = null


## Builds the nodes of the row of `id` in `trade_mode` (`&"sell"` or `&"buy"`).
func setup(id: StringName, trade_mode: StringName) -> void:
	item_id = id
	mode = trade_mode
	name = "Row_%s" % id
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(_apply_style.bind(true))
	mouse_exited.connect(_apply_style.bind(false))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", SEPARATION)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(ICON_SIDE, ICON_SIDE)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_icon)
	_name_label = _cell(row, "NameLabel", 0.0, HORIZONTAL_ALIGNMENT_LEFT)
	_name_label.custom_minimum_size.x = NAME_MIN_WIDTH
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_avail_label = _cell(row, "AvailLabel", AVAIL_WIDTH, HORIZONTAL_ALIGNMENT_RIGHT)
	_price_label = _cell(row, "PriceLabel", PRICE_WIDTH, HORIZONTAL_ALIGNMENT_RIGHT)
	_price_label.add_theme_color_override("font_color", UiStyle.GOLD_LIGHT)
	_trend_label = _cell(row, "TrendLabel", TREND_WIDTH, HORIZONTAL_ALIGNMENT_LEFT)
	_deposit_label = _cell(row, "DepositLabel", DEPOSIT_WIDTH, HORIZONTAL_ALIGNMENT_RIGHT)
	_deposit_label.visible = mode == &"sell"
	_deposit_label.add_theme_color_override("font_color", UiStyle.GOLD)
	gui_input.connect(_on_gui_input)
	_apply_style(false)


## Rereads the item from `auction` (an AuctionHouse) and `session`; `selected` and `zebra` are presentation.
func refresh(auction: Object, session: GameSession, selected: bool, zebra: bool) -> void:
	_selected = selected
	_zebra = zebra
	var def: ItemDef = session.data.item(item_id)
	_icon.texture = ItemSlotView.icon_of(def.icon)
	_name_label.text = def.name
	var trend: StringName = auction.trend(item_id)
	_trend_label.text = AuctionTexts.trend_arrow_text(trend)
	_trend_label.add_theme_color_override("font_color", trend_color(trend))
	if mode == &"sell":
		_avail_label.text = NumberFormat.format_int(session.bank.get_count(item_id))
		_price_label.text = Money.text(int(auction.sell_quote(item_id, 1)), session.data.currency())
		_deposit_label.text = Money.text(session.shop.sell_value(item_id, 1), session.data.currency())
	else:
		_price_label.text = Money.text(int(auction.buy_quote(item_id, 1)), session.data.currency())
		if int(auction.level()) >= int(auction.buy_level(item_id)):
			_avail_label.text = AuctionTexts.AVAILABLE_TEXT % [NumberFormat.format_int(int(auction.stock(item_id))),
					NumberFormat.format_int(int(auction.stock_max(item_id)))]
			_avail_label.remove_theme_color_override("font_color")
		else:
			_avail_label.text = AuctionTexts.REQUIRES_SHORT_TEXT % int(auction.buy_level(item_id))
			_avail_label.add_theme_color_override("font_color", UiStyle.BAD)
	_apply_style(false)


static func trend_color(trend: StringName) -> Color:
	match trend:
		&"up":
			return UiStyle.GOOD
		&"down":
			return UiStyle.BAD
	return UiStyle.GOLD  # readable on the window background (GOLD_DIM was too faint)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		row_clicked.emit(item_id)


func _apply_style(hover: bool) -> void:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.content_margin_left = PAD_X
	box.content_margin_right = PAD_X
	box.content_margin_top = PAD_Y
	box.content_margin_bottom = PAD_Y
	box.bg_color = Color(0, 0, 0, 0)
	if _zebra:
		box.bg_color = ZEBRA_COLOR
	if hover:
		box.bg_color = HOVER_COLOR
	if _selected:
		box.bg_color = UiStyle.GOLD_FAINT
		box.set_border_width_all(1)
		box.border_color = UiStyle.GOLD
	add_theme_stylebox_override("panel", box)


func _cell(parent: Node, node_name: String, width: float, align: HorizontalAlignment) -> Label:
	var label: Label = Label.new()
	label.name = node_name
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if width > 0.0:
		label.custom_minimum_size.x = width
	parent.add_child(label)
	return label
