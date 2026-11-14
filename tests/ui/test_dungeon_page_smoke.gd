extends GutTest
## DungeonPage (M22-06, docs/05_INTERFACES.md §7.q) bound to the DungeonStub (same signatures as `DungeonSystem`): the three views
## by phase, 2-4 direction buttons, two for an event, "Riprendi" when paused, "Fuggi" and "Esci" ask a confirmation, the boss
## intro card, the refusal of "Entra" in Italian, no game state in the UI. No exact texts checked, except the refusal.

const SCENE: PackedScene = preload("res://ui/pages/dungeon/dungeon_page.tscn")

var _session: GameSession
var _stub: DungeonStub
var _page: DungeonPage


func before_each() -> void:
	_session = TestFactory.session(1234, TestFactory.real_data())
	_stub = DungeonStub.new()
	_page = SCENE.instantiate() as DungeonPage
	_page.page_id = &"dungeon"
	add_child(_page)
	_page.bind_with(_session, _stub)


func after_each() -> void:
	if is_instance_valid(_page):
		_page.free()
	if is_instance_valid(_session):
		_session.free()
	await wait_physics_frames(1)


func _view(view_name: String) -> Control:
	return _page.find_child(view_name, true, false) as Control


func _buttons(prefix: String) -> Array[Button]:
	var result: Array[Button] = []
	for node: Node in _page.find_children("%s*" % prefix, "Button", true, false):
		if not node.is_queued_for_deletion():
			result.append(node as Button)
	return result


func _show(phase: StringName, directions: int = 3, kind: StringName = &"pack", paused: bool = false) -> void:
	_stub.set_phase(phase, directions, kind, paused)
	_page.refresh()


func _dialog() -> ConfirmDialog:
	for child: Node in _page.get_children():
		if child is ConfirmDialog:
			return child as ConfirmDialog
	return null


func test_entry_view_without_a_run_and_enter_refusal_is_in_italian() -> void:
	assert_true(_view("EntryView").visible)
	assert_false(_view("ChoiceView").visible)
	assert_false(_view("FightView").visible)
	var button: Button = _buttons("EnterButton")[0]
	_stub.forced_reason = Reasons.NOT_ENOUGH_ITEMS
	button.pressed.emit()
	assert_eq(_stub.calls.get(&"open", 0), 1)
	assert_eq((_page.find_child("MessageLabel", true, false) as Label).text, DungeonTexts.refusal(Reasons.NOT_ENOUGH_ITEMS))


func test_pending_loot_box_has_a_collect_button() -> void:
	_stub.pending_data = {"stacks": [], "pieces": 1, "cards": 0}
	_page.refresh()
	assert_eq(_buttons("CollectButton").size(), 1)
	_buttons("CollectButton")[0].pressed.emit()
	assert_eq(_stub.calls.get(&"collect", 0), 1)


func test_fork_has_one_button_per_direction_and_choose_sends_its_index() -> void:
	for count: int in [2, 3, 4]:
		_show(&"await", count)
		assert_true(_view("ChoiceView").visible)
		assert_false(_view("EntryView").visible)
		assert_eq(_buttons("Choice_").size(), count, "%d exits" % count)
	_buttons("Choice_")[2].pressed.emit()
	assert_eq(_stub.last_choice, 2)
	assert_eq(_stub.calls.get(&"choose", 0), 1)


func test_events_have_two_buttons() -> void:
	_show(&"event", 0, &"trap")
	assert_eq(_buttons("Choice_").size(), 2)
	_show(&"event", 0, &"rest")
	assert_eq(_buttons("Choice_").size(), 2)


func test_leave_button_asks_for_confirmation_before_the_command() -> void:
	_show(&"await", 3)
	_buttons("LeaveButton")[0].pressed.emit()
	await wait_physics_frames(1)
	var dialog: ConfirmDialog = _dialog()
	assert_not_null(dialog, "confirmation shown")
	assert_eq(_stub.calls.get(&"leave", 0), 0)
	dialog.confirmed.emit()
	await wait_physics_frames(1)
	assert_eq(_stub.calls.get(&"leave", 0), 1)


func test_fight_view_flee_asks_for_confirmation_and_cancel_does_nothing() -> void:
	_show(&"fight", 0, &"pack")
	assert_true(_view("FightView").visible)
	assert_false(_view("ChoiceView").visible)
	_page._process(0.0)
	_buttons("FleeButton")[0].pressed.emit()
	await wait_physics_frames(1)
	var dialog: ConfirmDialog = _dialog()
	assert_not_null(dialog)
	dialog.canceled.emit()
	await wait_physics_frames(1)
	assert_eq(_stub.calls.get(&"flee", 0), 0)


func test_boss_intro_shows_the_card_and_hides_the_enemies() -> void:
	_show(&"intro", 0, &"boss")
	var fight: DungeonFightView = _view("FightView") as DungeonFightView
	assert_true(fight.visible)
	_page._process(0.0)
	assert_true(fight.intro_visible())
	assert_false(fight.grid().visible)
	assert_true(fight.boss_bar().visible, "the band stays during the intro")
	_show(&"fight", 0, &"boss")
	_page._process(0.0)
	assert_false(fight.intro_visible())
	assert_true(fight.grid().visible)


func test_boss_band_shows_the_act_and_the_three_acts() -> void:
	_show(&"fight", 0, &"boss")
	_stub.set_phase(&"fight", 0, &"boss", false, 2)
	_page.refresh()
	var fight: DungeonFightView = _view("FightView") as DungeonFightView
	var bar: DungeonBossBar = fight.boss_bar()
	assert_true(bar.visible)
	assert_eq((_view("BossHeader") as Label).text, DungeonTexts.boss_header(2, 3))
	assert_eq(bar.act_count(), 3)
	assert_eq([bar.act_state(1), bar.act_state(2), bar.act_state(3)], [&"passed", &"current", &"next"])
	assert_eq((_view("ProgressLabel") as Label).text, DungeonTexts.PROGRESS_FINAL_TEXT)
	_show(&"fight", 0, &"pack")
	_page._process(0.0)
	assert_false(bar.visible, "no band outside the boss")
	_stub.set_phase(&"intro", 0, &"boss", false, 3)
	_page.refresh()
	_page._process(0.0)
	assert_true((_view("IntroCard") as DungeonIntroCard).is_final_look(), "the last act is stronger")


func test_food_and_eat_are_in_the_page_header_in_every_phase() -> void:
	for phase: StringName in [&"", &"await", &"event", &"fight", &"intro"]:
		_show(phase, 3, &"trap" if phase == &"event" else &"pack")
		_page._process(0.0)
		assert_true((_view("FoodLabel") as Label).is_visible_in_tree(), "food in %s" % phase)
		assert_eq((_view("EatButton") as Button).visible, phase != &"", "eat button with a run: %s" % phase)
	_show(&"await", 3)
	(_view("EatButton") as Button).pressed.emit()
	assert_true((_view("MessageLabel") as Label).visible, "a refused meal shows its reason")


func test_reveal_banner_follows_the_room_entered_and_goes_away() -> void:
	var banner: DungeonRevealBanner = _view("RevealBanner") as DungeonRevealBanner
	_show(&"fight", 0, &"horde")
	_session.events.dungeon_room_entered.emit(2, &"horde")
	assert_true(banner.is_showing())
	assert_eq(banner.shown_text(), DungeonTexts.reveal_text(&"horde"))
	assert_eq(banner.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	_session.events.dungeon_room_entered.emit(3, &"pack")
	assert_eq(banner.shown_text(), DungeonTexts.reveal_text(&"pack"), "replaced by the next one")
	_session.events.dungeon_finished.emit(&"fled", 2, 0)
	assert_false(banner.is_showing(), "gone at the end of the run")
	_session.events.dungeon_room_entered.emit(1, &"entrance")
	_session.events.dungeon_room_entered.emit(7, &"boss")
	assert_false(banner.is_showing(), "none for the entrance and the boss")
	_show(&"await", 3, &"pack", true)
	_session.events.dungeon_room_entered.emit(2, &"pack")
	assert_false(banner.is_showing(), "none in a paused run")


func test_paused_run_shows_resume_and_no_actions() -> void:
	_show(&"await", 3, &"pack", true)
	assert_true(_view("ResumeBox").visible)
	assert_eq(_buttons("Choice_").size(), 0)
	assert_eq(_buttons("LeaveButton").size(), 0)
	(_view("ResumeButton") as Button).pressed.emit()
	assert_eq(_stub.calls.get(&"resume", 0), 1)
	_show(&"fight", 0, &"pack", true)
	_page._process(0.0)
	assert_false(_buttons("FleeButton")[0].visible)


func test_layout_fits_1280x720_and_unbind_disconnects() -> void:
	_show(&"await", 4)
	assert_lte(_page.get_combined_minimum_size().x, 1280.0)
	assert_lte(_page.get_combined_minimum_size().y, 720.0)
	_page.unbind()
	assert_false(_session.events.dungeon_room_entered.is_connected(_page._request_redraw))
