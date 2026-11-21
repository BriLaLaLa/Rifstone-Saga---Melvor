extends GutTest
## Fracture bag list (M29-02): the Fractures page and the Combat strip show what drops during a Fracture; a REAL click on a piece
## row opens its detail; nothing can be withdrawn. Real data session, no exact texts.

const MAIN: PackedScene = preload("res://ui/screens/main/main_screen.tscn")

var _s: GameSession = null
var _screen: MainScreen = null


func before_each() -> void:
	_s = TestFactory.session(91, TestFactory.real_data())
	TestFactory.make_roomy(_s)
	TestFactory.set_character_level(_s, 30)
	_screen = MAIN.instantiate() as MainScreen
	_screen.session = _s
	add_child(_screen)
	for layer: Node in get_tree().root.find_children("GutLayer", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	await wait_process_frames(3)


func after_each() -> void:
	if is_instance_valid(_screen):
		_screen.free()
	if is_instance_valid(_s):
		_s.free()
	await wait_physics_frames(1)


func test_model_reads_the_bag_without_exposing_it() -> void:
	assert_true(_s.fractures.bag_contents().is_empty(), "nothing outside a Fracture")
	assert_true(BagFill.open_and_fill(_s))
	var contents: Dictionary = _s.fractures.bag_contents()
	assert_eq((contents["stacks"] as Array).size(), 3)
	assert_eq((contents["pieces"] as Array).size(), 1)
	assert_eq((contents["cards"] as Array).size(), 1)
	(contents["pieces"] as Array[ItemInstance]).clear()
	assert_eq(_s.fractures.bag_contents()["pieces"].size(), 1, "a copy: the bag is not changed from outside")


func test_page_lists_every_drop_and_a_real_click_opens_the_piece_detail() -> void:
	var host: PageHost = _screen.find_child("PageHost", true, false) as PageHost
	assert_true(BagFill.open_and_fill(_s))
	host.show_page(&"fractures")
	await wait_process_frames(3)
	var page: FracturesPage = _screen.find_child("Page", true, false) as FracturesPage
	var list: FractureBagList = page.find_child("BagList", true, false) as FractureBagList
	assert_eq(list.get_child_count(), 5, "three stacks, a piece and a Card")
	assert_not_null(list.find_child("Piece_0", true, false))
	assert_not_null(list.find_child("Card_0", true, false))
	assert_null(list.find_child("Detail", true, false))
	# a new drop appears at once (signal)
	_s.fractures.run().bag.add_stack(&"rift_dust", 5)
	_s.events.fracture_bag_changed.emit(4, 1, 1)
	await wait_process_frames(2)
	assert_eq(list.get_child_count(), 6)
	await _dismiss_hints()
	var row: Control = list.find_child("Piece_0", true, false) as Control
	await _click(row)
	assert_not_null(list.find_child("Detail", true, false), "the click opened the detail")
	await _click(list.find_child("Piece_0", true, false) as Control)
	assert_null(list.find_child("Detail", true, false), "a second click closes it")


func test_combat_strip_shows_the_fracture_bag_and_cannot_collect() -> void:
	var host: PageHost = _screen.find_child("PageHost", true, false) as PageHost
	assert_true(BagFill.open_and_fill(_s))
	host.show_page(&"combat")
	await wait_process_frames(3)
	var cells: Array[Node] = _screen.find_children("*", "ItemSlotView", true, false).filter(
			func(n: Node) -> bool: return (n.get_parent() as Node).name == "LootList")
	assert_gt(cells.size(), 0, "the drops of the Fracture are drawn in the strip")
	assert_true((_screen.find_child("CollectButton", true, false) as Button).disabled)


func test_unbind_disconnects_the_bag_signal() -> void:
	var host: PageHost = _screen.find_child("PageHost", true, false) as PageHost
	host.show_page(&"fractures")
	var page: FracturesPage = _screen.find_child("Page", true, false) as FracturesPage
	var before: int = _s.events.fracture_bag_changed.get_connections().size()
	page.unbind()
	assert_eq(_s.events.fracture_bag_changed.get_connections().size(), before - 1)


func _click(control: Control) -> void:
	var at: Vector2 = control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	get_viewport().push_input(motion, true)
	await wait_process_frames(1)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.position = at
		event.global_position = at
		get_viewport().push_input(event, true)
		await wait_process_frames(1)
	await wait_process_frames(3)


## The first-visit hint cards cover the page: dismiss them as the player does.
func _dismiss_hints() -> void:
	for hint: Node in _screen.find_children("*", "Button", true, false):
		if (hint as Button).text == "Ho capito" and hint.is_visible_in_tree():
			(hint as Button).pressed.emit()
	await wait_process_frames(2)
