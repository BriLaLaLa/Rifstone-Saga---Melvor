extends GutTest
## EngraverResolver (F-104, docs/05_INTERFACES.md §5.22): chance by Engraver level, partial loss, xp of the failure,
## one roll per cycle, room checked before the roll, dispatch of `kind: crystallize` by ActionRunner, and the ordinary
## fuse recipe (F-105, ArtisanResolver).
##
## Fixture: crystallize_test (riftbinding, 3000 ms, 160 xp, mastery) = 50 rift_dust -> 1 test_crystal; fuse_test_stone
## = 3 test_chip -> 1 test_stone. Data copies under user:// change the chance range (always / never) and the room.

const FIXTURE_ROOT: String = "res://tests/fixtures/data"
const CONFIG_ROOT: String = "res://data/config"
const PreRun := preload("res://tests/helpers/gut_pre_run.gd")
const SKILL: StringName = &"riftbinding"
const CRYSTALLIZE: StringName = &"crystallize_test"
const FUSE: StringName = &"fuse_test_stone"
const DUST: StringName = &"rift_dust"
const CRYSTAL: StringName = &"test_crystal"
const CHIP: StringName = &"test_chip"
const STONE: StringName = &"test_stone"
const SEED: int = 1234
const TRIALS: int = 4000

var _tmp_root: String = PreRun.test_dir("test_engraver_resolver")
var _cache: Dictionary[String, GameData] = {}


func after_all() -> void:
	for dir: String in DirAccess.get_directories_at(_tmp_root):
		DirAccess.remove_absolute(_tmp_root.path_join(dir))
	DirAccess.remove_absolute(_tmp_root)


# GameData of the fixtures with the Engraver chance range and the Deposit size given (balance copy under user://).
func _data(low: float, high: float, base_slots: int = 60) -> GameData:
	var key: String = "%s/%s/%d" % [low, high, base_slots]
	if _cache.has(key):
		return _cache[key]
	var dir: String = _tmp_root.path_join("cfg_%d" % _cache.size())
	DirAccess.make_dir_recursive_absolute(dir)
	var balance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_ROOT.path_join("balance.json")))
	(balance["engraver"] as Dictionary)["crystal_chance_min_pct"] = low
	(balance["engraver"] as Dictionary)["crystal_chance_max_pct"] = high
	(balance["deposit"] as Dictionary)["base_slots"] = base_slots
	_write(dir.path_join("balance.json"), JSON.stringify(balance))
	_write(dir.path_join("stats.json"), FileAccess.get_file_as_string(CONFIG_ROOT.path_join("stats.json")))
	var data: GameData = GameData.load_from_dirs(FIXTURE_ROOT, dir)
	assert(data.is_valid(), "engraver test data is not valid: %s" % ["\n".join(data.errors)])
	DirAccess.remove_absolute(dir.path_join("balance.json"))
	DirAccess.remove_absolute(dir.path_join("stats.json"))
	_cache[key] = data
	return data


func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _session(data: GameData) -> GameSession:
	return autofree(TestFactory.session(SEED, data))


func _action(session: GameSession) -> ActionDef:
	return session.data.action(CRYSTALLIZE)


# --- F-104 examples ---------------------------------------------------------------------------------------------------

func test_chance_examples() -> void:
	var data: GameData = TestFactory.fixture_data()
	assert_eq(EngraverResolver.crystal_chance_pct(1, data), 40.0)
	assert_eq(EngraverResolver.crystal_chance_pct(50, data), 65.0)
	assert_eq(EngraverResolver.crystal_chance_pct(99, data), 90.0)
	assert_almost_eq(EngraverResolver.crystal_chance_pct(25, data), 52.2449, 0.0001)


func test_fail_loss_examples() -> void:
	var data: GameData = TestFactory.fixture_data()
	assert_eq(EngraverResolver.fail_loss(10, data), 5)
	assert_eq(EngraverResolver.fail_loss(25, data), 12)
	assert_eq(EngraverResolver.fail_loss(50, data), 25)


func test_can_start_needs_the_dust() -> void:
	var session: GameSession = _session(_data(40.0, 90.0))
	assert_eq(EngraverResolver.can_start(session, _action(session)).reason, Reasons.MISSING_INPUTS)
	TestFactory.give(session, DUST, 49)
	assert_false(EngraverResolver.can_start(session, _action(session)).ok)
	TestFactory.give(session, DUST, 1)
	assert_true(EngraverResolver.can_start(session, _action(session)).ok)


# --- cycles -----------------------------------------------------------------------------------------------------------

func test_success_consumes_everything_and_gives_the_crystal() -> void:
	var session: GameSession = _session(_data(100.0, 100.0))
	TestFactory.give(session, DUST, 60)
	var outcome: ActionOutcome = EngraverResolver.resolve(session, _action(session))
	assert_true(outcome.ok)
	assert_false(outcome.failed)
	assert_eq(outcome.consumed, {DUST: 50})
	assert_eq(outcome.outputs, {CRYSTAL: 1})
	assert_eq(outcome.xp, 160)
	assert_eq(session.bank.get_count(DUST), 10)
	assert_eq(session.bank.get_count(CRYSTAL), 1)


func test_failure_loses_half_gives_proportional_xp_and_no_crystal() -> void:
	var session: GameSession = _session(_data(0.0, 0.0))
	TestFactory.give(session, DUST, 60)
	var outcome: ActionOutcome = EngraverResolver.resolve(session, _action(session))
	assert_true(outcome.ok, "the cycle counts")
	assert_true(outcome.failed)
	assert_eq(outcome.consumed, {DUST: 25})
	assert_true(outcome.outputs.is_empty())
	assert_eq(outcome.xp, 80, "floor(160 x 25 / 50)")
	assert_eq(outcome.mastery_xp, 0)
	assert_eq(session.bank.get_count(DUST), 35)
	assert_eq(session.bank.get_count(CRYSTAL), 0)
	assert_eq(session.skills.get_xp(SKILL), 80)


func test_mastery_is_full_on_success_and_none_on_failure() -> void:
	var data: GameData = GameData.load_from_dirs(FIXTURE_ROOT, CONFIG_ROOT)
	data.skill(SKILL).has_mastery = true
	var session: GameSession = _session(data)
	TestFactory.give(session, DUST, 5000)
	var successes: int = 0
	var failures: int = 0
	for i: int in 40:
		var outcome: ActionOutcome = EngraverResolver.resolve(session, _action(session))
		if outcome.failed:
			failures += 1
			assert_eq(outcome.mastery_xp, 0)
		else:
			successes += 1
			assert_gt(outcome.mastery_xp, 0)
	assert_gt(successes, 0)
	assert_gt(failures, 0)


func test_one_roll_per_cycle_on_the_session_rng() -> void:
	var session: GameSession = _session(_data(40.0, 90.0))
	TestFactory.give(session, DUST, 500)
	var reference := RngService.new(SEED)
	for i: int in 5:
		EngraverResolver.resolve(session, _action(session))
		reference.roll_pct(40.0)
	assert_eq(session.rng.to_save(), reference.to_save())


# Successes over TRIALS cycles against the sum of the chances of F-104 at the level reached before each cycle (the level
# grows with the xp of the successes and of the failures).
func _rate_error(session: GameSession) -> float:
	var expected: float = 0.0
	var successes: int = 0
	for i: int in TRIALS:
		expected += EngraverResolver.crystal_chance_pct(session.skills.get_level(SKILL), session.data) / 100.0
		if not EngraverResolver.resolve(session, _action(session)).failed:
			successes += 1
	return absf(float(successes) - expected) / float(TRIALS)


func test_success_rate_follows_the_chance_of_the_level() -> void:
	var session: GameSession = _session(_data(40.0, 90.0))
	TestFactory.give(session, DUST, 400000)
	assert_lt(_rate_error(session), 0.02)


func test_at_level_99_the_rate_is_the_maximum() -> void:
	var session: GameSession = _session(_data(40.0, 90.0))
	TestFactory.set_level(session, SKILL, 99)
	TestFactory.give(session, DUST, 400000)
	var successes: int = 0
	for i: int in TRIALS:
		if not EngraverResolver.resolve(session, _action(session)).failed:
			successes += 1
	assert_almost_eq(float(successes) / float(TRIALS), 0.90, 0.03)


func test_not_enough_dust_fails_without_rolling() -> void:
	var session: GameSession = _session(_data(100.0, 100.0))
	TestFactory.give(session, DUST, 49)
	var before: Dictionary = session.rng.to_save()
	var outcome: ActionOutcome = EngraverResolver.resolve(session, _action(session))
	assert_false(outcome.ok)
	assert_eq(outcome.reason, Reasons.MISSING_INPUTS)
	assert_eq(session.rng.to_save(), before)


func test_no_room_for_the_crystal_stops_before_the_roll() -> void:
	var session: GameSession = _session(_data(100.0, 100.0, 1))
	TestFactory.give(session, DUST, 80)  # the only box
	var before: Dictionary = session.rng.to_save()
	var outcome: ActionOutcome = EngraverResolver.resolve(session, _action(session))
	assert_false(outcome.ok)
	assert_eq(outcome.reason, Reasons.BANK_FULL)
	assert_eq(session.rng.to_save(), before, "no roll")
	assert_eq(session.bank.get_count(DUST), 80)


func test_the_box_freed_by_the_dust_counts_for_the_crystal() -> void:
	var session: GameSession = _session(_data(100.0, 100.0, 1))
	TestFactory.give(session, DUST, 50)
	var outcome: ActionOutcome = EngraverResolver.resolve(session, _action(session))
	assert_true(outcome.ok)
	assert_eq(session.bank.get_count(CRYSTAL), 1)
	assert_eq(session.bank.get_count(DUST), 0)


# --- ActionRunner dispatch ---------------------------------------------------------------------------------------------

func test_runner_failed_cycle_emits_empty_outputs_and_goes_on_while_the_dust_lasts() -> void:
	var session: GameSession = _session(_data(0.0, 0.0))
	TestFactory.give(session, DUST, 80)  # 80 -> 55 (fail, 25 lost) -> 30 (fail), then fewer than 50: missing_inputs
	watch_signals(session.events)
	assert_true(session.actions.start(SKILL, CRYSTALLIZE).ok)
	session.actions.advance(3000)
	assert_signal_emit_count(session.events, "action_completed", 1)
	assert_signal_emitted_with_parameters(session.events, "action_completed", [&"main", SKILL, CRYSTALLIZE, {}])
	assert_eq(session.bank.get_count(DUST), 55)
	assert_true(session.actions.is_running(), "55 dust left: the next cycle can start")
	for i: int in 3:
		session.actions.advance(3000)
	assert_eq(session.bank.get_count(DUST), 30)
	assert_signal_emit_count(session.events, "action_completed", 2)
	assert_false(session.actions.is_running())
	assert_eq(session.actions.stop_reasons_log().back(), Reasons.MISSING_INPUTS)


func test_runner_success_goes_to_the_bank() -> void:
	var session: GameSession = _session(_data(100.0, 100.0))
	TestFactory.give(session, DUST, 50)
	assert_true(session.actions.start(SKILL, CRYSTALLIZE).ok)
	session.actions.advance(6000)  # the second cycle finds no dust
	assert_eq(session.bank.get_count(CRYSTAL), 1)
	assert_eq(session.actions.stop_reasons_log().back(), Reasons.MISSING_INPUTS)


# --- F-105: an ordinary recipe -----------------------------------------------------------------------------------------

func test_fuse_is_an_ordinary_deterministic_recipe() -> void:
	var session: GameSession = _session(_data(40.0, 90.0))
	TestFactory.give(session, CHIP, 9)
	var action: ActionDef = session.data.action(FUSE)
	assert_eq(action.kind, &"craft")
	for i: int in 3:
		assert_true(ArtisanResolver.resolve(session, action).ok)
	assert_eq(session.bank.get_count(STONE), 3, "9 chips -> 3 cycles -> 3 stones")
	assert_eq(session.bank.get_count(CHIP), 0)
	TestFactory.give(session, CHIP, 2)
	assert_eq(ArtisanResolver.can_start(session, action).reason, Reasons.MISSING_INPUTS, "2 chips are not enough")
