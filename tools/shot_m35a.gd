extends Node
## Dev tool (M35-A): PNGs of the Equipment page (item level badge) with the piece tooltip open, on a TestFactory session.
## Needs a window (NOT --headless); always run it under a timeout:
##   timeout 120 Godot --path . --resolution 1280x720 res://tools/shot_m35a.tscn -- <out_dir>

const SCENE: String = "res://ui/screens/main/main_screen.tscn"

var _out: String = "user://shots_m35a"


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	await _run()
	get_tree().quit(0)


func _run() -> void:
	var session: GameSession = TestFactory.session(1234, TestFactory.real_data(), false, false)
	var worn: int = TestFactory.give_piece(session, &"emberbronze_sword", &"magic", 12)
	session.equipment.equip(worn)
	var rare: int = TestFactory.give_piece(session, &"emberbronze_sword", &"rare", 48)
	TestFactory.give_piece(session, &"head_cloth_1", &"legendary", 30)
	TestFactory.give_piece(session, &"head_cloth_1", &"common", 5)
	var screen: MainScreen = (load(SCENE) as PackedScene).instantiate() as MainScreen
	screen.session = session
	get_tree().root.add_child.call_deferred(screen)
	await _frames(4)
	(screen.find_child("PageHost", true, false) as PageHost).show_page(&"equipment")
	await _frames(8)
	_save(&"equipment")
	Tooltips.show_text("", ArmoryTexts.tooltip_text(session, rare), Vector2(520, 60))
	await _frames(6)
	_save(&"tooltip_rare")
	Tooltips.show_text("", ArmoryTexts.tooltip_text(session, worn), Vector2(80, 60))
	await _frames(6)
	_save(&"tooltip_worn")
	screen.free()
	session.free()


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().process_frame


func _save(shot: StringName) -> void:
	get_tree().root.get_texture().get_image().save_png("%s/%s.png" % [ProjectSettings.globalize_path(_out), String(shot)])
