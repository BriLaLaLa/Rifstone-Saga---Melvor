extends GutTest
## Closing criterion of docs/01_GDD_M24.md §35.12 (checked by M24-02 and M24-08): no reference to the hired helpers (hired workers) or to
## the Contracts left in core/, systems/, ui/, data/, tests/ (the support folder tests/helpers/ does not count), tools/ and assets/.
## The forbidden words are assembled from pieces so that this file does not match its own rules.

const ROOTS: PackedStringArray = ["res://core", "res://systems", "res://ui", "res://data", "res://tests", "res://tools", "res://assets"]
const TEXT_EXTENSIONS: PackedStringArray = ["gd", "tscn", "json", "svg", "cfg", "tres", "md"]
const SKIPPED_DIRS: PackedStringArray = ["res://tests/helpers"]
## Regular expressions of the words of §35.12 (the generic word for a support function is not one of them).
const PATTERNS: PackedStringArray = [
	"Hel" + "perSystem", "Hel" + "perIndex", "Hel" + "perGrade", "Hel" + "perRow", "Hel" + "perTexts", "DataValidatorHel" + "per",
	"hel" + "per_(changed|completed|blocked|grade|grades|row|texts|share|not_better)", "\\.hel" + "pers\\b", "_PHASE_HEL" + "PERS",
	"for_hel" + "per", "con" + "tract_(forestry|quarrying|angling|test)", "Con" + "tratt", "aiu" + "tant", "is_con" + "tract", "KIND_CON" + "TRACT", "no_hel" + "per",
	"hel" + "per\\.(xp_pct|mastery_pct|grades)", "\"hel" + "per\"",
]


func test_no_reference_to_the_helpers_or_the_contracts() -> void:
	var rules: Array[RegEx] = []
	for pattern: String in PATTERNS:
		rules.append(RegEx.create_from_string(pattern))
	var hits: PackedStringArray = []
	for root: String in ROOTS:
		_scan(root, rules, hits)
	assert_eq(hits.size(), 0, "found:\n%s" % "\n".join(hits.slice(0, 20)))


func _scan(dir_path: String, rules: Array[RegEx], hits: PackedStringArray) -> void:
	if SKIPPED_DIRS.has(dir_path):
		return
	for sub: String in DirAccess.get_directories_at(dir_path):
		_scan(dir_path.path_join(sub), rules, hits)
	for file_name: String in DirAccess.get_files_at(dir_path):
		var path: String = dir_path.path_join(file_name)
		if _matches(file_name, rules):
			hits.append("%s: the file name" % path)
		if TEXT_EXTENSIONS.has(file_name.get_extension()):
			var text: String = FileAccess.get_file_as_string(path)
			for rule: RegEx in rules:
				var found: RegExMatch = rule.search(text)
				if found != null:
					hits.append("%s: '%s'" % [path, found.get_string()])


func _matches(text: String, rules: Array[RegEx]) -> bool:
	for rule: RegEx in rules:
		if rule.search(text) != null:
			return true
	return false
