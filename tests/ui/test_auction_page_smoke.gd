extends GutTest
## AuctionPage (M23-04) smoke test: closed at level 0, Vendi / Compra tabs with one row per item (real module on the data with
## the building), the button disabled with the reason of `can_sell` / `can_buy` (AuctionStub, same signatures as
## `AuctionHouse`), one command per click, layout at 1280x720, everything disconnected by unbind. No exact texts or prices.

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
	assert_false(_page.find_child("Scroll", true, false).visible)
	assert_eq(_rows().size(), 0)


func test_tabs_list_one_row_per_item() -> void:
	_session = AuctionTestData.session(1)
	var listed: Array[StringName] = _session.auction.listed_items()
	_session.bank.add(listed[0], 5)
	_page = SCENE.instantiate()
	add_child(_page)
	_page.bind(_session)
	assert_eq(_rows().size(), 1, "only the item present in the Deposit")
	_page.find_child("Tab_buy", true, false).pressed.emit()
	assert_eq(_rows().size(), _session.auction.buyable_items().size())
	_page.find_child("Tab_sell", true, false).pressed.emit()
	assert_eq(_rows().size(), 1)


func test_disabled_button_shows_the_reason_and_click_sends_one_command() -> void:
	_session = AuctionTestData.session(1)
	var listed: Array[StringName] = _session.auction.listed_items()
	_session.bank.add(listed[0], 5)
	var stub: AuctionStub = AuctionStub.new(listed, _session.auction.buyable_items())
	_page = SCENE.instantiate()
	add_child(_page)
	_page.bind_with(_session, stub)
	var row: AuctionRow = _rows()[0]
	assert_false(_button(row).disabled)
	assert_false((row.find_child("ReasonLabel", true, false) as Label).visible)
	_button(row).pressed.emit()
	assert_eq(stub.sell_calls, 1)
	stub.forced_reason = Reasons.OUT_OF_STOCK
	_page._rebuild()
	row = _rows()[0]
	assert_true(_button(row).disabled)
	assert_true((row.find_child("ReasonLabel", true, false) as Label).visible)
	stub.forced_reason = Reasons.REQUIREMENT_NOT_MET
	_page.find_child("Tab_buy", true, false).pressed.emit()
	assert_true(_button(_rows()[0]).disabled)
	stub.forced_reason = &""
	_page._rebuild()
	_button(_rows()[0]).pressed.emit()
	assert_eq(stub.buy_calls, 1)


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
	var scroll: ScrollContainer = _page.find_child("Scroll", true, false)
	assert_true(scroll.get_global_rect().end.y <= MIN_SIZE.y + 1.0)
	assert_true(scroll.get_global_rect().end.x <= MIN_SIZE.x)
	for row: AuctionRow in _rows():
		assert_true(row.get_combined_minimum_size().x <= MIN_SIZE.x - 240.0, "row fits next to the sidebar")
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


func _button(row: AuctionRow) -> Button:
	return row.find_child("TradeButton", true, false)
