extends GutTest
## M34-02b: for EVERY item of the real data in the bank, selecting it leaves the size and position of the Deposit item panel, the
## grid and its body identical to the empty state (the panel is a fixed column; the content scrolls). A few selections are REAL clicks.

const SCENE: PackedScene = preload("res://ui/screens/main/main_screen.tscn")

var _s: GameSession = null
var _screen: MainScreen = null


func after_each() -> void:
	if is_instance_valid(_screen):
		_screen.free()
	if is_instance_valid(_s):
		_s.free()
	await wait_physics_frames(1)


func test_every_item_leaves_the_layout_unchanged() -> void:
	_s = TestFactory.session(77, TestFactory.real_data(), true)
	TestFactory.make_roomy(_s)
	# pieces with free sockets: the stone selection lists them in an OptionButton (long labels)
	for base: StringName in [&"head_cloth_1", &"body_cloth_1", &"legs_cloth_1"]:
		for rarity: StringName in [&"magic", &"rare", &"legendary"]:
			TestFactory.give_piece(_s, base, rarity, 30)
	var ids: Array[StringName] = []
	for def: ItemDef in _s.data.items():
		if _s.bank.add(def.id, 2).ok:
			ids.append(def.id)
	_screen = SCENE.instantiate() as MainScreen
	_screen.session = _s
	add_child(_screen)
	for layer: Node in get_tree().root.find_children("GutLayer", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	await wait_process_frames(3)
	(_screen.find_child("PageHost", true, false) as PageHost).show_page(&"bank")
	await wait_process_frames(3)
	var page: BankPage = _screen.find_child("Page", true, false) as BankPage
	var panel: BankItemPanel = page.find_child("ItemPanel", true, false) as BankItemPanel
	var grid: Control = page.find_child("Grid", true, false) as Control
	var body: Control = grid.get_parent().get_parent() as Control
	var empty: Array[Rect2] = _rects(panel, grid, body)
	assert_gt(ids.size(), 10)
	var bad: Array[String] = []
	for id: StringName in ids:
		panel.show_item(_s, id)
		await wait_process_frames(2)
		if _rects(panel, grid, body) != empty:
			bad.append("%s %s" % [id, _rects(panel, grid, body)])
	assert_eq(bad.size(), 0, "layout changed for: %s (empty %s)" % [bad.slice(0, 6), empty])
	# no horizontal overflow inside the panel: the content never wants more width than the column gives
	var content: Control = panel.find_child("Content", true, false) as Control
	panel.show_item(_s, ids[0])
	await wait_process_frames(2)
	assert_lte(content.get_combined_minimum_size().x, panel.size.x, "content fits the column")


func _rects(panel: Control, grid: Control, body: Control) -> Array[Rect2]:
	return [panel.get_global_rect(), grid.get_global_rect(), body.get_global_rect()]
