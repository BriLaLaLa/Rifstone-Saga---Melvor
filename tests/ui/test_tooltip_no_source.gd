extends GutTest
## M14-07 (F-124): the tooltip of an item never says where it comes from ("Si ottiene da" lives in the Guide, behind the
## discoveries); "Serve a" stays.


func test_no_item_shows_a_source_line_and_the_use_line_stays() -> void:
	var data: GameData = TestFactory.real_data()
	var index := GuideIndex.new(data)
	var with_use: int = 0
	for item: ItemDef in data.items():
		var text: String = "\n".join(ItemTooltipLines.guide_lines(item, data))
		assert_false(text.contains("Si ottiene da"), String(item.id))
		if not index.uses_of(item.id).is_empty():
			with_use += 1
			assert_string_contains(text, "Serve a: ")
	assert_gt(with_use, 100)
