class_name AuctionPage
extends Page
## Auction House page (docs/01_GDD.md §34.7, docs/05_INTERFACES.md §7.p), route `auction`, laid out like a classic auction
## house: category tree and name search on the left, sortable item list in the centre, selected item with quantity, total and
## Compra / Vendi button on the right, big Compra / Vendi tabs on top. With the building not built only the message
## "Costruisci la Casa d'Aste al Villaggio". Selling and buying are the `auction.sell` / `auction.buy` commands (one call per
## click); a refusal shows its reason in Italian. Prices, stock and trends are read from the module on every redraw
## (`auction_sold`, `auction_bought`, `auction_updated`, `bank_changed`, `gold_changed`, `village_upgraded`); the page keeps
## only presentation choices (tab, category, search, selected item; not saved) and references to its own nodes.

const AUCTION_FIELD: StringName = &"auction"
const SELL: StringName = &"sell"
const BUY: StringName = &"buy"
const MARGIN: int = 16
const SECTION_SEPARATION: int = 12
const BODY_SEPARATION: int = 12
const HEADER_SEPARATION: int = 28
const TAB_MIN_SIZE := Vector2(180, 44)

var _session: GameSession = null
## The session's AuctionHouse (5.30), used through its contract signatures only; a duck-typed reference so that the page
## can also be bound to a stub with the same signatures.
var _auction: Object = null
var _tab: StringName = BUY
var _category: StringName = AuctionCategoryTree.ALL
var _search: String = ""
var _selected: StringName = &""
var _redraw_queued: bool = false

@onready var _margin: MarginContainer = %Margin
@onready var _content: VBoxContainer = %Content
@onready var _title_label: Label = %TitleLabel
@onready var _level_label: Label = %LevelLabel
@onready var _gold_label: Label = %GoldLabel
@onready var _tabs: SubTabBar = %Tabs
@onready var _info_label: Label = %InfoLabel
@onready var _body: HBoxContainer = %Body
@onready var _categories: AuctionCategoryTree = %Categories
@onready var _items: AuctionList = %Items
@onready var _detail: AuctionDetail = %Detail


func _ready() -> void:
	for side: String in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		_margin.add_theme_constant_override(side, MARGIN)
	_content.add_theme_constant_override("separation", SECTION_SEPARATION)
	_body.add_theme_constant_override("separation", BODY_SEPARATION)
	(_level_label.get_parent() as BoxContainer).add_theme_constant_override("separation", HEADER_SEPARATION)
	_title_label.text = AuctionTexts.TITLE_TEXT
	_tabs.setup([{"id": BUY, "label": AuctionTexts.TAB_BUY_TEXT}, {"id": SELL, "label": AuctionTexts.TAB_SELL_TEXT}])
	for tab: Node in _tabs.get_children():
		(tab as Button).custom_minimum_size = TAB_MIN_SIZE
	_tabs.tab_selected.connect(_on_tab_selected)
	_categories.category_picked.connect(_on_category_picked)
	_categories.search_changed.connect(_on_search_changed)
	_items.item_picked.connect(_on_item_picked)
	_detail.trade_requested.connect(_on_trade_requested)


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
	if _items != null:
		_items.clear()


func _exit_tree() -> void:
	unbind()


## Rereads everything of the active tab: header, category counts, filtered list and the detail panel.
func _rebuild() -> void:
	_redraw_queued = false
	if _auction == null or _session == null:
		return
	_gold_label.text = AuctionTexts.GOLD_TEXT % NumberFormat.format_int(_session.wallet.get_gold())
	var open: bool = _auction.is_open()
	_level_label.visible = open
	_level_label.text = AuctionTexts.LEVEL_TEXT % int(_auction.level())
	_tabs.visible = open
	_body.visible = open
	_info_label.visible = not open
	_info_label.text = AuctionTexts.NOT_BUILT_TEXT
	if not open:
		_items.clear()
		return
	var base: Array[StringName] = _wanted_items()
	if _selected != &"" and not base.has(_selected):
		_selected = &""
	var counts: Dictionary = {}
	var searched: Array[StringName] = []
	for id: StringName in base:
		if _matches_search(id):
			searched.append(id)
			var category: StringName = _session.data.item(id).category
			counts[category] = int(counts.get(category, 0)) + 1
	var order: Array[StringName] = []
	for id: StringName in base:
		var category: StringName = _session.data.item(id).category
		if not order.has(category):
			order.append(category)
	order.sort_custom(func(a: StringName, b: StringName) -> bool:
		return AuctionTexts.category_name(a).naturalnocasecmp_to(AuctionTexts.category_name(b)) < 0)
	if _category != AuctionCategoryTree.ALL and not order.has(_category):
		_category = AuctionCategoryTree.ALL
	_categories.show_categories(order, counts, searched.size(), _category)
	var shown: Array[StringName] = []
	for id: StringName in searched:
		if _category == AuctionCategoryTree.ALL or _session.data.item(id).category == _category:
			shown.append(id)
	var empty_text: String = AuctionTexts.EMPTY_FILTER_TEXT
	if base.is_empty():
		empty_text = AuctionTexts.EMPTY_SELL_TEXT if _tab == SELL else AuctionTexts.EMPTY_BUY_TEXT
	_items.show_items(shown, _tab, _auction, _session, _selected, empty_text)
	_detail.refresh(_auction, _session, _tab, _selected)


func _wanted_items() -> Array[StringName]:
	if _tab == BUY:
		return _auction.buyable_items()
	var result: Array[StringName] = []
	for id: StringName in _auction.listed_items():
		if _session.bank.get_count(id) > 0:
			result.append(id)
	return result


func _matches_search(id: StringName) -> bool:
	return _search == "" or _session.data.item(id).name.to_lower().contains(_search)


func _on_tab_selected(id: StringName) -> void:
	_tab = id
	_selected = &""
	_rebuild()


func _on_category_picked(category: StringName) -> void:
	_category = category
	_rebuild()


func _on_search_changed(text: String) -> void:
	_search = text.strip_edges().to_lower()
	_rebuild()


func _on_item_picked(item_id: StringName) -> void:
	_selected = item_id
	_rebuild()


func _on_trade_requested(item_id: StringName, qty: int) -> void:
	if _auction == null:
		return
	var result: CommandResult = _auction.sell(item_id, qty) if _tab == SELL else _auction.buy(item_id, qty)
	if not result.ok:
		_detail.show_message(AuctionTexts.refused(result.reason), UiStyle.BAD)
	_rebuild()


## Coalesces the redraws asked by several signals in the same frame.
func _queue_redraw() -> void:
	if _redraw_queued:
		return
	_redraw_queued = true
	_rebuild.call_deferred()


func _on_sold(item_id: StringName, qty: int, gold: int) -> void:
	_detail.show_message(AuctionTexts.SOLD_TEXT % [NumberFormat.format_int(qty), _session.data.item(item_id).name,
			NumberFormat.format_int(gold)], UiStyle.GOOD)
	_queue_redraw()


func _on_bought(item_id: StringName, qty: int, gold: int) -> void:
	_detail.show_message(AuctionTexts.BOUGHT_TEXT % [NumberFormat.format_int(qty), _session.data.item(item_id).name,
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
