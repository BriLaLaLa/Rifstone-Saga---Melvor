extends SceneTree
## Fails (exit code 1) if a text file of the project contains a forbidden reference.
##
## Usage: godot --headless --path . -s tools/check_forbidden_refs.gd
## Rules (see docs/08_TEAM.md §4-5):
## - any text file: no path towards the previous game (the folder name followed by a separator, or `../` + its name);
## - GDScript-bearing files (.gd, .tscn, .tres): no root node-path lookup outside core/autoload/, no bare print call
##   outside core/autoload/log.gd. These two rules ignore `#` comments; string literals are still checked.
## Not scanned: docs/, CLAUDE.md, .claude/, .godot/, .git, addons/ (third-party code) and non-text files.
## The forbidden strings are built by concatenation so that this file does not match its own rules.
## The logic lives in static functions so that tests/tools/test_checks.gd can call it on in-memory strings.

const RULE_PREVIOUS_GAME: String = "previous_game_path"
const RULE_ROOT_NODE: String = "root_node_path"
const RULE_PRINT: String = "print_call"

const AUTOLOAD_DIR: String = "core/autoload/"
const LOG_SCRIPT: String = "core/autoload/log.gd"
const EXCLUDED_DIRS: PackedStringArray = ["docs", ".claude", ".godot", ".git", "addons"]
const EXCLUDED_FILES: PackedStringArray = ["CLAUDE.md"]
const TEXT_EXTENSIONS: PackedStringArray = [
	"gd", "tscn", "tres", "godot", "cfg", "json", "md", "txt", "csv", "ps1", "gdshader", "import", "uid",
	"gitignore", "gitattributes", "editorconfig", "gutconfig", "svg",
]
const CODE_EXTENSIONS: PackedStringArray = ["gd", "tscn", "tres"]
const IDENTIFIER_CHARS: String = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"


func _init() -> void:
	var files: PackedStringArray = collect_files("res://", "")
	var violations: PackedStringArray = PackedStringArray()
	for rel_path: String in files:
		var text: String = FileAccess.get_file_as_string("res://" + rel_path)
		if text.is_empty() and FileAccess.get_open_error() != OK:
			violations.append("%s: cannot read file (error %d)" % [rel_path, FileAccess.get_open_error()])
			continue
		violations.append_array(find_violations(rel_path, text))
	if violations.is_empty():
		print_rich("check_forbidden_refs: OK (%d files)" % files.size())
		quit(0)
		return
	for violation: String in violations:
		printerr(violation)
	printerr("check_forbidden_refs: FAILED (%d violations)" % violations.size())
	quit(1)


## Strings that point to the previous game's folder (forward slash, backslash, relative path).
static func previous_game_patterns() -> PackedStringArray:
	var folder: String = "RIFTSTONE" + " SAGA"
	return PackedStringArray([folder + "/", folder + "\\", ".." + "/RIFTSTONE", ".." + "\\RIFTSTONE"])


## Strings that look up a node from the scene root.
static func root_node_patterns() -> PackedStringArray:
	var call: String = "get_node" + "("
	return PackedStringArray([call + "\"/root/", call + "'/root/"])


## True if `rel_path` (relative to res://, `/` separators) must not be scanned.
static func is_excluded(rel_path: String) -> bool:
	if EXCLUDED_FILES.has(rel_path):
		return true
	var parts: PackedStringArray = rel_path.split("/")
	for i: int in range(parts.size() - 1):
		if EXCLUDED_DIRS.has(parts[i]):
			return true
	return false


## True if `rel_path` is a text file by its extension (hidden files like `.gitignore` included).
static func is_text_file(rel_path: String) -> bool:
	return TEXT_EXTENSIONS.has(rel_path.get_extension().to_lower())


## True if the GDScript rules (root node path, print call) apply to `rel_path`.
static func is_code_file(rel_path: String) -> bool:
	return CODE_EXTENSIONS.has(rel_path.get_extension().to_lower())


## `line` without its `#` comment; a `#` inside a string literal is kept.
static func strip_comment(line: String) -> String:
	var quote: String = ""
	var i: int = 0
	while i < line.length():
		var c: String = line[i]
		if not quote.is_empty():
			if c == "\\":
				i += 1
			elif c == quote:
				quote = ""
		elif c == "\"" or c == "'":
			quote = c
		elif c == "#":
			return line.substr(0, i)
		i += 1
	return line


## True if `code` calls the bare print function. `printerr(`, `print_rich(`, `print_debug(`, `push_error(` and
## identifiers that merely end in "print" (`blueprint(`, `_print(`) do not count.
static func has_print_call(code: String) -> bool:
	var needle: String = "print" + "("
	var from: int = code.find(needle)
	while from != -1:
		if from == 0 or not IDENTIFIER_CHARS.contains(code[from - 1]):
			return true
		from = code.find(needle, from + 1)
	return false


## True if `code` contains one of `patterns`.
static func contains_any(code: String, patterns: PackedStringArray) -> bool:
	for pattern: String in patterns:
		if code.contains(pattern):
			return true
	return false


## Violations of `text` as `path:line: rule` messages; `rel_path` is relative to res:// with `/` separators.
static func find_violations(rel_path: String, text: String) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var path_patterns: PackedStringArray = previous_game_patterns()
	var node_patterns: PackedStringArray = root_node_patterns()
	var code_file: bool = is_code_file(rel_path)
	var check_root: bool = code_file and not rel_path.begins_with(AUTOLOAD_DIR)
	var check_print: bool = code_file and rel_path != LOG_SCRIPT
	var lines: PackedStringArray = text.split("\n")
	for i: int in range(lines.size()):
		var line: String = lines[i]
		if contains_any(line, path_patterns):
			result.append(_message(rel_path, i + 1, RULE_PREVIOUS_GAME))
		if not code_file:
			continue
		var code: String = strip_comment(line)
		if check_root and contains_any(code, node_patterns):
			result.append(_message(rel_path, i + 1, RULE_ROOT_NODE))
		if check_print and has_print_call(code):
			result.append(_message(rel_path, i + 1, RULE_PRINT))
	return result


## Relative paths of all scannable text files under `dir_path` (`rel_dir` is its path relative to res://), sorted.
static func collect_files(dir_path: String, rel_dir: String) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return result
	dir.include_hidden = true
	for sub_dir: String in dir.get_directories():
		if EXCLUDED_DIRS.has(sub_dir):
			continue
		result.append_array(collect_files(dir_path.path_join(sub_dir), rel_dir + sub_dir + "/"))
	for file_name: String in dir.get_files():
		var rel_path: String = rel_dir + file_name
		if is_text_file(rel_path) and not is_excluded(rel_path):
			result.append(rel_path)
	result.sort()
	return result


static func _message(rel_path: String, line_number: int, rule: String) -> String:
	return "%s:%d: %s" % [rel_path, line_number, rule]
