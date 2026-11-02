extends GutHookScript
## GUT pre-run hook: isolates test saves from the player's real saves.
##
## If the SaveService autoload exists, its base_dir is redirected to TEST_SAVE_DIR and that folder is emptied,
## so no test can ever read or overwrite a real slot. If the autoload does not exist yet, the hook does nothing.

const SAVE_SERVICE_NAME: StringName = &"SaveService"
const BASE_DIR_PROPERTY: StringName = &"base_dir"
const TEST_SAVE_DIR: String = "user://test_saves"


func run() -> void:
	var save_service: Node = _find_save_service()
	if save_service == null:
		return
	# SaveStore (core/autoload/save_service.gd) does not exist before M1, so the property is set by name:
	# a typed `as SaveStore` cast would not parse until that class is written.
	save_service.set(BASE_DIR_PROPERTY, TEST_SAVE_DIR)
	_reset_dir(TEST_SAVE_DIR)


# Hook scripts are RefCounted, not nodes: the autoload is looked up from the running SceneTree.
func _find_save_service() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null(NodePath(String(SAVE_SERVICE_NAME)))


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
