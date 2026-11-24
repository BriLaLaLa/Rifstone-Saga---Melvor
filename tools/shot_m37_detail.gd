extends Node
## Dev tool (M37-3): PNGs of the Auction House detail panel (Compra and Vendi, every section, an outcome message) on a test session
## (never a real slot). Needs a window (NOT --headless); always run it under a timeout:
##   timeout 120 Godot --path . --resolution 1280x720 res://tools/shot_m37_detail.tscn -- <out_dir>

const SCENE: String = "res://ui/screens/main/main_screen.tscn"
const AuctionTestData := preload("res://tests/systems/auction/auction_test_data.gd")

var _out: String = "user://shots_m37_detail"


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	await _run()
	get_tree().quit(0)


func _run() -> void:
	var session: GameSession = AuctionTestData.session(10)
	var listed: Array[StringName] = session.auction.listed_items()
	for id: StringName in listed.slice(0, 14):
		TestFactory.give(session, id, 40)
	session.wallet.add_gold(250000)
	var screen: MainScreen = (load(SCENE) as PackedScene).instantiate() as MainScreen
	screen.session = session
	get_tree().root.add_child.call_deferred(screen)
	await _frames(4)
	(screen.find_child("HintCard", true, false) as Control).visible = false
	(screen.find_child("PageHost", true, false) as PageHost).show_page(&"auction")
	await _frames(6)
	var page: Node = screen.find_children("*", "AuctionPage", true, false)[0]
	for tab: StringName in [&"buy", &"sell"]:
		(page.find_child("Tab_%s" % tab, true, false) as Button).pressed.emit()
		await _frames(3)
		var row: AuctionRow = page.find_child("Rows", true, false).get_child(0) as AuctionRow
		row.row_clicked.emit(row.item_id)
		for section: StringName in [&"now", &"list", &"market"]:
			var button: Button = page.find_child("SectionButton_%s" % section, true, false) as Button
			if not button.is_visible_in_tree():
				continue
			button.pressed.emit()
			await _frames(4)
			_save("%s_%s" % [tab, section])
		(page.find_child("SectionButton_now", true, false) as Button).pressed.emit()
		(page.find_child("TradeButton", true, false) as Button).pressed.emit()
		await _frames(4)
		_save("%s_message" % tab)
	print_rich("shots in ", ProjectSettings.globalize_path(_out))
	screen.free()
	session.free()


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().process_frame


func _save(shot: String) -> void:
	get_tree().root.get_texture().get_image().save_png("%s/%s.png" % [ProjectSettings.globalize_path(_out), shot])
