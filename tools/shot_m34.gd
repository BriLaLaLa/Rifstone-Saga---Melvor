extends Node
## Dev tool (M34-02): PNGs of the Deposit (empty panel / with a selection) and of the tutorial card (Salta tutorial, confirmation), on a
## TestFactory session (never a real slot). Needs a window (NOT --headless); always run it under a timeout:
##   timeout 120 Godot --path . --resolution 1280x720 res://tools/shot_m34.tscn -- <out_dir>

const SCENE: String = "res://ui/screens/main/main_screen.tscn"
const ITEM: StringName = &"dungeon_ticket_monkey_den"

var _out: String = "user://shots_m34"


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	await _run()
	get_tree().quit(0)


func _run() -> void:
	var session: GameSession = TestFactory.session(1234, TestFactory.real_data(), false, false)
	TestFactory.give(session, ITEM, 4)
	TestFactory.give(session, &"redrock_clover", 7)
	TestFactory.give(session, &"stone_ember_chip", 2)
	for rarity: StringName in [&"magic", &"rare", &"legendary"]:
		TestFactory.give_piece(session, &"head_cloth_1", rarity, 30)
	var screen: MainScreen = await _open(session)
	(screen.find_child("PageHost", true, false) as PageHost).show_page(&"bank")
	await _frames(8)
	_save(&"bank_empty")
	var grid: Control = screen.find_child("Grid", true, false) as Control
	for child: Node in grid.get_children():
		if child is ItemSlotView and (child as ItemSlotView).item_id() == ITEM:
			(child as ItemSlotView).pressed.emit(ITEM)
	await _frames(8)
	_save(&"bank_selected")
	for id: StringName in [&"redrock_clover", &"stone_ember_chip"]:
		for child: Node in grid.get_children():
			if child is ItemSlotView and (child as ItemSlotView).item_id() == id:
				(child as ItemSlotView).pressed.emit(id)
		await _frames(8)
		_save(StringName("bank_" + String(id)))
	screen.free()
	session.free()
	await _frames(2)
	var tutorial: GameSession = TestFactory.session(1234, TestFactory.real_data(), true, true)
	var screen2: MainScreen = await _open(tutorial)
	await _frames(8)
	_save(&"card_skip")
	var card: TutorialPanel = screen2.find_child("Card", true, false) as TutorialPanel
	card.find_child("SkipTutorialButton", true, false).pressed.emit()
	await _frames(8)
	_save(&"card_confirm")
	card.find_child("ConfirmNoButton", true, false).pressed.emit()
	tutorial.tutorial.acknowledge()
	await _frames(8)
	_save(&"card_goto")
	print_rich("shots in ", ProjectSettings.globalize_path(_out))
	screen2.free()
	tutorial.free()


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
