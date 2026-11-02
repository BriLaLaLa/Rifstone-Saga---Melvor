class_name JsonLoader
extends RefCounted
## Reads JSON files from disk (docs/03_ARCHITECTURE.md §10). Only parsing: no schema or semantic checks.
##
## Problems (missing file or folder, unreadable file, broken JSON) are appended to `errors` with the path, and the
## file is left out: the caller (GameData) decides what an error means. Nothing is pushed to the debugger here,
## because a data error is a game error collected in `GameData.errors`, not a programming error.

const JSON_EXTENSION: String = "json"


## The parsed content of `path`; null (and an entry in `errors`) if the file is missing, unreadable, not valid
## JSON or contains only `null`.
static func load_file(path: String, errors: PackedStringArray) -> Variant:
	if not FileAccess.file_exists(path):
		errors.append("%s: file not found" % path)
		return null
	var text: String = FileAccess.get_file_as_string(path)
	var open_error: Error = FileAccess.get_open_error()
	if open_error != OK:
		errors.append("%s: cannot read the file (%s)" % [path, error_string(open_error)])
		return null
	var json := JSON.new()
	var parse_error: Error = json.parse(text)
	if parse_error != OK:
		errors.append("%s:%d: invalid JSON (%s)" % [path, json.get_error_line(), json.get_error_message()])
		return null
	if json.data == null:
		errors.append("%s: the file contains no data" % path)
		return null
	return json.data


## The top-level objects of every `.json` file directly inside `dir`, in alphabetical order of file name.
## Sub-folders are not visited. A missing folder, a file that fails `load_file` or a file whose top level is not an
## object is reported in `errors` and skipped.
static func load_dir(dir: String, errors: PackedStringArray) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not DirAccess.dir_exists_absolute(dir):
		errors.append("%s: folder not found" % dir)
		return result
	var file_names: PackedStringArray = DirAccess.get_files_at(dir)
	file_names.sort()
	for file_name: String in file_names:
		if file_name.get_extension().to_lower() != JSON_EXTENSION:
			continue
		var path: String = dir.path_join(file_name)
		var content: Variant = load_file(path, errors)
		if content == null:
			continue
		if not content is Dictionary:
			errors.append("%s: the top level is not an object" % path)
			continue
		result.append(content as Dictionary)
	return result
