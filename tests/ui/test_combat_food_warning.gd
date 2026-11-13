extends GutTest
## B2: starting a combat without food shows CombatTexts.NO_FOOD_WARNING in MessageLabel (it does not block the start);
## it goes away at the first food chosen or when the combat stops.

const SCENE: PackedScene = preload("res://ui/pages/combat/combat_page.tscn")
const AREA_ID: StringName = &"test_area"
const FOOD_ID: StringName = &"test_ration"

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


func test_start_without_food_warns_and_still_starts() -> void:
	assert_eq(_session.equipment.get_food(), &"")
	(_page.get_node("CombatMap") as CombatMap).area_chosen.emit(&"test_area")
	assert_true(_session.combat.is_active())
	var message: Label = _page.get_node("%MessageLabel") as Label
	assert_true(message.visible)
	assert_eq(message.text, CombatTexts.NO_FOOD_WARNING)


func test_choosing_food_removes_the_warning() -> void:
	(_page.get_node("CombatMap") as CombatMap).area_chosen.emit(&"test_area")
	TestFactory.give(_session, FOOD_ID, 5)
	assert_true(_session.equipment.set_food(FOOD_ID).ok)
	assert_false((_page.get_node("%MessageLabel") as Label).visible)


func test_stop_removes_the_warning() -> void:
	(_page.get_node("CombatMap") as CombatMap).area_chosen.emit(&"test_area")
	_session.combat.stop()
	assert_false((_page.get_node("%MessageLabel") as Label).visible)


func test_start_with_food_shows_no_warning() -> void:
	TestFactory.give(_session, FOOD_ID, 5)
	assert_true(_session.equipment.set_food(FOOD_ID).ok)
	(_page.get_node("CombatMap") as CombatMap).area_chosen.emit(&"test_area")
	assert_true(_session.combat.is_active())
	assert_false((_page.get_node("%MessageLabel") as Label).visible)
