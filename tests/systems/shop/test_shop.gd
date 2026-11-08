extends GutTest
## Shop: fixed prices, F-18 selling, F-19 modifiers, requirements, limits, bank full, save round trip.
## Uses the fixture entries test_pocket, test_upgrade_1/2 and test_buy_hatchet.

const FIXTURE_ROOT: String = "res://tests/fixtures/data"
const CONFIG_ROOT: String = "res://data/config"
const PreRun := preload("res://tests/helpers/gut_pre_run.gd")

var _tmp_config: String = PreRun.test_dir("test_shop").path_join("config")
var _small_data: GameData = null
var _session: GameSession = null
var _shop: Shop = null


func before_all() -> void:
	DirAccess.make_dir_recursive_absolute(_tmp_config)
	var balance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_ROOT.path_join("balance.json")))
	(balance["deposit"] as Dictionary)["base_slots"] = 1
	(balance["start"] as Dictionary)["items"] = [{"item": "seared_brookfin", "qty": 1}]  # the kit food, removed by clear_kit
	_write(_tmp_config.path_join("balance.json"), JSON.stringify(balance))
	_write(_tmp_config.path_join("stats.json"), FileAccess.get_file_as_string(CONFIG_ROOT.path_join("stats.json")))
	_small_data = GameData.load_from_dirs(FIXTURE_ROOT, _tmp_config)


func after_all() -> void:
	for file: String in ["balance.json", "stats.json"]:
		DirAccess.remove_absolute(_tmp_config.path_join(file))
	DirAccess.remove_absolute(_tmp_config)
	DirAccess.remove_absolute(_tmp_config.get_base_dir())


func before_each() -> void:
	_session = autofree(TestFactory.session())
	_shop = _session.shop


func _gold(amount: int) -> void:
	_session.wallet.add_gold(amount)


func test_price_is_the_fixed_gold_cost() -> void:
	assert_eq(_shop.price(&"test_pocket"), 100)
	_shop.from_save({"purchases": {"test_pocket": 30}})
	assert_eq(_shop.price(&"test_pocket"), 100, "M12: no price formulas, the cost does not grow")
	_shop.new_game()
	_gold(1000)
	assert_true(_shop.buy(&"test_pocket").ok)
	assert_eq(_session.wallet.get_gold(), _start_gold() + 1000 - 100)
	assert_eq(_shop.price(&"ghost"), 0)


func _start_gold() -> int:
	return int(_session.data.balance_value("start.gold"))


func test_f19_modifier_scaled_by_purchases() -> void:
	_gold(2000)
	_shop.buy(&"test_pocket")
	_shop.buy(&"test_pocket")
	assert_true(_session.modifiers.has_source(&"shop:test_pocket"))
	assert_eq(_session.modifiers.total(&"loot_bag_slots"), 2.0)


func test_unknown_and_not_enough_gold() -> void:
	assert_eq(_shop.buy(&"nope").reason, Reasons.UNKNOWN_ID)
	var before: int = _session.wallet.get_gold()
	var r: CommandResult = _shop.buy(&"test_upgrade_1")
	assert_eq(r.reason, Reasons.NOT_ENOUGH_GOLD)
	assert_eq(_session.wallet.get_gold(), before)
	assert_eq(_shop.purchase_count(&"test_upgrade_1"), 0)


func test_requirements_and_max_purchases() -> void:
	_gold(10000)
	assert_eq(_shop.buy(&"test_upgrade_2").reason, Reasons.REQUIREMENT_NOT_MET, "needs entry first")
	assert_true(_shop.buy(&"test_upgrade_1").ok)
	assert_eq(_shop.buy(&"test_upgrade_1").reason, Reasons.MAX_PURCHASES)
	assert_eq(_shop.buy(&"test_upgrade_2").reason, Reasons.REQUIREMENT_NOT_MET, "needs skill and total level")
	TestFactory.set_level(_session, &"test_gather", 10)
	assert_eq(_shop.can_buy(&"test_upgrade_2").reason, Reasons.REQUIREMENT_NOT_MET, "total level still low")
	for skill: SkillDef in _session.data.skills():
		TestFactory.set_level(_session, skill.id, maxi(10, _session.skills.get_level(skill.id)))
	var needed: int = _session.data.shop_entry(&"test_upgrade_2").req_total_level
	assert_gte(_session.total_level(), needed)
	assert_eq(_shop.can_buy(&"test_upgrade_2").reason, Reasons.REQUIREMENT_NOT_MET, "character level 20 missing")
	TestFactory.set_character_level(_session, 20)
	assert_true(_shop.buy(&"test_upgrade_2").ok)
	assert_eq(_session.modifiers.total(&"auto_eat_tier"), 2.0)


func test_piece_effect_goes_to_armory_and_is_repeatable() -> void:
	_gold(300)
	assert_true(_shop.buy(&"test_buy_hatchet").ok)
	assert_true(_shop.buy(&"test_buy_hatchet").ok)
	assert_eq(_session.bank.get_count(&"test_blade"), 0, "a piece is never in the bank")
	var pieces: Array[ItemInstance] = _session.armory.instances()
	assert_eq(pieces.size(), 2)
	assert_eq(pieces[0].base_id, &"test_blade")
	assert_eq(pieces[0].rarity, &"common")
	assert_eq(pieces[0].affixes.size(), 0)
	assert_ne(pieces[0].uid, pieces[1].uid)
	assert_eq(_shop.purchase_count(&"test_buy_hatchet"), 2)
	assert_false(_session.modifiers.has_source(&"shop:test_buy_hatchet"))


func test_buy_piece_with_full_armory_keeps_gold() -> void:
	var small: GameSession = autofree(TestFactory.session(1234, _small_data))
	small.wallet.add_gold(1000)
	TestFactory.give_piece(small, &"test_blade")
	assert_false(small.armory.can_add(1), "the Armory must be full for this test")
	var gold: int = small.wallet.get_gold()
	var r: CommandResult = small.shop.buy(&"test_buy_hatchet")
	assert_eq(r.reason, Reasons.ARMORY_FULL)
	assert_eq(small.wallet.get_gold(), gold)
	assert_eq(small.shop.purchase_count(&"test_buy_hatchet"), 0)
	assert_eq(small.armory.used(), 1)


func test_sell_instance() -> void:
	var uid: int = TestFactory.give_piece(_session, &"test_blade")
	var value: int = _session.data.item(&"test_blade").value
	assert_gt(value, 0)
	var gold: int = _session.wallet.get_gold()
	watch_signals(_session.events)
	assert_true(_shop.sell_instance(uid).ok)
	assert_eq(_session.wallet.get_gold(), gold + value)
	assert_false(_session.armory.has(uid))
	assert_signal_emitted_with_parameters(_session.events, "item_sold", [&"test_blade", 1, value])


func test_sell_instance_rejections() -> void:
	var uid: int = TestFactory.give_piece(_session, &"test_blade")
	var gold: int = _session.wallet.get_gold()
	assert_eq(_shop.sell_instance(999).reason, Reasons.UNKNOWN_ID)
	_session.armory.set_locked(uid, true)
	assert_eq(_shop.sell_instance(uid).reason, Reasons.ITEM_LOCKED)
	_session.armory.set_locked(uid, false)
	_session.armory.set_worn(uid, true)
	assert_eq(_shop.sell_instance(uid).reason, Reasons.ITEM_EQUIPPED)
	assert_eq(_session.wallet.get_gold(), gold)
	assert_true(_session.armory.has(uid))


func test_f18_sell() -> void:
	TestFactory.give(_session, &"test_log", 25)
	var gold: int = _session.wallet.get_gold()
	var value: int = _session.data.item(&"test_log").value
	assert_eq(_shop.sell_value(&"test_log", 25), value * 25)
	assert_true(_shop.sell(&"test_log", 25).ok)
	assert_eq(_session.wallet.get_gold(), gold + value * 25)
	assert_eq(_session.bank.get_count(&"test_log"), 0)


func test_sell_rejections() -> void:
	TestFactory.give(_session, &"test_log", 5)
	TestFactory.give(_session, &"rift_shard", 1)
	assert_eq(_shop.sell(&"test_log", 0).reason, Reasons.INVALID_AMOUNT)
	assert_eq(_shop.sell(&"nope", 1).reason, Reasons.UNKNOWN_ID)
	assert_eq(_shop.sell(&"rift_shard", 1).reason, Reasons.NOT_SELLABLE)
	assert_eq(_shop.sell(&"test_log", 6).reason, Reasons.NOT_ENOUGH_ITEMS)
	_session.bank.set_locked(&"test_log", true)
	assert_eq(_shop.sell(&"test_log", 1).reason, Reasons.ITEM_LOCKED)
	assert_eq(_session.bank.get_count(&"test_log"), 5)


func test_signals() -> void:
	watch_signals(_session.events)
	_gold(500)
	_shop.buy(&"test_pocket")
	assert_signal_emitted_with_parameters(_session.events, "shop_purchased", [&"test_pocket", 1])
	TestFactory.give(_session, &"test_log", 2)
	_shop.sell(&"test_log", 2)
	assert_signal_emitted_with_parameters(_session.events, "item_sold",
			[&"test_log", 2, _session.data.item(&"test_log").value * 2])


func test_save_round_trip_rebuilds_modifiers() -> void:
	_gold(2000)
	_shop.buy(&"test_pocket")
	_shop.buy(&"test_pocket")
	var saved: Dictionary = _session.to_save(0)
	assert_eq(saved["modules"]["shop"], {"purchases": {"test_pocket": 2}})
	var other: GameSession = autofree(TestFactory.session())
	assert_true(other.from_save(JSON.parse_string(JSON.stringify(saved))).ok)
	assert_eq(other.shop.purchase_count(&"test_pocket"), 2)
	assert_eq(other.modifiers.total(&"loot_bag_slots"), 2.0)
	other.shop.from_save({"purchases": {"test_pocket": -1, "ghost": 1, "test_upgrade_1": 3}})
	assert_eq(other.shop.purchase_count(&"test_pocket"), 0)
	assert_eq(other.shop.purchase_count(&"test_upgrade_1"), 1)
	assert_eq(other.shop.purchase_count(&"test_upgrade_1"), 1, "3 limited to max_purchases")


func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func test_buy_item_effect_goes_to_the_bank() -> void:
	_gold(100)
	var before: int = _session.wallet.get_gold()
	assert_true(_shop.buy(&"test_buy_log").ok)
	assert_eq(_session.bank.get_count(&"test_log"), 1)
	assert_eq(_session.wallet.get_gold(), before - 20)


func test_buy_item_with_full_bank_keeps_gold() -> void:
	var small: GameSession = autofree(TestFactory.session(1234, _small_data))
	small.wallet.add_gold(100)
	TestFactory.give(small, &"test_twig", 1)
	assert_false(small.bank.can_add(&"test_log"), "the bank must be full for this test")
	var gold: int = small.wallet.get_gold()
	var r: CommandResult = small.shop.buy(&"test_buy_log")
	assert_eq(r.reason, Reasons.BANK_FULL)
	assert_eq(small.wallet.get_gold(), gold, "gold not spent")
	assert_eq(small.shop.purchase_count(&"test_buy_log"), 0)
	assert_eq(small.bank.get_count(&"test_log"), 0)
