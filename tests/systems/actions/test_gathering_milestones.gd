extends GutTest
## GatheringResolver and the byproduct of mastery milestone 25 (F-103): mastery level gate, chance 100 / 0, order of the
## rolls (double F-06, shard F-07, byproduct), never doubled, helper profile (F-102).
##
## Fixture: gather_twig -> byproduct test_resin, gather_log -> test_sap (chance `mastery.milestones.byproduct_chance_pct`).

const FIXTURE_ROOT: String = "res://tests/fixtures/data"
const CONFIG_ROOT: String = "res://data/config"
const PreRun := preload("res://tests/helpers/gut_pre_run.gd")
const SKILL: StringName = &"test_gather"
const TWIG: StringName = &"gather_twig"
const LOG_ACTION: StringName = &"gather_log"
const BUNDLE: StringName = &"gather_bundle"
const RESIN: StringName = &"test_resin"
const SAP: StringName = &"test_sap"
const TWIG_ITEM: StringName = &"test_twig"
const DOUBLE: StringName = &"double_item_chance"
const SHARD_STAT: StringName = &"rift_shard_chance"

var _session: GameSession
var _table: XpTable


func before_each() -> void:
	_session = autofree(TestFactory.session())
	_table = _session.data.mastery_table()


func test_no_byproduct_below_level_25() -> void:
	var session: GameSession = _session_with_chance(100.0)
	_set_mastery(session, {TWIG: _table.xp_for_level(24)})
	var outcome: ActionOutcome = GatheringResolver.resolve(session, session.data.action(TWIG))
	assert_false(outcome.outputs.has(RESIN))
	assert_eq(session.bank.get_count(RESIN), 0)


func test_chance_100_always_gives_one_byproduct_of_the_action() -> void:
	var session: GameSession = _session_with_chance(100.0)
	_set_mastery(session, {TWIG: _table.xp_for_level(25), LOG_ACTION: _table.xp_for_level(25)})
	for i: int in 10:
		var outcome: ActionOutcome = GatheringResolver.resolve(session, session.data.action(TWIG))
		assert_eq(outcome.outputs[RESIN], 1)
		assert_false(outcome.outputs.has(SAP))
	assert_eq(session.bank.get_count(RESIN), 10)
	assert_eq(GatheringResolver.resolve(session, session.data.action(LOG_ACTION)).outputs[SAP], 1)


func test_chance_0_never_gives_a_byproduct() -> void:
	var session: GameSession = _session_with_chance(0.0)
	_set_mastery(session, {TWIG: _table.xp_for_level(25)})
	for i: int in 200:
		assert_false(GatheringResolver.resolve(session, session.data.action(TWIG)).outputs.has(RESIN))


func test_the_byproduct_is_never_doubled() -> void:
	var session: GameSession = _session_with_chance(100.0)
	_set_mastery(session, {TWIG: _table.xp_for_level(25)})
	var mods: Array[Modifier] = [Modifier.make(DOUBLE, 100.0)]
	session.modifiers.set_source(&"test", mods)
	var outcome: ActionOutcome = GatheringResolver.resolve(session, session.data.action(TWIG))
	assert_eq(outcome.outputs[TWIG_ITEM], 2)
	assert_eq(outcome.outputs[RESIN], 1)


## Order of the rolls on `session.rng`: double, shard, byproduct (the same seed replayed outside predicts each of them).
func test_roll_order_is_double_then_shard_then_byproduct() -> void:
	_set_mastery(_session, {TWIG: _table.xp_for_level(25)})
	var mods: Array[Modifier] = [Modifier.make(DOUBLE, 50.0), Modifier.make(SHARD_STAT, 49.5)]
	_session.modifiers.set_source(&"test", mods)
	var chance: float = float(_session.data.balance_value("mastery.milestones.byproduct_chance_pct"))
	var replica: RngService = RngService.new(1234)
	var seen_byproduct: int = 0
	for i: int in 400:
		var doubled: bool = replica.randf() * 100.0 < 50.0
		var shard: bool = replica.randf() * 100.0 < 50.0
		var byproduct: bool = replica.randf() * 100.0 < chance
		var outcome: ActionOutcome = GatheringResolver.resolve(_session, _session.data.action(TWIG))
		assert_eq(outcome.outputs[TWIG_ITEM], 2 if doubled else 1)
		assert_eq(outcome.shard, shard)
		assert_eq(outcome.outputs.has(RESIN), byproduct)
		seen_byproduct += 1 if byproduct else 0
	assert_gt(seen_byproduct, 0)


## F-102: the helper profile has the same milestones (the mastery level is the action's).
func test_the_helper_gets_the_same_byproduct() -> void:
	var session: GameSession = _session_with_chance(100.0)
	_set_mastery(session, {TWIG: _table.xp_for_level(25)})
	var outcome: ActionOutcome = GatheringResolver.resolve(session, session.data.action(TWIG), &"expert")
	assert_eq(outcome.outputs[RESIN], 1)


## An action without mastery has no mastery level, so no byproduct.
func test_action_without_mastery_has_no_byproduct() -> void:
	var session: GameSession = _session_with_chance(100.0)
	assert_false(GatheringResolver.resolve(session, session.data.action(BUNDLE)).outputs.has(RESIN))


# A session on the fixture content with `mastery.milestones.byproduct_chance_pct` = pct (config copy under user://).
func _session_with_chance(pct: float) -> GameSession:
	var dir: String = PreRun.test_dir("test_gathering_milestones_%d" % int(pct))
	DirAccess.make_dir_recursive_absolute(dir)
	var balance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_ROOT.path_join("balance.json")))
	((balance["mastery"] as Dictionary)["milestones"] as Dictionary)["byproduct_chance_pct"] = pct
	_write(dir.path_join("balance.json"), JSON.stringify(balance))
	_write(dir.path_join("stats.json"), FileAccess.get_file_as_string(CONFIG_ROOT.path_join("stats.json")))
	var data: GameData = GameData.load_from_dirs(FIXTURE_ROOT, dir)
	DirAccess.remove_absolute(dir.path_join("balance.json"))
	DirAccess.remove_absolute(dir.path_join("stats.json"))
	DirAccess.remove_absolute(dir)
	return autofree(TestFactory.session(1234, data))


func _set_mastery(session: GameSession, xp: Dictionary) -> void:
	session.mastery.from_save({String(SKILL): {"actions": xp}})
	session.rebuild_modifiers()


func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
