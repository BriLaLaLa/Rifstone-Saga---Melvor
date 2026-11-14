extends GutTest
## M22-11 (docs/05_INTERFACES.md §7.q, "Tab Combattimento bloccata"): on a real GameSession with the real DungeonSystem, a run on
## (also paused) disables the Combat entry with a tooltip, sends `show_page(&"combat")` to the Dungeon page, moves the dot from
## Combat to Dungeon, opens the Dungeon page after loading a slot with a run, and gives everything back when the run ends.

const SCENE: PackedScene = preload("res://ui/screens/main/main_screen.tscn")
const TICKET: StringName = &"dungeon_ticket_monkey_den"
const STEP_MS: int = 500
const STEP_LIMIT: int = 4000

var _s: GameSession
var _screen: MainScreen


func _new_session(seed_value: int) -> GameSession:
	var s: GameSession = TestFactory.session(seed_value, TestFactory.real_data())
	TestFactory.make_roomy(s)
	TestFactory.set_character_level(s, 55)
	s.modifiers.set_source(&"test:hero", [Modifier.make(&"power_bonus", 5000.0), Modifier.make(&"max_hp_flat", 100000.0)])
	return s


func _open_screen(s: GameSession) -> void:
	_screen = SCENE.instantiate() as MainScreen
	_screen.session = s
	add_child(_screen)


func before_each() -> void:
	_s = _new_session(2211)
	_s.bank.add(TICKET, 1)


func after_each() -> void:
	if is_instance_valid(_screen):
		_screen.free()
	if is_instance_valid(_s):
		_s.free()
	await wait_physics_frames(1)


func _row(row_name: String) -> Button:
	return _screen.find_child(row_name, true, false) as Button


func _sidebar() -> Sidebar:
	return _screen.find_child("Sidebar", true, false) as Sidebar


func _host() -> PageHost:
	return _screen.find_child("PageHost", true, false) as PageHost


func _until_choice(s: GameSession) -> void:
	for _i: int in STEP_LIMIT:
		var phase: StringName = s.dungeon.state()["phase"]
		if phase == &"await" or phase == &"event":
			return
		s.advance(STEP_MS)


func test_a_run_locks_combat_moves_the_dot_and_redirects_then_gives_it_back() -> void:
	_open_screen(_s)
	assert_false(_row("Combat").disabled)
	assert_true(_s.dungeon.open(&"monkey_den").ok)
	assert_true(_row("Combat").disabled, "combat disabled with a run")
	assert_ne(_row("Combat").tooltip_text, "", "with the reason as tooltip")
	assert_true(_sidebar().is_working(&"dungeon"))
	assert_false(_sidebar().is_working(&"combat"))
	_host().show_page(&"combat")
	assert_eq(_host().current_page_id(), &"dungeon", "redirected to the Dungeon page")
	_until_choice(_s)
	assert_true(_s.dungeon.leave().ok)
	await wait_physics_frames(2)
	assert_false(_row("Combat").disabled, "combat back after the run")
	assert_false(_sidebar().is_working(&"dungeon"))


func test_loading_a_slot_with_a_run_opens_the_dungeon_page() -> void:
	assert_true(_s.dungeon.open(&"monkey_den").ok)
	_until_choice(_s)
	var twin: GameSession = _new_session(7)
	assert_true(twin.from_save(_s.to_save(0)).ok)
	assert_true(twin.dungeon.is_active() and twin.dungeon.run().paused, "loaded in pause")
	_open_screen(twin)
	assert_eq(_host().current_page_id(), &"dungeon")
	assert_true(_row("Combat").disabled, "locked also in pause")
	var old: GameSession = _s
	_s = twin
	_screen.free()
	old.free()
