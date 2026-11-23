extends Node
## Dev tool (M35-B): PNGs of the character page (traits tab, abilities tab, a tile hovered), on a TestFactory session.
## Needs a window (NOT --headless); always run it under a timeout:
##   timeout 120 Godot --path . --resolution 1280x720 res://tools/shot_m35_char.tscn -- <out_dir>

const SCENE: String = "res://ui/screens/main/main_screen.tscn"

var _out: String = "user://shots_m35_char"


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	await _run()
	get_tree().quit(0)


func _run() -> void:
	var session: GameSession = TestFactory.session(1234, TestFactory.real_data(), false, false)
	TestFactory.set_character_level(session, 20)
	var screen: MainScreen = (load(SCENE) as PackedScene).instantiate() as MainScreen
	screen.session = session
	get_tree().root.add_child.call_deferred(screen)
	await _frames(5)
	var hint_card: HintCard = screen.find_child("HintCard", true, false) as HintCard
	while hint_card != null and hint_card.current_hint() != &"":
		hint_card.close_current()
	(screen.find_child("PageHost", true, false) as PageHost).show_page(&"character")
	await _frames(6)
	var panel: LoadoutPanel = screen.find_child("LoadoutPanel", true, false) as LoadoutPanel
	var class_def: ClassDef = session.character.class_def()
	session.loadout.set_trait(0, class_def.traits[0].id)
	session.loadout.set_ability(0, class_def.abilities[0].id)
	await _frames(4)
	var scroll: ScrollContainer = screen.find_child("Scroll", true, false) as ScrollContainer
	scroll.scroll_vertical = 330
	await _frames(4)
	_save(&"traits")
	var hovered: LoadoutCard = panel.card(LoadoutPanel.KIND_TRAIT, class_def.traits[0].id)
	hovered.mouse_entered.emit()
	await _frames(4)
	_save(&"traits_hover")
	hovered.mouse_exited.emit()
	(panel.find_child("Tabs", true, false) as TabContainer).current_tab = 1
	await _frames(4)
	_save(&"abilities")
	screen.free()
	session.free()


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().process_frame


func _save(shot: StringName) -> void:
	get_tree().root.get_texture().get_image().save_png("%s/%s.png" % [ProjectSettings.globalize_path(_out), String(shot)])
