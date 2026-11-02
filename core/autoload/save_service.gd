class_name SaveStore
extends Node
## Slot file store (autoload `SaveService`): reads and writes slot dictionaries, versions and migrations.
## It does not know GameSession and it never writes on its own: only write_slot and delete_slot touch the disk.
##
## Writes are atomic: the text goes to `slot_<n>.json.tmp`, the current file becomes `slot_<n>.json.bak`, then the
## temporary file is renamed. Reads fall back on the `.bak` when the main file is missing or not a valid save.
## A valid file with a newer format_version is never replaced by its `.bak` (that would lose newer progress).
##
## The number of slots comes from `slots.count` in balance.json and is passed in by the caller with configure():
## until then there are no valid slots.

const TMP_SUFFIX: String = ".tmp"
const BAK_SUFFIX: String = ".bak"
const LOG_CATEGORY: String = "save"
const STATE_EMPTY: StringName = &"empty"
const STATE_OK: StringName = &"ok"
const STATE_CORRUPTED: StringName = &"corrupted"
const STATE_UNSUPPORTED: StringName = &"unsupported"
const KEY_FORMAT_VERSION: String = "format_version"
const KEY_PLAYER_NAME: String = "player_name"
const KEY_SAVED_AT: String = "saved_at_unix_ms"
const KEY_PLAY_TIME: String = "play_time_ms"
const KEY_TOTAL_LEVEL: String = "total_level"

var base_dir: String = "user://saves"
var last_error: StringName = &""

var _slot_count: int = 0
# Outcome of the last _load(): &"" or one of Reasons.CORRUPTED, VERSION_UNSUPPORTED, IO_ERROR.
var _load_error: StringName = &""


func configure(slot_count: int) -> void:
	assert(slot_count >= 0, "slot_count must not be negative")
	_slot_count = maxi(slot_count, 0)


func slot_path(slot: int) -> String:
	return base_dir + "/slot_%d.json" % slot


func slot_exists(slot: int) -> bool:
	if not _is_valid_slot(slot):
		return false
	var path: String = slot_path(slot)
	return FileAccess.file_exists(path) or FileAccess.file_exists(path + BAK_SUFFIX)


## Already migrated to SaveMigrator.CURRENT_VERSION; {} on failure with last_error set.
func read_slot(slot: int) -> Dictionary:
	if not _is_valid_slot(slot):
		Log.warn(LOG_CATEGORY, "read_slot: slot %d out of range 1-%d" % [slot, _slot_count])
		last_error = Reasons.IO_ERROR
		return {}
	var d: Dictionary = _load(slot)
	last_error = _load_error
	return d


func write_slot(slot: int, payload: Dictionary) -> CommandResult:
	if not _is_valid_slot(slot):
		Log.warn(LOG_CATEGORY, "write_slot: slot %d out of range 1-%d" % [slot, _slot_count])
		return _fail(Reasons.IO_ERROR)
	var dir_error: Error = DirAccess.make_dir_recursive_absolute(base_dir)
	if dir_error != OK:
		Log.warn(LOG_CATEGORY, "cannot create %s (error %d)" % [base_dir, dir_error])
		return _fail(Reasons.IO_ERROR)
	var path: String = slot_path(slot)
	var tmp_path: String = path + TMP_SUFFIX
	if not _write_text(tmp_path, SaveCodec.encode(payload)):
		_remove_if_exists(tmp_path)
		return _fail(Reasons.IO_ERROR)
	if not _replace_with(path, tmp_path):
		return _fail(Reasons.IO_ERROR)
	last_error = &""
	return CommandResult.success()


func delete_slot(slot: int) -> CommandResult:
	if not _is_valid_slot(slot):
		Log.warn(LOG_CATEGORY, "delete_slot: slot %d out of range 1-%d" % [slot, _slot_count])
		return _fail(Reasons.IO_ERROR)
	var path: String = slot_path(slot)
	for file_path: String in [path, path + BAK_SUFFIX, path + TMP_SUFFIX]:
		if not _remove_if_exists(file_path):
			return _fail(Reasons.IO_ERROR)
	last_error = &""
	return CommandResult.success()


func read_slot_info(slot: int) -> SlotInfo:
	var info: SlotInfo = SlotInfo.new()
	info.slot = slot
	if not slot_exists(slot):
		info.state = STATE_EMPTY
		return info
	var d: Dictionary = _load(slot)
	match _load_error:
		&"":
			info.state = STATE_OK
			_fill_header(info, d)
		Reasons.VERSION_UNSUPPORTED:
			info.state = STATE_UNSUPPORTED
		_:
			info.state = STATE_CORRUPTED
	return info


func list_slots() -> Array[SlotInfo]:
	var infos: Array[SlotInfo] = []
	for slot: int in range(1, _slot_count + 1):
		infos.append(read_slot_info(slot))
	return infos


func _is_valid_slot(slot: int) -> bool:
	return slot >= 1 and slot <= _slot_count


func _fail(reason: StringName) -> CommandResult:
	last_error = reason
	return CommandResult.fail(reason)


# Reads the main file, or the .bak if the main one is missing or invalid, then checks the version and migrates.
func _load(slot: int) -> Dictionary:
	var path: String = slot_path(slot)
	var bak_path: String = path + BAK_SUFFIX
	if not FileAccess.file_exists(path) and not FileAccess.file_exists(bak_path):
		_load_error = Reasons.IO_ERROR
		return {}
	var d: Dictionary = _read_save_file(path)
	if d.is_empty():
		d = _read_save_file(bak_path)
		if d.is_empty():
			_load_error = Reasons.CORRUPTED
			return {}
		Log.warn(LOG_CATEGORY, "%s missing or not valid, loaded %s" % [path, bak_path])
	if not SaveMigrator.can_load(d):
		_load_error = Reasons.VERSION_UNSUPPORTED
		return {}
	var migrated: Dictionary = SaveMigrator.migrate(d)
	if migrated.is_empty():
		_load_error = Reasons.VERSION_UNSUPPORTED
		return {}
	_load_error = &""
	return migrated


# {} when the file is missing, unreadable, not JSON, not a dictionary or without a numeric format_version.
func _read_save_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		Log.warn(LOG_CATEGORY, "cannot open %s (error %d)" % [path, FileAccess.get_open_error()])
		return {}
	var text: String = file.get_as_text()
	file.close()
	var d: Dictionary = SaveCodec.decode(text)
	var version: Variant = d.get(KEY_FORMAT_VERSION)
	if not (version is int or version is float):
		Log.warn(LOG_CATEGORY, "%s is not a valid save file" % path)
		return {}
	return d


func _write_text(path: String, text: String) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		Log.warn(LOG_CATEGORY, "cannot open %s for writing (error %d)" % [path, FileAccess.get_open_error()])
		return false
	var stored: bool = file.store_string(text)
	var error: Error = file.get_error()
	file.close()
	if not stored or error != OK:
		Log.warn(LOG_CATEGORY, "cannot write %s (error %d)" % [path, error])
		return false
	return true


# Current file -> .bak, then tmp -> current. If the last rename fails the .bak still holds the previous save,
# and reads fall back on it.
func _replace_with(path: String, tmp_path: String) -> bool:
	var bak_path: String = path + BAK_SUFFIX
	if FileAccess.file_exists(path):
		if not _remove_if_exists(bak_path):
			return false
		if not _rename(path, bak_path):
			return false
	return _rename(tmp_path, path)


func _rename(from_path: String, to_path: String) -> bool:
	var error: Error = DirAccess.rename_absolute(from_path, to_path)
	if error != OK:
		Log.warn(LOG_CATEGORY, "cannot rename %s to %s (error %d)" % [from_path, to_path, error])
		return false
	return true


func _remove_if_exists(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return true
	var error: Error = DirAccess.remove_absolute(path)
	if error != OK:
		Log.warn(LOG_CATEGORY, "cannot remove %s (error %d)" % [path, error])
		return false
	return true


func _fill_header(info: SlotInfo, d: Dictionary) -> void:
	var player_name: Variant = d.get(KEY_PLAYER_NAME, "")
	info.player_name = player_name as String if player_name is String else ""
	info.saved_at_unix_ms = _header_int(d, KEY_SAVED_AT)
	info.play_time_ms = _header_int(d, KEY_PLAY_TIME)
	info.total_level = _header_int(d, KEY_TOTAL_LEVEL)


# JSON numbers arrive as float; a missing or non-numeric header field reads as 0.
func _header_int(d: Dictionary, key: String) -> int:
	var value: Variant = d.get(key, 0)
	if value is int or value is float:
		return int(value)
	return 0
