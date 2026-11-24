class_name AuctionPage
extends Page
## Auction House page (docs/01_GDD.md §34.7, docs/05_INTERFACES.md §7.p), route `auction`, laid out like a classic auction
## house: category tree and name search on the left, sortable item list in the centre, selected item with quantity, total and
## Compra / Vendi button on the right, big Compra / Vendi tabs on top. With the building not built only the message
## "Costruisci la Casa d'Aste al Villaggio". Selling and buying are the `auction.sell` / `auction.buy` commands (one call per
## click); a refusal shows its reason in Italian. Prices, stock and trends are read from the module on every redraw
## (`auction_sold`, `auction_bought`, `auction_updated`, `bank_changed`, `gold_changed`, `village_upgraded`); the page keeps
## only presentation choices (tab, category, search, selected item; not saved) and references to its own nodes.

signal page_requested(page_id: StringName)

const AUCTION_FIELD: StringName = &"auction"
const SELL: StringName = &"sell"
const BUY: StringName = &"buy"
const MINE: StringName = &"mine"
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
var _search: String = ""
## Presentation choices per tab (`AuctionViewState`): category, sort, filters, selected item; kept for the session, not saved.
var _views: Dictionary[StringName, AuctionViewState] = {BUY: AuctionViewState.new(), SELL: AuctionViewState.new()}
var _redraw_queued: bool = false

@onready var _margin: MarginContainer = %Margin
@onready var _content: VBoxContainer = %Content
@onready var _title_label: Label = %TitleLabel
@onready var _level_label: Label = %LevelLabel
@onready var _gold_label: MoneyLabel = %GoldLabel
@onready var _post_badge: Button = %PostBadge
@onready var _post_full: Label = %PostFullLabel
@onready var _tabs: SubTabBar = %Tabs
@onready var _info_label: Label = %InfoLabel
@onready var _body: HBoxContainer = %Body
@onready var _categories: AuctionCategoryTree = %Categories
@onready var _items: AuctionList = %Items
@onready var _detail: AuctionDetail = %Detail
@onready var _mine: AuctionMine = %Mine


func _ready() -> void:
	for side: String in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		_margin.add_theme_constant_override(side, MARGIN)
	_content.add_theme_constant_override("separation", SECTION_SEPARATION)
	_body.add_theme_constant_override("separation", BODY_SEPARATION)
	(_level_label.get_parent() as BoxContainer).add_theme_constant_override("separation", HEADER_SEPARATION)
	_title_label.text = AuctionTexts.TITLE_TEXT
	_tabs.setup([{"id": BUY, "label": AuctionTexts.TAB_BUY_TEXT}, {"id": SELL, "label": AuctionTexts.TAB_SELL_TEXT},
			{"id": MINE, "label": AuctionTexts.TAB_MINE_TEXT}])
	for tab: Node in _tabs.get_children():
		(tab as Button).custom_minimum_size = TAB_MIN_SIZE
	_tabs.tab_selected.connect(_on_tab_selected)
	_categories.category_picked.connect(_on_category_picked)
	_categories.search_changed.connect(_on_search_changed)
	_categories.filters_changed.connect(_on_filters_changed)
	_items.sort_changed.connect(_on_sort_changed)
	_post_badge.pressed.connect(func() -> void: page_requested.emit(&"mail"))
	_items.item_picked.connect(_on_item_picked)
	_detail.trade_requested.connect(_on_trade_requested)
	_detail.list_requested.connect(_on_list_requested)
	_mine.cancel_requested.connect(_on_cancel_requested)


## Draws the page of `session` (nothing if the session has no auction house yet) and follows its changes.
func bind(session: GameSession) -> void:
	bind_with(session, session.get(AUCTION_FIELD))
	var argument: StringName = PageHost.argument_of(page_id)  # route `auction:<item_id>` (from the Deposit): that item on Vendi
	if argument != &"":
		show_item(argument, SELL)


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
	events.auction_listings_changed.connect(_queue_redraw)
	events.mail_changed.connect(_on_mail_changed)
	_rebuild()


## Disconnects every event connected in `bind`.
func unbind() -> void:
	if _session != null and is_instance_valid(_session):
		var events: GameEvents = _session.events
		for pair: Array in [[events.auction_sold, _on_sold], [events.auction_bought, _on_bought],
				[events.auction_updated, _on_updated], [events.bank_changed, _on_bank_changed],
				[events.gold_changed, _on_gold_changed], [events.village_upgraded, _on_upgraded],
				[events.auction_listings_changed, _queue_redraw], [events.mail_changed, _on_mail_changed]]:
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
	_gold_label.caption = AuctionTexts.GOLD_CAPTION
	_gold_label.set_amount(_session.wallet.get_gold(), _session.data.currency())
	_refresh_post()
	var open: bool = _auction.is_open()
	_level_label.visible = open
	_level_label.text = AuctionTexts.LEVEL_TEXT % int(_auction.level())
	_tabs.visible = open
	_body.visible = open and _tab != MINE
	_mine.visible = open and _tab == MINE
	_info_label.visible = not open
	_info_label.text = AuctionTexts.NOT_BUILT_TEXT
	if not open:
		_items.clear()
		return
	if _tab == MINE:
		_mine.refresh(_auction, _session)
		return
	var view: AuctionViewState = _views[_tab]
	var base: Array[StringName] = _wanted_items()
	if view.selected != &"" and not base.has(view.selected):
		view.selected = &""
	var counts: Dictionary = {}
	var searched: Array[StringName] = []
	for id: StringName in base:
		if _matches_search(id) and _matches_filters(id, view):
			searched.append(id)
			var category: StringName = _session.data.item(id).category
			counts[category] = int(counts.get(category, 0)) + 1
	var order: Array[StringName] = []
	for id: StringName in base:
		var category: StringName = _session.data.item(id).category
		if not order.has(category):
			order.append(category)
	order.sort_custom(func(a: StringName, b: StringName) -> bool:
		var rank_a: int = AuctionTexts.category_rank(a)
		var rank_b: int = AuctionTexts.category_rank(b)
		if rank_a != rank_b:
			return rank_a < rank_b
		return AuctionTexts.category_name(a).naturalnocasecmp_to(AuctionTexts.category_name(b)) < 0)
	if view.category != AuctionCategoryTree.ALL and not order.has(view.category):
		view.category = AuctionCategoryTree.ALL
	_categories.set_filters(view.owned_only, view.buyable_only, _tab == BUY)
	_categories.show_categories(order, counts, searched.size(), view.category)
	var shown: Array[StringName] = []
	for id: StringName in searched:
		if view.category == AuctionCategoryTree.ALL or _session.data.item(id).category == view.category:
			shown.append(id)
	var empty_text: String = AuctionTexts.EMPTY_FILTER_TEXT
	if base.is_empty():
		empty_text = AuctionTexts.EMPTY_SELL_TEXT if _tab == SELL else AuctionTexts.EMPTY_BUY_TEXT
	_items.set_sort(view.sort_key, view.sort_desc)
	_items.show_items(shown, _tab, _auction, _session, view.selected, empty_text)
	_detail.refresh(_auction, _session, _tab, view.selected)


## Post badge and the red "Posta piena" notice, read from the session's mailbox.
func _refresh_post() -> void:
	var count: int = _session.mail.count()
	_post_badge.text = AuctionTexts.POST_BADGE_TEXT % count if count > 0 else AuctionTexts.POST_BADGE_EMPTY_TEXT
	_post_full.visible = _session.mail.is_full()
	_post_full.text = AuctionTexts.POST_FULL_TEXT


## "Posseduti" (Compra: at least one in the Deposit) and "Comprabili ora" (`can_buy(id, 1)` would succeed).
func _matches_filters(id: StringName, view: AuctionViewState) -> bool:
	if _tab == BUY and view.owned_only and _session.bank.get_count(id) <= 0:
		return false
	return not view.buyable_only or _auction.can_buy(id, 1).ok


## Selects `item_id` on the tab `tab` (`BUY` or `SELL`), clearing category, search and filters so that it is visible; an item the
## Casa d'Aste does not trade (or that is not there) only shows a text.
func show_item(item_id: StringName, tab: StringName = SELL) -> void:
	if _auction == null or not _auction.is_open():
		return
	if not _auction.listed_items().has(item_id) or not _tab_items(tab).has(item_id):
		_detail.show_message(AuctionTexts.NOT_LISTED_TEXT, UiStyle.BAD)
		return
	_search = ""
	_categories.clear_search()
	_views[tab].reset_filters()
	_views[tab].selected = item_id
	_tabs.select(tab)  # emits tab_selected: `_on_tab_selected` rebuilds


func _wanted_items() -> Array[StringName]:
	return _tab_items(_tab)


func _tab_items(tab: StringName) -> Array[StringName]:
	if tab == BUY:
		return _auction.buyable_items()
	var result: Array[StringName] = []
	for id: StringName in _auction.listed_items():
		if _session.bank.get_count(id) > 0:
			result.append(id)
	return result



func _matches_search(id: StringName) -> bool:
	return _search == "" or _session.data.item(id).name.to_lower().contains(_search)


func _on_tab_selected(id: StringName) -> void:
	_tab = id  # each of Compra and Vendi keeps its own category, sort, filters and item
	_rebuild()


func _on_category_picked(category: StringName) -> void:
	_views[_tab].category = category
	_rebuild()


func _on_search_changed(text: String) -> void:
	_search = text.strip_edges().to_lower()
	_rebuild()


func _on_item_picked(item_id: StringName) -> void:
	_views[_tab].selected = item_id
	_rebuild()


func _on_filters_changed(owned: bool, buyable: bool) -> void:
	_views[_tab].owned_only = owned
	_views[_tab].buyable_only = buyable
	_rebuild()


func _on_sort_changed(key: StringName, descending: bool) -> void:
	if _views.has(_tab):
		_views[_tab].sort_key = key
		_views[_tab].sort_desc = descending


func _on_trade_requested(item_id: StringName, qty: int) -> void:
	if _auction == null:
		return
	var result: CommandResult = _auction.sell(item_id, qty) if _tab == SELL else _auction.buy(item_id, qty)
	if not result.ok:
		_detail.show_message(AuctionTexts.refused(result.reason), UiStyle.BAD)
	_rebuild()


func _on_list_requested(item_id: StringName, qty: int, price: int, duration_id: StringName) -> void:
	if _auction == null:
		return
	var result: CommandResult = _auction.list_item(item_id, qty, price, duration_id)
	if result.ok:
		_detail.show_message(AuctionTexts.LISTED_TEXT % [NumberFormat.format_int(qty), _session.data.item(item_id).name],
				UiStyle.GOOD)
		_detail.reset_price()
	else:
		_detail.show_message(AuctionTexts.refused(result.reason), UiStyle.BAD)
	_rebuild()


func _on_cancel_requested(listing_id: int) -> void:
	if _auction == null:
		return
	var result: CommandResult = _auction.cancel_listing(listing_id)
	_mine.show_message(AuctionTexts.CANCELLED_TEXT if result.ok else AuctionTexts.refused(result.reason),
			UiStyle.GOOD if result.ok else UiStyle.BAD)
	_rebuild()


func _on_mail_changed(_unread: int, _total: int) -> void:
	_queue_redraw()


## Coalesces the redraws asked by several signals in the same frame.
func _queue_redraw() -> void:
	if _redraw_queued:
		return
	_redraw_queued = true
	_rebuild.call_deferred()


func _on_sold(item_id: StringName, qty: int, gold: int) -> void:
	_detail.show_message(AuctionTexts.SOLD_TEXT % [NumberFormat.format_int(qty), _session.data.item(item_id).name,
			Money.text(gold, _session.data.currency())], UiStyle.GOOD)
	_queue_redraw()


func _on_bought(item_id: StringName, qty: int, gold: int) -> void:
	_detail.show_message(AuctionTexts.BOUGHT_TEXT % [NumberFormat.format_int(qty), _session.data.item(item_id).name,
			Money.text(gold, _session.data.currency())], UiStyle.GOOD)
	_queue_redraw()


func _on_updated(_blocks: int) -> void:
	_queue_redraw()


func _on_bank_changed(_item_id: StringName, _new_count: int, _delta: int) -> void:
	_queue_redraw()


func _on_gold_changed(_new_amount: int, _delta: int) -> void:
	_queue_redraw()


func _on_upgraded(_building_id: StringName, _new_level: int) -> void:
	_queue_redraw()
