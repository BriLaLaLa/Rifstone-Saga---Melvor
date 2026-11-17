class_name AuctionMine
extends VBoxContainer
## "Le mie inserzioni" tab (docs/05_INTERFACES_M27.md §7.o): one row per active listing of the player from `AuctionHouse.my_listings`
## (item, sold of total, unit price, time left, status: in vendita / superata / venduta in parte) with Annulla (reason of
## `can_cancel`). Everything is read at each `refresh`; the click on Annulla sends `cancel_requested`, the page issues the command.

signal cancel_requested(listing_id: int)

const NAME_MIN: float = 150.0
const SOLD_WIDTH: float = 80.0
const PRICE_WIDTH: float = 170.0
const TIME_WIDTH: float = 90.0
const STATUS_WIDTH: float = 190.0
const BUTTON_WIDTH: float = 100.0
const WIDTHS: Array[float] = [NAME_MIN, SOLD_WIDTH, PRICE_WIDTH, TIME_WIDTH, STATUS_WIDTH, BUTTON_WIDTH]

var _count_label: Label = null
var _rows: VBoxContainer = null
var _empty: Label = null
var _message: Label = null


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	_count_label = Label.new()
	_count_label.name = "MineCount"
	_count_label.theme_type_variation = &"HeaderLabel"
	add_child(_count_label)
	var note: Label = Label.new()
	note.theme_type_variation = &"MutedLabel"
	note.text = AuctionTexts.MINE_NOTE_TEXT
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(note)
	add_child(_line([AuctionTexts.COLUMN_NAME_TEXT, AuctionTexts.MINE_SOLD_TEXT, AuctionTexts.COLUMN_PRICE_TEXT,
			AuctionTexts.MINE_TIME_TEXT, AuctionTexts.MINE_STATUS_TEXT, ""], true))
	_empty = Label.new()
	_empty.name = "MineEmpty"
	_empty.theme_type_variation = &"HeaderLabel"
	_empty.text = AuctionTexts.MINE_EMPTY_TEXT
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_empty)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.name = "MineRows"
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rows)
	_message = Label.new()
	_message.name = "MineMessage"
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.visible = false
	add_child(_message)


## Redraws from the module.
func refresh(auction: Object, session: GameSession) -> void:
	var currency: CurrencyParams = session.data.currency()
	var listings: Array = auction.my_listings()
	_count_label.text = AuctionTexts.MINE_COUNT_TEXT % [listings.size(), int(auction.max_listings())]
	_empty.visible = listings.is_empty()
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	for listing: Dictionary in listings:
		var id: int = int(listing["id"])
		var sold: int = int(listing["sold"])
		var total: int = sold + int(listing["qty"])
		var price: MoneyLabel = MoneyLabel.new()
		price.custom_minimum_size.x = PRICE_WIDTH
		price.set_amount(int(listing["price"]), currency)
		var cancel: Button = Button.new()
		cancel.name = "Cancel_%d" % id
		cancel.text = AuctionTexts.CANCEL_TEXT
		cancel.custom_minimum_size.x = BUTTON_WIDTH
		cancel.focus_mode = Control.FOCUS_NONE
		var can: CommandResult = auction.can_cancel(id)
		cancel.disabled = not can.ok
		cancel.tooltip_text = "" if can.ok else AuctionTexts.refused(can.reason)
		cancel.pressed.connect(func() -> void: cancel_requested.emit(id))
		var line: HBoxContainer = _line([session.data.item(listing["item"]).name,
				"%s/%s" % [NumberFormat.format_int(sold), NumberFormat.format_int(total)], price,
				AuctionTexts.time_left_text(int(listing["ends_in_ms"])),
				AuctionTexts.status_text(listing["status"], sold > 0), cancel], false)
		line.name = "Listing_%d" % id
		(line.get_child(4) as Label).add_theme_color_override("font_color",
				UiStyle.BAD if listing["status"] == &"undercut" else UiStyle.GOOD)
		_rows.add_child(line)


## Outcome of the last command (green) or refusal (red).
func show_message(text: String, color: Color) -> void:
	_message.text = text
	_message.add_theme_color_override("font_color", color)
	_message.visible = true


## A row of cells: a String becomes a Label of the column width, a Control is added as it is.
func _line(cells: Array, header: bool) -> HBoxContainer:
	var line: HBoxContainer = HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	for index: int in cells.size():
		if cells[index] is Control:
			line.add_child(cells[index] as Control)
			continue
		var label: Label = Label.new()
		label.text = cells[index]
		label.custom_minimum_size.x = WIDTHS[index]
		label.clip_text = true
		if index == 0:
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if header:
			label.theme_type_variation = &"MutedLabel"
		line.add_child(label)
	return line
