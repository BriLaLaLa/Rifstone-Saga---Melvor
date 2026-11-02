extends GutTest
## GatheringResolver: products, double roll (F-06), rift shard (F-07), bank full (nothing changes), xp and mastery.
##
## Fixture: gather_twig (test_gather, 3000 ms, 10 xp, mastery, 1 test_twig), gather_bundle (no mastery, 2 test_twig).
## A bank-full case uses a copy of res://data/config under user:// with `bank.base_slots` 1 and one test_log at start.

const FIXTURE_ROOT: String = "res://tests/fixtures/data"
const CONFIG_ROOT: String = "res://data/config"
const TMP_CONFIG: String = "user://test_gathering_resolver/config"
const SKILL: StringName = &"test_gather"
const TWIG: StringName = &"gather_twig"
const BUNDLE: StringName = &"gather_bundle"
const LOG_ACTION: StringName = &"gather_log"
const TWIG_ITEM: StringName = &"test_twig"
const LOG_ITEM: StringName = &"test_log"
const SHARD: StringName = &"rift_shard"
const DOUBLE: StringName = &"double_item_chance"
const SHARD_STAT: StringName = &"rift_shard_chance"
const XP_PCT: StringName = &"skill_xp_pct"

var _small_data: GameData = null
var _session: GameSession = null


func before_all() -> void:
	DirAccess.make_dir_recursive_absolute(TMP_CONFIG)
	var balance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_ROOT.path_join("balance.json")))
	(balance["bank"] as Dictionary)["base_slots"] = 1
	(balance["start"] as Dictionary)["items"] = [{"item": String(LOG_ITEM), "qty": 1}]
	_write(TMP_CONFIG.path_join("balance.json"), JSON.stringify(balance))
	_write(TMP_CONFIG.path_join("stats.json"), FileAccess.get_file_as_string(CONFIG_ROOT.path_join("stats.json")))
	_small_data = GameData.load_from_dirs(FIXTURE_ROOT, TMP_CONFIG)


func after_all() -> void:
	for file: String in ["balance.json", "stats.json"]:
		DirAccess.remove_absolute(TMP_CONFIG.path_join(file))
	DirAccess.remove_absolute(TMP_CONFIG)
	DirAccess.remove_absolute(TMP_CONFIG.get_base_dir())


func before_each() -> void:
	_session = autofree(TestFactory.session())


func test_resolve_adds_products_xp_and_mastery() -> void:
	watch_signals(_session.events)
	var outcome: ActionOutcome = GatheringResolver.resolve(_session, _action(TWIG))
	assert_true(outcome.ok)
	assert_eq(outcome.reason, &"")
	assert_eq(outcome.outputs[TWIG_ITEM], 1)
	assert_eq(outcome.outputs.has(SHARD), outcome.shard)
	assert_eq(outcome.consumed, {} as Dictionary[StringName, int])
	assert_eq(outcome.xp, 10)
	assert_eq(outcome.mastery_xp, 3)
	assert_eq(_session.bank.get_count(TWIG_ITEM), 1)
	assert_eq(_session.skills.get_xp(SKILL), 10)
	assert_eq(_session.mastery.get_mastery_xp(TWIG), 3)
	assert_signal_emitted_with_parameters(_session.events, "bank_changed", [TWIG_ITEM, 1, 1])
	assert_signal_emitted_with_parameters(_session.events, "xp_gained", [SKILL, 10])


func test_action_without_mastery_gives_no_mastery() -> void:
	var outcome: ActionOutcome = GatheringResolver.resolve(_session, _action(BUNDLE))
	assert_true(outcome.ok)
	assert_eq(outcome.outputs[TWIG_ITEM], 2)
	assert_eq(outcome.mastery_xp, 0)
	assert_eq(_session.mastery.get_pool(SKILL), 0)


## F-02 in the action's context: an action-scoped skill_xp_pct +15 turns 10 xp into 11.
func test_xp_uses_the_action_context() -> void:
	_set_mods([Modifier.make(XP_PCT, 15.0, &"action", TWIG)])
	assert_eq(GatheringResolver.resolve(_session, _action(TWIG)).xp, 11)
	assert_eq(GatheringResolver.resolve(_session, _action(BUNDLE)).xp, 10)


## Stat effect (stats.json), F-06: chance 100 always doubles every product (1 -> 2, 2 -> 4).
func test_double_item_chance_100() -> void:
	_set_mods([Modifier.make(DOUBLE, 100.0)])
	for i: int in 20:
		assert_eq(GatheringResolver.resolve(_session, _action(TWIG)).outputs[TWIG_ITEM], 2)
	assert_eq(GatheringResolver.resolve(_session, _action(BUNDLE)).outputs[TWIG_ITEM], 4)


## F-06: chance 0 never doubles (gather_bundle has no mastery, so no F-11 bonus grows meanwhile).
func test_double_item_chance_0_never_doubles() -> void:
	for i: int in 200:
		assert_eq(GatheringResolver.resolve(_session, _action(BUNDLE)).outputs[TWIG_ITEM], 2)


## F-06 scope: an action-scoped chance applies only to that action.
func test_double_item_chance_is_per_action() -> void:
	_set_mods([Modifier.make(DOUBLE, 100.0, &"action", BUNDLE)])
	assert_eq(GatheringResolver.resolve(_session, _action(TWIG)).outputs[TWIG_ITEM], 1)
	assert_eq(GatheringResolver.resolve(_session, _action(BUNDLE)).outputs[TWIG_ITEM], 4)


## Stat effect (stats.json), F-07: 0.5 base + 0.25 stat = 0.75%. The same seed replayed outside the resolver
## (one roll per cycle: the double chance is 0 and consumes nothing) predicts every shard; some rolls fall in
## [0.5, 0.75), so the stat really changes the result.
func test_rift_shard_chance() -> void:
	_set_mods([Modifier.make(SHARD_STAT, 0.25)])
	var replica: RngService = RngService.new(1234)
	var decisive: int = 0
	var shards: int = 0
	for i: int in 3000:
		var roll: float = replica.randf() * 100.0
		if roll >= 0.5 and roll < 0.75:
			decisive += 1
		var outcome: ActionOutcome = GatheringResolver.resolve(_session, _action(BUNDLE))
		assert_eq(outcome.shard, roll < 0.75)
		if outcome.shard:
			shards += 1
			assert_eq(outcome.outputs[SHARD], 1)
	assert_gt(decisive, 0)
	assert_eq(_session.bank.get_count(SHARD), shards)


## F-07: chance 100 (0.5 + 100, limited to 100) always gives one rift shard.
func test_rift_shard_chance_100_always_drops() -> void:
	_set_mods([Modifier.make(SHARD_STAT, 100.0)])
	for i: int in 10:
		var outcome: ActionOutcome = GatheringResolver.resolve(_session, _action(TWIG))
		assert_true(outcome.shard)
		assert_eq(outcome.outputs[SHARD], 1)
	assert_eq(_session.bank.get_count(SHARD), 10)


## 01_GDD §4: a new product without a free slot -> the cycle does not count and nothing changes.
func test_bank_full_changes_nothing() -> void:
	var session: GameSession = _small()
	watch_signals(session.events)
	var outcome: ActionOutcome = GatheringResolver.resolve(session, _action(TWIG, session))
	assert_false(outcome.ok)
	assert_eq(outcome.reason, Reasons.BANK_FULL)
	assert_eq(outcome.xp, 0)
	assert_eq(outcome.mastery_xp, 0)
	assert_eq(session.bank.get_count(TWIG_ITEM), 0)
	assert_eq(session.skills.get_xp(SKILL), 0)
	assert_eq(session.mastery.get_mastery_xp(TWIG), 0)
	assert_signal_not_emitted(session.events, "bank_changed")
	assert_signal_not_emitted(session.events, "bank_rejected")
	assert_signal_not_emitted(session.events, "xp_gained")


## A product already in a full bank always enters.
func test_full_bank_accepts_products_already_present() -> void:
	var session: GameSession = _small()
	TestFactory.set_level(session, SKILL, 5)
	var outcome: ActionOutcome = GatheringResolver.resolve(session, _action(LOG_ACTION, session))
	assert_true(outcome.ok)
	assert_eq(session.bank.get_count(LOG_ITEM), 2)


## Two new items (product and shard) need two free slots: with one free slot the cycle does not count.
func test_new_items_need_one_slot_each() -> void:
	var session: GameSession = _small()
	session.modifiers.set_source(&"test", [Modifier.make(SHARD_STAT, 100.0), Modifier.make(&"bank_slots", 1.0)]
			as Array[Modifier])
	assert_eq(session.bank.capacity() - session.bank.used(), 1)
	var outcome: ActionOutcome = GatheringResolver.resolve(session, _action(TWIG, session))
	assert_false(outcome.ok)
	assert_eq(outcome.reason, Reasons.BANK_FULL)
	assert_eq(session.bank.used(), 1)
	session.modifiers.set_source(&"test", [Modifier.make(SHARD_STAT, 100.0), Modifier.make(&"bank_slots", 2.0)]
			as Array[Modifier])
	assert_true(GatheringResolver.resolve(session, _action(TWIG, session)).ok)
	assert_eq(session.bank.used(), 3)


func _action(action_id: StringName, session: GameSession = null) -> ActionDef:
	var s: GameSession = session if session != null else _session
	return s.data.action(action_id)


func _set_mods(mods: Array) -> void:
	var typed: Array[Modifier] = []
	typed.assign(mods)
	_session.modifiers.set_source(&"test", typed)


func _small() -> GameSession:
	assert_true(_small_data.is_valid(), "\n".join(_small_data.errors))
	return autofree(TestFactory.session(1234, _small_data))


func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
