extends GutTest
## The Guide of the Dungeon (M22-06, docs/04_DATA_SCHEMA.md §27): the page `guide_dungeon` with its "?" route, the three tables
## generated from the data (rooms F-138, stages F-139, boss loot F-143) and the use of the Ticket (no exception left).

var _real: GameData = null
var _index: GuideIndex = null


func before_all() -> void:
	_real = TestFactory.real_data()
	_index = GuideIndex.new(_real)


func test_tables_are_declared_and_built_from_the_dungeon() -> void:
	var def: DungeonDef = _real.dungeons()[0]
	for id: String in ["dungeon_rooms", "dungeon_stages", "dungeon_loot"]:
		assert_true(GuideTables.ids().has(id), id)
		assert_gt(GuideTables.build(id, _real).size(), 1, id)
	assert_eq(GuideTables.build("dungeon_rooms", _real).size(), def.room_types.size() + 1)
	var stages: Array[Array] = GuideTables.build("dungeon_stages", _real)
	assert_eq(stages.size(), def.stages.size() + 1)
	assert_eq(stages[1][2], def.monster_def(def.stages[0].monster_id).name)


func test_help_route_and_page_exist() -> void:
	assert_ne(HelpButton.entry_for(_real, &"dungeon"), &"")
	assert_true(_real.guide_pages().any(func(page: GuidePageDef) -> bool: return page.id == GuideIndex.PAGE_DUNGEON))


func test_the_ticket_has_a_use_and_a_source_without_exceptions() -> void:
	var ticket: StringName = _real.dungeons()[0].ticket
	assert_false(_index.uses_of(ticket).is_empty(), "use of the Ticket")
	assert_false(_index.sources_of(ticket).is_empty(), "source of the Ticket")
