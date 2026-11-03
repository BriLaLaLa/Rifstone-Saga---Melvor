extends GutTest
## Integration (Lesson "everything per slot"): slots A (1) and B (2) never influence each other.
##
## Uses a private instance of game.gd on the real data and the EventBus, never the Game autoload, like
## tests/core/autoload/test_game.gd. SaveService.base_dir is user://test_saves (gut_pre_run.gd), emptied before and
## after each test; GameClock.time_source is fixed and restored. Game time comes from `session.advance` or from
## GameClock._process with exact binary fractions of a second. Every test ends with end_session(false), clock paused.

const GameScript := preload("res://core/autoload/game.gd")
const TEST_DIR: String = "user://test_saves"
const NOW_MS: int = 1793600000000
const SLOT_A: int = 1
const SLOT_B: int = 2
const SKILL: StringName = &"forestry"
const ACTION: StringName = &"cut_redbirch"
const LOG_ITEM: StringName = &"redbirch_log"
# 10 cycles of cut_redbirch (3000 ms, F-03) plus 1200 ms of the 11th: 100 XP, 10 logs, a lane half way.
const A_PLAY_MS: int = 31200
const A_ELAPSED_MS: int = 1200
const A_XP: int = 100
const A_LOGS: int = 10
const A_EXTRA_GOLD: int = 123
const B_EXTRA_GOLD: int = 7
const FRAME_S: float = 0.5
const FRAME_MS: int = 500

var _game: GameScript
var _saved_time_source: Callable


func before_each() -> void:
	_clear_dir(TEST_DIR)
	_saved_time_source = GameClock.time_source
	GameClock.time_source = func() -> int: return NOW_MS
	_game = GameScript.new()
	add_child_autofree(_game)


func after_each() -> void:
	_game.end_session(false)
	GameClock.set_paused(true)
	GameClock.time_source = _saved_time_source
	_clear_dir(TEST_DIR)


func test_slots_live_in_the_test_folder() -> void:
	assert_true(SaveService.slot_path(SLOT_A).begins_with(TEST_DIR), "never a real slot")


func test_new_game_in_b_after_a_starts_from_scratch() -> void:
	_play_slot_a()
	var a_session: GameSession = _game.session
	_game.end_session(true)
	assert_true(_game.new_game(SLOT_B, "Beta").ok)
	var b: GameSession = _game.session
	assert_ne(b, a_session, "a new GameSession")
	assert_eq(b.player_name, "Beta")
	assert_eq(b.slot, SLOT_B)
	assert_eq(b.play_time_ms, 0)
	assert_eq(b.skills.get_xp(SKILL), 0)
	assert_eq(b.mastery.get_mastery_xp(ACTION), 0)
	assert_eq(b.mastery.get_pool(SKILL), 0)
	assert_eq(b.bank.get_count(LOG_ITEM), 0)
	assert_eq(b.bank.used(), (b.data.balance_value("start.items") as Array).size())
	assert_eq(b.wallet.get_gold(), int(b.data.balance_value("start.gold")))
	assert_false(b.actions.is_running(), "the action of A does not follow into B")


func test_playing_and_saving_b_does_not_touch_the_file_of_a() -> void:
	_play_slot_a()
	_game.end_session(true)
	var a_text: String = _slot_text(SLOT_A)
	var a_bak: bool = FileAccess.file_exists(SaveService.slot_path(SLOT_A) + ".bak")
	_game.new_game(SLOT_B, "Beta")
	_game.session.wallet.add_gold(B_EXTRA_GOLD)
	_game.session.actions.start(SKILL, ACTION)
	_reset_clock()
	_simulate(25000)
	_game.save_now()
	_game.save_now()
	_game.end_session(true)
	assert_eq(_slot_text(SLOT_A), a_text, "slot A byte for byte")
	assert_eq(FileAccess.file_exists(SaveService.slot_path(SLOT_A) + ".bak"), a_bak, "backup of A untouched")


func test_deleting_b_keeps_a_and_deleting_a_keeps_b() -> void:
	_play_slot_a()
	_game.end_session(true)
	_game.new_game(SLOT_B, "Beta")
	_game.save_now()
	_game.end_session(true)
	var a_text: String = _slot_text(SLOT_A)
	var b_text: String = _slot_text(SLOT_B)
	assert_true(_game.delete_slot(SLOT_B).ok)
	assert_false(SaveService.slot_exists(SLOT_B))
	assert_eq(_slot_text(SLOT_A), a_text)
	_game.new_game(SLOT_B, "Beta")
	_game.end_session(true)
	b_text = _slot_text(SLOT_B)
	assert_true(_game.delete_slot(SLOT_A).ok)
	assert_false(SaveService.slot_exists(SLOT_A))
	assert_false(FileAccess.file_exists(SaveService.slot_path(SLOT_A) + ".bak"))
	assert_eq(_slot_text(SLOT_B), b_text, "slot B byte for byte")
	assert_eq(SaveService.read_slot_info(SLOT_B).state, &"ok")


func test_continue_a_after_b_restores_only_a() -> void:
	_play_slot_a()
	var a_gold: int = _game.session.wallet.get_gold()
	_game.end_session(true)
	_game.new_game(SLOT_B, "Beta")
	_game.session.wallet.add_gold(B_EXTRA_GOLD)
	_game.session.advance(A_PLAY_MS * 2)
	_game.end_session(true)
	assert_true(_game.continue_game(SLOT_A).ok)
	var a: GameSession = _game.session
	assert_eq(a.player_name, "Alfa")
	assert_eq(a.slot, SLOT_A)
	assert_eq(a.wallet.get_gold(), a_gold, "gold of A, not of B")
	assert_eq(a.play_time_ms, A_PLAY_MS)
	assert_eq(a.skills.get_xp(SKILL), A_XP)
	assert_eq(a.bank.get_count(LOG_ITEM), A_LOGS)
	assert_true(a.actions.is_running(), "the action in progress belongs to A")
	assert_eq(int(a.actions.get_lane()["elapsed_ms"]), A_ELAPSED_MS)


func test_continue_b_after_a_has_no_action_in_progress() -> void:
	_play_slot_a()
	_game.end_session(true)
	_game.new_game(SLOT_B, "Beta")
	_game.end_session(true)
	_game.continue_game(SLOT_A)
	_game.end_session(true)
	assert_true(_game.continue_game(SLOT_B).ok)
	assert_false(_game.session.actions.is_running())
	assert_eq(_game.session.skills.get_xp(SKILL), 0)
	assert_eq(_game.session.wallet.get_gold(), int(_game.session.data.balance_value("start.gold")))


func test_slot_list_reports_each_slot_separately() -> void:
	_play_slot_a()
	_game.end_session(true)
	_game.new_game(SLOT_B, "Beta")
	_game.end_session(true)
	var infos: Array[SlotInfo] = _game.list_slots()
	assert_eq(infos[SLOT_A - 1].player_name, "Alfa")
	assert_eq(infos[SLOT_A - 1].play_time_ms, A_PLAY_MS)
	assert_eq(infos[SLOT_B - 1].player_name, "Beta")
	assert_eq(infos[SLOT_B - 1].play_time_ms, 0)
	for index: int in range(2, infos.size()):
		assert_eq(infos[index].state, &"empty", "slot %d untouched" % infos[index].slot)


func test_no_listener_of_a_survives_into_b() -> void:
	var before: int = _event_bus_connections()
	_play_slot_a()
	var during_a: int = _event_bus_connections()
	_game.end_session(true)
	assert_eq(_event_bus_connections(), before, "A's systems left the EventBus")
	_game.new_game(SLOT_B, "Beta")
	assert_eq(_event_bus_connections(), during_a, "B has the same listeners as A had, not more")
	_game.end_session(true)
	_game.continue_game(SLOT_A)
	assert_eq(_event_bus_connections(), during_a)


func test_store_level_write_and_delete_are_per_slot() -> void:
	var a: Dictionary = {"format_version": SaveMigrator.CURRENT_VERSION, "slot": SLOT_A, "player_name": "Alfa"}
	var b: Dictionary = {"format_version": SaveMigrator.CURRENT_VERSION, "slot": SLOT_B, "player_name": "Beta"}
	assert_true(SaveService.write_slot(SLOT_B, b).ok)
	assert_true(SaveService.write_slot(SLOT_B, b).ok, "second write: B gets a .bak")
	var b_text: String = _slot_text(SLOT_B)
	assert_true(SaveService.write_slot(SLOT_A, a).ok)
	assert_true(SaveService.write_slot(SLOT_A, a).ok)
	assert_eq(_slot_text(SLOT_B), b_text)
	assert_true(SaveService.delete_slot(SLOT_A).ok)
	assert_eq(_slot_text(SLOT_B), b_text)
	assert_true(FileAccess.file_exists(SaveService.slot_path(SLOT_B) + ".bak"), "backup of B kept")
	assert_eq(SaveService.read_slot(SLOT_B)["player_name"], "Beta")


# Slot A: new game "Alfa", A_EXTRA_GOLD added, cut_redbirch for A_PLAY_MS through GameClock, saved.
func _play_slot_a() -> void:
	assert_true(_game.new_game(SLOT_A, "Alfa").ok)
	_game.session.wallet.add_gold(A_EXTRA_GOLD)
	assert_true(_game.session.actions.start(SKILL, ACTION).ok)
	_reset_clock()
	_simulate(A_PLAY_MS - A_ELAPSED_MS)
	_game.session.advance(A_ELAPSED_MS)
	assert_eq(_game.session.play_time_ms, A_PLAY_MS)
	_game.save_now()


# Total connections on every EventBus signal (systems that listen, e.g. Bank on modifiers_changed).
func _event_bus_connections() -> int:
	var total: int = 0
	for info: Dictionary in EventBus.get_signal_list():
		total += EventBus.get_signal_connection_list(StringName(str(info["name"]))).size()
	return total


func _slot_text(slot: int) -> String:
	return FileAccess.get_file_as_string(SaveService.slot_path(slot))


func _reset_clock() -> void:
	var data: GameData = DataRegistry.data
	GameClock.configure(int(data.balance_value("tick_ms")), int(data.balance_value("max_catchup_ms")))


# Exactly `ms` of clock time (a multiple of FRAME_MS), in frames of FRAME_S.
func _simulate(ms: int) -> void:
	assert_eq(ms % FRAME_MS, 0, "whole frames only")
	@warning_ignore("integer_division")
	var frames: int = ms / FRAME_MS
	for i: int in frames:
		GameClock._process(FRAME_S)


func _clear_dir(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for sub_dir: String in DirAccess.get_directories_at(path):
		_clear_dir(path.path_join(sub_dir))
		DirAccess.remove_absolute(path.path_join(sub_dir))
	for file_name: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file_name))
