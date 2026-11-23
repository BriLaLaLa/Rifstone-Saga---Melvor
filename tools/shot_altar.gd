extends Node
## Dev tool (M35-C): PNGs of the Altar page in four states (ready to socket, socketed, locked socket, no runes), on a TestFactory
## session (never a real slot). Needs a window (NOT --headless); always run it under a timeout:
##   timeout 120 Godot --path . --resolution 1280x720 res://tools/shot_altar.tscn -- <out_dir>

const SCENE: String = "res://ui/screens/main/main_screen.tscn"

var _out: String = "user://shots_altar"


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	await _run()
	get_tree().quit(0)


func _run() -> void:
	var session: GameSession = TestFactory.session(1234, TestFactory.real_data(), false, false)
	TestFactory.learn_discipline(session, &"riftbinding")
	TestFactory.set_level(session, &"riftbinding", 25)
	var screen: MainScreen = (load(SCENE) as PackedScene).instantiate() as MainScreen
	screen.session = session
	get_tree().root.add_child.call_deferred(screen)
	await _frames(5)
	for hint: Node in screen.find_children("*", "Button", true, false):
		if (hint as Button).text == "Ho capito":
			(hint as Button).pressed.emit()
	var host: PageHost = screen.find_child("PageHost", true, false) as PageHost
	host.show_page(&"rift")
	await _frames(6)
	_save(&"altar_no_runes")
	TestFactory.give(session, &"inf_swift_hands", 3)
	TestFactory.give(session, &"inf_swift_hands_2", 1)
	await _frames(6)
	_save(&"altar_ready")
	var page: Node = screen.find_child("Page", true, false)
	page.find_child("SocketButton", true, false).pressed.emit()
	await _frames(6)
	_save(&"altar_after_socket")
	page.find_child("Socket0", true, false).pressed.emit()
	await _frames(4)
	page.find_child("RemoveButton", true, false).pressed.emit()
	await _frames(6)
	_save(&"altar_remove_confirm")
	page.find_child("Socket3", true, false).pressed.emit()
	await _frames(6)
	_save(&"altar_locked")
	print_rich("shots in ", ProjectSettings.globalize_path(_out))
	screen.free()
	session.free()


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().process_frame


func _save(shot: StringName) -> void:
	get_tree().root.get_texture().get_image().save_png("%s/%s.png" % [ProjectSettings.globalize_path(_out), String(shot)])
