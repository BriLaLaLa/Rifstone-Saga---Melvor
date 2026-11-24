extends GutTest
## M37-5: "Vendi alla Casa d'Aste" in the bank item panel (docs/01_GDD_M37.md §45.2) and its forwarding by BankPage.

const PAGE_SCENE: PackedScene = preload("res://ui/pages/bank/bank_page.tscn")
const AuctionTestData := preload("res://tests/systems/auction/auction_test_data.gd")

var _session: GameSession
var _page: BankPage
var _routes: Array[StringName] = []


func after_each() -> void:
	if is_instance_valid(_page):
		_page.free()
	if is_instance_valid(_session):
		_session.free()
	await wait_physics_frames(1)


func _open(level: int, item: StringName, locked: bool = false) -> void:
	_session = AuctionTestData.session(level)
	_session.bank.add(item, 3)
	_session.bank.set_locked(item, locked)
	_page = PAGE_SCENE.instantiate()
	add_child(_page)
	_page.bind(_session)
	_page.page_requested.connect(func(id: StringName) -> void: _routes.append(id))
	(_page.find_child("ItemPanel", true, false) as BankItemPanel).show_item(_session, item)


func _button() -> Button:
	return _page.find_child("SellAtAuctionButton", true, false) as Button


func test_click_forwards_the_auction_route_with_the_item() -> void:
	_routes = []
	var item: StringName = AuctionTestData.session(1).auction.listed_items()[0]
	_open(1, item)
	assert_true(_button().visible)
	assert_false(_button().disabled)
	_button().pressed.emit()
	assert_eq(_routes, [StringName("auction:%s" % item)])


func test_disabled_with_tooltip_when_house_not_built_or_item_locked() -> void:
	var item: StringName = AuctionTestData.session(1).auction.listed_items()[0]
	_open(0, item)
	assert_true(_button().visible)
	assert_true(_button().disabled)
	assert_false(_button().tooltip_text.is_empty())
	_page.free()
	_session.free()
	_open(1, item, true)
	assert_true(_button().disabled)
	assert_false(_button().tooltip_text.is_empty())


func test_button_absent_for_an_item_the_house_does_not_trade() -> void:
	var traded: Array[StringName] = AuctionTestData.session(1).auction.listed_items()
	var other: StringName = &""
	_session = AuctionTestData.session(1)
	for def: ItemDef in _session.data.items():
		if not traded.has(def.id) and def.value > 0:
			other = def.id
			break
	assert_ne(other, &"", "an untraded item exists")
	_session.free()
	_open(1, other)
	assert_false(_button().visible)
