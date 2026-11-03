extends GutTest
## Armory: F-82 capacity, create/add, uid never reused, worn, lock, remove, signals, save round trip.
## Fixture pieces: test_blade, test_helm, test_hatchet. Tests that need a tiny Armory use a copy of the config.

const FIXTURE_ROOT: String = "res://tests/fixtures/data"
const CONFIG_ROOT: String = "res://data/config"
const PreRun := preload("res://tests/helpers/gut_pre_run.gd")
const SMALL_SLOTS: int = 3

var _tmp_config: String = PreRun.test_dir("test_armory").path_join("config")
var _small_data: GameData = null
var _session: GameSession = null
var _armory: Armory = null


func before_all() -> void:
	DirAccess.make_dir_recursive_absolute(_tmp_config)
	var balance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_ROOT.path_join("balance.json")))
	(balance["armory"] as Dictionary)["base_slots"] = SMALL_SLOTS
	_write(_tmp_config.path_join("balance.json"), JSON.stringify(balance))
	_write(_tmp_config.path_join("stats.json"), FileAccess.get_file_as_string(CONFIG_ROOT.path_join("stats.json")))
	_small_data = GameData.load_from_dirs(FIXTURE_ROOT, _tmp_config)


func after_all() -> void:
	for file: String in ["balance.json", "stats.json"]:
		DirAccess.remove_absolute(_tmp_config.path_join(file))
	DirAccess.remove_absolute(_tmp_config)
	DirAccess.remove_absolute(_tmp_config.get_base_dir())


func before_each() -> void:
	_session = autofree(TestFactory.session(1234, _small_data))
	_armory = _session.armory


func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)


func test_new_game_is_empty_with_base_capacity() -> void:
	assert_eq(_armory.used(), 0)
	assert_eq(_armory.capacity(), SMALL_SLOTS)
	assert_eq(_armory.instances().size(), 0)


func test_f82_base_capacity_is_forty() -> void:
	var real: GameSession = autofree(TestFactory.session(1, TestFactory.real_data()))
	assert_eq(real.armory.capacity(), 40)
	real.modifiers.set_source(&"test:slots", [Modifier.make(&"armory_slots", 10.0)])
	assert_eq(real.armory.capacity(), 50, "10 bought slots")


func test_capacity_uses_armory_slots() -> void:
	watch_signals(_session.events)
	_session.modifiers.set_source(&"test:slots", [Modifier.make(&"armory_slots", 2.7)])
	assert_eq(_armory.capacity(), SMALL_SLOTS + 2, "rounded down")
	assert_signal_emitted_with_parameters(_session.events, "armory_capacity_changed", [0, SMALL_SLOTS + 2])
	TestFactory.give_piece(_session, &"test_blade")
	TestFactory.give_piece(_session, &"test_helm")
	TestFactory.give_piece(_session, &"test_hatchet")
	TestFactory.give_piece(_session, &"test_blade")
	assert_true(_armory.can_add(1), "bought slots make room")
	assert_false(_armory.can_add(2))


func test_create_assigns_increasing_uids_from_one() -> void:
	assert_eq(TestFactory.give_piece(_session, &"test_blade"), 1)
	assert_eq(TestFactory.give_piece(_session, &"test_helm"), 2)
	var inst: ItemInstance = _armory.get_instance(2)
	assert_eq(inst.base_id, &"test_helm")
	assert_eq(inst.uid, 2)
	assert_eq(inst.rarity, &"common")
	assert_eq(_armory.used(), 2)


func test_create_with_rarity_rolls_affixes() -> void:
	var uid: int = _armory.create(&"test_blade", &"rare", 30)
	assert_gt(uid, 0)
	var inst: ItemInstance = _armory.get_instance(uid)
	assert_gt(inst.affixes.size(), 0, "a rare piece has affixes")
	assert_eq(inst.ilvl, 30)
	var base_mods: int = _session.data.item(&"test_blade").equip.modifiers.size()
	assert_eq(_armory.instance_modifiers(uid).size(), base_mods + inst.affixes.size())


func test_create_rejects_non_pieces() -> void:
	assert_eq(_armory.create(&"test_log", &"common", 1), 0)
	assert_eq(_armory.create(&"nope", &"common", 1), 0)
	assert_eq(_armory.used(), 0)


func test_full_armory_rejects_without_changes() -> void:
	for i: int in SMALL_SLOTS:
		TestFactory.give_piece(_session, &"test_blade")
	watch_signals(_session.events)
	assert_eq(_armory.create(&"test_helm", &"common", 1), 0)
	assert_signal_emitted_with_parameters(_session.events, "armory_rejected", [&"test_helm", 1])
	assert_signal_not_emitted(_session.events, "armory_changed")
	assert_eq(_armory.used(), SMALL_SLOTS)
	var extra := ItemInstance.new()
	extra.base_id = &"test_helm"
	assert_eq(_armory.add(extra), 0)
	assert_eq(_armory.used(), SMALL_SLOTS)


func test_add_stores_a_copy_and_assigns_the_uid() -> void:
	var inst := ItemInstance.new()
	inst.base_id = &"test_hatchet"
	var uid: int = _armory.add(inst)
	assert_eq(uid, 1)
	assert_eq(inst.uid, 0, "the instance of the caller is untouched")
	inst.locked = true
	assert_false(_armory.get_instance(uid).locked)


func test_getters_return_copies() -> void:
	var uid: int = TestFactory.give_piece(_session, &"test_blade")
	_armory.get_instance(uid).locked = true
	_armory.instances()[0].ilvl = 99
	assert_false(_armory.get_instance(uid).locked)
	assert_eq(_armory.get_instance(uid).ilvl, 1)
	assert_null(_armory.get_instance(77))


func test_worn_pieces_do_not_count_for_capacity() -> void:
	var uids: Array[int] = []
	for i: int in SMALL_SLOTS:
		uids.append(TestFactory.give_piece(_session, &"test_blade"))
	assert_false(_armory.can_add(1))
	watch_signals(_session.events)
	_armory.set_worn(uids[0], true)
	assert_true(_armory.is_worn(uids[0]))
	assert_eq(_armory.used(), SMALL_SLOTS - 1)
	assert_true(_armory.can_add(1))
	assert_signal_emitted_with_parameters(_session.events, "armory_changed", [uids[0], &"updated"])
	assert_signal_emitted_with_parameters(_session.events, "armory_capacity_changed", [SMALL_SLOTS - 1, SMALL_SLOTS])
	_armory.set_worn(uids[0], false)
	assert_eq(_armory.used(), SMALL_SLOTS)


func test_quiet_set_worn_emits_nothing() -> void:
	var uid: int = TestFactory.give_piece(_session, &"test_blade")
	watch_signals(_session.events)
	_armory.set_worn(uid, true, true)
	assert_true(_armory.is_worn(uid))
	assert_eq(_armory.used(), 0)
	assert_signal_not_emitted(_session.events, "armory_changed")
	assert_signal_not_emitted(_session.events, "armory_capacity_changed")


func test_remove_rules_and_uid_not_reused() -> void:
	var a: int = TestFactory.give_piece(_session, &"test_blade")
	var b: int = TestFactory.give_piece(_session, &"test_helm")
	assert_eq(_armory.remove(99).reason, Reasons.UNKNOWN_ID)
	_armory.set_locked(a, true)
	assert_eq(_armory.remove(a).reason, Reasons.ITEM_LOCKED)
	_armory.set_worn(b, true)
	assert_eq(_armory.remove(b).reason, Reasons.ITEM_EQUIPPED)
	_armory.set_locked(a, false)
	watch_signals(_session.events)
	assert_true(_armory.remove(a).ok)
	assert_signal_emitted_with_parameters(_session.events, "armory_changed", [a, &"removed"])
	assert_false(_armory.has(a))
	assert_eq(TestFactory.give_piece(_session, &"test_blade"), 3, "uid not reused")


func test_set_locked() -> void:
	var uid: int = TestFactory.give_piece(_session, &"test_blade")
	assert_eq(_armory.set_locked(55, true).reason, Reasons.UNKNOWN_ID)
	watch_signals(_session.events)
	assert_true(_armory.set_locked(uid, true).ok)
	assert_true(_armory.get_instance(uid).locked)
	assert_signal_emitted_with_parameters(_session.events, "armory_changed", [uid, &"updated"])


func test_add_signals() -> void:
	watch_signals(_session.events)
	var uid: int = TestFactory.give_piece(_session, &"test_blade")
	assert_signal_emitted_with_parameters(_session.events, "armory_changed", [uid, &"added"])
	assert_signal_emitted_with_parameters(_session.events, "armory_capacity_changed", [1, SMALL_SLOTS])


func test_save_round_trip_keeps_uids_and_never_reuses_them() -> void:
	var a: int = _armory.create(&"test_blade", &"magic", 20)
	var b: int = TestFactory.give_piece(_session, &"test_helm")
	_armory.set_locked(b, true)
	_armory.set_worn(a, true)
	_armory.remove(TestFactory.give_piece(_session, &"test_hatchet"))  # uid 3 used, then freed
	var saved: Dictionary = JSON.parse_string(JSON.stringify(_armory.to_save()))
	var other: GameSession = autofree(TestFactory.session(5, _small_data))
	other.armory.from_save(saved)
	assert_eq(other.armory.to_save()["items"], _armory.to_save()["items"])
	assert_eq(other.armory.used(), 2, "the worn flag is not saved")
	assert_false(other.armory.is_worn(a))
	assert_true(other.armory.get_instance(b).locked)
	assert_eq(TestFactory.give_piece(other, &"test_blade"), 4, "next_uid survives")


func test_from_save_is_tolerant_and_reports() -> void:
	var good: Dictionary = {"uid": 3, "base": "test_blade", "rarity": "common", "ilvl": 1, "affixes": [],
			"upgrade": 0, "sockets": [], "locked": false}
	var dup: Dictionary = good.duplicate()
	var log_base: Dictionary = good.duplicate()
	log_base["uid"] = 4
	log_base["base"] = "test_log"
	var unknown: Dictionary = good.duplicate()
	unknown["uid"] = 5
	unknown["base"] = "nope"
	var zero: Dictionary = good.duplicate()
	zero["uid"] = 0
	_armory.from_save({"next_uid": 2, "items": [good, dup, log_base, unknown, zero, "junk"]})
	assert_eq(_armory.instances().size(), 1)
	assert_true(_armory.has(3))
	assert_eq(TestFactory.give_piece(_session, &"test_helm"), 4, "next_uid raised above the maximum")
	_armory.from_save({"items": "no"})
	assert_eq(_armory.used(), 0)


func test_from_save_does_not_check_capacity() -> void:
	var items: Array = []
	for i: int in SMALL_SLOTS + 2:
		items.append({"uid": i + 1, "base": "test_blade", "rarity": "common", "ilvl": 1, "affixes": [],
				"upgrade": 0, "sockets": [], "locked": false})
	_armory.from_save({"next_uid": 99, "items": items})
	assert_eq(_armory.used(), SMALL_SLOTS + 2)
	assert_false(_armory.can_add(1))


func test_session_save_round_trip_includes_armory() -> void:
	TestFactory.give_piece(_session, &"test_blade")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(_session.to_save(0)))
	assert_true((saved["modules"] as Dictionary).has("armory"))
	var other: GameSession = autofree(TestFactory.session(9, _small_data))
	assert_true(other.from_save(saved).ok)
	assert_eq(other.armory.used(), 1)
