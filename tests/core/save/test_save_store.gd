extends GutTest
## SaveStore: atomic write, .bak fallback, SlotInfo from the header, version checks, no writes unless asked.
##
## Each test uses its own SaveStore instance pointed at PreRun.save_dir() (emptied before each test), never the
## real saves folder. SLOT_COUNT stands for `slots.count` of balance.json, passed in as the caller will.

const PreRun := preload("res://tests/helpers/gut_pre_run.gd")
const SLOT_COUNT: int = 4
const TARGET_BYTES: int = 200 * 1024
const SLOW_WRITE_MS: float = 30.0

var _test_dir: String = PreRun.save_dir()
var _untouched_dir: String = PreRun.save_dir().path_join("untouched")
var _store: SaveStore


func before_each() -> void:
	_clear_dir(_test_dir)
	_store = autofree(SaveStore.new()) as SaveStore
	_store.base_dir = _test_dir
	_store.configure(SLOT_COUNT)


func after_all() -> void:
	_clear_dir(_test_dir)


func test_hook_points_autoload_at_test_saves() -> void:
	assert_eq(SaveService.base_dir, _test_dir)


func test_slot_path_format() -> void:
	assert_eq(_store.slot_path(2), _test_dir + "/slot_2.json")


func test_write_then_read_round_trip() -> void:
	var result: CommandResult = _store.write_slot(2, _payload("Davide", 31))
	assert_true(result.ok)
	assert_eq(_store.last_error, &"")
	var d: Dictionary = _store.read_slot(2)
	assert_eq(_store.last_error, &"")
	assert_eq(d["player_name"], "Davide")
	assert_eq(int(d["total_level"]), 31)
	assert_eq(int(d["modules"]["wallet"]["gold"]), 1250)
	assert_eq(d["format_version"], SaveMigrator.CURRENT_VERSION)


func test_first_write_leaves_no_tmp_and_no_bak() -> void:
	_store.write_slot(1, _payload("A", 1))
	var path: String = _store.slot_path(1)
	assert_true(FileAccess.file_exists(path))
	assert_false(FileAccess.file_exists(path + ".tmp"))
	assert_false(FileAccess.file_exists(path + ".bak"))


func test_second_write_keeps_previous_in_bak() -> void:
	_store.write_slot(1, _payload("First", 1))
	_store.write_slot(1, _payload("Second", 2))
	var path: String = _store.slot_path(1)
	assert_eq(SaveCodec.decode(_read_text(path))["player_name"], "Second")
	assert_eq(SaveCodec.decode(_read_text(path + ".bak"))["player_name"], "First")
	assert_false(FileAccess.file_exists(path + ".tmp"))


func test_corrupted_main_reads_bak() -> void:
	_store.write_slot(1, _payload("First", 1))
	_store.write_slot(1, _payload("Second", 2))
	_write_text(_store.slot_path(1), "{ not json")
	var d: Dictionary = _store.read_slot(1)
	assert_eq(_store.last_error, &"")
	assert_eq(d["player_name"], "First")
	assert_eq(_store.read_slot_info(1).state, &"ok")


func test_main_without_format_version_reads_bak() -> void:
	_store.write_slot(1, _payload("First", 1))
	_store.write_slot(1, _payload("Second", 2))
	_write_text(_store.slot_path(1), "{\"player_name\": \"x\"}")
	assert_eq(_store.read_slot(1)["player_name"], "First")


func test_missing_main_reads_bak() -> void:
	_store.write_slot(1, _payload("First", 1))
	_store.write_slot(1, _payload("Second", 2))
	DirAccess.remove_absolute(_store.slot_path(1))
	assert_true(_store.slot_exists(1), "a slot with only the .bak can still be loaded")
	assert_eq(_store.read_slot(1)["player_name"], "First")


func test_both_corrupted_reports_corrupted() -> void:
	_write_text(_store.slot_path(3), "garbage")
	_write_text(_store.slot_path(3) + ".bak", "[1, 2]")
	assert_eq(_store.read_slot(3), {})
	assert_eq(_store.last_error, Reasons.CORRUPTED)
	var info: SlotInfo = _store.read_slot_info(3)
	assert_eq(info.slot, 3)
	assert_eq(info.state, &"corrupted")
	assert_eq(info.player_name, "")


func test_corrupted_main_without_bak_reports_corrupted() -> void:
	_write_text(_store.slot_path(3), "")
	assert_eq(_store.read_slot(3), {})
	assert_eq(_store.last_error, Reasons.CORRUPTED)
	assert_eq(_store.read_slot_info(3).state, &"corrupted")


func test_newer_version_is_unsupported() -> void:
	var d: Dictionary = _payload("Future", 9)
	d["format_version"] = 5
	_write_text(_store.slot_path(2), SaveCodec.encode(d))
	assert_eq(_store.read_slot(2), {})
	assert_eq(_store.last_error, Reasons.VERSION_UNSUPPORTED)
	assert_eq(_store.read_slot_info(2).state, &"unsupported")


func test_newer_version_does_not_fall_back_on_bak() -> void:
	_store.write_slot(2, _payload("Old", 1))
	_store.write_slot(2, _payload("Old", 1))
	var d: Dictionary = _payload("Future", 9)
	d["format_version"] = 5
	_write_text(_store.slot_path(2), SaveCodec.encode(d))
	assert_eq(_store.read_slot(2), {}, "loading the older .bak would later overwrite newer progress")
	assert_eq(_store.last_error, Reasons.VERSION_UNSUPPORTED)


func test_version_without_migration_is_unsupported() -> void:
	var d: Dictionary = _payload("Ancient", 1)
	d["format_version"] = 0
	_write_text(_store.slot_path(2), SaveCodec.encode(d))
	assert_eq(_store.read_slot(2), {})
	assert_eq(_store.last_error, Reasons.VERSION_UNSUPPORTED)


func test_empty_slot() -> void:
	assert_false(_store.slot_exists(4))
	assert_eq(_store.read_slot(4), {})
	assert_eq(_store.last_error, Reasons.IO_ERROR)
	var info: SlotInfo = _store.read_slot_info(4)
	assert_eq(info.slot, 4)
	assert_eq(info.state, &"empty")


func test_slot_info_reads_header() -> void:
	_store.write_slot(2, _payload("Davide", 31))
	var info: SlotInfo = _store.read_slot_info(2)
	assert_eq(info.slot, 2)
	assert_eq(info.state, &"ok")
	assert_eq(info.player_name, "Davide")
	assert_eq(info.saved_at_unix_ms, 1793603600000)
	assert_eq(info.play_time_ms, 3600000)
	assert_eq(info.total_level, 31)


func test_list_slots_covers_every_configured_slot() -> void:
	_store.write_slot(2, _payload("Davide", 31))
	_write_text(_store.slot_path(3), "garbage")
	var infos: Array[SlotInfo] = _store.list_slots()
	assert_eq(infos.size(), SLOT_COUNT)
	var states: Array[StringName] = []
	for i: int in infos.size():
		assert_eq(infos[i].slot, i + 1)
		states.append(infos[i].state)
	assert_eq(states, [&"empty", &"ok", &"corrupted", &"empty"] as Array[StringName])


func test_list_slots_before_configure_is_empty() -> void:
	var store: SaveStore = autofree(SaveStore.new()) as SaveStore
	store.base_dir = _test_dir
	assert_eq(store.list_slots().size(), 0)


func test_slot_out_of_range_is_rejected() -> void:
	var result: CommandResult = _store.write_slot(SLOT_COUNT + 1, _payload("X", 1))
	assert_false(result.ok)
	assert_eq(result.reason, Reasons.IO_ERROR)
	assert_false(_store.write_slot(0, _payload("X", 1)).ok)
	assert_false(FileAccess.file_exists(_store.slot_path(SLOT_COUNT + 1)))
	assert_false(FileAccess.file_exists(_store.slot_path(0)))
	assert_eq(_store.read_slot(SLOT_COUNT + 1), {})


func test_failed_write_keeps_previous_file() -> void:
	_store.write_slot(1, _payload("Kept", 1))
	var tmp_path: String = _store.slot_path(1) + ".tmp"
	# A folder where the temporary file should go makes opening it for writing fail.
	DirAccess.make_dir_recursive_absolute(tmp_path)
	var result: CommandResult = _store.write_slot(1, _payload("Lost", 2))
	DirAccess.remove_absolute(tmp_path)
	assert_false(result.ok)
	assert_eq(result.reason, Reasons.IO_ERROR)
	assert_eq(_store.last_error, Reasons.IO_ERROR)
	assert_eq(_store.read_slot(1)["player_name"], "Kept")


func test_delete_removes_main_and_bak() -> void:
	_store.write_slot(1, _payload("A", 1))
	_store.write_slot(1, _payload("B", 1))
	assert_true(_store.delete_slot(1).ok)
	assert_false(_store.slot_exists(1))
	assert_false(FileAccess.file_exists(_store.slot_path(1) + ".bak"))
	assert_eq(_store.read_slot_info(1).state, &"empty")


func test_delete_empty_slot_succeeds() -> void:
	assert_true(_store.delete_slot(4).ok)


func test_no_write_unless_asked() -> void:
	var store: SaveStore = autofree(SaveStore.new()) as SaveStore
	store.base_dir = _untouched_dir
	store.configure(SLOT_COUNT)
	store.list_slots()
	store.read_slot(1)
	store.read_slot_info(2)
	store.slot_exists(3)
	store.slot_path(4)
	assert_false(DirAccess.dir_exists_absolute(_untouched_dir), "reads never create the folder")
	_store.list_slots()
	_store.read_slot(1)
	assert_eq(DirAccess.get_files_at(_test_dir).size(), 0, "reads never create files")


func test_write_200_kb_and_measure() -> void:
	var payload: Dictionary = _large_payload(TARGET_BYTES)
	var size: int = SaveCodec.encode(payload).to_utf8_buffer().size()
	assert_gte(size, TARGET_BYTES)
	_store.write_slot(1, payload) # first write: no .bak to rotate
	var start_us: int = Time.get_ticks_usec()
	var result: CommandResult = _store.write_slot(1, payload)
	var write_ms: float = (Time.get_ticks_usec() - start_us) / 1000.0
	start_us = Time.get_ticks_usec()
	var d: Dictionary = _store.read_slot(1)
	var read_ms: float = (Time.get_ticks_usec() - start_us) / 1000.0
	assert_true(result.ok)
	assert_eq((d["modules"]["bank"]["stacks"] as Array).size(), (payload["modules"]["bank"]["stacks"] as Array).size())
	Log.info("save", "write of %d bytes: %.2f ms (encode + .tmp + .bak + rename), read: %.2f ms" % [
		size, write_ms, read_ms])
	if write_ms > SLOW_WRITE_MS:
		Log.warn("save", "write above %.0f ms: consider the threaded save" % SLOW_WRITE_MS)


func _payload(player_name: String, total_level: int) -> Dictionary:
	return {
		"format_version": SaveMigrator.CURRENT_VERSION,
		"game_version": "0.1.0",
		"player_name": player_name,
		"created_at_unix_ms": 1793600000000,
		"saved_at_unix_ms": 1793603600000,
		"play_time_ms": 3600000,
		"total_level": total_level,
		"modules": {"wallet": {"gold": 1250}},
	}


func _large_payload(min_bytes: int) -> Dictionary:
	var d: Dictionary = _payload("Large", 100)
	var stacks: Array[Dictionary] = []
	var i: int = 0
	var modules: Dictionary = d["modules"]
	modules["bank"] = {"stacks": stacks}
	while i % 100 != 0 or SaveCodec.encode(d).length() < min_bytes:
		stacks.append({"item": "test_item_%05d" % i, "count": i * 37, "locked": i % 3 == 0})
		i += 1
	return d


func _read_text(path: String) -> String:
	return FileAccess.get_file_as_string(path)


func _write_text(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file, "test helper cannot write " + path)
	if file != null:
		file.store_string(text)
		file.close()


func _clear_dir(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for sub_dir: String in DirAccess.get_directories_at(path):
		_clear_dir(path.path_join(sub_dir))
		DirAccess.remove_absolute(path.path_join(sub_dir))
	for file_name: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file_name))


func test_v1_save_is_unsupported() -> void:
	var d: Dictionary = _payload("Old", 1)
	d["format_version"] = 1
	_write_text(_store.slot_path(2), SaveCodec.encode(d))
	assert_eq(_store.read_slot(2), {})
	assert_eq(_store.last_error, Reasons.VERSION_UNSUPPORTED)
	assert_eq(_store.read_slot_info(2).state, &"unsupported")
