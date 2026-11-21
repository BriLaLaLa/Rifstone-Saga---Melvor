extends GutTest
## Pages closed by the tutorial (M30-04): PageHost refuses them (Log.info only), the sidebar rows are disabled with the
## tutorial hint and light up again when the tutorial ends, the first page does not break on a closed page.

const SCENE: PackedScene = preload("res://ui/screens/main/main_screen.tscn")

var _s: GameSession = null
var _screen: MainScreen = null


func after_each() -> void:
	if is_instance_valid(_screen):
		_screen.free()
	if is_instance_valid(_s):
		_s.free()
	await wait_physics_frames(1)


func _open(from_step: Dictionary) -> void:
	_s = TestFactory.session(79, TestFactory.real_data(), true, true)
	_s.tutorial.from_save(from_step)
	_screen = SCENE.instantiate() as MainScreen
	_screen.session = _s
	add_child(_screen)
	await wait_process_frames(3)


func test_host_refuses_a_closed_page_and_keeps_the_current_one() -> void:
	await _open({"completed": false, "step": "character", "visited": [], "since_ms": 0})
	var host: PageHost = _screen.find_child("PageHost", true, false) as PageHost
	var shown: StringName = host.current_page_id()
	assert_false(_s.tutorial.is_page_open(&"village"))
	host.show_page(&"village")
	assert_eq(host.current_page_id(), shown)
	host.show_page(&"character")
	assert_eq(host.current_page_id(), &"character", "the page of the step is open")
	host.show_page(&"guide")
	assert_eq(host.current_page_id(), &"guide", "the Guide is always open")


func test_sidebar_rows_of_closed_pages_are_disabled_and_reopen_at_the_end() -> void:
	await _open({"completed": false, "step": "character", "visited": [], "since_ms": 0})
	var sidebar: Sidebar = _screen.find_child("Sidebar", true, false) as Sidebar
	var closed: Button = sidebar.nav_row(&"village")
	assert_true(closed.disabled)
	assert_ne(closed.tooltip_text, "", "the row says why")
	assert_false(sidebar.nav_row(&"character").disabled)
	assert_false(sidebar.nav_row(&"guide").disabled)
	_s.tutorial.from_save({"completed": true, "step": "", "visited": []})
	_s.events.tutorial_completed.emit()
	assert_false(sidebar.nav_row(&"village").disabled, "everything open once completed")


func test_a_loaded_slot_whose_first_page_is_closed_shows_the_page_of_the_step() -> void:
	await _open({"completed": false, "step": "combat_start", "visited": ["character"], "since_ms": 0})
	var host: PageHost = _screen.find_child("PageHost", true, false) as PageHost
	assert_eq(host.current_page_id(), &"combat")
