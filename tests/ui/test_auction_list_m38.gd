extends GutTest
## AuctionList / AuctionRow (M38-4, docs/05_INTERFACES_M38.md §7.ag): Compra shows `available` with no "/ max", sorts by it,
## "% sulla media" comes from `price_gap` (a dash for `NO_GAP`), the sold-out reason reads "Esaurito.". AuctionStub on real data.

const AuctionTestData := preload("res://tests/systems/auction/auction_test_data.gd")

var _session: GameSession = null
var _stub: AuctionStub = null
var _list: AuctionList = null
var _ids: Array[StringName] = []


func before_each() -> void:
	_session = AuctionTestData.session(10)
	_ids = _session.auction.buyable_items().slice(0, 3)
	_stub = AuctionStub.new(_session.auction.listed_items(), _session.auction.buyable_items())
	_stub.level_value = 10
	_list = AuctionList.new()
	add_child(_list)


func after_each() -> void:
	_list.free()
	_session.free()
	await wait_physics_frames(1)


func test_buy_rows_show_available_without_a_maximum() -> void:
	_stub.available_value = 1234
	_list.show_items(_ids, &"buy", _stub, _session, &"", "")
	var text: String = _avail_text(_ids[0])
	assert_false(text.contains("/"), "no '/ max'")
	assert_true(text.contains("1") and text.contains("234"), "the available count")


func test_sort_by_available_uses_available() -> void:
	_stub = _stub_with_available({_ids[0]: 3, _ids[1]: 50, _ids[2]: 20})
	_list.set_sort(AuctionList.SORT_AVAIL, true)
	_list.show_items(_ids, &"buy", _stub, _session, &"", "")
	assert_eq(_row_order(), [_ids[1], _ids[2], _ids[0]] as Array[StringName])
	_list.set_sort(AuctionList.SORT_AVAIL, false)
	_list.show_items(_ids, &"buy", _stub, _session, &"", "")
	assert_eq(_row_order(), [_ids[0], _ids[2], _ids[1]] as Array[StringName])


func test_gap_comes_from_the_module_and_no_gap_is_a_dash() -> void:
	_stub.gap_by_item = {_ids[0]: 12, _ids[1]: AuctionHouse.NO_GAP}
	_list.show_items(_ids, &"buy", _stub, _session, &"", "")
	var shown: String = _gap_text(_ids[0])
	assert_true(shown.contains("12"), "the percent of price_gap")
	assert_eq(_gap_text(_ids[1]), AuctionTexts.gap_text(AuctionHouse.NO_GAP))
	assert_false(_gap_text(_ids[1]).contains("0"), "a dash, not a number")


func test_sold_out_reason_reads_esaurito() -> void:
	assert_eq(AuctionTexts.refused(Reasons.OUT_OF_STOCK), "Esaurito.")


func test_sold_out_row_shows_zero_available() -> void:
	_stub.sold_out = {_ids[0]: true}
	_list.show_items(_ids, &"buy", _stub, _session, &"", "")
	assert_eq(_avail_text(_ids[0]), "0")


func _stub_with_available(values: Dictionary) -> AuctionStub:
	var stub: AuctionStub = AuctionStub.new(_session.auction.listed_items(), _session.auction.buyable_items())
	stub.level_value = 10
	stub.available_by_item = values
	return stub


func _row(id: StringName) -> AuctionRow:
	for child: Node in _list.find_child("Rows", true, false).get_children():
		if child is AuctionRow and (child as AuctionRow).item_id == id:
			return child
	return null


func _row_order() -> Array[StringName]:
	var result: Array[StringName] = []
	for child: Node in _list.find_child("Rows", true, false).get_children():
		if child is AuctionRow:
			result.append((child as AuctionRow).item_id)
	return result


func _avail_text(id: StringName) -> String:
	return (_row(id).get("_avail_label") as Label).text


func _gap_text(id: StringName) -> String:
	return (_row(id).get("_gap_label") as Label).text
