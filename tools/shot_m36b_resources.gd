extends Node
## Dev tool (M36-2): PNGs of the compact resource list of the Quarrying page: closed, one row open, a row locked by level (open).
## Needs a window (NOT --headless); always run it under a timeout:
##   timeout 120 Godot --path . --resolution 1280x720 res://tools/shot_m36b_resources.tscn -- <out_dir>

const SCENE: String = "res://ui/screens/main/main_screen.tscn"
const SKILL: StringName = &"quarrying"

var _out: String = "user://shots_m36b_resources"


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	await _run()
	get_tree().quit(0)


func _run() -> void:
	var session: GameSession = TestFactory.session(1234, TestFactory.real_data(), false, false)
	TestFactory.learn_discipline(session, SKILL)
	TestFactory.set_level(session, SKILL, 12)
	var screen: MainScreen = (load(SCENE) as PackedScene).instantiate() as MainScreen
	screen.session = session
	get_tree().root.add_child.call_deferred(screen)
	await _frames(4)
	(screen.find_child("HintCard", true, false) as Control).visible = false
	(screen.find_child("PageHost", true, false) as PageHost).show_page(StringName("skill:%s" % SKILL))
	await _frames(8)
	var table: ResourceTable = screen.find_child("ResourceTable", true, false) as ResourceTable
	var scroll: ScrollContainer = _scroll_of(screen)
	scroll.scroll_vertical = 100000
	await _frames(4)
	_save(&"closed")
	var ids: Array[StringName] = table.row_ids()
	(table.find_child("ResourceRow_%s" % ids[0], true, false) as ResourceRow).header_clicked.emit(ids[0])
	await _frames(6)
	await _frames(2)
	scroll.scroll_vertical = 100000
	await _frames(4)
	_save(&"open")
	var last: StringName = ids[ids.size() - 1]
	(table.find_child("ResourceRow_%s" % last, true, false) as ResourceRow).header_clicked.emit(last)
	await _frames(6)
	scroll.scroll_vertical = 100000
	await _frames(4)
	_save(&"locked")
	screen.free()
	session.free()


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().process_frame


func _save(shot: StringName) -> void:
	get_tree().root.get_texture().get_image().save_png("%s/%s.png" % [ProjectSettings.globalize_path(_out), String(shot)])


func _scroll_of(screen: Node) -> ScrollContainer:
	for node: Node in screen.find_children("*", "", true, false):
		if node is SkillPage:
			return (node as SkillPage).get_node("%Scroll") as ScrollContainer
	return null
