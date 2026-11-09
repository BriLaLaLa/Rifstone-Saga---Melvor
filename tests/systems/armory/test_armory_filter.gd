extends GutTest
## Automatic filter (docs/01_GDD.md §25): per-slot rules, Armory.add_drop (filtered and full-Armory drops are salvaged
## with auto = true), the filter in the save. Real data; a small Armory comes from a copy of the config.

const SHARD: StringName = &"rift_shard"
const CONFIG_ROOT: String = "res://data/config"
const PreRun := preload("res://tests/helpers/gut_pre_run.gd")
const SMALL_SLOTS: int = 8  # deposit.base_slots of the small data

var _tmp_config: String = PreRun.test_dir("test_armory_filter").path_join("config")
var _small_data: GameData = null
var _data: GameData = TestFactory.real_data()
var _session: GameSession = null


func before_all() -> void:
	DirAccess.make_dir_recursive_absolute(_tmp_config)
	var balance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_ROOT.path_join("balance.json")))
	(balance["deposit"] as Dictionary)["base_slots"] = SMALL_SLOTS
	_write(_tmp_config.path_join("balance.json"), JSON.stringify(balance))
	_write(_tmp_config.path_join("stats.json"), FileAccess.get_file_as_string(CONFIG_ROOT.path_join("stats.json")))
	_small_data = GameData.load_from_dirs(TestFactory.REAL_CONTENT_ROOT, _tmp_config)


func after_all() -> void:
	for file: String in ["balance.json", "stats.json"]:
		DirAccess.remove_absolute(_tmp_config.path_join(file))
	DirAccess.remove_absolute(_tmp_config)
	DirAccess.remove_absolute(_tmp_config.get_base_dir())


func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


# These sessions run on the real data: they start with the kit (M10); the Armory tests want an empty game.
func _empty(session: GameSession) -> GameSession:
	TestFactory.clear_kit(session)
	return session


func before_each() -> void:
	_session = _empty(autofree(TestFactory.session(21, _data)))


func _inst(base: StringName, rarity: StringName, level: int = 0) -> ItemInstance:
	var inst := ItemInstance.new()
	inst.base_id = base
	inst.rarity = rarity
	inst.ilvl = 1
	inst.upgrade = level
	return inst


func test_default_filter_keeps_everything() -> void:
	var rule: Dictionary = _session.armory.filter_rule(&"weapon")
	assert_eq(rule, {"min_rarity": &"common", "min_grade": 1})
	assert_eq(_session.armory.filter_rules(), {})
	assert_false(_session.armory.is_filtered(_inst(&"emberbronze_sword", &"common")))


func test_set_filter_and_rejections() -> void:
	assert_true(_session.armory.set_filter(&"weapon", &"magic", 3).ok)
	assert_eq(_session.armory.filter_rule(&"weapon"), {"min_rarity": &"magic", "min_grade": 3})
	assert_eq(_session.armory.set_filter(&"wing", &"magic", 1).reason, Reasons.UNKNOWN_ID)
	assert_eq(_session.armory.set_filter(&"weapon", &"epic", 1).reason, Reasons.UNKNOWN_ID)
	assert_eq(_session.armory.set_filter(&"weapon", &"magic", 0).reason, Reasons.INVALID_AMOUNT)
	assert_eq(_session.armory.set_filter(&"weapon", &"magic", 16).reason, Reasons.INVALID_AMOUNT, "M14: 15 piece grades")
	assert_true(_session.armory.set_filter(&"weapon", &"legendary", 15).ok)
	assert_true(_session.armory.set_filter(&"weapon", &"magic", 3).ok)
	assert_eq(_session.armory.filter_rule(&"weapon"), {"min_rarity": &"magic", "min_grade": 3}, "unchanged")
	assert_true(_session.armory.set_filter(&"weapon", &"common", 1).ok, "back to keep everything")
	assert_eq(_session.armory.filter_rules(), {})


func test_a_piece_is_kept_only_if_it_meets_both_minimums() -> void:
	_session.armory.set_filter(&"weapon", &"magic", 2)
	assert_true(_session.armory.is_filtered(_inst(&"emberbronze_sword", &"magic")), "grade 1 < 2")
	assert_true(_session.armory.is_filtered(_inst(&"ashlead_sword", &"common")), "common < magic")
	assert_false(_session.armory.is_filtered(_inst(&"ashlead_sword", &"magic")))
	assert_false(_session.armory.is_filtered(_inst(&"ashlead_sword", &"rare")))
	assert_false(_session.armory.is_filtered(_inst(&"emberbronze_cuirass", &"common")), "other slots are unaffected")


func test_drop_over_the_filter_is_stored() -> void:
	_session.armory.set_filter(&"weapon", &"magic", 1)
	var uid: int = _session.armory.add_drop(_inst(&"emberbronze_sword", &"rare"))
	assert_gt(uid, 0)
	assert_true(_session.armory.has(uid))


func test_drop_under_the_filter_is_salvaged_at_once() -> void:
	_session.armory.set_filter(&"weapon", &"rare", 1)
	watch_signals(_session.events)
	var uid: int = _session.armory.add_drop(_inst(&"duskcobalt_sword", &"magic"))
	assert_eq(uid, 0, "not stored")
	assert_eq(_session.armory.used(), 0)
	var comps: Dictionary[StringName, int] = Salvage.components(&"duskcobalt_sword", _session.data)  # F-95: blueprint inputs x 0.4
	for item_id: StringName in comps:
		assert_eq(_session.bank.get_count(item_id), comps[item_id])
	assert_eq(_session.bank.get_count(SHARD), 2, "magic 1 x grade of the material 2 (piece grade 4, F-95 M14)")
	assert_signal_emitted_with_parameters(_session.events, "item_salvaged", [1, &"duskcobalt_sword", true])
	assert_signal_not_emitted(_session.events, "armory_changed")
	var kept: int = _session.armory.add_drop(_inst(&"duskcobalt_sword", &"rare"))
	assert_eq(kept, 2, "the spent uid is not reused")


func test_drop_with_a_full_armory_is_salvaged() -> void:
	var session: GameSession = _empty(autofree(TestFactory.session(22, _small_data)))
	# The Deposit is shared: the yield only fits in stacks the bank already holds, so they are there before it fills up.
	var comps: Dictionary[StringName, int] = Salvage.components(&"stormzinc_cuirass", session.data)
	for item_id: StringName in comps:
		TestFactory.give(session, item_id, 1)
	TestFactory.give(session, SHARD, 1)
	var filled: int = 0
	while session.armory.can_add(1):
		assert_gt(session.armory.add(_inst(&"emberbronze_sword", &"common")), 0)
		filled += 1
	assert_gt(filled, 0)
	watch_signals(session.events)
	var uid: int = session.armory.add_drop(_inst(&"stormzinc_cuirass", &"rare"))
	assert_eq(uid, 0)
	assert_eq(session.armory.used(), filled, "still full")
	for item_id: StringName in comps:
		assert_eq(session.bank.get_count(item_id), comps[item_id] + 1)
	assert_eq(session.bank.get_count(SHARD), 7, "1 + rare 3 x grade of the material 2 (piece grade 3, F-95 M14)")
	assert_signal_emitted_with_parameters(session.events, "item_salvaged", [filled + 1, &"stormzinc_cuirass", true])
	assert_signal_not_emitted(session.events, "armory_rejected")


func test_drop_that_is_not_a_piece_is_ignored() -> void:
	assert_eq(_session.armory.add_drop(_inst(&"redbirch_log", &"common")), 0)
	assert_eq(_session.armory.add_drop(null), 0)
	assert_eq(_session.bank.get_count(&"redbirch_log"), 0)


func test_filter_save_round_trip() -> void:
	_session.armory.set_filter(&"weapon", &"magic", 2)
	_session.armory.set_filter(&"tool_forestry", &"rare", 1)
	var saved: Dictionary = _session.armory.to_save()
	assert_eq(saved["filter"], {"weapon": {"min_rarity": "magic", "min_grade": 2},
			"tool_forestry": {"min_rarity": "rare", "min_grade": 1}})
	var other: GameSession = _empty(autofree(TestFactory.session(23, _data)))
	other.armory.from_save(saved)
	assert_eq(other.armory.filter_rules(), _session.armory.filter_rules())
	assert_eq(other.armory.to_save(), saved, "save -> load -> save")


func test_old_save_without_filter_keeps_everything() -> void:
	_session.armory.set_filter(&"weapon", &"rare", 1)
	_session.armory.from_save({"next_uid": 1, "items": []})
	assert_eq(_session.armory.filter_rules(), {})


func test_invalid_filter_rules_are_dropped_with_a_warning() -> void:
	_session.armory.from_save({"next_uid": 1, "items": [], "filter": {
		"weapon": {"min_rarity": "magic", "min_grade": 2}, "wing": {"min_rarity": "rare", "min_grade": 1},
		"head": {"min_rarity": "epic", "min_grade": 1}, "body": {"min_rarity": "rare", "min_grade": 16},
		"legs": "rare", "feet": {"min_rarity": "rare", "min_grade": 1.5}}})
	assert_eq(_session.armory.filter_rules(), {&"weapon": {"min_rarity": &"magic", "min_grade": 2}})
	_session.armory.from_save({"next_uid": 1, "items": [], "filter": 5})
	assert_eq(_session.armory.filter_rules(), {})


func test_new_game_clears_the_filter() -> void:
	_session.armory.set_filter(&"weapon", &"rare", 1)
	_session.armory.new_game()
	assert_eq(_session.armory.filter_rules(), {})
