class_name AuctionMine
extends VBoxContainer
## "Le mie vendite" tab (docs/01_GDD_M37.md §45.2 punto 7), two sections: **Attive** (one row per listing of the player from
## `AuctionHouse.my_listings`: icon, item, sold of total, unit price, time left, status, Annulla; a summary from
## `listings_summary`) and **Storico** (`AuctionHistoryView`). Annulla asks a confirmation (`ConfirmCancel_<id>`) only when the
## listing already sold something. Everything is read at each `refresh`; the click sends `cancel_requested`, the page issues the
## command. Keeps only presentation: the section and the listing waiting for the confirmation.

signal cancel_requested(listing_id: int)

const ACTIVE: StringName = &"active"
const HISTORY: StringName = &"history"
const ICON_SIDE: int = 24
const NAME_MIN: float = 130.0
const SOLD_WIDTH: float = 70.0
const PRICE_WIDTH: float = 150.0
const TIME_WIDTH: float = 80.0
const STATUS_WIDTH: float = 180.0
const BUTTON_WIDTH: float = 100.0
const WIDTHS: Array[float] = [ICON_SIDE, NAME_MIN, SOLD_WIDTH, PRICE_WIDTH, TIME_WIDTH, STATUS_WIDTH, BUTTON_WIDTH]

var _section: StringName = ACTIVE
var _confirming: int = -1
var _sections: SubTabBar = null
var _active_box: VBoxContainer = null
var _history: AuctionHistoryView = null
var _count_label: Label = null
var _summary: HBoxContainer = null
var _rows: VBoxContainer = null
var _empty: Label = null
var _message: Label = null
var _last: Array = []


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	_sections = SubTabBar.new()
	_sections.name = "MineSections"
	add_child(_sections)
	_sections.setup([{"id": ACTIVE, "label": AuctionTexts.SECTION_ACTIVE_TEXT}, {"id": HISTORY, "label": AuctionTexts.SECTION_HISTORY_TEXT}])
	_sections.tab_selected.connect(_on_section_selected)
	_active_box = VBoxContainer.new()
	_active_box.name = "ActiveBox"
	_active_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_active_box.add_theme_constant_override("separation", 8)
	add_child(_active_box)
	_count_label = Label.new()
	_count_label.name = "MineCount"
	_count_label.theme_type_variation = &"HeaderLabel"
	_active_box.add_child(_count_label)
	_summary = HBoxContainer.new()
	_summary.name = "MineSummary"
	_active_box.add_child(_summary)
	var note: Label = Label.new()
	note.theme_type_variation = &"MutedLabel"
	note.text = AuctionTexts.MINE_NOTE_TEXT
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_active_box.add_child(note)
	_active_box.add_child(_line([null, AuctionTexts.COLUMN_NAME_TEXT, AuctionTexts.MINE_SOLD_TEXT, AuctionTexts.COLUMN_PRICE_TEXT,
			AuctionTexts.MINE_TIME_TEXT, AuctionTexts.MINE_STATUS_TEXT, ""], true))
	_empty = Label.new()
	_empty.name = "MineEmpty"
	_empty.theme_type_variation = &"HeaderLabel"
	_empty.text = AuctionTexts.MINE_EMPTY_TEXT
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_active_box.add_child(_empty)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_active_box.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.name = "MineRows"
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rows)
	_message = Label.new()
	_message.name = "MineMessage"
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.visible = false
	_active_box.add_child(_message)
	_history = AuctionHistoryView.new()
	_history.name = "History"
	_history.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_history)
	_show_section()


## Redraws from the module.
func refresh(auction: Object, session: GameSession) -> void:
	_last = [auction, session]
	if _history.visible:
		_history.refresh(auction, session)
		return
	var currency: CurrencyParams = session.data.currency()
	var listings: Array = auction.my_listings()
	_count_label.text = AuctionTexts.MINE_COUNT_TEXT % [listings.size(), int(auction.max_listings())]
	_refresh_summary(auction.listings_summary(), currency)
	_empty.visible = listings.is_empty()
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	for listing: Dictionary in listings:
		_rows.add_child(_listing_line(listing, auction, session, currency))


## Outcome of the last command (green) or refusal (red).
func show_message(text: String, color: Color) -> void:
	_message.text = text
	_message.add_theme_color_override("font_color", color)
	_message.visible = true


func _refresh_summary(summary: Dictionary, currency: CurrencyParams) -> void:
	for child: Node in _summary.get_children():
		_summary.remove_child(child)
		child.queue_free()
	_summary.visible = int(summary["count"]) > 0
	var text: Label = Label.new()
	text.text = AuctionTexts.SUMMARY_TEXT % [NumberFormat.format_int(int(summary["count"])),
			NumberFormat.format_int(int(summary["units"]))]
	_summary.add_child(text)
	var net: MoneyLabel = MoneyLabel.new()
	net.set_amount(int(summary["expected_net"]), currency)
	_summary.add_child(net)


func _listing_line(listing: Dictionary, auction: Object, session: GameSession, currency: CurrencyParams) -> HBoxContainer:
	var id: int = int(listing["id"])
	var sold: int = int(listing["sold"])
	var total: int = sold + int(listing["qty"])
	var def: ItemDef = session.data.item(listing["item"])
	var icon: TextureRect = TextureRect.new()
	icon.texture = ItemSlotView.icon_of(def.icon)
	var price: MoneyLabel = MoneyLabel.new()
	price.custom_minimum_size.x = PRICE_WIDTH
	price.set_amount(int(listing["price"]), currency)
	var line: HBoxContainer = _line([icon, def.name, "%s/%s" % [NumberFormat.format_int(sold), NumberFormat.format_int(total)], price,
			AuctionTexts.time_left_text(int(listing["ends_in_ms"])), AuctionTexts.status_text(listing["status"], sold > 0),
			_cancel_cell(id, sold > 0, auction)], false)
	line.name = "Listing_%d" % id
	(line.get_child(5) as Label).add_theme_color_override("font_color",
			UiStyle.BAD if listing["status"] == &"undercut" else UiStyle.GOOD)
	return line


## Annulla; for a listing that already sold something the first click asks "Conferma" / "Indietro" (`ConfirmCancel_<id>`).
func _cancel_cell(id: int, partly_sold: bool, auction: Object) -> Control:
	var can: CommandResult = auction.can_cancel(id)
	if partly_sold and _confirming == id:
		var box: HBoxContainer = HBoxContainer.new()
		box.custom_minimum_size.x = BUTTON_WIDTH
		var confirm: Button = _button("ConfirmCancel_%d" % id, AuctionTexts.CONFIRM_CANCEL_TEXT)
		confirm.disabled = not can.ok
		confirm.tooltip_text = AuctionTexts.CONFIRM_CANCEL_NOTE_TEXT
		confirm.pressed.connect(func() -> void:
			_confirming = -1
			cancel_requested.emit(id))
		box.add_child(confirm)
		var keep: Button = _button("KeepListing_%d" % id, AuctionTexts.KEEP_TEXT)
		keep.pressed.connect(func() -> void:
			_confirming = -1
			_redraw())
		box.add_child(keep)
		return box
	var cancel: Button = _button("Cancel_%d" % id, AuctionTexts.CANCEL_TEXT)
	cancel.custom_minimum_size.x = BUTTON_WIDTH
	cancel.disabled = not can.ok
	cancel.tooltip_text = "" if can.ok else AuctionTexts.refused(can.reason)
	cancel.pressed.connect(func() -> void:
		if partly_sold:
			_confirming = id
			_redraw()
		else:
			cancel_requested.emit(id))
	return cancel


func _button(node_name: String, text: String) -> Button:
	var button: Button = Button.new()
	button.name = node_name
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	return button


func _on_section_selected(id: StringName) -> void:
	_section = id
	_show_section()
	_redraw()


func _show_section() -> void:
	_active_box.visible = _section == ACTIVE
	_history.visible = _section == HISTORY


func _redraw() -> void:
	if _last.size() == 2:
		refresh(_last[0], _last[1])


## A row of cells: a String becomes a Label of the column width, a TextureRect the icon, any other Control is added as it is.
func _line(cells: Array, header: bool) -> HBoxContainer:
	var line: HBoxContainer = HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	for index: int in cells.size():
		var cell: Variant = cells[index]
		if cell == null or cell is TextureRect:
			var holder: TextureRect = cell if cell != null else TextureRect.new()
			holder.custom_minimum_size = Vector2(ICON_SIDE, ICON_SIDE)
			holder.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			holder.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			line.add_child(holder)
			continue
		if cell is Control:
			line.add_child(cell as Control)
			continue
		var label: Label = Label.new()
		label.text = cell
		label.custom_minimum_size.x = WIDTHS[index]
		label.clip_text = true
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		if index == 1:
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if header:
			label.theme_type_variation = &"MutedLabel"
		line.add_child(label)
	return line
