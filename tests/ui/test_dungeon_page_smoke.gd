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
	assert_false(_view("EnemyZone").visible)
	_show(&"fight", 0, &"boss")
	_page._process(0.0)
	assert_false(fight.intro_visible())


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
