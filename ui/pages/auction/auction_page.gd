class_name AuctionPage
extends Page
## Auction House page (docs/01_GDD.md §34.7, docs/05_INTERFACES.md §7.p), route `auction`: two tabs, Vendi (one `AuctionRow`
## per listed item present in the Deposit) and Compra (one row per buyable item). With the building not built only the
## message "Costruisci la Casa d'Aste al Villaggio". Selling and buying are the `auction.sell` / `auction.buy` commands (one
## call per click); a refusal shows its reason in Italian. Prices, stock and trends are read from the module on every redraw
## (`auction_sold`, `auction_bought`, `auction_updated`, `bank_changed`, `gold_changed`, `village_upgraded`); the page keeps
## only the active tab (presentation, not saved) and references to its own nodes.

const ROW_SCRIPT: GDScript = preload("res://ui/pages/auction/auction_row.gd")
const AUCTION_FIELD: StringName = &"auction"
const SELL: StringName = &"sell"
const BUY: StringName = &"buy"
const MARGIN: int = 16
const SECTION_SEPARATION: int = 12
const ROWS_SEPARATION: int = 10

var _session: GameSession = null
## The session's AuctionHouse (5.30), used through its contract signatures only; a duck-typed reference so that the page
## can also be bound to a stub with the same signatures.
var _auction: Object = null
var _tab: StringName = SELL
var _rows: Dictionary[StringName, AuctionRow] = {}
var _redraw_queued: bool = false

@onready var _margin: MarginContainer = %Margin
@onready var _content: VBoxContainer = %Content
@onready var _title_label: Label = %TitleLabel
@onready var _gold_label: Label = %GoldLabel
@onready var _tabs: SubTabBar = %Tabs
@onready var _message_label: Label = %MessageLabel
@onready var _info_label: Label = %InfoLabel
@onready var _scroll: ScrollContainer = %Scroll
@onready var _rows_box: VBoxContainer = %Rows


func _ready() -> void:
	for side: String in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		_margin.add_theme_constant_override(side, MARGIN)
	_content.add_theme_constant_override("separation", SECTION_SEPARATION)
	_rows_box.add_theme_constant_override("separation", ROWS_SEPARATION)
	_title_label.text = AuctionTexts.TITLE_TEXT
	_tabs.setup([{"id": SELL, "label": AuctionTexts.TAB_SELL_TEXT}, {"id": BUY, "label": AuctionTexts.TAB_BUY_TEXT}])
	_tabs.tab_selected.connect(_on_tab_selected)
	_message_label.add_theme_color_override("font_color", UiStyle.BAD)


## Draws the page of `session` (nothing if the session has no auction house yet) and follows its changes.
func bind(session: GameSession) -> void:
	bind_with(session, session.get(AUCTION_FIELD))


## Same as `bind`, with the auction module given: used by `bind` and by the smoke test with a stub of the same signatures.
func bind_with(session: GameSession, auction: Object) -> void:
	unbind()
	_session = session
	_auction = auction
	if _auction == null:
		return
	var events: GameEvents = _session.events
	events.auction_sold.connect(_on_sold)
	events.auction_bought.connect(_on_bought)
	events.auction_updated.connect(_on_updated)
	events.bank_changed.connect(_on_bank_changed)
	events.gold_changed.connect(_on_gold_changed)
	events.village_upgraded.connect(_on_upgraded)
	_rebuild()


## Disconnects every event connected in `bind`.
func unbind() -> void:
	if _session != null and is_instance_valid(_session):
		var events: GameEvents = _session.events
		for pair: Array in [[events.auction_sold, _on_sold], [events.auction_bought, _on_bought],
				[events.auction_updated, _on_updated], [events.bank_changed, _on_bank_changed],
				[events.gold_changed, _on_gold_changed], [events.village_upgraded, _on_upgraded]]:
			var sig: Signal = pair[0]
			var callback: Callable = pair[1]
			if sig.is_connected(callback):
				sig.disconnect(callback)
	_session = null
	_auction = null
	_clear_rows()


func _exit_tree() -> void:
	unbind()


## Rebuilds the list of the active tab (rows are reused by item, so the picked quantities survive) and rereads every row.
func _rebuild() -> void:
	_redraw_queued = false
	if _auction == null or _session == null:
		return
	_gold_label.text = AuctionTexts.GOLD_TEXT % NumberFormat.format_int(_session.wallet.get_gold())
	var open: bool = _auction.is_open()
	_tabs.visible = open
	_scroll.visible = open
	_info_label.visible = not open
	_info_label.text = AuctionTexts.NOT_BUILT_TEXT
	if not open:
		_clear_rows()
		return
	var wanted: Array[StringName] = _wanted_items()
	for id: StringName in _rows.keys():
		if not wanted.has(id) or _rows[id].mode != _tab:
			_rows[id].queue_free()
			_rows_box.remove_child(_rows[id])
			_rows.erase(id)
	for position: int in wanted.size():
		var id: StringName = wanted[position]
		if not _rows.has(id):
			var row: AuctionRow = ROW_SCRIPT.new()
			_rows_box.add_child(row)
			row.setup(id, _tab)
			row.trade_requested.connect(_on_trade_requested)
			_rows[id] = row
		_rows_box.move_child(_rows[id], position)
		_rows[id].refresh(_auction, _session)
	_info_label.visible = wanted.is_empty()
	_info_label.text = AuctionTexts.EMPTY_SELL_TEXT if _tab == SELL else AuctionTexts.EMPTY_BUY_TEXT


func _wanted_items() -> Array[StringName]:
	if _tab == BUY:
		return _auction.buyable_items()
	var result: Array[StringName] = []
	for id: StringName in _auction.listed_items():
		if _session.bank.get_count(id) > 0:
			result.append(id)
	return result


func _clear_rows() -> void:
	for id: StringName in _rows:
		_rows_box.remove_child(_rows[id])
		_rows[id].queue_free()
	_rows.clear()


func _on_tab_selected(id: StringName) -> void:
	_tab = id
	_message_label.visible = false
	_rebuild()


func _on_trade_requested(item_id: StringName, qty: int) -> void:
	if _auction == null:
		return
	var result: CommandResult = _auction.sell(item_id, qty) if _tab == SELL else _auction.buy(item_id, qty)
	if not result.ok:
		_show_message(AuctionTexts.refused(result.reason), UiStyle.BAD)
	_rebuild()


func _show_message(text: String, color: Color) -> void:
	_message_label.visible = true
	_message_label.text = text
	_message_label.add_theme_color_override("font_color", color)


## Coalesces the redraws asked by several signals in the same frame.
func _queue_redraw() -> void:
	if _redraw_queued:
		return
	_redraw_queued = true
	_rebuild.call_deferred()


func _on_sold(item_id: StringName, qty: int, gold: int) -> void:
	_show_message(AuctionTexts.SOLD_TEXT % [NumberFormat.format_int(qty), _session.data.item(item_id).name,
			NumberFormat.format_int(gold)], UiStyle.GOOD)
	_queue_redraw()


func _on_bought(item_id: StringName, qty: int, gold: int) -> void:
	_show_message(AuctionTexts.BOUGHT_TEXT % [NumberFormat.format_int(qty), _session.data.item(item_id).name,
			NumberFormat.format_int(gold)], UiStyle.GOOD)
	_queue_redraw()


func _on_updated(_blocks: int) -> void:
	_queue_redraw()


func _on_bank_changed(_item_id: StringName, _new_count: int, _delta: int) -> void:
	_queue_redraw()


func _on_gold_changed(_new_amount: int, _delta: int) -> void:
	_queue_redraw()


func _on_upgraded(_building_id: StringName, _new_level: int) -> void:
	_queue_redraw()
