extends GutTest
## F-86 refinement: pure rules (Upgrade) and Armory.upgrade (costs, success, downgrade, Seal, signals). Real data.
## The commands use a copy of the config whose
## `upgrade.seal_item` is a generic existing item (SEAL), so the tests do not depend on the real `warding_seal`.

const SWORD_T1: StringName = &"emberbronze_sword"
const SWORD_T4: StringName = &"duskcobalt_sword"
const INGOT_T1: StringName = &"emberbronze_ingot"
const INGOT_T4: StringName = &"duskcobalt_ingot"
const SEAL: StringName = &"redbirch_log"
const SHARD: StringName = &"rift_shard"
const CONFIG_ROOT: String = "res://data/config"
const PreRun := preload("res://tests/helpers/gut_pre_run.gd")

var _tmp_config: String = PreRun.test_dir("test_upgrade").path_join("config")
var _seal_data: GameData = null
var _data: GameData = null
var _session: GameSession = null


func before_all() -> void:
	DirAccess.make_dir_recursive_absolute(_tmp_config)
	var balance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_ROOT.path_join("balance.json")))
	(balance["upgrade"] as Dictionary)["seal_item"] = String(SEAL)
	_write(_tmp_config.path_join("balance.json"), JSON.stringify(balance))
	_write(_tmp_config.path_join("stats.json"), FileAccess.get_file_as_string(CONFIG_ROOT.path_join("stats.json")))
	_seal_data = GameData.load_from_dirs(TestFactory.REAL_CONTENT_ROOT, _tmp_config)
	_data = TestFactory.real_data()


func after_all() -> void:
	for file: String in ["balance.json", "stats.json"]:
		DirAccess.remove_absolute(_tmp_config.path_join(file))
	DirAccess.remove_absolute(_tmp_config)
	DirAccess.remove_absolute(_tmp_config.get_base_dir())


func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


## A session on `seed_value` whose first roll_pct(chance) gives `success`; found by searching the seeds.
func _session_with_roll(chance: float, success: bool, data: GameData = null) -> GameSession:
	for seed_value: int in range(1, 500):
		if RngService.new(seed_value).roll_pct(chance) == success:
			return autofree(TestFactory.session(seed_value, data if data != null else _data))
	fail_test("no seed found")
	return autofree(TestFactory.session(1, data if data != null else _data))


func _piece(session: GameSession, base: StringName, level: int, rarity: StringName = &"common") -> int:
	var inst := ItemInstance.new()
	inst.base_id = base
	inst.rarity = rarity
	inst.ilvl = 1
	inst.upgrade = level
	return session.armory.add(inst)


func _set_gold(session: GameSession, gold: int) -> void:
	if session.wallet.get_gold() > 0:
		session.wallet.spend(session.wallet.get_gold())
	if gold > 0:
		session.wallet.add_gold(gold)


func _stock(session: GameSession, gold: int, items: Dictionary) -> void:
	_set_gold(session, gold)
	for item: StringName in items:
		TestFactory.give(session, item, items[item])


func test_table_matches_formula_doc() -> void:
	var success: Array[int] = [95, 90, 85, 75, 65, 55, 45, 35, 25]
	var gold: Array[int] = [50, 100, 200, 400, 800, 1600, 3200, 6400, 12800]
	var ingots: Array[int] = [1, 1, 2, 2, 3, 3, 4, 4, 5]
	var shards: Array[int] = [0, 0, 0, 0, 0, 5, 10, 15, 20]
	assert_eq(Upgrade.max_level(_data), 9)
	for n: int in 9:
		var row: Dictionary = Upgrade.row(n, _data)
		assert_eq(int(row["success_pct"]), success[n], "success %d" % n)
		assert_eq(int(row["gold_per_grade"]), gold[n], "gold %d" % n)
		assert_eq(int(row["ingots"]), ingots[n], "ingots %d" % n)
		assert_eq(int(row["shards"]), shards[n], "shards %d" % n)


func test_chance_with_bonus() -> void:
	assert_almost_eq(Upgrade.chance_pct(5, 10.0, _data), 60.5, 0.0001, "+5 -> +6 with +10%")
	assert_almost_eq(Upgrade.chance_pct(5, 0.0, _data), 55.0, 0.0001)
	assert_eq(Upgrade.chance_pct(0, 300.0, _data), 100.0, "capped at 100")


func test_failed_level_downgrades_from_four() -> void:
	assert_eq(Upgrade.failed_level(5, _data), 4, "failure from +5 -> +4")
	assert_eq(Upgrade.failed_level(4, _data), 3, "from the threshold")
	assert_eq(Upgrade.failed_level(3, _data), 3, "failure from +3 stays +3")
	assert_eq(Upgrade.failed_level(0, _data), 0)


func test_cost_t4_sword_plus5() -> void:
	var cost: Dictionary = Upgrade.cost(5, _data.item(SWORD_T4).equip.grade, _data)
	assert_eq(int(cost["gold"]), 6400)
	assert_eq(cost["ingot"], INGOT_T4)
	assert_eq(int(cost["ingots"]), 3)
	assert_eq(int(cost["shards"]), 5)


func test_upgrade_success_pct() -> void:
	# The stat feeds the chance: at +8 -> +9 (25%) a +300% bonus makes the attempt certain.
	var session: GameSession = _session_with_roll(25.0, false)
	var uid: int = _piece(session, SWORD_T4, 8)
	_stock(session, 100000, {INGOT_T4: 5, SHARD: 20})
	session.modifiers.set_source(&"test:upg", [Modifier.make(Upgrade.STAT, 300.0)])
	assert_eq(Upgrade.chance_pct(8, session.modifiers.total(Upgrade.STAT), _data), 100.0)
	assert_true(session.armory.upgrade(uid).ok)
	assert_eq(session.armory.get_instance(uid).upgrade, 9, "the roll that would fail succeeds with the bonus")


func test_success_spends_materials_and_raises_level() -> void:
	var session: GameSession = _session_with_roll(95.0, true)
	var uid: int = _piece(session, SWORD_T1, 0)
	_stock(session, 80, {INGOT_T1: 3})
	watch_signals(session.events)
	var result: CommandResult = session.armory.upgrade(uid)
	assert_true(result.ok)
	assert_eq(session.armory.get_instance(uid).upgrade, 1)
	assert_eq(session.wallet.get_gold(), 30, "50 gold spent")
	assert_eq(session.bank.get_count(INGOT_T1), 2)
	assert_signal_emitted_with_parameters(session.events, "item_upgraded", [uid, true, 1])
	assert_signal_emitted_with_parameters(session.events, "armory_changed", [uid, &"updated"])


func test_failure_from_plus5_loses_a_level_and_materials() -> void:
	var session: GameSession = _session_with_roll(55.0, false)
	var uid: int = _piece(session, SWORD_T4, 5)
	_stock(session, 7000, {INGOT_T4: 4, SHARD: 6})
	watch_signals(session.events)
	assert_true(session.armory.upgrade(uid).ok)
	assert_eq(session.armory.get_instance(uid).upgrade, 4)
	assert_eq(session.wallet.get_gold(), 600, "6400 spent")
	assert_eq(session.bank.get_count(INGOT_T4), 1)
	assert_eq(session.bank.get_count(SHARD), 1)
	assert_signal_emitted_with_parameters(session.events, "item_upgraded", [uid, false, 4])


func test_failure_from_plus3_keeps_the_level() -> void:
	var session: GameSession = _session_with_roll(75.0, false)
	var uid: int = _piece(session, SWORD_T1, 3)
	_stock(session, 400, {INGOT_T1: 2})
	assert_true(session.armory.upgrade(uid).ok)
	assert_eq(session.armory.get_instance(uid).upgrade, 3)
	assert_eq(session.wallet.get_gold(), 0, "materials lost anyway")
	assert_eq(session.bank.get_count(INGOT_T1), 0)
	assert_true(session.armory.has(uid), "never destroyed")


func test_seal_prevents_the_downgrade_and_is_consumed() -> void:
	var session: GameSession = _session_with_roll(55.0, false, _seal_data)
	var uid: int = _piece(session, SWORD_T1, 5)
	_stock(session, 1600, {INGOT_T1: 3, SHARD: 5, SEAL: 2})
	assert_true(session.armory.upgrade(uid, true).ok)
	assert_eq(session.armory.get_instance(uid).upgrade, 5, "kept")
	assert_eq(session.bank.get_count(SEAL), 1, "one Seal consumed")


func test_seal_is_kept_on_success() -> void:
	var session: GameSession = _session_with_roll(55.0, true, _seal_data)
	var uid: int = _piece(session, SWORD_T1, 5)
	_stock(session, 1600, {INGOT_T1: 3, SHARD: 5, SEAL: 1})
	assert_true(session.armory.upgrade(uid, true).ok)
	assert_eq(session.armory.get_instance(uid).upgrade, 6)
	assert_eq(session.bank.get_count(SEAL), 1, "not consumed on success")


func test_seal_missing_fails_without_changes() -> void:
	var session: GameSession = _session_with_roll(55.0, false, _seal_data)
	var uid: int = _piece(session, SWORD_T1, 5)
	_stock(session, 1600, {INGOT_T1: 3, SHARD: 5})
	var result: CommandResult = session.armory.upgrade(uid, true)
	assert_false(result.ok)
	assert_eq(result.reason, Reasons.NOT_ENOUGH_ITEMS)
	assert_eq(session.wallet.get_gold(), 1600)
	assert_eq(session.armory.get_instance(uid).upgrade, 5)


func test_seal_is_not_needed_below_the_threshold() -> void:
	var session: GameSession = _session_with_roll(85.0, false, _seal_data)
	var uid: int = _piece(session, SWORD_T1, 2)
	_stock(session, 200, {INGOT_T1: 2})
	assert_true(session.armory.upgrade(uid, true).ok, "no Seal in the bank, none required")
	assert_eq(session.armory.get_instance(uid).upgrade, 2)


func test_rejections_change_nothing() -> void:
	var session: GameSession = autofree(TestFactory.session(3, _data))
	var uid: int = _piece(session, SWORD_T4, 5)
	assert_eq(session.armory.upgrade(999).reason, Reasons.UNKNOWN_ID)
	_set_gold(session, 0)
	assert_eq(session.armory.upgrade(uid).reason, Reasons.NOT_ENOUGH_GOLD, "gold is checked first")
	_set_gold(session, 6400)
	assert_eq(session.armory.upgrade(uid).reason, Reasons.NOT_ENOUGH_ITEMS, "no ingots")
	TestFactory.give(session, INGOT_T4, 3)
	assert_eq(session.armory.upgrade(uid).reason, Reasons.NOT_ENOUGH_ITEMS, "no shards")
	assert_eq(session.wallet.get_gold(), 6400)
	assert_eq(session.bank.get_count(INGOT_T4), 3)
	assert_eq(session.armory.get_instance(uid).upgrade, 5)


func test_max_level_is_rejected() -> void:
	var session: GameSession = autofree(TestFactory.session(3, _data))
	var uid: int = _piece(session, SWORD_T1, 9)
	_stock(session, 1000000, {INGOT_T1: 10, SHARD: 100})
	var result: CommandResult = session.armory.upgrade(uid)
	assert_false(result.ok)
	assert_eq(result.reason, Reasons.UPGRADE_MAX)
	assert_eq(session.wallet.get_gold(), 1000000)


## F-93: the source `skill_level:forging` gives `upgrade_success_pct` = 0.4 x level (level_modifiers of the skill); with
## the Forgiatura at 50 the step +5 -> +6 (success_pct 55) is 55 x 1.2 = 66. M10 fixtures (forging has level_modifiers).
func test_forging_level_bonus() -> void:
	var data: GameData = preload("res://tests/systems/actions/blueprint_data.gd").data()
	var session: GameSession = autofree(TestFactory.session(3, data))
	assert_almost_eq(session.modifiers.total(&"upgrade_success_pct"), 0.4, 0.0001, "level 1")
	TestFactory.set_level(session, &"forging", 50)
	assert_almost_eq(session.modifiers.total(&"upgrade_success_pct"), 20.0, 0.0001, "level 50")
	assert_almost_eq(Upgrade.chance_pct(5, session.modifiers.total(Upgrade.STAT), data), 66.0, 0.0001)
	TestFactory.set_level(session, &"forging", 99)
	assert_almost_eq(session.modifiers.total(&"upgrade_success_pct"), 39.6, 0.0001, "level 99")
	assert_true(session.modifiers.has_source(&"skill_level:forging"))
	assert_false(session.modifiers.has_source(&"skill_level:forestry"), "skills without level_modifiers: no source")


## The source is rebuilt from the saved experience.
func test_forging_level_bonus_after_load() -> void:
	var data: GameData = preload("res://tests/systems/actions/blueprint_data.gd").data()
	var a: GameSession = autofree(TestFactory.session(3, data))
	TestFactory.set_level(a, &"forging", 50)
	var b: GameSession = autofree(TestFactory.session(4, data))
	assert_true(b.from_save(a.to_save(0)).ok)
	assert_almost_eq(b.modifiers.total(&"upgrade_success_pct"), 20.0, 0.0001)
