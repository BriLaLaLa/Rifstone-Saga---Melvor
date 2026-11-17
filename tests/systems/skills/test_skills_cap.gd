extends GutTest
## F-160 (M24-03): the xp of a discipline stops at the limit of its Trainer grade; the xp above is lost and `xp_capped` follows.

const SKILL: StringName = &"forestry"

var _s: GameSession = null


func before_each() -> void:
	_s = autofree(TestFactory.session_no_kit(1, TestFactory.real_data()))
	_s.modifiers.clear_all()
	TestFactory.learn_discipline(_s, SKILL, 1)


func test_grade_1_xp_4900_plus_100_gives_4941_and_loses_59() -> void:
	_s.skills.from_save({"forestry": {"xp": 4900}})
	watch_signals(_s.events)
	assert_eq(_s.skills.add_xp(SKILL, 100), 41)
	assert_eq(_s.skills.get_xp(SKILL), 4941)
	assert_eq(_s.skills.get_level(SKILL), 20)
	assert_signal_emitted_with_parameters(_s.events, "xp_gained", [SKILL, 41])
	assert_signal_emitted_with_parameters(_s.events, "xp_capped", [SKILL, 59])


func test_at_the_limit_there_is_no_xp_gained_only_xp_capped() -> void:
	_s.skills.from_save({"forestry": {"xp": 4941}})
	watch_signals(_s.events)
	assert_eq(_s.skills.add_xp(SKILL, 100), 0)
	assert_signal_not_emitted(_s.events, "xp_gained")
	assert_signal_emitted_with_parameters(_s.events, "xp_capped", [SKILL, 100])


func test_xp_capped_comes_after_xp_gained_and_level_up() -> void:
	_s.skills.from_save({"forestry": {"xp": 4900}})
	var order: Array[String] = []
	_s.events.xp_gained.connect(func(_s2: StringName, _a: int) -> void: order.append("gained"))
	_s.events.level_up.connect(func(_s2: StringName, _l: int) -> void: order.append("level"))
	_s.events.xp_capped.connect(func(_s2: StringName, _l: int) -> void: order.append("capped"))
	_s.skills.add_xp(SKILL, 100)
	assert_eq(order, ["gained", "level", "capped"])


func test_below_the_limit_nothing_is_lost() -> void:
	watch_signals(_s.events)
	assert_eq(_s.skills.add_xp(SKILL, 100), 100)
	assert_signal_not_emitted(_s.events, "xp_capped")


func test_a_higher_grade_raises_the_limit() -> void:
	_s.skills.from_save({"forestry": {"xp": 4941}})
	TestFactory.learn_discipline(_s, SKILL, 2)
	assert_eq(_s.skills.add_xp(SKILL, 100), 100)


func test_a_discipline_not_learned_gets_nothing() -> void:
	_s.disciplines.new_game()
	watch_signals(_s.events)
	assert_eq(_s.skills.add_xp(SKILL, 100), 0)
	assert_eq(_s.skills.get_xp(SKILL), 0)
	assert_signal_not_emitted(_s.events, "xp_gained")


func test_a_skill_without_discipline_uses_the_global_cap() -> void:
	_s = autofree(TestFactory.session_no_kit(1, TestFactory.fixture_data()))  # the real data have no skill without discipline
	assert_eq(_s.skills.add_xp(&"riftbinding", 100), 100)


func test_reset_skill() -> void:
	_s.skills.add_xp(SKILL, 500)
	watch_signals(_s.events)
	_s.skills.reset_skill(SKILL)
	assert_eq(_s.skills.get_xp(SKILL), 0)
	assert_eq(_s.skills.get_level(SKILL), 1)
	assert_signal_emitted_with_parameters(_s.events, "skill_reset", [SKILL])
	assert_signal_not_emitted(_s.events, "level_up")
