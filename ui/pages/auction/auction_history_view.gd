class_name AuctionHistoryView
extends VBoxContainer
## "Storico" section of the "Le mie vendite" tab (docs/01_GDD_M37.md §45.4, F-209): one line per entry of
## `AuctionHouse.history()` (newest first): item with icon, kind (coloured), pieces, unit price, net and how long ago
## (`history_age_ms` + text). Everything is read at each `refresh`; the view keeps only its own nodes.

const NAME_MIN: float = 150.0
const KIND_WIDTH: float = 120.0
const QTY_WIDTH: float = 60.0
const UNIT_WIDTH: float = 110.0
const NET_WIDTH: float = 110.0
const AGE_WIDTH: float = 90.0
const ICON_SIDE: int = 24
const ROW_SEPARATION: int = 8
const SOLD_KINDS: Array[StringName] = [&"listing_sold", &"instant_sold"]

var _rows: VBoxContainer = null
var _empty: Label = null


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	var note: Label = Label.new()
	note.theme_type_variation = &"MutedLabel"
	note.text = AuctionTexts.HISTORY_NOTE_TEXT
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(note)
	add_child(_line([null, AuctionTexts.COLUMN_NAME_TEXT, AuctionTexts.COLUMN_KIND_TEXT, AuctionTexts.COLUMN_QTY_TEXT,
			AuctionTexts.COLUMN_UNIT_TEXT, AuctionTexts.COLUMN_NET_TEXT, AuctionTexts.COLUMN_AGE_TEXT], true))
	_empty = Label.new()
	_empty.name = "HistoryEmpty"
	_empty.theme_type_variation = &"HeaderLabel"
	_empty.text = AuctionTexts.HISTORY_EMPTY_TEXT
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_empty)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.name = "HistoryRows"
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rows)


## Redraws from the module (`auction` is an AuctionHouse or a stub with `history` and `history_age_ms`).
func refresh(auction: Object, session: GameSession) -> void:
	var currency: CurrencyParams = session.data.currency()
	var entries: Array = auction.history()
	_empty.visible = entries.is_empty()
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	for entry: Dictionary in entries:
		var kind: StringName = entry["kind"]
		var def: ItemDef = session.data.item(entry["item"])
		var icon: TextureRect = TextureRect.new()
		icon.texture = ItemSlotView.icon_of(def.icon)
		var sold: bool = SOLD_KINDS.has(kind)
		var line: HBoxContainer = _line([icon, def.name, AuctionTexts.kind_text(kind), NumberFormat.format_int(int(entry["qty"])),
				AuctionTexts.money_short(int(entry["unit"]), currency) if int(entry["unit"]) > 0 else "–",
				AuctionTexts.money_short(int(entry["net"]), currency) if sold else "–",
				AuctionTexts.age_text(int(auction.history_age_ms(entry)))], false)
		line.name = "History_%d" % _rows.get_child_count()
		(line.get_child(2) as Label).add_theme_color_override("font_color", UiStyle.GOOD if sold else UiStyle.GOLD)
		_rows.add_child(line)


## A row of cells: null (icon column, or an empty header cell), a TextureRect, or a String (Label of the column width).
func _line(cells: Array, header: bool) -> HBoxContainer:
	var widths: Array[float] = [ICON_SIDE, NAME_MIN, KIND_WIDTH, QTY_WIDTH, UNIT_WIDTH, NET_WIDTH, AGE_WIDTH]
	var line: HBoxContainer = HBoxContainer.new()
	line.add_theme_constant_override("separation", ROW_SEPARATION)
	for index: int in cells.size():
		var cell: Variant = cells[index]
		if cell == null or cell is TextureRect:
			var holder: TextureRect = cell if cell != null else TextureRect.new()
			holder.custom_minimum_size = Vector2(ICON_SIDE, ICON_SIDE)
			holder.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			holder.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			line.add_child(holder)
			continue
		var label: Label = Label.new()
		label.text = cell
		label.custom_minimum_size.x = widths[index]
		label.clip_text = true
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		if index == 1:
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		elif index >= 3:
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if header:
			label.theme_type_variation = &"MutedLabel"
		line.add_child(label)
	return line
