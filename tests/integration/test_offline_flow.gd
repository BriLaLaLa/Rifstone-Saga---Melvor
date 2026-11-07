extends GutTest
## M9-07 offline integration (docs/01_GDD.md §12, F-40, F-41): save -> load with saved_at in the past -> consistent
## summary; online/offline equivalence; the 12 h cap; silence under offline.min_ms; hints triggered while away stay
## pending. A private Game instance, the real data, SaveService in PreRun.save_dir() (never a real slot), fixed seeds.

const GameScript := preload("res://core/autoload/game.gd")
const PreRun := preload("res://tests/helpers/gut_pre_run.gd")
const NOW_MS: int = 1793600000000
const HOUR_MS: int = 3600000
const CAP_MS: int = 43200000
const MIN_MS: int = 60000
const TICK_MS: int = 100
const SLOT: int = 1
const CHAR_LEVEL: int = 60
const AREA: StringName = &"redrock_plains"
const SWORD: StringName = &"emberbronze_sword"

var _test_dir: String = PreRun.save_dir()
var _game: GameScript
var _saved_time_source: Callable


func before_each() -> void:
	_clear_dir(_test_dir)
	_saved_time_source = GameClock.time_source
	GameClock.time_source = func() -> int: return NOW_MS
	_game = GameScript.new()
	add_child_autofree(_game)


func after_each() -> void:
	_game.end_session(false)
	GameClock.time_source = _saved_time_source
	_clear_dir(_test_dir)


# New game in SLOT, `prepare` sets the scene, the session is saved and closed, the clock moves `away_ms` forward.
func _leave(prepare: Callable, away_ms: int) -> void:
	assert_true(_game.new_game(SLOT, "Tester").ok)
	prepare.call(_game.session)
	_game.end_session(true)
	GameClock.time_source = func() -> int: return NOW_MS + away_ms


func _angling(s: GameSession) -> void:
	assert_true(s.actions.start(&"angling", &"catch_brookfin").ok)


func _fighting(s: GameSession) -> void:
	assert_true(s.equipment.equip(TestFactory.give_piece(s, SWORD)).ok)
	TestFactory.set_character_level(s, CHAR_LEVEL)
	assert_true(s.combat.start(AREA).ok)


func _bank_total(s: GameSession) -> Dictionary[StringName, int]:
	var all: Dictionary[StringName, int] = {}
	for item: ItemDef in s.data.items():
		var n: int = s.bank.get_count(item.id)
		if n > 0:
			all[item.id] = n
	return all


# --- save -> load -> coherent summary --------------------------------------------------------------------------------

func test_summary_matches_the_session_after_a_three_hour_absence() -> void:
	_leave(_angling, 3 * HOUR_MS)
	var saved: Dictionary = SaveService.read_slot(SLOT)
	assert_eq(saved["saved_at_unix_ms"], NOW_MS, "saved_at is the moment of leaving")
	assert_true((await _game.continue_game(SLOT)).ok)
	var sum: OfflineSummary = _game.last_offline_summary
	var s: GameSession = _game.session
	assert_not_null(sum)
	assert_eq(sum.elapsed_ms, 3 * HOUR_MS)
	assert_false(sum.capped)
	assert_eq(sum.xp.get(&"angling", 0), s.skills.get_xp(&"angling"), "summary xp = what the session gained (it started at 0)")
	assert_eq(sum.levels[&"angling"], Vector2i(1, s.skills.get_level(&"angling")))
	var bank: Dictionary[StringName, int] = _bank_total(s)
	for item_id: StringName in sum.items:
		if sum.items[item_id] > 0:
			assert_eq(bank.get(item_id, 0), sum.items[item_id], "%s in the bank = summary" % item_id)
	assert_eq(sum.gold_delta, s.wallet.get_gold() - int(s.data.balance_value("start.gold")))
	assert_eq(_game.state, &"playing")
	assert_eq(SaveService.read_slot(SLOT)["saved_at_unix_ms"], NOW_MS + 3 * HOUR_MS, "saved right after the offline")


func test_combat_summary_matches_the_session_after_a_two_hour_absence() -> void:
	_leave(_fighting, 2 * HOUR_MS)
	assert_true((await _game.continue_game(SLOT)).ok)
	var sum: OfflineSummary = _game.last_offline_summary
	var s: GameSession = _game.session
	var kills: int = 0
	for n: int in sum.kills.values():
		kills += n
	assert_gt(kills, 100)
	assert_lt(sum.deaths, 2, "a death stops the fight: at most one")
	assert_eq(sum.xp.get(CharacterSystem.SAVE_KEY, 0), s.character.get_xp() - s.data.character_xp_table().xp_for_level(CHAR_LEVEL), "character xp gained = summary")
	assert_eq(sum.gold_delta, s.wallet.get_gold() - int(s.data.balance_value("start.gold")))
	assert_eq(s.combat.is_active(), sum.deaths == 0, "the fight goes on only if the hero did not die")
	assert_eq(sum.stop_reasons.has(Reasons.PLAYER_DIED), sum.deaths == 1, "the death is in the stop reasons")


func test_a_second_load_has_no_second_offline() -> void:
	_leave(_angling, 2 * HOUR_MS)
	await _game.continue_game(SLOT)
	_game.end_session(true)
	GameClock.time_source = func() -> int: return NOW_MS + 2 * HOUR_MS + 1000
	await _game.continue_game(SLOT)
	assert_null(_game.last_offline_summary, "one second away: nothing to show")


# --- online / offline equivalence --------------------------------------------------------------------------------

func _geared(seed_value: int) -> GameSession:
	var s: GameSession = autofree(TestFactory.session(seed_value, TestFactory.real_data()))
	_angling(s)
	return s


func test_online_ticks_and_offline_blocks_give_the_same_gathering_state() -> void:
	var online: GameSession = _geared(31)
	var away: GameSession = _geared(31)
	for i: int in 20 * 60000 / TICK_MS:
		online.advance(TICK_MS)
	await OfflineSimulator.new().run(away, 20 * 60000, false, false)
	online.play_time_ms = 0
	away.play_time_ms = 0
	assert_eq(SaveCodec.encode(away.to_save(NOW_MS)), SaveCodec.encode(online.to_save(NOW_MS)))


func test_online_ticks_and_offline_blocks_give_the_same_combat_state() -> void:
	var online: GameSession = autofree(TestFactory.session(32, TestFactory.real_data()))
	var away: GameSession = autofree(TestFactory.session(32, TestFactory.real_data()))
	_fighting(online)
	_fighting(away)
	for i: int in 10 * 60000 / TICK_MS:
		online.advance(TICK_MS)
	await OfflineSimulator.new().run(away, 10 * 60000, false, false)
	online.play_time_ms = 0
	away.play_time_ms = 0
	assert_eq(SaveCodec.encode(away.to_save(NOW_MS)), SaveCodec.encode(online.to_save(NOW_MS)))


# --- cap and minimum ---------------------------------------------------------------------------------------------

func test_thirty_hours_away_count_as_twelve() -> void:
	_leave(_angling, 30 * HOUR_MS)
	await _game.continue_game(SLOT)
	var sum: OfflineSummary = _game.last_offline_summary
	assert_eq(sum.elapsed_ms, CAP_MS)
	assert_true(sum.capped)
	var reference: GameSession = _geared(7)
	await OfflineSimulator.new().run(reference, CAP_MS, true, false)
	assert_gt(sum.xp.get(&"angling", 0), 0)
	assert_lt(sum.xp[&"angling"], 3 * reference.skills.get_xp(&"angling"), "far from 30 h worth of xp")


func test_exactly_twelve_hours_is_not_flagged_as_capped() -> void:
	_leave(_angling, CAP_MS)
	await _game.continue_game(SLOT)
	assert_eq(_game.last_offline_summary.elapsed_ms, CAP_MS)
	assert_false(_game.last_offline_summary.capped)


func test_the_minimum_is_the_boundary_of_the_screen() -> void:
	_leave(_angling, MIN_MS - 1)
	var completed: Array[int] = []
	var on_completed: Callable = func(_s: OfflineSummary) -> void: completed.append(1)
	EventBus.offline_completed.connect(on_completed)
	await _game.continue_game(SLOT)
	assert_null(_game.last_offline_summary, "59.999 s: silent")
	assert_gt(_game.session.skills.get_xp(&"angling"), 0, "but the time was played")
	_game.end_session(false)
	_leave_again(MIN_MS)
	await _game.continue_game(SLOT)
	EventBus.offline_completed.disconnect(on_completed)
	assert_not_null(_game.last_offline_summary, "60 s: the screen")
	assert_eq(completed.size(), 1, "offline_completed only for the second")


func _leave_again(away_ms: int) -> void:
	_clear_dir(_test_dir)
	GameClock.time_source = func() -> int: return NOW_MS
	_leave(_angling, away_ms)


# --- hints (pending) ---------------------------------------------------------------------------------------------

func test_hints_triggered_while_away_stay_pending_until_closed() -> void:
	_leave(_angling, 6 * HOUR_MS)
	var fired: Array[StringName] = []
	var on_hint: Callable = func(id: StringName) -> void: fired.append(id)
	EventBus.hint_triggered.connect(on_hint)
	await _game.continue_game(SLOT)
	EventBus.hint_triggered.disconnect(on_hint)
	var s: GameSession = _game.session
	assert_gte(s.skills.get_level(&"angling"), HintsSystem.LEVEL_TARGET, "six hours of angling reach level 10")
	assert_true(fired.has(&"first_level_ten"), "the hint fired during the offline")
	assert_true(s.hints.pending().has(&"first_level_ten"), "and is waiting for the card, not lost")
	assert_true(s.hints.is_seen(&"first_level_ten"))
	s.hints.mark_seen(&"first_level_ten")
	assert_false(s.hints.pending().has(&"first_level_ten"), "closing it clears the pending")
	var again: Array[StringName] = []
	EventBus.hint_triggered.connect(func(id: StringName) -> void: again.append(id), CONNECT_ONE_SHOT)
	s.advance(HOUR_MS)
	assert_false(again.has(&"first_level_ten"), "once per slot")


func _clear_dir(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for sub_dir: String in DirAccess.get_directories_at(path):
		_clear_dir(path.path_join(sub_dir))
		DirAccess.remove_absolute(path.path_join(sub_dir))
	for file_name: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file_name))
