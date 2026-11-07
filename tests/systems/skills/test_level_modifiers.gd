extends GutTest
## F-93: the source `skill_level:<skill>` of SkillsSystem.rebuild_modifiers (`level_modifiers` of skills.json), kept current
## at every level_up and rebuilt after a load. M10 fixtures: forging has `upgrade_success_pct` 0.4 per level.

const BlueprintData := preload("res://tests/systems/actions/blueprint_data.gd")
const SOURCE: StringName = &"skill_level:forging"

var _session: GameSession = null


func before_each() -> void:
	_session = autofree(TestFactory.session(31, BlueprintData.data()))


func test_new_game_sets_the_source_at_level_one() -> void:
	assert_true(_session.modifiers.has_source(SOURCE))
	assert_almost_eq(_session.modifiers.total(&"upgrade_success_pct"), 0.4, 0.0001)


func test_level_up_updates_the_source() -> void:
	TestFactory.set_level(_session, &"forging", 10)
	assert_almost_eq(_session.modifiers.total(&"upgrade_success_pct"), 4.0, 0.0001)


func test_xp_without_a_new_level_changes_nothing() -> void:
	_session.skills.add_xp(&"forging", 1)
	assert_eq(_session.skills.get_level(&"forging"), 1)
	assert_almost_eq(_session.modifiers.total(&"upgrade_success_pct"), 0.4, 0.0001)


func test_the_bonus_is_global() -> void:
	TestFactory.set_level(_session, &"forging", 5)
	var other: ModifierContext = ModifierContext.for_skill(&"forestry")
	assert_almost_eq(_session.modifiers.total(&"upgrade_success_pct", other), 2.0, 0.0001)


func test_only_skills_with_level_modifiers_have_a_source() -> void:
	for def: SkillDef in _session.data.skills():
		assert_eq(_session.modifiers.has_source(StringName("skill_level:" + String(def.id))), not def.level_modifiers.is_empty(), def.id)


func test_rebuild_after_a_load() -> void:
	TestFactory.set_level(_session, &"forging", 20)
	var loaded: GameSession = autofree(TestFactory.session(32, BlueprintData.data()))
	assert_true(loaded.from_save(_session.to_save(0)).ok)
	assert_almost_eq(loaded.modifiers.total(&"upgrade_success_pct"), 8.0, 0.0001)
