extends Node
## Dev tool (M37-4): PNGs of the Auction House list (Compra, Vendi), "Le mie vendite" (Attive, Storico) and the full Mailbox notice, on a
## TestFactory session (never a real slot). Needs a window (NOT --headless); always run it under a timeout:
##   timeout 120 Godot --path . --resolution 1280x720 res://tools/shot_m37_page.tscn -- <out_dir>

const SCENE: String = "res://ui/screens/main/main_screen.tscn"
const AuctionTestData := preload("res://tests/systems/auction/auction_test_data.gd")

var _out: String = "user://shots_m37_page"


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	await _run()
	get_tree().quit(0)


func _run() -> void:
	var session: GameSession = AuctionTestData.session(3)
	TestFactory.make_roomy(session)
	session.wallet.add_gold(5000000)
	var listed: Array[StringName] = session.auction.listed_items()
	for index: int in mini(14, listed.size()):
		TestFactory.give(session, listed[index], 3 + index * 7)
	# History: two instant sales, one listing cancelled, one listing left active.
	print_rich("sell ", session.auction.sell(listed[0], 2).ok, " ", session.auction.sell(listed[1], 1).ok)
	var cancelled: CommandResult = session.auction.list_item(listed[2], 2, session.auction.suggested_price(listed[2]), session.auction.durations()[0].id)
	print_rich("list ", cancelled.ok)
	if not session.auction.my_listings().is_empty():
		session.auction.cancel_listing(int(session.auction.my_listings()[0]["id"]))
	for index: int in [3, 4]:
		session.auction.list_item(listed[index], 3, session.auction.suggested_price(listed[index]), session.auction.durations()[0].id)
	session.mail.post(&"auction_cancelled", {"item": listed[5], "qty": 1, "items": [{"item": listed[5], "qty": 1}]})
	var screen: MainScreen = await _open(session)
	var host: PageHost = screen.find_child("PageHost", true, false) as PageHost
	host.show_page(&"auction")
	await _frames(8)
	var page: Control = host.get_child(host.get_child_count() - 1) as Control
	_save("1_compra")
	(page.find_child("Tab_sell", true, false) as Button).pressed.emit()
	await _frames(6)
	(page.find_child("Items", true, false).find_child("Row_%s" % listed[1], true, false) as Control).gui_input.emit(_click())
	await _frames(6)
	_save("2_vendi")
	(page.find_child("Tab_mine", true, false) as Button).pressed.emit()
	await _frames(6)
	_save("3_mine_attive")
	(page.find_child("Tab_history", true, false) as Button).pressed.emit()
	await _frames(6)
	_save("4_mine_storico")
	while not session.mail.is_full():
		session.mail.post(&"auction_cancelled", {"item": listed[5], "qty": 1, "items": [{"item": listed[5], "qty": 1}]})
	(page.find_child("Tab_buy", true, false) as Button).pressed.emit()
	await _frames(8)
	_save("5_posta_piena")
	print_rich("shots in ", ProjectSettings.globalize_path(_out))
	screen.free()
	session.free()


func _click() -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	return event


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
