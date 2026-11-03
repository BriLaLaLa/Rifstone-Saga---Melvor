extends GutHookScript
## GUT pre-run hook: isolates test saves from the player's real saves, and each checkout's test folders from the
## others.
##
## Every worktree shares the same user:// folder (same config/name), so two suites running at the same time in two
## checkouts would overwrite each other's files. Every folder a test writes under user:// is therefore below
## checkout_root() = user://test_runs/<hash of the checkout's absolute res:// path>, through test_dir() and save_dir().
## Tests reach these functions with `const PreRun := preload("res://tests/helpers/gut_pre_run.gd")`.
##
## If the SaveService autoload exists, its base_dir is redirected to save_dir() and that folder is emptied, so no test
## can ever read or overwrite a real slot. If the autoload does not exist yet, the hook does nothing.

const SAVE_SERVICE_NAME: StringName = &"SaveService"
const TEST_RUNS_DIR: String = "user://test_runs"
const SAVE_DIR_NAME: String = "test_saves"
# Hex characters of the md5 kept in the folder name: enough to tell checkouts apart, short enough to read.
const CHECKOUT_ID_LENGTH: int = 12


## The folder of this checkout under user://, the same for every run of the same checkout.
static func checkout_root() -> String:
	var checkout_path: String = ProjectSettings.globalize_path("res://")
	return TEST_RUNS_DIR.path_join(checkout_path.md5_text().substr(0, CHECKOUT_ID_LENGTH))


## A scratch folder of this checkout for one test file (`name` = a plain folder name, e.g. "test_json_loader").
static func test_dir(name: String) -> String:
	return checkout_root().path_join(name)


## The folder SaveService writes to during the tests.
static func save_dir() -> String:
	return test_dir(SAVE_DIR_NAME)


func run() -> void:
	var save_service: SaveStore = _find_save_service()
	if save_service == null:
		return
	save_service.base_dir = save_dir()
	_reset_dir(save_dir())


# Hook scripts are RefCounted, not nodes: the autoload is looked up from the running SceneTree.
func _find_save_service() -> SaveStore:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null(NodePath(String(SAVE_SERVICE_NAME))) as SaveStore


func _reset_dir(path: String) -> void:
	if DirAccess.dir_exists_absolute(path):
		_clear_dir(path)
	var err: Error = DirAccess.make_dir_recursive_absolute(path)
	if err != OK:
		push_error("gut_pre_run: cannot create %s (error %d)" % [path, err])


func _clear_dir(path: String) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		push_error("gut_pre_run: cannot open %s" % path)
		return
	for sub_dir: String in dir.get_directories():
		var sub_path: String = path.path_join(sub_dir)
		_clear_dir(sub_path)
		DirAccess.remove_absolute(sub_path)
	for file_name: String in dir.get_files():
		var err: Error = dir.remove(file_name)
		if err != OK:
			push_error("gut_pre_run: cannot remove %s (error %d)" % [path.path_join(file_name), err])
