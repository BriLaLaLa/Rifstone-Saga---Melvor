extends GutTest
## Smoke tests of the clickable area map (M17-05) and of the hit percentages (F-129) on the combat page, with a
## TestFactory session (fixture data). No exact texts.

const SCENE: PackedScene = preload("res://ui/pages/combat/combat_page.tscn")
const AREA_ID: StringName = &"test_area"

var _session: GameSession
var _page: CombatPage


func before_each() -> void:
	_session = TestFactory.session()
	_page = SCENE.instantiate() as CombatPage
	_page.page_id = &"combat"
	add_child(_page)
	_page.bind(_session)


func after_each() -> void:
	if is_instance_valid(_page):
		_page.free()
	if is_instance_valid(_session):
		_session.free()
	await wait_physics_frames(1)


func test_map_opens_from_the_button_and_lists_every_area() -> void:
	var map: CombatMap = _page.get_node("CombatMap") as CombatMap
	assert_false(map.visible)
	(_page.get_node("%MapButton") as Button).pressed.emit()
	assert_true(map.visible)
	for area: AreaDef in _session.data.areas():
		assert_not_null(map.node(area.id), area.id)


func test_click_on_an_area_starts_combat_and_closes_the_map() -> void:
	var map: CombatMap = _page.get_node("CombatMap") as CombatMap
	map.open(_session)
	map.node(AREA_ID).pressed.emit()
	assert_false(map.visible)
	assert_true(_session.combat.is_active())
	assert_eq(_session.combat.area_id(), AREA_ID)


func test_click_outside_and_escape_close_the_map() -> void:
	var map: CombatMap = _page.get_node("CombatMap") as CombatMap
	map.open(_session)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	map.get_node("Dim").gui_input.emit(click)
	assert_false(map.visible)
	map.open(_session)
	var esc := InputEventAction.new()
	esc.action = &"ui_cancel"
	esc.pressed = true
	map._input(esc)
	assert_false(map.visible)


func test_hit_percentages_are_shown_on_the_target_card_from_the_state() -> void:
	assert_true(_session.combat.start(AREA_ID).ok)
	_page._process(0.0)
	var zone: EnemyZone = _page.get_node("%EnemyZone") as EnemyZone
	var state: Dictionary = _session.combat.get_state()
	assert_true((state["enemies"] as Array).size() > 0)
	var line: Label = zone.target_card().find_child("HitLabel", true, false) as Label
	assert_not_null(line)
	assert_true(line.text.contains(str(int(state["enemies"][int(state["target"])]["hit_pct"]))))
