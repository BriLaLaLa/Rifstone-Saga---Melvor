extends GutTest
## Auction House detail panel (M37-3): sections with a remembered choice per tab, "Inserzione" only in Vendi, the footer outside the
## scroll, Compra max and the gap label, on the real `AuctionHouse` (no exact texts or prices).

const AuctionTestData := preload("res://tests/systems/auction/auction_test_data.gd")
const SCENE: PackedScene = preload("res://ui/pages/auction/auction_page.tscn")

var _session: GameSession = null
var _page: AuctionPage = null


func before_each() -> void:
	_session = AuctionTestData.session(1)
	var listed: Array[StringName] = _session.auction.listed_items()
	_session.bank.add(listed[0], 5)
	_page = SCENE.instantiate()
	add_child(_page)
	_page.bind(_session)


func after_each() -> void:
	if is_instance_valid(_page):
		_page.free()
	if is_instance_valid(_session):
		_session.free()
	await wait_physics_frames(1)


func test_sections_footer_and_remembered_choice() -> void:
	_select_first()
	assert_true(_node("Section_now").visible)
	assert_false(_node("Section_market").visible)
	assert_false(_node("SectionButton_list").visible, "Inserzione only in Vendi")
	_node("SectionButton_market").pressed.emit()
	assert_true(_node("Section_market").visible)
	assert_true(_node("TradeButton").is_visible_in_tree(), "action fixed outside the sections")
	_page.find_child("Tab_sell", true, false).pressed.emit()
	_select_first()
	assert_true(_node("Section_now").visible, "each tab remembers its own section")
	assert_true(_node("SectionButton_list").visible)
	_node("SectionButton_list").pressed.emit()
	assert_true(_node("Section_list").visible)
	assert_false(_node("TradeFooter").visible)
	assert_true(_node("ListButton").is_visible_in_tree())
	_page.find_child("Tab_buy", true, false).pressed.emit()
	_select_first()
	assert_true(_node("Section_market").visible, "Compra kept Mercato")


func test_buy_max_and_gap_label() -> void:
	_select_first()
	var item: StringName = (_page.find_child("Rows", true, false).get_child(0) as AuctionRow).item_id
	var most: int = _session.auction.max_buyable(item)
	_node("Shortcut_max").pressed.emit()
	assert_eq(int((_node("QtySpin") as SpinBox).value), maxi(most, 1))
	var gap: int = _session.auction.price_gap(item, &"buy")
	assert_eq(_node("PriceGapLabel").visible, gap != AuctionHouse.NO_GAP)
	_page.find_child("Tab_sell", true, false).pressed.emit()
	_select_first()
	assert_false(_node("Shortcut_max").visible, "Compra max only in Compra")


func _select_first() -> void:
	var row: AuctionRow = _page.find_child("Rows", true, false).get_child(0) as AuctionRow
	row.row_clicked.emit(row.item_id)


func _node(node_name: String) -> Control:
	return _page.find_child(node_name, true, false) as Control
