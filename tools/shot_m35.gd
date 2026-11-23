extends Node
## Dev tool (M35-D3, M35B-3): PNGs of the Quarrying page (resource table in a low and in a high zone, "Teste" section) and of the node card, on a TestFactory
## session (never a real slot). Needs a window (NOT --headless); always run it under a timeout:
##   timeout 120 Godot --path . --resolution 1280x720 res://tools/shot_m35.tscn -- <out_dir>

const SCENE: String = "res://ui/screens/main/main_screen.tscn"
const SKILL: StringName = &"quarrying"
const AREA: StringName = &"redrock_plains"

var _out: String = "user://shots_m35"


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
	TestFactory.set_level(session, SKILL, 20)
	for action: ActionDef in session.data.actions_for_skill(SKILL).slice(0, 3):
		TestFactory.give(session, action.outputs[0].item_id, 40)
	var uid: int = session.armory.tool_uid(&"tool_quarrying")
	(session.armory._items[uid] as ItemInstance).upgrade = 4
	session.armory.choose_tool_head(uid, 3, &"pick_vein")
	var screen: MainScreen = await _open(session)
	var hint: Control = screen.find_child("HintCard", true, false) as Control
	hint.visible = false
	(screen.find_child("PageHost", true, false) as PageHost).show_page(StringName("skill:%s" % SKILL))
	await _frames(8)
	_save(&"skill_table")
	TestFactory.set_character_level(session, 60)
	var areas: Array[AreaDef] = session.data.areas()
	var scroll_table: ScrollContainer = _find_page(screen).get_node("%Scroll") as ScrollContainer
	var high: StringName = areas[0].id
	for i: int in range(areas.size() - 1, -1, -1):  # the highest zone the test character may enter
		if session.combat.start(areas[i].id).ok:
			high = areas[i].id
			break
	for pair: Array in [[&"skill_table_low", areas[0].id], [&"skill_table_high", high]]:
		session.combat.stop()
		print("start ", pair[1], ": ", session.combat.start(StringName(pair[1])).ok)
		await _frames(6)
		scroll_table.scroll_vertical = 100000
		await _frames(4)
		_save(StringName(pair[0]))
	session.combat.stop()
	var page: SkillPage = _find_page(screen)
	var scroll: ScrollContainer = page.get_node("%Scroll") as ScrollContainer
	scroll.scroll_vertical = 100000
	await _frames(4)
	_save(&"skill_heads")
	TestFactory.learn_discipline(session, &"forestry")
	TestFactory.set_level(session, &"forestry", 20)
	var found: bool = false
	for _i: int in 40000:
		if session.combat.state() == CombatEngine.STATE_IDLE:
			session.combat.start(AREA)
		session.advance(250)
		var node: Dictionary = session.combat.get_state()["node"]
		if session.combat.state() == CombatEngine.STATE_NODE and not bool(node["skipped"]) and StringName(node["skill"]) == SKILL:
			found = true
			break
	(screen.find_child("PageHost", true, false) as PageHost).show_page(&"combat")
	hint.visible = false
	await _frames(8)
	_save(&"node_card")
	print_rich("shots in ", ProjectSettings.globalize_path(_out))
	screen.free()
	session.free()


func _find_page(root: Node) -> SkillPage:
	for node: Node in root.find_children("*", "", true, false):
		if node is SkillPage:
			return node as SkillPage
	return null


func _open(session: GameSession) -> MainScreen:
	var screen: MainScreen = (load(SCENE) as PackedScene).instantiate() as MainScreen
	screen.session = session
	get_tree().root.add_child.call_deferred(screen)
	await _frames(4)
	return screen


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().process_frame


func _save(shot: StringName) -> void:
	get_tree().root.get_texture().get_image().save_png("%s/%s.png" % [ProjectSettings.globalize_path(_out), String(shot)])
