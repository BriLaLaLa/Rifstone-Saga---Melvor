extends Node
## Dev tool (M38-3): PNGs of the Auction House detail (Compra: available, sold out, huge-purchase confirmation) on a test session
## (never a real slot), the panel alone at the width it has in the page. Needs a window (NOT --headless); run it under a timeout:
##   timeout 120 Godot --path . --resolution 1280x720 res://tools/shot_m38_detail.tscn -- <out_dir>

const AuctionTestData := preload("res://tests/systems/auction/auction_test_data.gd")
const PANEL_WIDTH: float = 520.0

var _out: String = "user://shots_m38_detail"


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	await _run()
	get_tree().quit(0)


func _run() -> void:
	var session: GameSession = AuctionTestData.session(10)
	session.wallet.add_gold(900000000)
	var bg: Control = Control.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	get_tree().root.add_child.call_deferred(bg)
	await _frames(2)
	var holder: Control = Control.new()
	holder.size = Vector2(PANEL_WIDTH, get_tree().root.size.y)
	bg.add_child(holder)
	var detail: AuctionDetail = AuctionDetail.new()
	detail.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(detail)
	var item: StringName = _pick(session)
	var buy_all: int = int(session.auction.available(item))
	detail.refresh(session.auction, session, &"buy", item)
	await _frames(4)
	_save("buy_available")
	(detail.find_child("SectionButton_market", true, false) as Button).pressed.emit()
	await _frames(4)
	_save("buy_market")
	(detail.find_child("SectionButton_now", true, false) as Button).pressed.emit()
	(detail.find_child("QtySpin", true, false) as SpinBox).value = buy_all
	await _frames(2)
	(detail.find_child("TradeButton", true, false) as Button).pressed.emit()
	await _frames(6)
	_save("buy_confirm")
	(detail.find_child("BuyConfirm", true, false) as Window).hide()
	session.auction.buy(item, buy_all)
	detail.refresh(session.auction, session, &"buy", item)
	await _frames(4)
	_save("buy_soldout")
	print_rich("shots in ", ProjectSettings.globalize_path(_out))
	bg.queue_free()
	session.free()


## The buyable item with the most pieces on the book (so the book rows and the large purchase are visible).
func _pick(session: GameSession) -> StringName:
	var best: StringName = &""
	var most: int = -1
	for id: StringName in session.auction.buyable_items():
		var left: int = int(session.auction.available(id))
		if left > most and session.auction.buy_level(id) <= session.auction.level():
			best = id
			most = left
	return best


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().process_frame


func _save(shot: String) -> void:
	get_tree().root.get_texture().get_image().save_png("%s/%s.png" % [ProjectSettings.globalize_path(_out), shot])
