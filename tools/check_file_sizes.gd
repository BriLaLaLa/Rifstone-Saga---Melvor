extends SceneTree
## Fails (exit code 1) if a `.gd` or `.tscn` file under core/, systems/, ui/ or tools/ is longer than MAX_LINES lines.
##
## Usage: godot --headless --path . -s tools/check_file_sizes.gd
## The counting and filtering logic lives in static functions so that tests/tools/test_checks.gd can call it on
## in-memory strings. Output goes through printerr/print_rich: the Log autoload is not guaranteed to exist here.

const MAX_LINES: int = 400
const SCAN_DIRS: PackedStringArray = ["res://core", "res://systems", "res://ui", "res://tools"]
const CHECKED_EXTENSIONS: PackedStringArray = ["gd", "tscn"]
# Third-party code is never scanned, even if a copy ends up under one of the scanned folders.
const EXCLUDED_DIR_NAMES: PackedStringArray = ["addons", ".godot"]


func _init() -> void:
	var files: PackedStringArray = PackedStringArray()
	for dir_path: String in SCAN_DIRS:
		files.append_array(collect_files(dir_path))
	var failures: PackedStringArray = PackedStringArray()
	for path: String in files:
		var text: String = FileAccess.get_file_as_string(path)
		if text.is_empty() and FileAccess.get_open_error() != OK:
			failures.append("%s: cannot read file (error %d)" % [path, FileAccess.get_open_error()])
			continue
		var message: String = check_text(path, text)
		if not message.is_empty():
			failures.append(message)
	if failures.is_empty():
		print_rich("check_file_sizes: OK (%d files, max %d lines)" % [files.size(), MAX_LINES])
		quit(0)
		return
	for failure: String in failures:
		printerr(failure)
	printerr("check_file_sizes: FAILED (%d files over %d lines)" % [failures.size(), MAX_LINES])
	quit(1)


## Number of lines in `text`, as an editor shows them: a trailing newline does not start a new line.
## CRLF and LF count the same. An empty text has 0 lines.
static func count_lines(text: String) -> int:
	if text.is_empty():
		return 0
	var lines: int = text.count("\n")
	if not text.ends_with("\n"):
		lines += 1
	return lines


## True if `text` is longer than `max_lines` lines.
static func is_over_limit(text: String, max_lines: int = MAX_LINES) -> bool:
	return count_lines(text) > max_lines


## Empty string if `text` is within the limit, otherwise the failure message for `path`.
static func check_text(path: String, text: String, max_lines: int = MAX_LINES) -> String:
	var lines: int = count_lines(text)
	if lines <= max_lines:
		return ""
	return "%s: %d lines (max %d)" % [path, lines, max_lines]


## True if `path` has a checked extension and is not inside an excluded folder (generated `.tres` are not checked).
static func is_checked_file(path: String) -> bool:
	if not CHECKED_EXTENSIONS.has(path.get_extension().to_lower()):
		return false
	for part: String in path.trim_prefix("res://").split("/"):
		if EXCLUDED_DIR_NAMES.has(part):
			return false
	return true


## All checked files under `dir_path`, recursively, sorted.
static func collect_files(dir_path: String) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return result
	dir.include_hidden = true
	for sub_dir: String in dir.get_directories():
		if EXCLUDED_DIR_NAMES.has(sub_dir):
			continue
		result.append_array(collect_files(dir_path.path_join(sub_dir)))
	for file_name: String in dir.get_files():
		var path: String = dir_path.path_join(file_name)
		if is_checked_file(path):
			result.append(path)
	result.sort()
	return result
