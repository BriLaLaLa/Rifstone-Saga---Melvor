class_name AuctionOffersView
extends VBoxContainer
## The order book of the selected item (docs/05_INTERFACES_M27.md §5.39, §7.o; M38 §7.ag): one row per listing from the cheapest.
## Sell mode: the listing price and the pieces. Buy mode (`buying`): the buy price and the pieces `left` (`BuyRow_<j>`, sold-out rows
## dimmed); the player's own listings are shown but cannot be bought. It draws what `AuctionHouse.book` returns; no state.

const ROW_HEIGHT: float = 24.0
const MAX_HEIGHT: float = 150.0
const OWN_BG: Color = Color(0.79, 0.64, 0.36, 0.22)
const DIM_ALPHA: float = 0.4

var _scroll: ScrollContainer = null
var _rows: VBoxContainer = null
var _empty: Label = null


func _ready() -> void:
	_empty = Label.new()
	_empty.name = "BookEmpty"
	_empty.theme_type_variation = &"MutedLabel"
	_empty.text = AuctionTexts.BOOK_EMPTY_TEXT
	add_child(_empty)
	_scroll = ScrollContainer.new()
	_scroll.name = "BookScroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.custom_minimum_size.y = MAX_HEIGHT
	add_child(_scroll)
	_rows = VBoxContainer.new()
	_rows.name = "BookRows"
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_rows)


## Redraws the rows of `book` (`AuctionHouse.book`) with the money format of `currency`; `buying` shows the buy prices.
func show_book(book: Array, currency: CurrencyParams, buying: bool = false) -> void:
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	_empty.visible = book.is_empty()
	_scroll.visible = not book.is_empty()
	var npc_index: int = 0
	for entry: Dictionary in book:
		var mine: bool = bool(entry["mine"])
		var row_name: String = ("Book_%d" % int(entry["listing"])) if mine else "Book_npc"
		if buying and not mine:
			row_name = "BuyRow_%d" % npc_index
		if not mine:
			npc_index += 1
		_rows.add_child(_row(entry, mine, buying, row_name, currency))


func _row(entry: Dictionary, mine: bool, buying: bool, row_name: String, currency: CurrencyParams) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = row_name
	panel.custom_minimum_size.y = ROW_HEIGHT
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = OWN_BG if mine else Color(0, 0, 0, 0)
	style.content_margin_left = 4
	style.content_margin_right = 4
	panel.add_theme_stylebox_override("panel", style)
	var row: HBoxContainer = HBoxContainer.new()
	panel.add_child(row)
	var shown_price: int = int(entry["price"])
	var shown_qty: int = int(entry["qty"])
	if buying and not mine:
		shown_price = int(entry.get("buy_price", shown_price))
		shown_qty = int(entry.get("left", shown_qty))
	var price: MoneyLabel = MoneyLabel.new()
	price.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(price)
	price.set_amount(shown_price, currency)
	var qty: Label = Label.new()
	qty.text = AuctionTexts.BOOK_QTY_TEXT % NumberFormat.format_int(shown_qty)
	row.add_child(qty)
	if mine:
		var own: Label = Label.new()
		own.text = AuctionTexts.BOOK_MINE_TEXT
		own.add_theme_color_override("font_color", UiStyle.GOLD_LIGHT)
		row.add_child(own)
	if (buying and not mine and shown_qty <= 0) or (buying and mine):
		panel.modulate.a = DIM_ALPHA
	return panel
