extends GutTest
## Bank: slots and capacity (F-16), add/remove with their signals, bank full, locks, order, sort, save round trip.
##
## Fixture items: 8 types, fewer than bank.base_slots. Tests that need a full bank or start items use a copy of
## res://data/config written under user:// with a small `bank.base_slots` and some `start.items`.

const FIXTURE_ROOT: String = "res://tests/fixtures/data"
const CONFIG_ROOT: String = "res://data/config"
const PreRun := preload("res://tests/helpers/gut_pre_run.gd")
const SMALL_BASE_SLOTS: int = 2
const START_ITEMS: Array[Dictionary] = [{"item": "test_log", "qty": 3}, {"item": "test_twig", "qty": 5}]

var _tmp_config: String = PreRun.test_dir("test_bank").path_join("config")
var _small_data: GameData = null
var _session: GameSession = null


func before_all() -> void:
	DirAccess.make_dir_recursive_absolute(_tmp_config)
	var balance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_ROOT.path_join("balance.json")))
	(balance["bank"] as Dictionary)["base_slots"] = SMALL_BASE_SLOTS
	(balance["start"] as Dictionary)["items"] = START_ITEMS + [{"item": "seared_brookfin", "qty": 1}]  # the kit food, removed by clear_kit
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


func _small() -> GameSession:
	assert_true(_small_data.is_valid(), "\n".join(_small_data.errors))
	return autofree(TestFactory.session(1234, _small_data))


func _ids(bank: Bank) -> Array[StringName]:
	var result: Array[StringName] = []
	for stack: Dictionary in bank.stacks():
		result.append(stack["item"])
	return result


func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func test_new_game_is_empty_with_base_capacity() -> void:
	assert_eq(_session.bank.used(), 0)
	assert_eq(_session.bank.capacity(), int(_session.data.balance_value("bank.base_slots")))
	assert_eq(_session.bank.stacks(), [] as Array[Dictionary])


func test_new_game_applies_start_items() -> void:
	var session: GameSession = _small()
	assert_eq(_ids(session.bank), [&"test_log", &"test_twig"] as Array[StringName])
	assert_eq(session.bank.get_count(&"test_log"), 3)
	assert_eq(session.bank.get_count(&"test_twig"), 5)
	TestFactory.give(session, &"test_log", 4)
	session.new_game()
	assert_eq(session.bank.get_count(&"test_log"), 3)


func test_capacity_uses_bank_slots() -> void:
	# F-16: 3 purchased slots -> 24 + 3 = 27.
	assert_eq(_session.bank.capacity(), 24)
	TestFactory.give(_session, &"test_log", 1)
	watch_signals(_session.events)
	_session.modifiers.set_source(&"shop:bank_slot", [Modifier.make(&"bank_slots", 3.0)] as Array[Modifier])
	assert_eq(_session.bank.capacity(), 27)
	assert_signal_emitted_with_parameters(_session.events, "bank_capacity_changed", [1, 27])


func test_capacity_rounds_bank_slots_down() -> void:
	_session.modifiers.set_source(&"shop:bank_slot", [Modifier.make(&"bank_slots", 2.9)] as Array[Modifier])
	assert_eq(_session.bank.capacity(), 26)


func test_modifiers_change_without_capacity_change_emits_nothing() -> void:
	watch_signals(_session.events)
	_session.modifiers.set_source(&"other", [Modifier.make(&"skill_xp_pct", 5.0)] as Array[Modifier])
	assert_signal_not_emitted(_session.events, "bank_capacity_changed")


func test_add_new_item_takes_a_slot_and_emits() -> void:
	watch_signals(_session.events)
	var result: CommandResult = _session.bank.add(&"test_log", 7)
	assert_true(result.ok)
	assert_eq(_session.bank.get_count(&"test_log"), 7)
	assert_eq(_session.bank.used(), 1)
	assert_signal_emitted_with_parameters(_session.events, "bank_changed", [&"test_log", 7, 7])
	assert_signal_emitted_with_parameters(_session.events, "bank_capacity_changed", [1, 24])


func test_add_existing_item_keeps_slots_and_emits_its_delta() -> void:
	TestFactory.give(_session, &"test_log", 7)
	watch_signals(_session.events)
	assert_true(_session.bank.add(&"test_log", 5).ok)
	assert_eq(_session.bank.get_count(&"test_log"), 12)
	assert_eq(_session.bank.used(), 1)
	assert_signal_emitted_with_parameters(_session.events, "bank_changed", [&"test_log", 12, 5])
	assert_signal_not_emitted(_session.events, "bank_capacity_changed")


func test_add_unknown_item_fails() -> void:
	watch_signals(_session.events)
	assert_eq(_session.bank.add(&"ghost_item", 1).reason, Reasons.UNKNOWN_ID)
	assert_eq(_session.bank.used(), 0)
	assert_signal_not_emitted(_session.events, "bank_changed")


func test_add_non_positive_quantity_is_invalid() -> void:
	assert_eq(_session.bank.add(&"test_log", 0).reason, Reasons.INVALID_AMOUNT)
	assert_eq(_session.bank.add(&"test_log", -2).reason, Reasons.INVALID_AMOUNT)
	assert_eq(_session.bank.used(), 0)


func test_bank_full_rejects_new_item() -> void:
	var session: GameSession = _small()
	assert_eq(session.bank.used(), session.bank.capacity())
	watch_signals(session.events)
	var result: CommandResult = session.bank.add(&"test_plank", 2)
	assert_false(result.ok)
	assert_eq(result.reason, Reasons.BANK_FULL)
	assert_signal_emitted_with_parameters(session.events, "bank_rejected", [&"test_plank", 2])
	assert_signal_not_emitted(session.events, "bank_changed")
	assert_eq(session.bank.get_count(&"test_plank"), 0)
	assert_eq(session.bank.used(), SMALL_BASE_SLOTS)


func test_bank_full_still_accepts_items_already_present() -> void:
	var session: GameSession = _small()
	assert_true(session.bank.add(&"test_log", 1).ok)
	assert_eq(session.bank.get_count(&"test_log"), 4)


func test_can_add() -> void:
	var session: GameSession = _small()
	assert_true(session.bank.can_add(&"test_log"))
	assert_false(session.bank.can_add(&"test_plank"))
	assert_false(_session.bank.can_add(&"ghost_item"))
	assert_true(_session.bank.can_add(&"test_plank"))


func test_bought_slot_makes_room_in_a_full_bank() -> void:
	var session: GameSession = _small()
	session.modifiers.set_source(&"shop:bank_slot", [Modifier.make(&"bank_slots", 1.0)] as Array[Modifier])
	assert_true(session.bank.add(&"test_plank", 2).ok)


func test_has() -> void:
	TestFactory.give(_session, &"test_log", 4)
	assert_true(_session.bank.has(&"test_log", 4))
	assert_false(_session.bank.has(&"test_log", 5))
	assert_false(_session.bank.has(&"test_plank", 1))


func test_remove_part_emits_negative_delta() -> void:
	TestFactory.give(_session, &"test_log", 10)
	watch_signals(_session.events)
	assert_true(_session.bank.remove(&"test_log", 4).ok)
	assert_eq(_session.bank.get_count(&"test_log"), 6)
	assert_eq(_session.bank.used(), 1)
	assert_signal_emitted_with_parameters(_session.events, "bank_changed", [&"test_log", 6, -4])
	assert_signal_not_emitted(_session.events, "bank_capacity_changed")


func test_zero_quantity_frees_the_slot() -> void:
	TestFactory.give(_session, &"test_log", 3)
	TestFactory.give(_session, &"test_twig", 1)
	_session.bank.set_locked(&"test_log", true)
	watch_signals(_session.events)
	assert_true(_session.bank.remove(&"test_log", 3).ok)
	assert_eq(_session.bank.used(), 1)
	assert_eq(_ids(_session.bank), [&"test_twig"] as Array[StringName])
	assert_false(_session.bank.is_locked(&"test_log"))
	assert_signal_emitted_with_parameters(_session.events, "bank_changed", [&"test_log", 0, -3])
	assert_signal_emitted_with_parameters(_session.events, "bank_capacity_changed", [1, 24])


func test_remove_failures_change_nothing() -> void:
	TestFactory.give(_session, &"test_log", 3)
	watch_signals(_session.events)
	assert_eq(_session.bank.remove(&"test_log", 4).reason, Reasons.NOT_ENOUGH_ITEMS)
	assert_eq(_session.bank.remove(&"test_plank", 1).reason, Reasons.NOT_ENOUGH_ITEMS)
	assert_eq(_session.bank.remove(&"test_log", 0).reason, Reasons.INVALID_AMOUNT)
	assert_eq(_session.bank.remove(&"test_log", -1).reason, Reasons.INVALID_AMOUNT)
	assert_eq(_session.bank.get_count(&"test_log"), 3)
	assert_signal_not_emitted(_session.events, "bank_changed")


func test_stacks_keep_insertion_order_and_are_copies() -> void:
	TestFactory.give(_session, &"test_plank", 1)
	TestFactory.give(_session, &"test_log", 2)
	TestFactory.give(_session, &"test_plank", 1)
	var stacks: Array[Dictionary] = _session.bank.stacks()
	assert_eq(stacks, [{"item": &"test_plank", "count": 2, "locked": false},
			{"item": &"test_log", "count": 2, "locked": false}] as Array[Dictionary])
	stacks[0]["count"] = 99
	assert_eq(_session.bank.get_count(&"test_plank"), 2)


func test_set_locked() -> void:
	TestFactory.give(_session, &"test_log", 2)
	watch_signals(_session.events)
	assert_true(_session.bank.set_locked(&"test_log", true).ok)
	assert_true(_session.bank.is_locked(&"test_log"))
	assert_signal_emitted_with_parameters(_session.events, "bank_changed", [&"test_log", 2, 0])
	assert_true(_session.bank.set_locked(&"test_log", false).ok)
	assert_false(_session.bank.is_locked(&"test_log"))
	assert_eq(_session.bank.set_locked(&"test_plank", true).reason, Reasons.UNKNOWN_ID)
	assert_false(_session.bank.is_locked(&"test_plank"))


func test_move_stack() -> void:
	for id: StringName in [&"test_twig", &"test_log", &"test_plank"]:
		TestFactory.give(_session, id, 1)
	watch_signals(_session.events)
	assert_true(_session.bank.move_stack(&"test_plank", 0).ok)
	assert_eq(_ids(_session.bank), [&"test_plank", &"test_twig", &"test_log"] as Array[StringName])
	assert_signal_emit_count(_session.events, "bank_changed", 3)
	assert_signal_emitted_with_parameters(_session.events, "bank_changed", [&"test_plank", 1, 0], 0)
	assert_true(_session.bank.move_stack(&"test_plank", 2).ok)
	assert_eq(_ids(_session.bank), [&"test_twig", &"test_log", &"test_plank"] as Array[StringName])


func test_move_stack_failures_change_nothing() -> void:
	TestFactory.give(_session, &"test_twig", 1)
	TestFactory.give(_session, &"test_log", 1)
	assert_eq(_session.bank.move_stack(&"test_plank", 0).reason, Reasons.UNKNOWN_ID)
	assert_eq(_session.bank.move_stack(&"test_log", 2).reason, Reasons.INVALID_AMOUNT)
	assert_eq(_session.bank.move_stack(&"test_log", -1).reason, Reasons.INVALID_AMOUNT)
	assert_eq(_ids(_session.bank), [&"test_twig", &"test_log"] as Array[StringName])


func test_sort_stacks_by_category_then_sort_order() -> void:
	for id: StringName in [&"rift_shard", &"test_plank", &"test_ration", &"test_twig",
			&"test_infusion", &"test_log"]:
		TestFactory.give(_session, id, 1)
	_session.bank.sort_stacks()
	assert_eq(_ids(_session.bank), [&"test_twig", &"test_log", &"test_plank", &"test_ration",
			&"test_infusion", &"rift_shard"] as Array[StringName])


func test_to_save_format() -> void:
	TestFactory.give(_session, &"test_log", 412)
	TestFactory.give(_session, &"rift_shard", 3)
	_session.bank.set_locked(&"rift_shard", true)
	assert_eq(_session.bank.to_save(), {"stacks": [{"item": "test_log", "count": 412, "locked": false},
			{"item": "rift_shard", "count": 3, "locked": true}]})


func test_round_trip_keeps_order_counts_and_locks() -> void:
	for id: StringName in [&"test_plank", &"rift_shard", &"test_log"]:
		TestFactory.give(_session, id, 5)
	_session.bank.move_stack(&"test_log", 0)
	_session.bank.set_locked(&"rift_shard", true)
	var text: String = SaveCodec.encode(_session.to_save(0))
	var other: GameSession = autofree(TestFactory.session(9))
	assert_true(other.from_save(SaveCodec.decode(text)).ok)
	assert_eq(other.bank.stacks(), _session.bank.stacks())
	assert_eq(SaveCodec.encode(other.to_save(0)), text)


func test_from_save_drops_unknown_duplicate_and_bad_stacks() -> void:
	_session.bank.from_save({"stacks": [
		{"item": "test_log", "count": 4.0, "locked": true},
		{"item": "ghost_item", "count": 1},
		{"item": "test_log", "count": 9},
		{"item": "test_twig", "count": 0},
		{"item": "test_plank", "count": 1.5},
		"junk",
		{"item": "rift_shard", "count": 2, "locked": "yes"},
	]})
	assert_eq(_session.bank.stacks(), [{"item": &"test_log", "count": 4, "locked": true},
			{"item": &"rift_shard", "count": 2, "locked": false}] as Array[Dictionary])


func test_from_save_without_stacks_is_empty() -> void:
	TestFactory.give(_session, &"test_log", 1)
	_session.bank.from_save({})
	assert_eq(_session.bank.used(), 0)


func test_snapshot_reads_bank_and_gold() -> void:
	TestFactory.give(_session, &"test_log", 6)
	TestFactory.give(_session, &"rift_shard", 1)
	_session.wallet.add_gold(10)
	var snapshot: SessionSnapshot = SessionSnapshot.take(_session)
	assert_eq(snapshot.bank, {&"test_log": 6, &"rift_shard": 1} as Dictionary[StringName, int])
	assert_eq(snapshot.gold, _session.wallet.get_gold())


func test_not_stackable_pieces() -> void:
	watch_signals(_session.events)
	for id: StringName in [&"test_blade", &"unique_hatchet"]:
		assert_false(_session.bank.can_add(id), "can_add %s" % id)
		assert_eq(_session.bank.add(id, 1).reason, Reasons.NOT_STACKABLE)
		assert_eq(_session.bank.add(id, 0).reason, Reasons.NOT_STACKABLE, "before invalid_amount")
	assert_eq(_session.bank.add(&"nope", 1).reason, Reasons.UNKNOWN_ID, "unknown_id comes first")
	assert_eq(_session.bank.used(), 0)
	assert_signal_not_emitted(_session.events, "bank_changed")
	assert_signal_not_emitted(_session.events, "bank_rejected")


func test_from_save_drops_pieces() -> void:
	_session.bank.from_save({"stacks": [
		{"item": "test_blade", "count": 1, "locked": false},
		{"item": "test_log", "count": 4, "locked": true},
		{"item": "unique_hatchet", "count": 2},
	]})
	assert_eq(_ids(_session.bank), [&"test_log"] as Array[StringName])
	assert_eq(_session.bank.get_count(&"test_log"), 4)
