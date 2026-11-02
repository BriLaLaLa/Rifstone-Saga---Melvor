extends GutTest
## SkillsSystem: F-02 xp with skill_xp_pct, derived levels (F-01), one level_up per level, xp_cap, save, requirements.

const SKILL: StringName = &"test_gather"
const OTHER_SKILL: StringName = &"blade"
const XP_PCT: StringName = &"skill_xp_pct"
const SOURCE: StringName = &"test:xp"
const FIXTURE_SKILL_COUNT: int = 9

var _session: GameSession
var _skills: SkillsSystem


func before_each() -> void:
	_session = autofree(TestFactory.session())
	_skills = _session.skills
	watch_signals(_session.events)


func test_new_game_starts_every_skill_at_level_1() -> void:
	for def: SkillDef in _session.data.skills():
		assert_eq(_skills.get_xp(def.id), 0)
		assert_eq(_skills.get_level(def.id), 1)
		assert_eq(_skills.get_progress(def.id), 0.0)
	assert_eq(_skills.total_level(), FIXTURE_SKILL_COUNT)


## F-02 examples: base 10, pct 0 -> 10; base 10, pct 15 -> 11; base 28, pct 25 -> 35.
func test_f02_examples() -> void:
	assert_eq(_skills.add_xp(SKILL, 10), 10)
	_set_pct(15.0)
	assert_eq(_skills.add_xp(SKILL, 10), 11)
	_set_pct(25.0)
	assert_eq(_skills.add_xp(SKILL, 28), 35)
	assert_eq(_skills.get_xp(SKILL), 56)


func test_add_xp_applies_skill_xp_pct() -> void:
	_set_pct(15.0)
	assert_eq(_skills.add_xp(SKILL, 10), 11)
	assert_eq(_skills.get_xp(SKILL), 11)


func test_add_xp_default_context_is_the_skill() -> void:
	_session.modifiers.set_source(SOURCE, [Modifier.make(XP_PCT, 25.0, &"skill", SKILL)] as Array[Modifier])
	assert_eq(_skills.add_xp(SKILL, 28), 35)
	assert_eq(_skills.add_xp(OTHER_SKILL, 28), 28)
	assert_eq(_skills.add_xp(SKILL, 28, ModifierContext.global_ctx()), 28)


func test_add_xp_emits_xp_gained_with_granted_amount() -> void:
	_set_pct(15.0)
	_skills.add_xp(SKILL, 10)
	assert_signal_emit_count(_session.events, "xp_gained", 1)
	assert_signal_emitted_with_parameters(_session.events, "xp_gained", [SKILL, 11])
	assert_signal_not_emitted(_session.events, "level_up")


func test_zero_xp_emits_nothing() -> void:
	assert_eq(_skills.add_xp(SKILL, 0), 0)
	assert_signal_not_emitted(_session.events, "xp_gained")


func test_reaching_a_level_emits_level_up() -> void:
	_skills.add_xp(SKILL, 69)
	assert_eq(_skills.get_level(SKILL), 1)
	assert_signal_not_emitted(_session.events, "level_up")
	_skills.add_xp(SKILL, 1)
	assert_eq(_skills.get_level(SKILL), 2)
	assert_signal_emitted_with_parameters(_session.events, "level_up", [SKILL, 2])


func test_three_level_jump_emits_three_level_ups_in_order() -> void:
	var xp: int = _session.data.xp_table().xp_for_level(4)
	_skills.add_xp(SKILL, xp)
	assert_eq(_skills.get_level(SKILL), 4)
	assert_signal_emit_count(_session.events, "level_up", 3)
	for i: int in 3:
		assert_eq(get_signal_parameters(_session.events, "level_up", i), [SKILL, 2 + i])


func test_progress_inside_the_level() -> void:
	# Level 2 at 70, level 3 at 155: 70 + 17 is 20% of the way.
	_skills.add_xp(SKILL, 87)
	assert_almost_eq(_skills.get_progress(SKILL), 0.2, 0.0001)


func test_xp_grows_past_max_level_up_to_the_cap() -> void:
	var cap: int = int(_session.data.balance_value("xp_curve.xp_cap"))
	var max_level: int = int(_session.data.balance_value("xp_curve.max_level"))
	_skills.add_xp(SKILL, cap - 10)
	assert_eq(_skills.get_level(SKILL), max_level)
	assert_eq(_skills.get_progress(SKILL), 1.0)
	assert_signal_emit_count(_session.events, "level_up", max_level - 1)
	assert_eq(_skills.add_xp(SKILL, 25), 10)
	assert_eq(_skills.get_xp(SKILL), cap)
	assert_eq(_skills.add_xp(SKILL, 25), 0)
	assert_eq(_skills.get_xp(SKILL), cap)
	assert_signal_emit_count(_session.events, "xp_gained", 2)
	assert_signal_emit_count(_session.events, "level_up", max_level - 1)


func test_negative_xp_is_ignored() -> void:
	_skills.add_xp(SKILL, 50)
	assert_eq(_skills.add_xp(SKILL, -10), 0)
	assert_push_error(1)
	assert_eq(_skills.get_xp(SKILL), 50)


func test_unknown_skill_is_an_error() -> void:
	assert_eq(_skills.add_xp(&"no_such_skill", 10), 0)
	assert_eq(_skills.get_xp(&"no_such_skill"), 0)
	assert_eq(_skills.get_level(&"no_such_skill"), 0)
	assert_push_error(3)
	assert_signal_not_emitted(_session.events, "xp_gained")


func test_meets_requirements() -> void:
	TestFactory.set_level(_session, SKILL, 10)
	assert_true(_skills.meets_requirements({}))
	assert_true(_skills.meets_requirements({SKILL: 10}))
	assert_true(_skills.meets_requirements({"test_gather": 5.0, OTHER_SKILL: 1}))
	assert_false(_skills.meets_requirements({SKILL: 11}))
	assert_false(_skills.meets_requirements({SKILL: 10, OTHER_SKILL: 2}))


func test_meets_requirements_with_unknown_skill_is_false() -> void:
	assert_false(_skills.meets_requirements({&"no_such_skill": 1}))
	assert_push_error(1)


func test_total_level_sums_every_skill() -> void:
	TestFactory.set_level(_session, SKILL, 10)
	TestFactory.set_level(_session, OTHER_SKILL, 5)
	assert_eq(_skills.total_level(), FIXTURE_SKILL_COUNT - 2 + 10 + 5)
	assert_eq(_session.total_level(), _skills.total_level())


func test_set_level_reaches_the_exact_level() -> void:
	TestFactory.set_level(_session, SKILL, 30)
	assert_eq(_skills.get_level(SKILL), 30)
	assert_eq(_skills.get_xp(SKILL), _session.data.xp_table().xp_for_level(30))


func test_save_round_trip() -> void:
	_skills.add_xp(SKILL, 15320)
	_skills.add_xp(OTHER_SKILL, 4100)
	var saved: Dictionary = SaveCodec.decode(SaveCodec.encode(_skills.to_save()))
	assert_eq(saved.size(), FIXTURE_SKILL_COUNT)
	var other: GameSession = autofree(TestFactory.session())
	other.skills.from_save(saved)
	assert_eq(other.skills.get_xp(SKILL), 15320)
	assert_eq(other.skills.get_xp(OTHER_SKILL), 4100)
	assert_eq(other.skills.get_xp(&"arcana"), 0)
	assert_eq(other.skills.get_level(SKILL), _skills.get_level(SKILL))


func test_to_save_format() -> void:
	_skills.add_xp(SKILL, 70)
	var saved: Dictionary = _skills.to_save()
	assert_eq(saved["test_gather"], {"xp": 70})
	assert_eq(saved["blade"], {"xp": 0})


func test_from_save_drops_unknown_and_malformed_entries() -> void:
	_skills.add_xp(OTHER_SKILL, 500)
	clear_signal_watcher()
	watch_signals(_session.events)
	_skills.from_save({
		"test_gather": {"xp": 155.0},
		"no_such_skill": {"xp": 10},
		"arcana": {"xp": "lots"},
		"guard": 12,
		"vitality": {"xp": 1.5},
	})
	assert_eq(_skills.get_xp(SKILL), 155)
	assert_eq(_skills.get_level(SKILL), 3)
	assert_eq(_skills.get_xp(OTHER_SKILL), 0)
	assert_eq(_skills.get_xp(&"arcana"), 0)
	assert_eq(_skills.get_xp(&"guard"), 0)
	assert_eq(_skills.get_xp(&"vitality"), 0)
	assert_signal_not_emitted(_session.events, "level_up")


func test_from_save_limits_xp_to_zero_and_cap() -> void:
	var cap: int = int(_session.data.balance_value("xp_curve.xp_cap"))
	_skills.from_save({"test_gather": {"xp": cap + 1000}, "blade": {"xp": -5}})
	assert_eq(_skills.get_xp(SKILL), cap)
	assert_eq(_skills.get_xp(OTHER_SKILL), 0)


func test_new_game_resets_xp() -> void:
	_skills.add_xp(SKILL, 1000)
	_skills.new_game()
	assert_eq(_skills.get_xp(SKILL), 0)


func test_session_saves_and_loads_the_skills_module() -> void:
	_skills.add_xp(SKILL, 155)
	var saved: Dictionary = _session.to_save(0)
	assert_eq((saved["modules"] as Dictionary)[String(SkillsSystem.SAVE_KEY)], _skills.to_save())
	assert_eq(saved["total_level"], FIXTURE_SKILL_COUNT + 2)
	var other: GameSession = autofree(TestFactory.session())
	assert_true(other.from_save(SaveCodec.decode(SaveCodec.encode(saved))).ok)
	assert_eq(other.skills.get_xp(SKILL), 155)


func test_snapshot_copies_xp_and_levels() -> void:
	_skills.add_xp(SKILL, 155)
	var snapshot: SessionSnapshot = SessionSnapshot.take(_session)
	assert_eq(snapshot.xp.size(), FIXTURE_SKILL_COUNT)
	assert_eq(snapshot.xp[SKILL], 155)
	assert_eq(snapshot.levels[SKILL], 3)
	assert_eq(snapshot.levels[OTHER_SKILL], 1)
	_skills.add_xp(SKILL, 1000)
	assert_eq(snapshot.xp[SKILL], 155)


func _set_pct(pct: float) -> void:
	_session.modifiers.set_source(SOURCE, [Modifier.make(XP_PCT, pct)] as Array[Modifier])
