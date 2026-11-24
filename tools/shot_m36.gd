extends Node
## Dev tool (M36-1): PNGs of the three tabs of the Quarrying (Minatore) and Herbalism (Erborista) pages, with "Teste" closed and open, on a
## TestFactory session (never a real slot). Needs a window (NOT --headless); always run it under a timeout:
##   timeout 120 Godot --path . --resolution 1280x720 res://tools/shot_m36.tscn -- <out_dir>

const SCENE: String = "res://ui/screens/main/main_screen.tscn"
const SKILLS: Array[StringName] = [&"quarrying", &"herbalism"]

var _out: String = "user://shots_m36"


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	await _run()
	get_tree().quit(0)


func _run() -> void:
	var session: GameSession = TestFactory.session(1234, TestFactory.real_data(), false, false)
	TestFactory.set_character_level(session, 60)
	var screen: MainScreen = await _open(session)
	(screen.find_child("HintCard", true, false) as Control).visible = false
	for skill: StringName in SKILLS:
		TestFactory.learn_discipline(session, skill)
		TestFactory.set_level(session, skill, 20)
		for action: ActionDef in session.data.actions_for_skill(skill).slice(0, 3):
			TestFactory.give(session, action.outputs[0].item_id, 40)
		var uid: int = session.armory.tool_uid(StringName("tool_%s" % skill))
		(session.armory._items[uid] as ItemInstance).upgrade = 4
		session.armory.choose_tool_head(uid, 3, _first_head(session, uid))
	var area: StringName = session.data.areas()[2].id
	print_rich("start ", area, ": ", session.combat.start(area).ok)
	for skill: StringName in SKILLS:
		(screen.find_child("PageHost", true, false) as PageHost).show_page(StringName("skill:%s" % skill))
		await _frames(8)
		var body: GatherBody = _find_body(screen)
		for tab: StringName in GatherBody.TAB_ORDER:
			body.show_tab(tab)
			await _frames(4)
			_save("%s_%s" % [skill, tab])
		var fold: FoldableSection = body.find_child("HeadsFold", true, false) as FoldableSection
		fold.set_collapsed(false)
		await _frames(4)
		_save("%s_tool_heads_open" % skill)
		fold.set_collapsed(true)
	print_rich("shots in ", ProjectSettings.globalize_path(_out))
	screen.free()
	session.free()


func _first_head(session: GameSession, uid: int) -> StringName:
	var inst: ItemInstance = session.armory.get_instance(uid)
	return session.data.item(inst.base_id).equip.heads[0].id


func _find_body(root: Node) -> GatherBody:
	return root.find_child("GatherBody", true, false) as GatherBody


func _open(session: GameSession) -> MainScreen:
	var screen: MainScreen = (load(SCENE) as PackedScene).instantiate() as MainScreen
	screen.session = session
	get_tree().root.add_child.call_deferred(screen)
	await _frames(4)
	return screen


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().process_frame


func _save(shot: String) -> void:
	get_tree().root.get_texture().get_image().save_png("%s/%s.png" % [ProjectSettings.globalize_path(_out), shot])
