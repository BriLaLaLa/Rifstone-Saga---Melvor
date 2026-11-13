extends GutTest
## Combat page visual effects (M17-07): one smoke test that ticks the page with the effects on and with the reduced
## effects setting, hits and heavy hits included. No exact texts or timings.

const SCENE: PackedScene = preload("res://ui/pages/combat/combat_page.tscn")
const AREA_ID: StringName = &"test_area"

var _session: GameSession
var _page: CombatPage


func before_each() -> void:
	GameSettings.reset()
	_session = TestFactory.session()
	_page = SCENE.instantiate() as CombatPage
	_page.page_id = &"combat"
	add_child(_page)
	_page.bind(_session)


func after_each() -> void:
	GameSettings.set_value(GameSettings.KEY_REDUCED_FX, false)
	if is_instance_valid(_page):
		_page.free()
	if is_instance_valid(_session):
		_session.free()
	await wait_physics_frames(1)


func test_tick_with_effects_on_and_reduced() -> void:
	for reduced: bool in [false, true]:
		GameSettings.set_value(GameSettings.KEY_REDUCED_FX, reduced)
		_session.combat.start(AREA_ID)
		_page._process(0.0)
		_session.advance(500)
		_page._process(0.016)
		_session.events.combat_hit.emit(-1, 0, true, 9999, false)
		_session.events.combat_hit.emit(0, -1, true, 999999, false)
		_session.events.combat_hit.emit(0, -1, true, 0, true)
		_page._process(0.016)
		var zone: EnemyZone = _page.get_node("%EnemyZone") as EnemyZone
		assert_eq(CombatFx.reduced(), reduced)
		assert_true(zone.target_card().visible)
		assert_gt(zone.target_card().floater_count(), 0)
		_session.combat.stop()
		assert_eq(zone.target_card().floater_count(), 0)
	assert_ne(CombatFx.area_tint(0), CombatFx.area_tint(1))
