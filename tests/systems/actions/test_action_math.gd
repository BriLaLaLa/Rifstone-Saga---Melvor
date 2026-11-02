extends GutTest
## ActionMath: F-03 interval with its minimum, F-51 secondary-lane penalty, and the effect of skill_interval_pct
## (clamped by ModifierService, F-05) on the interval the runner uses.
##
## Fixture: gather_twig (test_gather) has a 3000 ms base interval; action.min_interval_ms is 250.

const SKILL: StringName = &"test_gather"
const TWIG: StringName = &"gather_twig"
const INTERVAL_STAT: StringName = &"skill_interval_pct"
const MIN_MS: int = 250


func test_f03_examples() -> void:
	assert_eq(ActionMath.interval_ms(3000, -10.0, MIN_MS), 2700)
	assert_eq(ActionMath.interval_ms(3000, -80.0, MIN_MS), 600)
	assert_eq(ActionMath.interval_ms(1000, -80.0, MIN_MS), 250)
	assert_eq(ActionMath.interval_ms(2500, 0.0, MIN_MS), 2500)


func test_f03_slower_interval() -> void:
	assert_eq(ActionMath.interval_ms(3000, 100.0, MIN_MS), 6000)


func test_f51_secondary_penalty() -> void:
	assert_eq(ActionMath.secondary_interval_ms(3000, 40.0), 4200)
	assert_eq(ActionMath.secondary_interval_ms(2500, 0.0), 2500)


## Stat effect (stats.json): the runner's interval follows T(skill_interval_pct) of the action's context;
## -90 is limited to -80 by the stat (F-03 example 3000, -90 -> 600).
func test_interval_uses_skill_interval_pct() -> void:
	var session: GameSession = autofree(TestFactory.session())
	assert_eq(session.data.balance_value("action.min_interval_ms"), float(MIN_MS))
	assert_eq(session.actions.current_interval_ms(TWIG), 3000)
	_set_mod(session, Modifier.make(INTERVAL_STAT, -10.0, &"skill", SKILL))
	assert_eq(session.actions.current_interval_ms(TWIG), 2700)
	_set_mod(session, Modifier.make(INTERVAL_STAT, -90.0, &"action", TWIG))
	assert_eq(session.actions.current_interval_ms(TWIG), 600)
	_set_mod(session, Modifier.make(INTERVAL_STAT, -10.0, &"skill", &"test_gather_b"))
	assert_eq(session.actions.current_interval_ms(TWIG), 3000)


func test_current_interval_of_unknown_action_is_zero() -> void:
	var session: GameSession = autofree(TestFactory.session())
	assert_eq(session.actions.current_interval_ms(&"no_such_action"), 0)
	assert_push_error(1)


func _set_mod(session: GameSession, mod: Modifier) -> void:
	session.modifiers.set_source(&"test", [mod] as Array[Modifier])
