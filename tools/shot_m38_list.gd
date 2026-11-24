extends Node
## Dev tool (M38-4): PNGs of the Auction House page (Compra with one sold-out item and one with a +% on the average) on a test
## session with a stand-in module (never a real slot). Needs a window (NOT --headless); run it under a timeout:
##   timeout 120 Godot --path . --resolution 1280x720 res://tools/shot_m38_list.tscn -- <out_dir>

const AuctionTestData := preload("res://tests/systems/auction/auction_test_data.gd")
const SIDEBAR_WIDTH: float = 240.0

var _out: String = "user://shots_m38_list"


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	await _run()
	get_tree().quit(0)


func _run() -> void:
	var session: GameSession = AuctionTestData.session(10)
	var buyable: Array[StringName] = session.auction.buyable_items()
	var stub: AuctionStub = AuctionStub.new(session.auction.listed_items(), buyable)
	stub.level_value = 10
	stub.available_value = 1193
	stub.sold_out = {buyable[1]: true}
	stub.gap_by_item = {buyable[0]: 18, buyable[2]: -9, buyable[3]: AuctionHouse.NO_GAP}
	var holder: Control = Control.new()
	holder.size = Vector2(get_tree().root.size.x - SIDEBAR_WIDTH, get_tree().root.size.y)
	add_child(holder)
	var page: AuctionPage = preload("res://ui/pages/auction/auction_page.tscn").instantiate()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(page)
	page.bind_with(session, stub)
	await _frames(6)
	_save("buy_list")
	page.find_child("Tab_sell", true, false).pressed.emit()
	await _frames(4)
	_save("sell_list")
	print_rich("shots in ", ProjectSettings.globalize_path(_out))
	holder.queue_free()
	session.free()


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().process_frame


func _save(shot: String) -> void:
	get_tree().root.get_texture().get_image().save_png("%s/%s.png" % [ProjectSettings.globalize_path(_out), shot])
