extends GutTest
## Integration, M12-08: the whole way through `Game` (slot on disk in PreRun.save_dir(), never a real one): a helper hired
## and bags in the slots are saved, the clock moves 3 hours, the helper has worked while away, the summary shows its
## products and the bags and the capacity are still there. A save of an older version is refused by the load.

const GameScript := preload("res://core/autoload/game.gd")
const PreRun := preload("res://tests/helpers/gut_pre_run.gd")
const NOW_MS: int = 1793600000000
const HOUR_MS: int = 3600000
const SLOT: int = 1

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


func _clear_dir(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for sub_dir: String in DirAccess.get_directories_at(path):
		_clear_dir(path.path_join(sub_dir))
		DirAccess.remove_absolute(path.path_join(sub_dir))
	for file_name: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file_name))


func test_helper_and_bags_survive_three_hours_away_and_the_summary_counts_the_helper() -> void:
	assert_true(_game.new_game(SLOT, "Tester").ok)
	var s: GameSession = _game.session
	TestFactory.give(s, &"contract_forestry_master", 1)
	TestFactory.give(s, &"bag_leather", 1)
	assert_true(s.helpers.hire(&"contract_forestry_master").ok)
	assert_true(s.helpers.set_action(&"forestry", &"cut_redbirch").ok)
	assert_true(s.bank.equip_bag(0, &"bag_leather").ok)
	var capacity: int = s.deposit.capacity()
	_game.end_session(true)
	GameClock.time_source = func() -> int: return NOW_MS + 3 * HOUR_MS
	assert_true((await _game.continue_game(SLOT)).ok)
	s = _game.session
	var sum: OfflineSummary = _game.last_offline_summary
	assert_not_null(sum)
	var cycles: int = 3 * HOUR_MS / 4500
	var xp: int = s.skills.get_xp(&"forestry")
	assert_between(xp, cycles * 2, cycles * 2 * 6 / 5, "Master: 4500 ms per cycle, 2 xp each; the mastery steps (F-122) shorten it a little")
	assert_eq(sum.xp.get(&"forestry", 0), xp)
	assert_gte(int(sum.items.get(&"redbirch_log", 0)), cycles, "the helper's logs are in the summary")
	assert_eq(s.bank.get_count(&"redbirch_log"), int(sum.items.get(&"redbirch_log", 0)))
	assert_eq(s.deposit.get_bag(0), &"bag_leather")
	assert_eq(s.deposit.capacity(), capacity)
	assert_eq(s.helpers.get_grade(&"forestry"), &"master")


func test_a_v3_slot_on_disk_is_not_loaded_and_not_touched() -> void:
	assert_true(_game.new_game(SLOT, "Tester").ok)
	_game.end_session(true)
	var data: Dictionary = SaveService.read_slot(SLOT)
	data["format_version"] = 3
	var path: String = _test_dir.path_join("slot_%d.json" % SLOT)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(SaveCodec.encode(data))
	file.close()
	var before: String = FileAccess.get_file_as_string(path)
	var result: CommandResult = await _game.continue_game(SLOT)
	assert_false(result.ok)
	assert_eq(result.reason, Reasons.VERSION_UNSUPPORTED)
	assert_eq(FileAccess.get_file_as_string(path), before, "the file is left as it was")
