extends GutTest
## JsonLoader: missing file, broken JSON, folder loading in alphabetical order. Errors go to `errors` with the path.
## Files are written to a scratch folder under user:// and removed after the tests.

const TMP_DIR: String = "user://test_json_loader"


func before_each() -> void:
	_remove_tmp_dir()
	DirAccess.make_dir_recursive_absolute(TMP_DIR)


func after_all() -> void:
	_remove_tmp_dir()


func test_load_file_returns_parsed_object() -> void:
	var path: String = _write("ok.json", "{\"skills\": [{\"id\": \"forestry\", \"order\": 1}]}")
	var errors: PackedStringArray = []
	var content: Variant = JsonLoader.load_file(path, errors)
	assert_eq(errors.size(), 0)
	assert_true(content is Dictionary)
	var skills: Array = (content as Dictionary)["skills"]
	assert_eq(skills[0]["id"], "forestry")
	assert_eq(skills[0]["order"], 1.0)


func test_load_file_returns_non_object_top_level() -> void:
	var path: String = _write("list.json", "[1, 2]")
	var errors: PackedStringArray = []
	assert_eq(JsonLoader.load_file(path, errors), [1.0, 2.0])
	assert_eq(errors.size(), 0)


func test_load_file_missing_is_null_with_error() -> void:
	var errors: PackedStringArray = []
	var path: String = TMP_DIR.path_join("nope.json")
	assert_null(JsonLoader.load_file(path, errors))
	assert_eq(errors.size(), 1)
	assert_string_contains(errors[0], path)
	assert_string_contains(errors[0], "not found")


func test_load_file_broken_json_is_null_with_line() -> void:
	var path: String = _write("broken.json", "{\n  \"id\": \"forestry\",\n  \"order\": \n}")
	var errors: PackedStringArray = []
	assert_null(JsonLoader.load_file(path, errors))
	assert_eq(errors.size(), 1)
	assert_string_contains(errors[0], path)
	assert_string_contains(errors[0], "invalid JSON")


func test_load_file_empty_is_null_with_error() -> void:
	var path: String = _write("empty.json", "")
	var errors: PackedStringArray = []
	assert_null(JsonLoader.load_file(path, errors))
	assert_eq(errors.size(), 1)
	assert_string_contains(errors[0], path)


func test_load_file_literal_null_is_an_error() -> void:
	var path: String = _write("null.json", "null")
	var errors: PackedStringArray = []
	assert_null(JsonLoader.load_file(path, errors))
	assert_eq(errors.size(), 1)
	assert_string_contains(errors[0], "no data")


func test_load_file_keeps_previous_errors() -> void:
	var errors: PackedStringArray = ["earlier"]
	JsonLoader.load_file(TMP_DIR.path_join("nope.json"), errors)
	assert_eq(errors.size(), 2)
	assert_eq(errors[0], "earlier")


func test_load_dir_reads_json_files_in_alphabetical_order() -> void:
	_write("tools.json", "{\"name\": \"tools\"}")
	_write("equipment.json", "{\"name\": \"equipment\"}")
	_write("materials.json", "{\"name\": \"materials\"}")
	var errors: PackedStringArray = []
	var contents: Array[Dictionary] = JsonLoader.load_dir(TMP_DIR, errors)
	assert_eq(errors.size(), 0)
	assert_eq(contents.size(), 3)
	assert_eq(contents[0]["name"], "equipment")
	assert_eq(contents[1]["name"], "materials")
	assert_eq(contents[2]["name"], "tools")


func test_load_dir_ignores_other_files_and_subfolders() -> void:
	_write("a.json", "{\"name\": \"a\"}")
	_write("notes.txt", "not json")
	DirAccess.make_dir_recursive_absolute(TMP_DIR.path_join("sub"))
	_write("sub/b.json", "{\"name\": \"b\"}")
	var errors: PackedStringArray = []
	var contents: Array[Dictionary] = JsonLoader.load_dir(TMP_DIR, errors)
	assert_eq(errors.size(), 0)
	assert_eq(contents.size(), 1)
	assert_eq(contents[0]["name"], "a")


func test_load_dir_skips_broken_and_non_object_files_with_errors() -> void:
	_write("a.json", "{\"name\": \"a\"}")
	_write("b.json", "{broken")
	_write("c.json", "[\"not\", \"an object\"]")
	_write("d.json", "{\"name\": \"d\"}")
	var errors: PackedStringArray = []
	var contents: Array[Dictionary] = JsonLoader.load_dir(TMP_DIR, errors)
	assert_eq(contents.size(), 2)
	assert_eq(contents[0]["name"], "a")
	assert_eq(contents[1]["name"], "d")
	assert_eq(errors.size(), 2)
	assert_string_contains(errors[0], "b.json")
	assert_string_contains(errors[1], "c.json")
	assert_string_contains(errors[1], "not an object")


func test_load_dir_empty_folder_is_empty_without_errors() -> void:
	var errors: PackedStringArray = []
	assert_eq(JsonLoader.load_dir(TMP_DIR, errors).size(), 0)
	assert_eq(errors.size(), 0)


func test_load_dir_missing_folder_is_an_error() -> void:
	var errors: PackedStringArray = []
	var dir: String = TMP_DIR.path_join("missing")
	assert_eq(JsonLoader.load_dir(dir, errors).size(), 0)
	assert_eq(errors.size(), 1)
	assert_string_contains(errors[0], dir)


func _write(file_name: String, text: String) -> String:
	var path: String = TMP_DIR.path_join(file_name)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file, "cannot write %s" % path)
	file.store_string(text)
	file.close()
	return path


func _remove_tmp_dir() -> void:
	_remove_recursive(TMP_DIR)


func _remove_recursive(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for sub_dir: String in DirAccess.get_directories_at(path):
		_remove_recursive(path.path_join(sub_dir))
	for file_name: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file_name))
	DirAccess.remove_absolute(path)
