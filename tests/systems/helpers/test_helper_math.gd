extends GutTest
## F-101 (interval) and F-102 (xp and mastery share) of the helpers, with the examples of docs/02_FORMULAS.md §5d.
## Real data: Betulla (forestry, 3000 ms, xp 10). Helpers are put in place with `from_save` (no contract items in the data yet).

const SKILL: StringName = &"forestry"
const BIRCH: StringName = &"cut_redbirch"
const MODS: StringName = &"test:mods"
const GRADES: Array[StringName] = [&"apprentice", &"journeyman", &"expert", &"master"]
const F101_P0: Array[int] = [9000, 7500, 6000, 4500]

var _session: GameSession


func before_each() -> void:
	_session = autofree(TestFactory.session_no_kit(7, TestFactory.real_data()))


func _helper(grade: StringName) -> void:
	_session.helpers.from_save({String(SKILL): {"grade": String(grade), "action": String(BIRCH), "elapsed_ms": 0}})


func test_f101_interval_per_grade_without_modifiers() -> void:
	for i: int in GRADES.size():
		_helper(GRADES[i])
		assert_eq(_session.helpers.interval_ms(SKILL), F101_P0[i], String(GRADES[i]))
		assert_eq(_session.helpers.interval_ms(SKILL, BIRCH), F101_P0[i])


func test_f101_with_minus_10_percent() -> void:
	_session.modifiers.set_source(MODS, [Modifier.make(&"skill_interval_pct", -10.0)] as Array[Modifier])
	_helper(&"master")
	assert_eq(_session.helpers.interval_ms(SKILL), 4050)  # base 2700 x 1.5


func test_f101_minimum_interval_then_multiplier() -> void:
	var base: int = ActionMath.interval_ms(1000, -80.0, int(_session.data.balance_value("action.min_interval_ms")))
	assert_eq(base, 250)
	assert_eq(roundi(base * _session.data.helper_grade(&"master").interval_mult), 375)


func test_interval_is_zero_without_helper_or_action() -> void:
	assert_eq(_session.helpers.interval_ms(SKILL), 0)
	_helper(&"master")
	_session.helpers.stop(SKILL)
	assert_eq(_session.helpers.interval_ms(SKILL), 0)
	assert_eq(_session.helpers.interval_ms(SKILL, BIRCH), 4500)


## F-102: xp_h = floor(F-02 x 25 / 100).
func test_f102_xp_examples() -> void:
	var ctx: ModifierContext = ModifierContext.for_helper(SKILL, BIRCH)
	assert_eq(_session.skills.add_xp(SKILL, 10, ctx, 25.0), 2)
	_session.skills.new_game()
	_session.modifiers.set_source(MODS, [Modifier.make(&"skill_xp_pct", 25.0)] as Array[Modifier])
	assert_eq(_session.skills.add_xp(SKILL, 28, ctx, 25.0), 8)  # F-02 gives 35
	_session.skills.new_game()
	watch_signals(_session.events)
	assert_eq(_session.skills.add_xp(SKILL, 3, ctx, 25.0), 0)
	assert_signal_not_emitted(_session.events, "xp_gained")


func test_f102_default_share_is_the_full_xp() -> void:
	assert_eq(_session.skills.add_xp(SKILL, 10), 10)


## F-102: mxp_h = round(F-10 x 25 / 100); the pool gets the F-12 share of mxp_h.
func test_f102_mastery_examples() -> void:
	var pairs: Array[Vector2i] = [Vector2i(3, 1), Vector2i(20, 5), Vector2i(41, 10), Vector2i(5, 1)]
	for p: Vector2i in pairs:
		assert_eq(MasteryMath.helper_share(p.x, 25.0), p.y, "F-10 = %d" % p.x)
	assert_eq(MasteryMath.pool_gain(5, float(_session.data.balance_value("mastery.pool_share_pct"))), 1)


func test_mastery_share_through_the_system() -> void:
	var action: ActionDef = _session.data.action(BIRCH)
	var full: int = MasteryMath.mastery_xp(action.interval_ms, 0, 0.0, 0.0, _session.data)
	assert_eq(full, 3)
	assert_eq(_session.mastery.add_for_action(action, 25.0), 1)
	assert_eq(_session.mastery.get_mastery_xp(BIRCH), 1)
	assert_eq(_session.mastery.add_for_action(action), 3)


func test_helper_balance_values() -> void:
	assert_eq(float(_session.data.balance_value("helper.xp_pct")), 25.0)
	assert_eq(float(_session.data.balance_value("helper.mastery_pct")), 25.0)
	var mults: Array[float] = []
	for grade: HelperGradeDef in _session.data.helper_grades():
		mults.append(grade.interval_mult)
	assert_eq(mults, [3.0, 2.5, 2.0, 1.5] as Array[float])
