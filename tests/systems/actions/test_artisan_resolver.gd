extends GutTest
## ArtisanResolver: input check, consumption, preservation (F-08), double product (F-06), bank room, no rift shard.
##
## Fixture: craft_plank (test_craft, 2000 ms, 8 xp, mastery) = 2 test_log -> 1 test_plank. A bank-full case uses a
## copy of res://data/config under user:// with `bank.base_slots` 1 and one test_log at start.

const FIXTURE_ROOT: String = "res://tests/fixtures/data"
const CONFIG_ROOT: String = "res://data/config"
const PreRun := preload("res://tests/helpers/gut_pre_run.gd")
const SKILL: StringName = &"test_craft"
const PLANK: StringName = &"craft_plank"
const LOG_ITEM: StringName = &"test_log"
const PLANK_ITEM: StringName = &"test_plank"
const PRESERVATION: StringName = &"preservation_chance"
const DOUBLE: StringName = &"double_item_chance"
const CYCLES: int = 10000

var _tmp_config: String = PreRun.test_dir("test_artisan_resolver").path_join("config")
var _small_data: GameData = null
var _session: GameSession = null


func before_all() -> void:
	DirAccess.make_dir_recursive_absolute(_tmp_config)
	var balance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_ROOT.path_join("balance.json")))
	(balance["bank"] as Dictionary)["base_slots"] = 1
	(balance["start"] as Dictionary)["items"] = [{"item": String(LOG_ITEM), "qty": 1}, {"item": "seared_brookfin", "qty": 1}]  # the kit food, removed by clear_kit
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


func test_can_start_needs_every_input() -> void:
	assert_eq(ArtisanResolver.can_start(_session, _action()).reason, Reasons.MISSING_INPUTS)
	TestFactory.give(_session, LOG_ITEM, 1)
	assert_false(ArtisanResolver.can_start(_session, _action()).ok)
	TestFactory.give(_session, LOG_ITEM, 1)
	assert_true(ArtisanResolver.can_start(_session, _action()).ok)


func test_resolve_consumes_inputs_and_gives_products_xp_and_mastery() -> void:
	TestFactory.give(_session, LOG_ITEM, 3)
	watch_signals(_session.events)
	var outcome: ActionOutcome = ArtisanResolver.resolve(_session, _action())
	assert_true(outcome.ok)
	assert_eq(outcome.consumed, {LOG_ITEM: 2} as Dictionary[StringName, int])
	assert_eq(outcome.outputs, {PLANK_ITEM: 1} as Dictionary[StringName, int])
	assert_false(outcome.shard)
	assert_eq(outcome.xp, 8)
	assert_eq(outcome.mastery_xp, 2)
	assert_eq(_session.bank.get_count(LOG_ITEM), 1)
	assert_eq(_session.bank.get_count(PLANK_ITEM), 1)
	assert_eq(_session.skills.get_xp(SKILL), 8)
	assert_signal_emitted_with_parameters(_session.events, "xp_gained", [SKILL, 8])


func test_resolve_without_inputs_fails_and_changes_nothing() -> void:
	TestFactory.give(_session, LOG_ITEM, 1)
	watch_signals(_session.events)
	var outcome: ActionOutcome = ArtisanResolver.resolve(_session, _action())
	assert_false(outcome.ok)
	assert_eq(outcome.reason, Reasons.MISSING_INPUTS)
	assert_eq(_session.bank.get_count(LOG_ITEM), 1)
	assert_eq(_session.skills.get_xp(SKILL), 0)
	assert_signal_not_emitted(_session.events, "xp_gained")


## Stat effect (stats.json), F-08: chance 0 always consumes.
func test_preservation_0_always_consumes() -> void:
	TestFactory.give(_session, LOG_ITEM, 200)
	for i: int in 100:
		assert_true(ArtisanResolver.resolve(_session, _action()).ok)
	assert_eq(_session.bank.get_count(LOG_ITEM), 0)


## F-08: a total of 95 is limited to 80; over 10,000 cycles (fixed seed) about 80% do not consume (+-2%).
func test_preservation_cap() -> void:
	_set_mods([Modifier.make(PRESERVATION, 95.0)])
	TestFactory.give(_session, LOG_ITEM, 2)
	var preserved: int = 0
	for i: int in CYCLES:
		var outcome: ActionOutcome = ArtisanResolver.resolve(_session, _action())
		assert_true(outcome.ok)
		if outcome.consumed.is_empty():
			preserved += 1
		else:
			TestFactory.give(_session, LOG_ITEM, 2)
	assert_almost_eq(float(preserved) / CYCLES, 0.8, 0.02)


## F-08 scope: a chance of another skill does not apply, so every cycle consumes.
func test_preservation_applies_to_the_action_context() -> void:
	_set_mods([Modifier.make(PRESERVATION, 100.0, &"skill", &"forestry")])
	TestFactory.give(_session, LOG_ITEM, 200)
	for i: int in 100:
		ArtisanResolver.resolve(_session, _action())
	assert_eq(_session.bank.get_count(LOG_ITEM), 0)


## The same seed replayed outside the resolver (preservation roll first, then the double roll, which consumes
## nothing at chance 0) predicts which cycles keep the inputs; they still give products and xp.
func test_preserved_cycle_keeps_the_inputs() -> void:
	_set_mods([Modifier.make(PRESERVATION, 80.0)])
	var replica: RngService = RngService.new(1234)
	var kept: int = 0
	for i: int in 200:
		var preserve: bool = replica.roll_pct(80.0)
		TestFactory.give(_session, LOG_ITEM, 2)
		var before: int = _session.bank.get_count(LOG_ITEM)
		var outcome: ActionOutcome = ArtisanResolver.resolve(_session, _action())
		assert_true(outcome.ok)
		assert_eq(outcome.consumed.is_empty(), preserve)
		assert_eq(_session.bank.get_count(LOG_ITEM), before if preserve else before - 2)
		assert_eq(outcome.xp, 8)
		kept += 1 if preserve else 0
	assert_gt(kept, 0)
	assert_lt(kept, 200)


## F-06: chance 100 doubles the product; chance 0 never does.
func test_double_item_chance() -> void:
	TestFactory.give(_session, LOG_ITEM, 20)
	for i: int in 5:
		assert_eq(ArtisanResolver.resolve(_session, _action()).outputs[PLANK_ITEM], 1)
	_set_mods([Modifier.make(DOUBLE, 100.0)])
	for i: int in 5:
		assert_eq(ArtisanResolver.resolve(_session, _action()).outputs[PLANK_ITEM], 2)
	assert_eq(_session.bank.get_count(PLANK_ITEM), 15)


## 01_GDD §5: no rift shard even with the stat at 100.
func test_no_rift_shard() -> void:
	_set_mods([Modifier.make(&"rift_shard_chance", 100.0)])
	TestFactory.give(_session, LOG_ITEM, 20)
	for i: int in 10:
		var outcome: ActionOutcome = ArtisanResolver.resolve(_session, _action())
		assert_false(outcome.shard)
		assert_false(outcome.outputs.has(&"rift_shard"))
	assert_eq(_session.bank.get_count(&"rift_shard"), 0)


## No room for the product (the logs remain): nothing changes, no xp, `bank_full`.
func test_bank_full_consumes_nothing() -> void:
	var session: GameSession = autofree(TestFactory.session(1234, _small_data))
	TestFactory.give(session, LOG_ITEM, 2)
	watch_signals(session.events)
	var outcome: ActionOutcome = ArtisanResolver.resolve(session, _action())
	assert_false(outcome.ok)
	assert_eq(outcome.reason, Reasons.BANK_FULL)
	assert_eq(session.bank.get_count(LOG_ITEM), 3)
	assert_eq(session.bank.get_count(PLANK_ITEM), 0)
	assert_eq(session.skills.get_xp(SKILL), 0)
	assert_eq(session.mastery.get_mastery_xp(PLANK), 0)
	assert_signal_not_emitted(session.events, "bank_changed")


## Consuming the last logs frees their slot, which the product takes.
func test_freed_slot_takes_the_product() -> void:
	var session: GameSession = autofree(TestFactory.session(1234, _small_data))
	TestFactory.give(session, LOG_ITEM, 1)
	var outcome: ActionOutcome = ArtisanResolver.resolve(session, _action())
	assert_true(outcome.ok)
	assert_eq(session.bank.get_count(LOG_ITEM), 0)
	assert_eq(session.bank.get_count(PLANK_ITEM), 1)


func _action() -> ActionDef:
	return _session.data.action(PLANK)


func _set_mods(mods: Array[Modifier]) -> void:
	_session.modifiers.set_source(&"test", mods)


func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
