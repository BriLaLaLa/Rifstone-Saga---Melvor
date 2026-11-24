extends GutTest
## AuctionHistoryView smoke test (M37-4): empty history shows the text, three entries make three lines. No exact texts.

const AuctionTestData := preload("res://tests/systems/auction/auction_test_data.gd")

var _session: GameSession = null
var _view: AuctionHistoryView = null


func after_each() -> void:
	if is_instance_valid(_view):
		_view.free()
	if is_instance_valid(_session):
		_session.free()
	await wait_physics_frames(1)


func test_empty_history_shows_the_empty_text() -> void:
	_open()
	_view.refresh(_session.auction, _session)
	assert_true(_view.find_child("HistoryEmpty", true, false).visible)
	assert_eq(_view.find_child("HistoryRows", true, false).get_child_count(), 0)


func test_three_entries_make_three_lines() -> void:
	_open()
	var stub: AuctionStub = AuctionStub.new(_session.auction.listed_items(), _session.auction.buyable_items())
	_view.refresh(stub, _session)
	assert_false(_view.find_child("HistoryEmpty", true, false).visible)
	assert_eq(_view.find_child("HistoryRows", true, false).get_child_count(), 3)


func _open() -> void:
	_session = AuctionTestData.session(1)
	_view = AuctionHistoryView.new()
	add_child(_view)
