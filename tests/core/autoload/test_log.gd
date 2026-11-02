extends GutTest
## Log: level filtering, line format and push_error on error().

const LogScript := preload("res://core/autoload/log.gd")


## Captures every printed line while registered with OS.add_logger.
class CaptureLogger extends Logger:
	var lines: PackedStringArray = []

	func _log_message(message: String, _error: bool) -> void:
		lines.append(message.strip_edges())


var _log: LogScript
var _capture: CaptureLogger


func before_each() -> void:
	_log = autofree(LogScript.new())
	_capture = CaptureLogger.new()
	OS.add_logger(_capture)


func after_each() -> void:
	OS.remove_logger(_capture)


func test_default_level_is_info() -> void:
	assert_eq(_log.level, LogScript.Level.INFO)


func test_info_level_drops_debug() -> void:
	_log_all_levels()
	assert_eq(_captured(), PackedStringArray(["[INFO] test: i", "[WARN] test: w", "[ERROR] test: e"]))


func test_debug_level_keeps_everything() -> void:
	_log.level = LogScript.Level.DEBUG
	_log_all_levels()
	assert_eq(_captured(), PackedStringArray([
		"[DEBUG] test: d", "[INFO] test: i", "[WARN] test: w", "[ERROR] test: e",
	]))


func test_warn_level_keeps_warn_and_error() -> void:
	_log.level = LogScript.Level.WARN
	_log_all_levels()
	assert_eq(_captured(), PackedStringArray(["[WARN] test: w", "[ERROR] test: e"]))


func test_error_level_keeps_only_error() -> void:
	_log.level = LogScript.Level.ERROR
	_log_all_levels()
	assert_eq(_captured(), PackedStringArray(["[ERROR] test: e"]))


func test_error_also_pushes_an_engine_error() -> void:
	_log.error("save", "disk full")
	assert_push_error("[ERROR] save: disk full")


func test_debug_info_warn_do_not_push_errors() -> void:
	_log.level = LogScript.Level.DEBUG
	_log.debug("test", "d")
	_log.info("test", "i")
	_log.warn("test", "w")
	assert_eq(get_errors().size(), 0)


func _log_all_levels() -> void:
	_log.debug("test", "d")
	_log.info("test", "i")
	_log.warn("test", "w")
	_log.error("test", "e")
	assert_push_error(1)


# Only the lines written by Log: GUT and the engine may print other lines meanwhile.
func _captured() -> PackedStringArray:
	var result: PackedStringArray = []
	for line: String in _capture.lines:
		if line.begins_with("[") and line.contains("] test: "):
			result.append(line)
	return result
