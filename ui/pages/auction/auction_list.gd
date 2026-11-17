class_name AuctionList
extends VBoxContainer
## Sortable item list of the Auction House page (docs/05_INTERFACES.md §7.p): clickable column headers, one `AuctionRow` per
## item (reused by id, so redraws are cheap), zebra rows, the selected one highlighted. Keeps only the sort choice
## (presentation, not saved); every sorted value is read from the auction module on each `show_items`.

signal item_picked(item_id: StringName)

const ROW_SCRIPT: GDScript = preload("res://ui/pages/auction/auction_row.gd")
const ROWS_SEPARATION: int = 1
const HEADER_SEPARATION: int = 8
const SORT_NAME: StringName = &"name"
const SORT_AVAIL: StringName = &"avail"
const SORT_PRICE: StringName = &"price"
const SORT_TREND: StringName = &"trend"
const SORT_DEPOSIT: StringName = &"deposit"
const TREND_RANK: Dictionary[StringName, int] = {&"down": 0, &"stable": 1, &"up": 2}

var _sort_key: StringName = SORT_NAME
var _sort_desc: bool = false
var _mode: StringName = &"sell"
var _rows: Dictionary[StringName, AuctionRow] = {}
var _headers: Dictionary[StringName, Button] = {}
var _header_row: HBoxContainer = null
var _scroll: ScrollContainer = null
var _rows_box: VBoxContainer = null
var _empty_label: Label = null
var _last: Array = []  # arguments of the last `show_items`, to redraw after a sort click


func _ready() -> void:
	add_theme_constant_override("separation", ROWS_SEPARATION)
	_header_row = HBoxContainer.new()
	_header_row.name = "Header"
	_header_row.add_theme_constant_override("separation", AuctionRow.SEPARATION)
	add_child(_header_row)
	var spacer: Control = Control.new()  # lines up with the row icon
	spacer.custom_minimum_size.x = AuctionRow.ICON_SIDE + AuctionRow.PAD_X
	_header_row.add_child(spacer)
	_add_header(SORT_NAME, 0.0, HORIZONTAL_ALIGNMENT_LEFT).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_add_header(SORT_AVAIL, AuctionRow.AVAIL_WIDTH, HORIZONTAL_ALIGNMENT_RIGHT)
	_add_header(SORT_PRICE, AuctionRow.PRICE_WIDTH, HORIZONTAL_ALIGNMENT_RIGHT)
	_add_header(SORT_TREND, AuctionRow.TREND_WIDTH, HORIZONTAL_ALIGNMENT_LEFT)
	_add_header(SORT_DEPOSIT, AuctionRow.DEPOSIT_WIDTH, HORIZONTAL_ALIGNMENT_RIGHT)
	var edge: Control = Control.new()  # keeps the last column away from the scrollbar
	edge.name = "ScrollbarGap"
	edge.custom_minimum_size.x = AuctionRow.PAD_X + 8
	_header_row.add_child(edge)
	_scroll = ScrollContainer.new()
	_scroll.name = "Scroll"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	_rows_box = VBoxContainer.new()
	_rows_box.name = "Rows"
	_rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows_box.add_theme_constant_override("separation", ROWS_SEPARATION)
	_scroll.add_child(_rows_box)
	_empty_label = Label.new()
	_empty_label.name = "EmptyLabel"
	_empty_label.theme_type_variation = &"HeaderLabel"
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty_label.visible = false
	add_child(_empty_label)
	_update_headers()


## Draws `ids` of the tab `mode`, sorted by the active column; `selected` is highlighted; `empty_text` shows when `ids` is empty.
func show_items(ids: Array[StringName], mode: StringName, auction: Object, session: GameSession, selected: StringName,
		empty_text: String) -> void:
	_last = [ids, mode, auction, session, selected, empty_text]
	if mode != _mode:
		_mode = mode
		_update_headers()
	var sorted: Array[StringName] = ids.duplicate()
	sorted.sort_custom(func(a: StringName, b: StringName) -> bool: return _before(a, b, auction, session))
	for id: StringName in _rows.keys():
		if not sorted.has(id) or _rows[id].mode != mode:
			_rows_box.remove_child(_rows[id])
			_rows[id].queue_free()
			_rows.erase(id)
	for position: int in sorted.size():
		var id: StringName = sorted[position]
		if not _rows.has(id):
			var row: AuctionRow = ROW_SCRIPT.new()
			_rows_box.add_child(row)
			row.setup(id, mode)
			row.row_clicked.connect(func(picked: StringName) -> void: item_picked.emit(picked))
			_rows[id] = row
		_rows_box.move_child(_rows[id], position)
		_rows[id].refresh(auction, session, id == selected, position % 2 == 1)
	_scroll.visible = not sorted.is_empty()
	_empty_label.visible = sorted.is_empty()
	_empty_label.text = empty_text


## Drops every row (unbind).
func clear() -> void:
	for id: StringName in _rows:
		_rows_box.remove_child(_rows[id])
		_rows[id].queue_free()
	_rows.clear()
	_last = []


func _before(a: StringName, b: StringName, auction: Object, session: GameSession) -> bool:
	var va: Variant = _value(a, auction, session)
	var vb: Variant = _value(b, auction, session)
	if va != vb:
		return va > vb if _sort_desc else va < vb
	return session.data.item(a).name.naturalnocasecmp_to(session.data.item(b).name) < 0


func _value(id: StringName, auction: Object, session: GameSession) -> Variant:
	match _sort_key:
		SORT_AVAIL:
			return session.bank.get_count(id) if _mode == &"sell" else int(auction.stock(id))
		SORT_PRICE:
			return int(auction.sell_quote(id, 1)) if _mode == &"sell" else int(auction.buy_quote(id, 1))
		SORT_TREND:
			return TREND_RANK.get(auction.trend(id), 1)
		SORT_DEPOSIT:
			return session.shop.sell_value(id, 1)
	return session.data.item(id).name.to_lower()


func _on_header_pressed(key: StringName) -> void:
	if _sort_key == key:
		_sort_desc = not _sort_desc
	else:
		_sort_key = key
		_sort_desc = false
	_update_headers()
	if _last.size() == 6:
		show_items(_last[0], _last[1], _last[2], _last[3], _last[4], _last[5])


func _update_headers() -> void:
	var titles: Dictionary[StringName, String] = {SORT_NAME: AuctionTexts.COLUMN_NAME_TEXT,
			SORT_AVAIL: AuctionTexts.COLUMN_OWNED_TEXT if _mode == &"sell" else AuctionTexts.COLUMN_AVAILABLE_TEXT,
			SORT_PRICE: AuctionTexts.COLUMN_PRICE_TEXT, SORT_TREND: AuctionTexts.COLUMN_TREND_TEXT,
			SORT_DEPOSIT: AuctionTexts.COLUMN_DEPOSIT_TEXT}
	for key: StringName in _headers:
		var arrow: String = ""
		if key == _sort_key:
			arrow = AuctionTexts.SORT_DESC_TEXT if _sort_desc else AuctionTexts.SORT_ASC_TEXT
		_headers[key].text = titles[key] + arrow
	_headers[SORT_DEPOSIT].visible = _mode == &"sell"


func _add_header(key: StringName, width: float, align: HorizontalAlignment) -> Button:
	var button: Button = Button.new()
	button.name = "Header_%s" % key
	button.flat = true
	button.alignment = align
	button.focus_mode = Control.FOCUS_NONE
	for style: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(style, StyleBoxEmpty.new())  # no padding: text lines up with the cells below
	button.add_theme_color_override("font_color", UiStyle.GOLD)
	button.add_theme_color_override("font_hover_color", UiStyle.GOLD_LIGHT)
	button.add_theme_color_override("font_pressed_color", UiStyle.GOLD_LIGHT)
	if width > 0.0:
		button.custom_minimum_size.x = width
	button.pressed.connect(_on_header_pressed.bind(key))
	_header_row.add_child(button)
	_headers[key] = button
	return button
