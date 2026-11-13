extends GutTest
## M20-04 (docs/02_FORMULAS.md F-136): cost of the Noticeboard and the Market (examples of the document), the effect of
## the Noticeboard (`quest_slots`, source `village:noticeboard`), the Market without modifiers, upgrades with real data.

var _data: GameData


func before_all() -> void:
	_data = TestFactory.real_data()


func _level(building: StringName, level: int) -> Dictionary:
	return _data.village_building(building).levels[level - 1]


func _qty(row: Dictionary, item: StringName) -> int:
	for entry: Dictionary in row["items"] as Array:
		if entry["item"] == item:
			return int(entry["qty"])
	return -1


func test_noticeboard_costs() -> void:
	var row: Dictionary = _level(&"noticeboard", 1)
	assert_eq(_qty(row, &"redbirch_grip"), 20)
	assert_eq(_qty(row, &"redbirch_shieldcore"), 20)
	assert_eq(row["gold"], 210)
	assert_eq(row["requires_woodwright"], 1)
	row = _level(&"noticeboard", 2)
	assert_eq(_qty(row, &"ashpine_grip"), 30)
	assert_eq(_qty(row, &"ashpine_shieldcore"), 30)
	assert_eq(row["gold"], 290, "294 rounds to 290")
	assert_eq(row["requires_woodwright"], 10)
	row = _level(&"noticeboard", 4)
	assert_eq(_qty(row, &"duskelm_grip"), 50)
	assert_eq(_qty(row, &"duskelm_shieldcore"), 50)
	assert_eq(row["gold"], 580, "576.2 rounds to 580")
	assert_eq(row["requires_woodwright"], 30)
	row = _level(&"noticeboard", 8)
	assert_eq(_qty(row, &"riftspruce_grip"), 90)
	assert_eq(_qty(row, &"riftspruce_shieldcore"), 90)
	assert_eq(row["gold"], 2210, "2213.7 rounds to 2210")
	assert_eq(row["requires_woodwright"], 90)


func test_market_costs() -> void:
	var row: Dictionary = _level(&"market", 1)
	assert_eq(_qty(row, &"redbirch_shieldcore"), 20)
	assert_eq(_qty(row, &"emberbronze_plate"), 2, "ceil(0.25 x 8)")
	assert_eq(_qty(row, &"seared_brookfin"), 4, "ceil(0.25 x 16)")
	assert_eq(row["gold"], 300)
	row = _level(&"market", 6)
	assert_eq(_qty(row, &"veilcypress_shieldcore"), 70)
	assert_eq(_qty(row, &"palecinnabar_plate"), 7)
	assert_eq(_qty(row, &"seared_mist_barbel"), 12, "ceil(11.5)")
	assert_eq(row["gold"], 1610)
	assert_eq(row["requires_woodwright"], 60)
	row = _level(&"market", 8)
	assert_eq(_qty(row, &"riftspruce_shieldcore"), 90)
	assert_eq(_qty(row, &"riftite_plate"), 9)
	assert_eq(_qty(row, &"seared_riftmaw"), 15, "ceil(14.5)")
	assert_eq(row["gold"], 3160)
	assert_eq(row["requires_woodwright"], 90)


func test_market_levels_have_no_effect_value() -> void:
	var market: VillageBuildingDef = _data.village_building(&"market")
	assert_true(market.unlocks_shop)
	assert_eq(market.effect_stat, &"")
	for level: Dictionary in market.levels:
		assert_eq(level["effect_value"], 0.0)


func _session_with_gold() -> GameSession:
	var session: GameSession = TestFactory.session_no_kit(7, _data)
	add_child_autofree(session)
	session.wallet.add_gold(100000 - session.wallet.get_gold())
	return session


func test_noticeboard_3_gives_3_quest_slots() -> void:
	var session: GameSession = _session_with_gold()
	session.village.from_save({"levels": {"noticeboard": 3}})
	session.rebuild_modifiers()
	assert_eq(session.modifiers.total(&"quest_slots"), 3.0)
	assert_true(session.modifiers.has_source(&"village:noticeboard"))


func test_market_has_no_modifier_source() -> void:
	var session: GameSession = _session_with_gold()
	session.village.from_save({"levels": {"market": 4}})
	session.rebuild_modifiers()
	assert_false(session.modifiers.has_source(&"village:market"))
	assert_eq(session.village.level(&"market"), 4)


func test_upgrade_noticeboard_and_market() -> void:
	var session: GameSession = _session_with_gold()
	TestFactory.give(session, &"redbirch_grip", 20)
	TestFactory.give(session, &"redbirch_shieldcore", 40)
	TestFactory.give(session, &"emberbronze_plate", 2)
	TestFactory.give(session, &"seared_brookfin", 4)
	assert_true(session.village.upgrade(&"noticeboard").ok)
	assert_eq(session.village.level(&"noticeboard"), 1)
	assert_eq(session.modifiers.total(&"quest_slots"), 1.0)
	assert_true(session.village.upgrade(&"market").ok)
	assert_eq(session.village.level(&"market"), 1)
	assert_eq(session.wallet.get_gold(), 100000 - 210 - 300)
	assert_eq(session.bank.get_count(&"redbirch_shieldcore"), 0)
