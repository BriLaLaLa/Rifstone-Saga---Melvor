extends Node
## Dev tool (M29-02): screenshots of the Fractures page and of the Combat page during a Fracture with a full bag.
## Needs a window (NOT --headless): timeout 90 Godot --path . --resolution 1280x720 res://tools/shot_fracture.tscn -- <out_dir> <w>x<h>

const SCENE: String = "res://ui/screens/main/main_screen.tscn"

var _out: String = "user://shots"


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	if args.size() > 1:
		var parts: PackedStringArray = args[1].split("x")
		get_tree().root.size = Vector2i(int(parts[0]), int(parts[1]))
	_run()


func _run() -> void:
	var session: GameSession = TestFactory.session(1234, TestFactory.real_data(), true)
	TestFactory.set_character_level(session, 30)
	TestFactory.make_roomy(session)
	var screen: MainScreen = (load(SCENE) as PackedScene).instantiate() as MainScreen
	screen.session = session
	get_tree().root.add_child.call_deferred(screen)
	await _frames(5)
	BagFill.open_and_fill(session)
	var host: PageHost = screen.get_node("%PageHost") as PageHost
	host.show_page(&"fractures")
	await _frames(8)
	_save(&"fracture_bag")
	var list: Node = host.find_child("BagList", true, false)
	for key: String in ["Piece_0", "Card_0"]:
		var row: Node = list.find_child(key, true, false)
		if row != null:
			(row as Control).gui_input.emit(_click())
	await _frames(8)
	_save(&"fracture_bag_open")
	host.show_page(&"combat")
	await _frames(8)
	_save(&"fracture_combat")
	get_tree().quit(0)


func _click() -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	return event


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().process_frame
		for hint: Node in get_tree().root.find_children("*", "Button", true, false):
			if (hint as Button).text == "Ho capito" and hint.is_visible_in_tree():
				(hint as Button).pressed.emit()


func _save(name: StringName) -> void:
	get_tree().root.get_texture().get_image().save_png("%s/%s.png" % [ProjectSettings.globalize_path(_out), String(name)])
