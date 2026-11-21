extends GutTest
## M30-05: the first steps of the tutorial played on the real main screen (real data, a real new game, 1280x720) with real mouse clicks:
## welcome -> character -> equipment (a piece is selected and "Equipaggia" pressed with clicks) -> combat_start (the Map and an area with
## clicks) until the step "combat_kills"; then the screen is thrown away, the slot is saved and loaded into a new session and a new
## screen, which resumes from the same step. No exact texts (docs/05_INTERFACES_M30.md §7.ab, docs/01_GDD_M30.md §41.8).

const SCENE: PackedScene = preload("res://ui/screens/main/main_screen.tscn")
const Play := preload("res://tests/integration/test_tutorial_playthrough.gd")
const AREA_ID: StringName = &"redrock_plains"

var _s: GameSession = null
var _screen: MainScreen = null


func after_each() -> void:
	if is_instance_valid(_screen):
		_screen.free()
	if is_instance_valid(_s):
		_s.free()
	await wait_physics_frames(1)


func _show(session: GameSession) -> void:
	_s = session
	_screen = SCENE.instantiate() as MainScreen
	_screen.session = _s
	add_child(_screen)
	# the output panel of the GUT runner sits over the top right corner of the window: it must not catch the test's clicks
	for layer: Node in get_tree().root.find_children("GutLayer", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	await _settle()


func _host() -> PageHost:
	return _screen.find_child("PageHost", true, false) as PageHost


func _sidebar() -> Sidebar:
	return _screen.find_child("Sidebar", true, false) as Sidebar


## Opens the page of the step with a click on its sidebar row, as the overlay asks ("Vai a ...").
func _go_to_page_of_step() -> void:
	assert_true(_s.tutorial.needs_navigation(), "the step asks to go to its page")
	assert_true((_screen.find_child("GoToLabel", true, false) as Label).visible)
	await _click(_sidebar().nav_row(_s.tutorial.required_route()))
	assert_false(_s.tutorial.needs_navigation())


func test_the_first_steps_with_real_clicks_and_a_restart_in_the_middle() -> void:
	await _show(Play.new_game_session(3050))
	assert_eq(_s.tutorial.step_index(), 0)
	assert_eq(_s.tutorial.current_step().id, &"welcome")
	# 1 welcome: the card is centred, Avanti
	var next: Button = _screen.find_child("NextButton", true, false) as Button
	assert_true(next.is_visible_in_tree(), "Avanti is there on a reading step")
	await _click(next)
	# 2 character: go to the page, then Avanti
	assert_eq(_s.tutorial.current_step().id, &"character")
	await _go_to_page_of_step()
	assert_eq(PageHost.route_of(_host().current_page_id()), &"character")
	await _click(_screen.find_child("NextButton", true, false) as Button)
	# 3 equipment: go to the page, select the Spadone, Equipaggia
	assert_eq(_s.tutorial.current_step().id, &"equipment")
	await _go_to_page_of_step()
	var uid: int = _greatsword_uid()
	assert_gt(uid, 0)
	var cell: InventoryCell = _cell_of(uid)
	assert_not_null(cell, "the Spadone is a cell of the Armory page")
	await _click(cell)
	var equip: Button = _screen.find_child("EquipButton", true, false) as Button
	assert_true(equip.is_visible_in_tree(), "the piece panel offers Equipaggia")
	await _click(equip)
	assert_eq(_s.equipment.get_item(&"weapon"), &"emberbronze_greatsword", "the click put the piece on")
	assert_eq(_s.tutorial.current_step().id, &"combat_start", "the event step ended on the model")
	# 4 combat_start: go to Combat, the Map, the area
	await _go_to_page_of_step()
	await _click(_screen.find_child("MapButton", true, false) as Button)
	var map: CombatMap = _screen.find_child("CombatMap", true, false) as CombatMap
	assert_true(map.visible)
	await _click(map.node(AREA_ID))
	assert_true(_s.combat.is_active())
	assert_eq(_s.tutorial.current_step().id, &"combat_kills", "the fight started: the next step is the kills")
	assert_eq(_s.tutorial.step_target_count(), 3)
	# the card of the step is on screen and the page is the combat one
	assert_true((_screen.find_child("StepBox", true, false) as Control).visible)
	assert_false((_screen.find_child("GoToLabel", true, false) as Control).visible)
	# a restart in the middle: save, throw everything away, load into a new session and a new screen
	var saved: Dictionary = _s.to_save(1_700_000_000_000)
	var before: Dictionary = (saved["modules"] as Dictionary)["tutorial"]
	_screen.free()
	_s.free()
	_screen = null
	var events: GameEvents = GameEvents.new()
	var again: GameSession = GameSession.new(TestFactory.real_data(), events, 1)
	again.add_child(events)
	assert_true(again.from_save(SaveMigrator.migrate(JSON.parse_string(JSON.stringify(saved)) as Dictionary)).ok)
	await _show(again)
	assert_true(_s.tutorial.is_active())
	assert_eq(_s.tutorial.current_step().id, &"combat_kills", "the new screen resumes from the same step")
	assert_eq((_s.to_save(0)["modules"] as Dictionary)["tutorial"]["step"], before["step"])
	assert_true((_screen.find_child("TutorialOverlay", true, false) as Control).is_visible_in_tree(), "the overlay is back")
	assert_true(_s.tutorial.is_page_open(&"combat"))
	assert_false(_s.tutorial.is_page_open(&"village"), "the pages not reached stay closed after the restart")


func _greatsword_uid() -> int:
	for inst: ItemInstance in _s.armory.instances():
		if inst.base_id == &"emberbronze_greatsword":
			return inst.uid
	return 0


func _cell_of(uid: int) -> InventoryCell:
	for node: Node in _screen.find_children("*", "InventoryCell", true, false):
		if (node as InventoryCell).uid() == uid:
			return node as InventoryCell
	return null


func _settle() -> void:
	await wait_process_frames(3)


func _move_to(at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()  # the mouse arrives over the control first, as with a real hand
	motion.position = at
	motion.global_position = at
	get_viewport().push_input(motion, true)
	await wait_process_frames(1)


func _press(at: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.position = at
		event.global_position = at
		get_viewport().push_input(event, true)
		await wait_process_frames(1)
	await _settle()


## A real left click on the centre of `control`; the click must land on it (or on a child of it).
func _click(control: Control) -> void:
	assert_not_null(control)
	if control == null:
		return
	var at: Vector2 = control.get_global_rect().get_center()
	await _move_to(at)
	var hovered: Control = get_viewport().gui_get_hovered_control()
	assert_true(hovered == control or control.is_ancestor_of(hovered), "the click lands on %s (hovered: %s)" % [control.name, hovered])
	await _press(at)


## BUG-M30-05-2: `MailTexts._fill` reads `data.item(message["item"])` also for a message with money only (item = &""): each text of the gift of
## step 17 and of every starter reward logs "unknown item ''" (an error in the log on every redraw of the Mail page). Pending until fixed.
func test_money_only_messages_of_the_tutorial_compose_without_errors() -> void:
	var data: GameData = TestFactory.real_data()
	var sample: Dictionary = {"id": 1, "kind": &"tutorial_gift", "item": &"", "qty": 0, "price": 0, "listing": 0, "money": 3000, "items": [], "read": false}
	for kind: StringName in [&"tutorial_gift", &"starter_reward"]:
		sample["kind"] = kind
		var composed: Dictionary = MailTexts.compose(sample, data)
		assert_false(String(composed["subject"]).is_empty(), "%s has a subject" % kind)
	var errors: Array = get_errors()
	for error: Variant in errors:
		error.handled = true
	assert_true(errors.is_empty(), "no errors composing money-only messages")
