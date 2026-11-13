extends GutTest
## Village (docs/05_INTERFACES.md §5.27): can_upgrade reasons in order, atomic upgrade, effect and signal, the highest
## level, placeholders, tolerant save. Real data; costs of docs/02_FORMULAS.md F-131.

var _session: GameSession
var _village: Village
var _upgraded: Array = []


func before_each() -> void:
	_session = TestFactory.session_no_kit(5, TestFactory.real_data())
	add_child_autofree(_session)
	_village = _session.village
	_upgraded = []
	_session.events.village_upgraded.connect(func(id: StringName, level: int) -> void: _upgraded.append([id, level]))


# Gold and items of storehouse level 1: 300 gold, 20 redbirch_shieldcore, 4 emberbronze_plate (Falegname 1).
func _fund_storehouse_1() -> void:
	_session.wallet.add_gold(300)
	TestFactory.give(_session, &"redbirch_shieldcore", 20)
	TestFactory.give(_session, &"emberbronze_plate", 4)


func test_buildings_in_order_with_placeholders() -> void:
	assert_eq(_village.buildings(), [&"storehouse", &"inn", &"forge", &"sawmill", &"loot_shed", &"market", &"noticeboard"] as Array[StringName])
	assert_true(_village.is_buildable(&"inn"))
	assert_false(_village.is_buildable(&"market"))
	assert_false(_village.is_buildable(&"nothing"))
	assert_eq(_village.max_level(), 8)
	assert_eq(_village.level(&"nothing"), 0)


func test_next_cost_is_the_next_level() -> void:
	var cost: Dictionary = _village.next_cost(&"storehouse")
	assert_eq(cost["gold"], 300)
	assert_eq(cost["requires_woodwright"], 1)
	assert_eq((cost["items"] as Array)[0], {"item": &"redbirch_shieldcore", "qty": 20})
	assert_eq(_village.next_cost(&"market"), {})
	assert_eq(_village.next_cost(&"nothing"), {})


func test_can_upgrade_reasons_in_order() -> void:
	assert_eq(_village.can_upgrade(&"nothing").reason, Reasons.UNKNOWN_ID)
	assert_eq(_village.can_upgrade(&"market").reason, Reasons.NOT_BUILDABLE)
	# Woodwright 1 is the minimum: level 2 needs 10.
	_village.from_save({"levels": {"storehouse": 1}})
	assert_eq(_village.can_upgrade(&"storehouse").reason, Reasons.LEVEL_TOO_LOW, "before gold and items")
	TestFactory.set_level(_session, &"woodwright", 10)
	assert_eq(_village.can_upgrade(&"storehouse").reason, Reasons.NOT_ENOUGH_GOLD, "before items")
	_session.wallet.add_gold(420)
	assert_eq(_village.can_upgrade(&"storehouse").reason, Reasons.NOT_ENOUGH_ITEMS)
	TestFactory.give(_session, &"ashpine_shieldcore", 30)
	TestFactory.give(_session, &"ashlead_plate", 5)
	assert_eq(_village.can_upgrade(&"storehouse").reason, Reasons.NOT_ENOUGH_ITEMS, "one short")
	TestFactory.give(_session, &"ashlead_plate", 1)
	assert_true(_village.can_upgrade(&"storehouse").ok)


func test_max_level_comes_before_the_other_checks() -> void:
	_village.from_save({"levels": {"inn": 8}})
	assert_eq(_village.can_upgrade(&"inn").reason, Reasons.MAX_LEVEL)
	assert_eq(_village.next_cost(&"inn"), {})
	assert_eq(_village.upgrade(&"inn").reason, Reasons.MAX_LEVEL)


func test_upgrade_pays_everything_and_builds() -> void:
	_fund_storehouse_1()
	var gold: int = _session.wallet.get_gold()
	var result: CommandResult = _village.upgrade(&"storehouse")
	assert_true(result.ok)
	assert_eq(_village.level(&"storehouse"), 1)
	assert_eq(_session.wallet.get_gold(), gold - 300)
	assert_eq(_session.bank.get_count(&"redbirch_shieldcore"), 0)
	assert_eq(_session.bank.get_count(&"emberbronze_plate"), 0)
	assert_eq(_upgraded, [[&"storehouse", 1]])
	assert_eq(_session.modifiers.total(&"deposit_slots"), 4.0)
	assert_eq(_session.deposit.capacity(), 64, "F-133: 60 + 4")


func test_upgrade_spends_locked_items() -> void:
	_fund_storehouse_1()
	_session.bank.set_locked(&"redbirch_shieldcore", true)
	assert_true(_village.upgrade(&"storehouse").ok)
	assert_eq(_session.bank.get_count(&"redbirch_shieldcore"), 0)


func test_failed_upgrade_changes_nothing() -> void:
	_session.wallet.add_gold(300)
	TestFactory.give(_session, &"redbirch_shieldcore", 20)
	TestFactory.give(_session, &"emberbronze_plate", 3)
	var gold: int = _session.wallet.get_gold()
	var result: CommandResult = _village.upgrade(&"storehouse")
	assert_eq(result.reason, Reasons.NOT_ENOUGH_ITEMS)
	assert_eq(_session.wallet.get_gold(), gold)
	assert_eq(_session.bank.get_count(&"redbirch_shieldcore"), 20)
	assert_eq(_session.bank.get_count(&"emberbronze_plate"), 3)
	assert_eq(_village.level(&"storehouse"), 0)
	assert_eq(_upgraded.size(), 0)
	assert_false(_session.modifiers.has_source(&"village:storehouse"))


func test_placeholder_cannot_be_built() -> void:
	assert_eq(_village.upgrade(&"noticeboard").reason, Reasons.NOT_BUILDABLE)
	assert_eq(_village.level(&"noticeboard"), 0)


func test_save_round_trip_keeps_levels_and_effects() -> void:
	_village.from_save({"levels": {"inn": 3, "forge": 1}})
	var saved: Dictionary = _village.to_save()
	assert_eq(saved, {"levels": {"inn": 3, "forge": 1}})
	_village.new_game()
	assert_eq(_village.level(&"inn"), 0)
	_village.from_save(JSON.parse_string(JSON.stringify(saved)) as Dictionary)
	assert_eq(_village.level(&"inn"), 3, "JSON turns the integers into floats")
	assert_eq(_village.level(&"forge"), 1)


func test_session_save_and_load_rebuilds_the_modifiers() -> void:
	_village.from_save({"levels": {"storehouse": 2}})
	var saved: Dictionary = _session.to_save(0)
	var other: GameSession = TestFactory.session_no_kit(6, TestFactory.real_data())
	add_child_autofree(other)
	assert_true(other.from_save(JSON.parse_string(JSON.stringify(saved)) as Dictionary).ok)
	assert_eq(other.village.level(&"storehouse"), 2)
	assert_eq(other.deposit.capacity(), 68)
	assert_false((saved["modules"] as Dictionary)["village"]["levels"].has("inn"), "only the built buildings are saved")


func test_from_save_is_tolerant() -> void:
	_village.from_save({"levels": [1, 2]})
	assert_eq(_village.to_save(), {"levels": {}}, "not an object: all 0")
	_village.from_save({"levels": {"inn": 99, "market": 2, "nothing": 1, "forge": 0, "sawmill": -1, "storehouse": "3",
			"loot_shed": 2.5}})
	assert_eq(_village.level(&"inn"), 8, "capped at max_level")
	for id: StringName in [&"market", &"nothing", &"forge", &"sawmill", &"storehouse", &"loot_shed"]:
		assert_eq(_village.level(id), 0, str(id))
	_village.from_save({})
	assert_eq(_village.to_save(), {"levels": {}}, "missing key = new game")
