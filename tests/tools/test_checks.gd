extends GutTest
## Tests for the counting and search functions of tools/check_file_sizes.gd and tools/check_forbidden_refs.gd.
## Everything runs on in-memory strings. Forbidden strings are built by concatenation so that this file does not
## match the rules it tests.

const SizeCheck := preload("res://tools/check_file_sizes.gd")
const RefsCheck := preload("res://tools/check_forbidden_refs.gd")

const PRINT_CALL: String = "pri" + "nt("
const ROOT_LOOKUP: String = "get_" + "node(\"/root/"
const OLD_FOLDER: String = "RIFTSTONE" + " SAGA"


func _lines(count: int, trailing_newline: bool = true) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for i: int in range(count):
		parts.append("var x%d: int = %d" % [i, i])
	var text: String = "\n".join(parts)
	if trailing_newline and count > 0:
		text += "\n"
	return text


# --- check_file_sizes ---

func test_count_lines_empty_text_is_zero() -> void:
	assert_eq(SizeCheck.count_lines(""), 0)


func test_count_lines_trailing_newline_does_not_add_a_line() -> void:
	assert_eq(SizeCheck.count_lines("a\nb\n"), 2)
	assert_eq(SizeCheck.count_lines("a\nb"), 2)


func test_count_lines_counts_empty_lines() -> void:
	assert_eq(SizeCheck.count_lines("\n\n\n"), 3)
	assert_eq(SizeCheck.count_lines("a\n\nb\n"), 3)


func test_count_lines_crlf_counts_like_lf() -> void:
	assert_eq(SizeCheck.count_lines("a\r\nb\r\n"), 2)


func test_400_lines_pass_and_401_fail() -> void:
	assert_eq(SizeCheck.MAX_LINES, 400)
	assert_false(SizeCheck.is_over_limit(_lines(400)), "400 lines are allowed")
	assert_false(SizeCheck.is_over_limit(_lines(400, false)), "400 lines without final newline are allowed")
	assert_true(SizeCheck.is_over_limit(_lines(401)), "401 lines fail")
	assert_true(SizeCheck.is_over_limit(_lines(401, false)), "401 lines without final newline fail")


func test_check_text_message_names_file_and_count() -> void:
	assert_eq(SizeCheck.check_text("res://core/a.gd", _lines(400)), "")
	assert_eq(SizeCheck.check_text("res://core/a.gd", _lines(401)), "res://core/a.gd: 401 lines (max 400)")


func test_check_text_custom_limit() -> void:
	assert_eq(SizeCheck.check_text("x.gd", "a\nb\nc\n", 2), "x.gd: 3 lines (max 2)")


func test_checked_files_are_gd_and_tscn_only() -> void:
	assert_true(SizeCheck.is_checked_file("res://core/session/game_session.gd"))
	assert_true(SizeCheck.is_checked_file("res://ui/pages/bank/bank_page.tscn"))
	assert_false(SizeCheck.is_checked_file("res://ui/theme/ui_theme.tres"), "generated .tres are not checked")
	assert_false(SizeCheck.is_checked_file("res://tools/run_checks.ps1"))
	assert_false(SizeCheck.is_checked_file("res://core/session/game_session.gd.uid"))


func test_files_under_addons_are_not_checked() -> void:
	assert_false(SizeCheck.is_checked_file("res://tools/addons/gut/gut.gd"))
	assert_false(SizeCheck.is_checked_file("res://addons/gut/gut.gd"))


# --- check_forbidden_refs: previous game path ---

func test_previous_game_path_is_found_in_any_text_file() -> void:
	var text: String = "ok\nsee C:/AI/" + OLD_FOLDER + "/scripts\n"
	var found: PackedStringArray = RefsCheck.find_violations("data/notes.json", text)
	assert_eq(found, PackedStringArray(["data/notes.json:2: previous_game_path"]))


func test_previous_game_path_variants_are_found() -> void:
	assert_eq(RefsCheck.find_violations("a.gd", "x = \"" + OLD_FOLDER + "\\\\x\"").size(), 1, "backslash")
	assert_eq(RefsCheck.find_violations("a.md", "../" + "RIFTSTONE").size(), 1, "relative path")
	assert_eq(RefsCheck.find_violations("a.md", "..\\" + "RIFTSTONE").size(), 1, "relative windows path")
	assert_eq(RefsCheck.find_violations("a.ps1", "# ../" + OLD_FOLDER + "/x").size(), 1, "also in comments")


func test_project_name_is_not_a_previous_game_path() -> void:
	assert_eq(RefsCheck.find_violations("a.md", OLD_FOLDER + " - Melvor\\tools").size(), 0)
	assert_eq(RefsCheck.find_violations("a.gd", "const NAME: String = \"RiftStone Saga: Idle\"").size(), 0)


# --- check_forbidden_refs: root node path ---

func test_root_lookup_fails_outside_autoload() -> void:
	var text: String = "var g: Node = " + ROOT_LOOKUP + "Game\")\n"
	assert_eq(RefsCheck.find_violations("ui/pages/bank/bank_page.gd", text),
			PackedStringArray(["ui/pages/bank/bank_page.gd:1: root_node_path"]))


func test_root_lookup_single_quotes_fails() -> void:
	var text: String = "var g: Node = get_" + "node('/root/Game')\n"
	assert_eq(RefsCheck.find_violations("systems/bank/bank.gd", text).size(), 1)


func test_root_lookup_allowed_in_autoload() -> void:
	var text: String = "var g: Node = " + ROOT_LOOKUP + "Game\")\n"
	assert_eq(RefsCheck.find_violations("core/autoload/game.gd", text).size(), 0)


func test_root_lookup_in_comment_is_ignored() -> void:
	var text: String = "# never use " + ROOT_LOOKUP + "Game\")\n"
	assert_eq(RefsCheck.find_violations("ui/a.gd", text).size(), 0)


# --- check_forbidden_refs: print ---

func test_print_fails_outside_log() -> void:
	var text: String = "func f() -> void:\n\t" + PRINT_CALL + "\"hi\")\n"
	assert_eq(RefsCheck.find_violations("systems/bank/bank.gd", text),
			PackedStringArray(["systems/bank/bank.gd:2: print_call"]))


func test_print_allowed_in_log_script() -> void:
	assert_eq(RefsCheck.find_violations("core/autoload/log.gd", "\t" + PRINT_CALL + "msg)\n").size(), 0)


func test_print_not_allowed_in_other_autoloads() -> void:
	assert_eq(RefsCheck.find_violations("core/autoload/game.gd", "\t" + PRINT_CALL + "msg)\n").size(), 1)


func test_print_in_tscn_embedded_script_fails() -> void:
	assert_eq(RefsCheck.find_violations("ui/a.tscn", "script/source = \"" + PRINT_CALL + "1)\"\n").size(), 1)


func test_print_like_functions_are_allowed() -> void:
	var allowed: PackedStringArray = PackedStringArray([
		"printerr(\"x\")", "print_rich(\"x\")", "print_debug(\"x\")", "push_error(\"x\")", "printraw(\"x\")",
		"blue" + PRINT_CALL + ")", "_" + PRINT_CALL + ")", "x2" + PRINT_CALL + ")",
	])
	for code: String in allowed:
		assert_false(RefsCheck.has_print_call(code), code)


func test_print_call_detected_after_non_identifier_chars() -> void:
	var calls: PackedStringArray = PackedStringArray([
		PRINT_CALL + ")", "\t" + PRINT_CALL + ")", "x;" + PRINT_CALL + ")", "printerr(1); " + PRINT_CALL + "2)",
	])
	for code: String in calls:
		assert_true(RefsCheck.has_print_call(code), code)


func test_print_in_comment_is_ignored() -> void:
	var text: String = "## Use Log, never " + PRINT_CALL + ")\nvar a: int = 1  # " + PRINT_CALL + ")\n"
	assert_eq(RefsCheck.find_violations("core/a.gd", text).size(), 0)


func test_print_in_non_code_file_is_ignored() -> void:
	assert_eq(RefsCheck.find_violations("tools/run_checks.ps1", PRINT_CALL + "1)\n").size(), 0)
	assert_eq(RefsCheck.find_violations("data/a.json", "\"" + PRINT_CALL + "\"\n").size(), 0)


# --- check_forbidden_refs: helpers ---

func test_strip_comment_keeps_hash_inside_strings() -> void:
	assert_eq(RefsCheck.strip_comment("var c: String = \"#fff\" # color"), "var c: String = \"#fff\" ")
	assert_eq(RefsCheck.strip_comment("var c: String = '#fff'"), "var c: String = '#fff'")
	assert_eq(RefsCheck.strip_comment("var s: String = \"a\\\"#b\" # c"), "var s: String = \"a\\\"#b\" ")
	assert_eq(RefsCheck.strip_comment("# all comment"), "")
	assert_eq(RefsCheck.strip_comment("no comment"), "no comment")


func test_excluded_paths() -> void:
	assert_true(RefsCheck.is_excluded("CLAUDE.md"))
	assert_true(RefsCheck.is_excluded("docs/01_GDD.md"))
	assert_true(RefsCheck.is_excluded(".claude/agents/qa-test-engineer.md"))
	assert_true(RefsCheck.is_excluded(".godot/global_script_class_cache.cfg"))
	assert_true(RefsCheck.is_excluded("addons/gut/gut.gd"))
	assert_false(RefsCheck.is_excluded("core/docs.gd"), "only the docs folder is excluded")
	assert_false(RefsCheck.is_excluded("tests/CLAUDE.md"), "only the root CLAUDE.md is excluded")
	assert_false(RefsCheck.is_excluded("tools/check_forbidden_refs.gd"))


func test_text_files_by_extension() -> void:
	var text_files: PackedStringArray = PackedStringArray([
		"a.gd", "a.tscn", "a.tres", "project.godot", "a.cfg", "a.json", "a.md", "a.ps1", ".gitignore",
		".gutconfig.json", "icon.svg.import",
	])
	for path: String in text_files:
		assert_true(RefsCheck.is_text_file(path), path)
	for path: String in PackedStringArray(["a.png", "a.ttf", "a.ogg", "a.exe", "a.res"]):
		assert_false(RefsCheck.is_text_file(path), path)


func test_clean_file_has_no_violations() -> void:
	var text: String = "extends Node\n\nfunc _ready() -> void:\n\tLog.info(&\"ui\", \"ready\")\n"
	assert_eq(RefsCheck.find_violations("ui/a.gd", text).size(), 0)


func test_multiple_violations_are_all_reported() -> void:
	var text: String = PRINT_CALL + "1)\n" + ROOT_LOOKUP + "X\")\n" + "\"" + OLD_FOLDER + "/a\"\n"
	assert_eq(RefsCheck.find_violations("systems/a.gd", text), PackedStringArray([
		"systems/a.gd:1: print_call", "systems/a.gd:2: root_node_path", "systems/a.gd:3: previous_game_path",
	]))
