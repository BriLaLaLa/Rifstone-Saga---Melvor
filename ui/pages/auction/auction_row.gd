class_name AuctionRow
extends PanelContainer
## One line of the Auction House list (docs/05_INTERFACES.md §7.p, M37 §45.2): icon and name, owned (sell) or stock (buy), unit
## price, "% sulla media" with its arrow and colour, and when selling the total of the pieces owned and the fixed Deposit price.
## Zebra background; the selected row has a fill and a 3 px bar on the left; a click only asks the page to select the item.
## Every number is read at each `refresh` from the auction module (`sell_quote`, `buy_quote`, `price_gap`, `stock`, `stock_max`,
## `buy_level`, `level`) or `Shop.sell_value`; the row keeps no game value.

signal row_clicked(item_id: StringName)

const SEPARATION: int = 8
const ICON_SIDE: int = 28
const PAD_X: int = 6
const PAD_Y: int = 3
const NAME_MIN_WIDTH: float = 110.0
const AVAIL_WIDTH: float = 64.0
const PRICE_WIDTH: float = 96.0
const GAP_WIDTH: float = 84.0
const TOTAL_WIDTH: float = 96.0
const DEPOSIT_WIDTH: float = 84.0
const BAR_WIDTH: int = 3
const NEUTRAL_COLOR := Color(0.85, 0.82, 0.74)
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
var _gap_label: Label = null
var _total_label: Label = null
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
	_gap_label = _cell(row, "GapLabel", GAP_WIDTH, HORIZONTAL_ALIGNMENT_RIGHT)
	_total_label = _cell(row, "TotalLabel", TOTAL_WIDTH, HORIZONTAL_ALIGNMENT_RIGHT)
	_total_label.visible = mode == &"sell"
	_total_label.add_theme_color_override("font_color", UiStyle.GOLD_LIGHT)
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
	var gap: int = int(auction.price_gap(item_id, mode))
	_gap_label.text = AuctionTexts.gap_text(gap)
	_gap_label.add_theme_color_override("font_color", gap_color(gap, mode))
	var currency: CurrencyParams = session.data.currency()
	if mode == &"sell":
		var owned: int = session.bank.get_count(item_id)
		_avail_label.text = NumberFormat.format_int(owned)
		_set_money(_price_label, int(auction.sell_quote(item_id, 1)), currency)
		_set_money(_total_label, int(auction.sell_quote(item_id, owned)), currency)
		_set_money(_deposit_label, session.shop.sell_value(item_id, 1), currency)
	else:
		_set_money(_price_label, int(auction.buy_quote(item_id, 1)), currency)
		if int(auction.level()) >= int(auction.buy_level(item_id)):
			_avail_label.text = AuctionTexts.AVAILABLE_TEXT % [NumberFormat.format_int(int(auction.stock(item_id))),
					NumberFormat.format_int(int(auction.stock_max(item_id)))]
			_avail_label.remove_theme_color_override("font_color")
		else:
			_avail_label.text = AuctionTexts.REQUIRES_SHORT_TEXT % int(auction.buy_level(item_id))
			_avail_label.add_theme_color_override("font_color", UiStyle.BAD)
	_apply_style(false)


## Colour of a gap from `AuctionHouse.price_gap`: green = convenient (buying below the average, selling above it), red = not,
## a readable neutral inside +-1 % and when there is no gap.
static func gap_color(gap: int, trade_mode: StringName) -> Color:
	if gap == AuctionTexts.NO_GAP or absi(gap) <= AuctionTexts.GAP_NEUTRAL_PCT:
		return NEUTRAL_COLOR
	var convenient: bool = gap < 0 if trade_mode == &"buy" else gap > 0
	return UiStyle.GOOD if convenient else UiStyle.BAD


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
		box.border_width_left = BAR_WIDTH  # the 1 px frame got lost at 1280x720
		box.border_color = UiStyle.GOLD
	add_theme_stylebox_override("panel", box)


func _set_money(label: Label, copper: int, currency: CurrencyParams) -> void:
	label.text = AuctionTexts.money_short(copper, currency)


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
