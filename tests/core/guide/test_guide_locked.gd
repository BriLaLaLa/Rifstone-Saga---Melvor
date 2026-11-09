extends GutTest
## The wiki by discovery (F-124): an item never obtained keeps its page and its source closed; the page of a monster lists
## everything it can give, locked until the item is discovered. Composition of GuideIndex and Discoveries (the UI does the same).

const LOG_ITEM: StringName = &"redbirch_log"

var _data: GameData
var _index: GuideIndex
var _session: GameSession


func before_all() -> void:
	_data = TestFactory.real_data()
	_index = GuideIndex.new(_data)


func before_each() -> void:
	_session = autofree(TestFactory.session_no_kit(3, _data))
	_session.discoveries.new_game()


func test_an_undiscovered_item_does_not_reveal_its_source() -> void:
	assert_false(_session.discoveries.has(LOG_ITEM))
	assert_gt(_index.sources_of(LOG_ITEM).size(), 0, "the index knows it")
	assert_eq(_index.sources_visible(LOG_ITEM, _session.discoveries).size(), 0)
	assert_false(GuideDrops.is_unlocked(LOG_ITEM, _session.discoveries))


func test_after_the_first_one_is_obtained_the_source_opens_and_stays_open() -> void:
	TestFactory.give(_session, LOG_ITEM, 1)
	assert_gt(_index.sources_visible(LOG_ITEM, _session.discoveries).size(), 0)
	_session.bank.remove(LOG_ITEM, 1)
	assert_gt(_index.sources_visible(LOG_ITEM, _session.discoveries).size(), 0, "sold or lost: still open")


func test_the_page_of_an_action_has_locked_entries_until_the_item_is_found() -> void:
	var before: Array[Dictionary] = _index.drops_view(&"action", &"cut_redbirch", _session.discoveries)
	assert_eq(before[0]["unlocked"], false)
	assert_eq(before[0]["name"], "???")
	assert_eq(before[0]["chance_pct"], -1.0)
	TestFactory.give(_session, LOG_ITEM, 1)
	var after: Array[Dictionary] = _index.drops_view(&"action", &"cut_redbirch", _session.discoveries)
	assert_eq(after[0]["unlocked"], true)
	assert_eq(after[0]["name"], _data.item(LOG_ITEM).name)


func test_a_monster_page_lists_everything_with_locked_boxes() -> void:
	var monster: MonsterDef = _data.monster(_data.areas()[0].monster_ids[0])
	var view: Array[Dictionary] = _index.drops_view(&"monster", monster.id, _session.discoveries)
	assert_eq(view.size(), _index.drops_of(&"monster", monster.id).size(), "all of it, found or not")
	var locked: int = 0
	for entry: Dictionary in view:
		locked += 0 if entry["unlocked"] else 1
		if not entry["unlocked"]:
			assert_eq(entry["chance_pct"], -1.0, "the percentage is hidden too")
	assert_gt(locked, 0)


func test_an_unlocked_pool_piece_shows_the_f124_percentage() -> void:
	var monster: MonsterDef = _data.monster(_data.areas()[3].monster_ids[0])
	var table: Dictionary[StringName, float] = EquipmentPool.table(EquipmentPool.monster_level(monster), _data)
	var piece: StringName = table.keys()[0]
	_session.discoveries.note(piece)
	for entry: Dictionary in _index.drops_view(&"monster", monster.id, _session.discoveries):
		if entry["item"] == piece:
			assert_true(entry["unlocked"])
			assert_eq(entry["chance_pct"], table[piece])
			return
	fail_test("the piece is in the page of the monster")


func test_without_discoveries_everything_is_locked() -> void:
	assert_false(GuideDrops.is_unlocked(LOG_ITEM, null))
	assert_eq(_index.sources_visible(LOG_ITEM, null).size(), 0)
