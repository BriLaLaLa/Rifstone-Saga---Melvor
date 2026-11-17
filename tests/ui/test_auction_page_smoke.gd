extends GutTest
## AuctionPage smoke test (M23-04, layout v2): closed at level 0, Compra / Vendi tabs with one row per item (real module on
## the data with the building), selecting a row fills the detail panel, the button disabled with the reason of `can_sell` /
## `can_buy` (AuctionStub, same signatures as `AuctionHouse`), one command per click, the search filters the list, layout at
## 1280x720, everything disconnected by unbind. No exact texts or prices.

const SCENE: PackedScene = preload("res://ui/pages/auction/auction_page.tscn")
const MIN_SIZE: Vector2 = Vector2(1280, 720)
const AuctionTestData := preload("res://tests/systems/auction/auction_test_data.gd")

var _session: GameSession = null
var _page: AuctionPage = null


func after_each() -> void:
	if is_instance_valid(_page):
		_page.free()
	if is_instance_valid(_session):
		_session.free()
	await wait_physics_frames(1)


func test_closed_page_shows_only_the_message() -> void:
	_open(AuctionTestData.session(0))
	assert_true(_page.find_child("InfoLabel", true, false).visible)
	assert_false(_page.find_child("Body", true, false).visible)
	assert_eq(_rows().size(), 0)


func test_tabs_list_one_row_per_item_and_search_filters() -> void:
	_session = AuctionTestData.session(1)
	var listed: Array[StringName] = _session.auction.listed_items()
	_session.bank.add(listed[0], 5)
	_page = SCENE.instantiate()
	add_child(_page)
	_page.bind(_session)
	assert_eq(_rows().size(), _session.auction.buyable_items().size(), "Compra is the first tab")
	_page.find_child("Tab_sell", true, false).pressed.emit()
	assert_eq(_rows().size(), 1, "only the item present in the Deposit")
	_page.find_child("SearchField", true, false).text_changed.emit("zzzz-no-such-item")
	assert_eq(_rows().size(), 0)
	_page.find_child("SearchField", true, false).text_changed.emit("")
	assert_eq(_rows().size(), 1)
	assert_true(_page.find_child("Detail", true, false).find_child("EmptyLabel", true, false).visible, "nothing selected")


func test_disabled_button_shows_the_reason_and_click_sends_one_command() -> void:
	_session = AuctionTestData.session(1)
	var listed: Array[StringName] = _session.auction.listed_items()
	_session.bank.add(listed[0], 5)
	var stub: AuctionStub = AuctionStub.new(listed, _session.auction.buyable_items())
	_page = SCENE.instantiate()
	add_child(_page)
	_page.bind_with(_session, stub)
	_page.find_child("Tab_sell", true, false).pressed.emit()
	_rows()[0].row_clicked.emit(_rows()[0].item_id)
	assert_false(_button().disabled)
	assert_false((_page.find_child("ReasonLabel", true, false) as Label).visible)
	_button().pressed.emit()
	assert_eq(stub.sell_calls, 1)
	stub.forced_reason = Reasons.OUT_OF_STOCK
	_page._rebuild()
	assert_true(_button().disabled)
	assert_true((_page.find_child("ReasonLabel", true, false) as Label).visible)
	stub.forced_reason = Reasons.REQUIREMENT_NOT_MET
	_page.find_child("Tab_buy", true, false).pressed.emit()
	_rows()[0].row_clicked.emit(_rows()[0].item_id)
	assert_true(_button().disabled)
	stub.forced_reason = &""
	_page._rebuild()
	_button().pressed.emit()
	assert_eq(stub.buy_calls, 1)


func test_detail_shows_the_market_block() -> void:
	_open(AuctionTestData.session(1))
	_rows()[0].row_clicked.emit(_rows()[0].item_id)
	var market: Control = _page.find_child("MarketBox", true, false)
	assert_true(market.visible)
	for label_name: String in ["BuyersLabel", "SellersLabel", "DemandLabel"]:
		assert_ne((market.find_child(label_name, true, false) as Label).text, "")


func test_layout_at_minimum_size_and_unbind() -> void:
	_session = AuctionTestData.session(1)
	for id: StringName in _session.auction.listed_items().slice(0, 12):
		_session.bank.add(id, 3)
	_page = SCENE.instantiate()
	var holder: Control = Control.new()
	holder.size = MIN_SIZE - Vector2(240, 0)
	add_child(holder)
	holder.add_child(_page)
	_page.bind(_session)
	await wait_physics_frames(2)
	var body: Control = _page.find_child("Body", true, false)
	assert_true(body.get_global_rect().end.y <= MIN_SIZE.y + 1.0)
	assert_true(body.get_global_rect().end.x <= MIN_SIZE.x)
	assert_true(_page.get_combined_minimum_size().x <= MIN_SIZE.x - 240.0, "page fits next to the sidebar")
	_page.unbind()
	for sig: Signal in [_session.events.auction_sold, _session.events.auction_bought, _session.events.auction_updated,
			_session.events.bank_changed, _session.events.gold_changed, _session.events.village_upgraded]:
		for connection: Dictionary in sig.get_connections():
			assert_ne((connection["callable"] as Callable).get_object(), _page, "page disconnected")


func _open(session: GameSession) -> void:
	_session = session
	_page = SCENE.instantiate()
	add_child(_page)
	_page.bind(_session)


func _rows() -> Array[AuctionRow]:
	var result: Array[AuctionRow] = []
	for child: Node in _page.find_child("Rows", true, false).get_children():
		if child is AuctionRow and not child.is_queued_for_deletion():
			result.append(child)
	return result


func _button() -> Button:
	return _page.find_child("TradeButton", true, false)


## Regression: a real mouse click on a category used to rebuild the Tree from inside its own `item_selected` signal,
## where `create_item` returns null ("Cannot call method 'set_text' on a null value"). The click is sent through the
## Tree's input path, which is what blocks it; `select()` alone does not.
func test_mouse_click_on_a_category_rebuilds_the_tree_without_error() -> void:
	_session = AuctionTestData.session(1)
	_page = SCENE.instantiate()
	add_child(_page)
	_page.bind(_session)
	await wait_physics_frames(2)
	var tree: Tree = _page.find_child("CategoryTree", true, false) as Tree
	var all_item: TreeItem = tree.get_root().get_first_child()
	assert_gt(all_item.get_child_count(), 0, "the categories are listed")
	var target: TreeItem = all_item.get_first_child()
	tree.scroll_to_item(target)
	var rect: Rect2 = tree.get_item_area_rect(target)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = tree.get_global_rect().position + rect.position + rect.size * 0.5
	click.global_position = click.position
	tree.get_viewport().push_input(click, true)
	click.pressed = false
	tree.get_viewport().push_input(click, true)
	await wait_physics_frames(2)
	assert_not_null(tree.get_root().get_first_child(), "the tree was rebuilt, not emptied")
	assert_gt(tree.get_root().get_first_child().get_child_count(), 0, "the categories are listed again")
