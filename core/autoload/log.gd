extends Node
## Leveled logger (autoload `Log`): the only place in the project that calls `print`.
##
## Lines look like `[INFO] category: message`, without emoji. Messages below `level` are dropped;
## `error` also calls `push_error`, so errors show up in the debugger and fail GUT tests unless expected.

enum Level { DEBUG, INFO, WARN, ERROR }

const LEVEL_TAGS: Dictionary[Level, String] = {
	Level.DEBUG: "DEBUG",
	Level.INFO: "INFO",
	Level.WARN: "WARN",
	Level.ERROR: "ERROR",
}

var level: Level = Level.INFO


func debug(category: String, message: String) -> void:
	_write(Level.DEBUG, category, message)


func info(category: String, message: String) -> void:
	_write(Level.INFO, category, message)


func warn(category: String, message: String) -> void:
	_write(Level.WARN, category, message)


func error(category: String, message: String) -> void:
	var line: String = _write(Level.ERROR, category, message)
	push_error(line)


# Returns the formatted line, also when it is filtered out (error() needs it for push_error).
func _write(message_level: Level, category: String, message: String) -> String:
	var line: String = "[%s] %s: %s" % [LEVEL_TAGS[message_level], category, message]
	if message_level >= level:
		print(line)
	return line
