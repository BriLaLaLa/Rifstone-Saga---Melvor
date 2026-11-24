extends GutTest
## Auction House detail, M38-3: "Disponibili" (no maximum), "Esaurito" with the reason on the disabled button, "Media 12 h" and the
## gap, the buy book rows, and the confirmation of a huge purchase (only if `buy_preview(...).large`; Compra emits, Annulla does not).
## `AuctionStub` has the signatures of `AuctionHouse`; no exact texts or prices.

const AuctionTestData := preload("res://tests/systems/auction/auction_test_data.gd")

var _session: GameSession = null
var _detail: AuctionDetail = null
var _stub: AuctionStub = null
var _sent: Array[int] = []


func before_each() -> void:
	_session = AuctionTestData.session(1)
	var listed: Array[StringName] = _session.auction.listed_items()
	_stub = AuctionStub.new(listed, _session.auction.buyable_items())
	_detail = AuctionDetail.new()
	add_child(_detail)
	_sent.clear()
	_detail.trade_requested.connect(func(_id: StringName, qty: int) -> void: _sent.append(qty))
	_open()


func after_each() -> void:
	if is_instance_valid(_detail):
		_detail.free()
	if is_instance_valid(_session):
		_session.free()
	await wait_physics_frames(1)


func test_available_and_reference_are_shown() -> void:
	assert_true(_find("AvailableLabel").visible)
	assert_false(_find("SoldOutLabel").visible)
	assert_ne((_find("AvailableLabel") as Label).tooltip_text, "")
	assert_true(_find("RefLabel").visible)
	assert_true(_find("PriceGapLabel").visible)
	assert_not_null(_find("BuyRow_0"), "the buy book has its rows")


func test_sold_out_disables_buy_with_the_reason() -> void:
	_stub.available_value = 0
	_stub.forced_reason = Reasons.OUT_OF_STOCK
	_open()
	assert_true(_find("SoldOutLabel").visible)
	assert_true((_find("TradeButton") as Button).disabled)
	assert_ne((_find("TradeButton") as Button).tooltip_text, "")


func test_small_purchase_never_asks() -> void:
	(_find("TradeButton") as Button).pressed.emit()
	assert_eq(_sent, [1])
	assert_false((_find("BuyConfirm") as Window).visible)


func test_large_purchase_asks_and_buy_sends() -> void:
	_stub.large_preview = true
	(_find("TradeButton") as Button).pressed.emit()
	assert_eq(_sent.size(), 0, "nothing goes out before the answer")
	var dialog: AuctionBuyConfirm = _find("BuyConfirm") as AuctionBuyConfirm
	assert_true(dialog.visible)
	dialog.confirmed.emit()
	assert_eq(_sent, [1])


func test_large_purchase_cancel_sends_nothing() -> void:
	_stub.large_preview = true
	(_find("TradeButton") as Button).pressed.emit()
	var dialog: AuctionBuyConfirm = _find("BuyConfirm") as AuctionBuyConfirm
	dialog.canceled.emit()
	dialog.hide()
	assert_eq(_sent.size(), 0)


func test_sell_mode_never_asks() -> void:
	_stub.large_preview = true
	_detail.refresh(_stub, _session, &"sell", _session.auction.listed_items()[0])
	(_find("TradeButton") as Button).pressed.emit()
	assert_eq(_sent, [1])


func _open() -> void:
	_detail.refresh(_stub, _session, &"buy", _session.auction.listed_items()[0])


func _find(node_name: String) -> Node:
	return _detail.find_child(node_name, true, false)
