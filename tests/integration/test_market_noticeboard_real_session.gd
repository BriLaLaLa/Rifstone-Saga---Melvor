extends GutTest
## M20-06: Market and Noticeboard on the real GameSession / GameData: a real Market entry is locked at Market 0
## (reason shown in the shop page) and opens after building the Market; building the Noticeboard assigns quests
## that the Noticeboard page shows.

const SHOP_SCENE: PackedScene = preload("res://ui/pages/shop/shop_page.tscn")
const BOARD_SCENE: PackedScene = preload("res://ui/pages/noticeboard/noticeboard_page.tscn")
const ENTRY: StringName = &"market_shelf_1"

var _session: GameSession


func before_each() -> void:
	_session = TestFactory.session_no_kit(5, TestFactory.real_data())
	add_child(_session)


func after_each() -> void:
	if is_instance_valid(_session):
		_session.free()
	await wait_physics_frames(1)


func _build(building: StringName) -> void:
	var cost: Dictionary = _session.village.next_cost(building)
	_session.wallet.add_gold(int(cost["gold"]))
	for row: Dictionary in cost["items"] as Array:
		TestFactory.give(_session, row["item"] as StringName, int(row["qty"]))
	var result: CommandResult = _session.village.upgrade(building)
	assert_true(result.ok, "build %s: %s" % [building, result.reason])


func test_market_entry_locked_then_open() -> void:
	var page: ShopPage = SHOP_SCENE.instantiate()
	add_child(page)
	page.bind(_session)
	_session.wallet.add_gold(5000)
	var entry: ShopEntryDef = _session.data.shop_entry(ENTRY)
	assert_eq(entry.req_village.get(&"market", 0), 1)
	var check: CommandResult = _session.shop.can_buy(ENTRY)
	assert_false(check.ok)
	assert_eq(check.reason, Reasons.REQUIREMENT_NOT_MET)
	assert_false(page.missing_village(entry.req_village).is_empty(), "Market level shown as missing")
	_build(&"market")
	assert_eq(_session.village.level(&"market"), 1)
	assert_true(page.missing_village(entry.req_village).is_empty())
	assert_true(_session.shop.can_buy(ENTRY).ok)
	page.free()


func test_noticeboard_assigns_and_page_shows_quests() -> void:
	var page: NoticeboardPage = BOARD_SCENE.instantiate()
	add_child(page)
	page.bind(_session)
	assert_eq(_session.quests.slot_count(), 0)
	_build(&"noticeboard")
	assert_gt(_session.quests.slot_count(), 0)
	assert_ne(_session.quests.quest_at(0), &"")
	assert_eq(page.find_child("Rows", true, false).get_child_count(), _session.quests.slot_count())
	assert_false(page.find_child("NoBoardLabel", true, false).visible)
	page.free()
