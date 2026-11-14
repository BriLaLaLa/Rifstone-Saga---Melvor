extends GutTest
## M22-06 integration: the DungeonPage on a real GameSession with the real DungeonSystem and combat engine (not the stub):
## entry -> choice -> fight views through a whole run of the Covo delle Scimmie with a fixed seed, down to the boss stages, the
## "Riprendi" button after a save/load of the session, the `dungeon` route of the PageHost and the sidebar entry.

const TICKET: StringName = &"dungeon_ticket_monkey_den"
const HERO: StringName = &"test:hero"
const STEP_MS: int = 500
const STEP_LIMIT: int = 30000

var _s: GameSession
var _page: DungeonPage


func _new_session(seed_value: int) -> GameSession:
	var s: GameSession = TestFactory.session(seed_value, TestFactory.real_data())
	TestFactory.make_roomy(s)
	TestFactory.set_character_level(s, 55)
	s.modifiers.set_source(HERO, [Modifier.make(&"power_bonus", 5000.0), Modifier.make(&"max_hp_flat", 100000.0)])
	(s.data._balance["dungeon"] as Dictionary)["reveal_ms"] = 3000  # until the real data has it (M22-10)
	return s


func _bind(s: GameSession) -> void:
	_page = (load("res://ui/pages/dungeon/dungeon_page.tscn") as PackedScene).instantiate() as DungeonPage
	_page.page_id = &"dungeon"
	add_child(_page)
	_page.bind(s)


func before_each() -> void:
	_s = _new_session(2211)
	_s.bank.add(TICKET, 1)
	_bind(_s)


func after_each() -> void:
	if is_instance_valid(_page):
		_page.free()
	if is_instance_valid(_s):
		_s.free()
	await wait_physics_frames(1)


func _visible(view_name: String) -> bool:
	return (_page.find_child(view_name, true, false) as Control).visible


func _buttons(prefix: String) -> Array[Button]:
	var result: Array[Button] = []
	for node: Node in _page.find_children("%s*" % prefix, "Button", true, false):
		if not node.is_queued_for_deletion():
			result.append(node as Button)
	return result


func _views() -> String:
	return "%s%s%s" % ["E" if _visible("EntryView") else "", "C" if _visible("ChoiceView") else "", "F" if _visible("FightView") else ""]


func test_the_page_follows_a_whole_run_through_its_three_views() -> void:
	assert_eq(_views(), "E")
	assert_eq(_buttons("EnterButton").size(), 1)
	_buttons("EnterButton")[0].pressed.emit()
	assert_true(_s.dungeon.is_active())
	var seen: Dictionary = {}
	var boss_stage: bool = false
	var steps: int = 0
	while _s.dungeon.is_active() and steps < STEP_LIMIT:
		_page.refresh()
		var phase: StringName = _s.dungeon.state()["phase"]
		var views: String = _views()
		seen[views] = true
		if phase == &"await" or phase == &"event":
			assert_eq(views, "C", "choice view in %s" % phase)
			var choices: Array[Button] = _buttons("Choice_")
			assert_between(choices.size(), 2, 4)
			choices[0].pressed.emit()
		else:
			assert_eq(views, "F", "fight view in %s" % phase)
			if _s.dungeon.state().has("stage"):
				boss_stage = true
			_s.advance(STEP_MS)
		steps += 1
	assert_false(_s.dungeon.is_active(), "the run ends")
	assert_true(boss_stage, "the boss stages were reached through the page")
	assert_true(seen.has("C") and seen.has("F"))
	_page.refresh()
	assert_eq(_views(), "E", "back to the entry after the run")


func test_resume_button_after_a_save_and_load_of_the_session() -> void:
	assert_true(_s.dungeon.open(&"monkey_den").ok)
	for _i: int in 4000:
		var phase: StringName = _s.dungeon.state()["phase"]
		if phase == &"await" or phase == &"event":
			break
		_s.advance(STEP_MS)
	var saved: Dictionary = _s.to_save(0)
	var twin: GameSession = _new_session(7)
	var loaded: CommandResult = twin.from_save(saved)
	assert_true(loaded.ok, "the session loads")
	_page.unbind()
	_page.free()
	_bind(twin)
	var old: GameSession = _s
	_s = twin
	old.free()
	assert_true(twin.dungeon.is_active())
	assert_true(twin.dungeon.run().paused, "loaded paused")
	var resume: Button = _page.find_child("ResumeButton", true, false) as Button
	assert_true(resume.is_visible_in_tree())
	resume.pressed.emit()
	assert_false(twin.dungeon.run().paused)
	assert_ne(_views(), "E")


func test_route_and_sidebar_entry() -> void:
	var host: PageHost = PageHost.new()
	add_child(host)
	host.setup(_s)
	assert_true(host.has_page(&"dungeon"))
	host.show_page(&"dungeon")
	assert_eq(host.current_page_id(), &"dungeon")
	var pages: Array = Sidebar.SECTIONS.map(func(e: Dictionary) -> StringName: return e["page"])
	assert_true(pages.has(&"dungeon"))
	assert_eq(pages.find(&"dungeon"), pages.find(&"fractures") + 1, "right after Fratture")
	host.free()
