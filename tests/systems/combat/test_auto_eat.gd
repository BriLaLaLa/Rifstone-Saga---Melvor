extends GutTest
## AutoEat: F-29 (food healing) and F-30 (field rations). Fixture food `test_ration` heals 20; +80% gives 36.

const RATION: StringName = &"test_ration"

var _session: GameSession = null


func before_each() -> void:
	_session = autofree(TestFactory.session())
	TestFactory.give(_session, RATION, 10)
	assert_true(_session.equipment.set_food(RATION).ok)
	watch_signals(_session.events)


func _mods(list: Array[Modifier]) -> void:
	_session.modifiers.set_source(&"test:food", list)


func test_eat_one_heals() -> void:
	assert_eq(AutoEat.eat_one(_session, 10, 100), 30, "20 with +0%")
	assert_eq(_session.bank.get_count(RATION), 9)
	assert_signal_emitted_with_parameters(_session.events, "food_eaten", [RATION, 20])


func test_food_healing_pct() -> void:
	_mods([Modifier.make(&"food_healing_pct", 80.0)])
	assert_eq(AutoEat.eat_one(_session, 10, 100), 46, "20 with +80% heals 36")


func test_eat_never_exceeds_the_maximum() -> void:
	assert_eq(AutoEat.eat_one(_session, 90, 100), 100)
	assert_signal_emitted_with_parameters(_session.events, "food_eaten", [RATION, 10])


func test_full_hp_eats_nothing() -> void:
	assert_eq(AutoEat.eat_one(_session, 100, 100), 100)
	assert_eq(_session.bank.get_count(RATION), 10)


func test_no_food() -> void:
	_session.equipment.set_food(&"")
	assert_eq(AutoEat.eat_one(_session, 10, 100), -1, "none worn")
	_session.equipment.set_food(RATION)
	_session.bank.remove(RATION, 10)
	assert_eq(AutoEat.eat_one(_session, 10, 100), -1, "none left")


func test_tier_thresholds() -> void:
	# F-30 example: max 170, tier 1 (threshold 51, target 102), food heals 36: 45 -> 81 -> 117, 2 pieces.
	_mods([Modifier.make(&"food_healing_pct", 80.0), Modifier.make(&"auto_eat_tier", 1.0)])
	assert_eq(AutoEat.after_hit(_session, 45, 170), 117)
	assert_eq(_session.bank.get_count(RATION), 8)
	assert_eq(AutoEat.after_hit(_session, 52, 170), 52, "above the threshold: no meal")
	assert_eq(_session.bank.get_count(RATION), 8)
	assert_eq(AutoEat.after_hit(_session, 51, 170), 123, "at the threshold (floor) it eats: 51 -> 87 -> 123")


func test_tier_two_and_three() -> void:
	_mods([Modifier.make(&"auto_eat_tier", 2.0)])
	assert_eq(AutoEat.after_hit(_session, 40, 100), 80, "tier 2: threshold 40, target 75: 40 -> 60 -> 80")
	_mods([Modifier.make(&"auto_eat_tier", 3.0)])
	assert_eq(AutoEat.after_hit(_session, 51, 100), 51, "tier 3: threshold 50")
	assert_eq(AutoEat.after_hit(_session, 50, 100), 90, "tier 3: target 90: 50 -> 70 -> 90")


func test_tier_zero_is_off() -> void:
	assert_eq(AutoEat.after_hit(_session, 1, 100), 1)
	assert_eq(_session.bank.get_count(RATION), 10)


func test_food_runs_out() -> void:
	_session.bank.remove(RATION, 8)
	_mods([Modifier.make(&"auto_eat_tier", 1.0)])
	assert_eq(AutoEat.after_hit(_session, 5, 1000), 45, "two pieces, then nothing left")
	assert_eq(AutoEat.after_hit(_session, 45, 1000), 45)


func test_dead_player_does_not_eat() -> void:
	_mods([Modifier.make(&"auto_eat_tier", 1.0)])
	assert_eq(AutoEat.after_hit(_session, 0, 100), 0)
	assert_eq(_session.bank.get_count(RATION), 10)
