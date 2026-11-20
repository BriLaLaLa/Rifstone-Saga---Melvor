extends GutTest
## docs/05_INTERFACES_M28.md §6f: the save of the conditions, the Ward and the Bleed clock (additive, format v11 unchanged).
## Save -> load -> save is the same, a save of M27 is loaded and written as before, a malformed one is read with care.


func _loaded(saved: Dictionary) -> GameSession:
	var s: GameSession = autofree(TestFactory.session(3))
	s.modifiers.set_source(&"test:sturdy", [Modifier.make(&"max_hp_flat", 100000.0)] as Array[Modifier])
	s.combat.from_save(saved)
	return s


# A fight with every condition on enemy 0, a Ward and the clock running.
func _busy_save() -> Dictionary:
	var s: GameSession = autofree(ConditionKit.session([EffectKit.enemy(ConditionKit.MONSTER_B, 60, 2400), EffectKit.enemy(ConditionKit.MONSTER_B, 60, 1000)]))
	var params: ConditionParams = s.data.conditions()
	s.combat._apply_condition(0, ConditionKit.apply(ConditionApply.BLEED, 50.0, 4000), 37)
	s.combat._apply_condition(0, ConditionKit.apply(ConditionApply.WEAKEN, 25.0, 3000), 0)
	s.combat._apply_condition(0, ConditionKit.apply(ConditionApply.EXPOSE, 15.0, 1200), 0)
	s.combat._apply_condition(0, ConditionKit.apply(ConditionApply.STAGGER, 0.0, 900), 0)
	s.combat._ward.grant(35, 4200)
	s.combat.advance(600)
	assert_eq(s.combat._clock.ms, 400)
	assert_eq(params.tick_ms, 1000)
	return s.combat.to_save()


func test_the_save_has_the_keys_of_the_format() -> void:
	var saved: Dictionary = _busy_save()
	var first: Dictionary = saved["enemies"][0]
	assert_eq(first["cond"]["bleed"], {"left": 18, "ticks": 4})
	assert_eq(first["cond"]["weaken"], {"pct": 25.0, "ms": 2400})
	assert_eq(first["cond"]["expose"], {"pct": 15.0, "ms": 600})
	assert_eq(first["cond"]["stagger_ms"], 300)
	assert_eq(first["cond"]["immune_ms"], 3400)
	assert_false((saved["enemies"][1] as Dictionary).has("cond"), "an enemy without conditions has no `cond`")
	assert_eq(saved["cond_clock_ms"], 400)
	assert_eq(saved["ward"], {"amount": 35, "ms": 3600})
	assert_eq(saved["enemies"][0]["timer_ms"], 2400 + 900 - 600, "the Stagger lengthened the timer and time passed")


func test_save_load_save_is_the_same() -> void:
	var saved: Dictionary = _busy_save()
	var again: Dictionary = _loaded(saved).combat.to_save()
	assert_eq(JSON.stringify(again), JSON.stringify(saved))
	assert_eq(again, saved)


func test_a_loaded_fight_goes_on_like_the_original() -> void:
	var saved: Dictionary = _busy_save()
	var a: GameSession = _loaded(saved)
	var b: GameSession = _loaded(saved)
	var rows_a: Array = []
	var rows_b: Array = []
	var clock: Dictionary = {"t": 0}
	ConditionKit.record(a, rows_a)
	ConditionKit.record(b, rows_b, clock)
	a.combat.advance(5000)
	for i: int in 50:
		clock["t"] = i * 100
		b.combat.advance(100)
	assert_eq(rows_a, rows_b)
	assert_true(rows_a.any(func(r: Array) -> bool: return r[1] == "tick"))
	assert_eq(a.combat.to_save(), b.combat.to_save())


func test_a_save_of_m27_is_loaded_and_written_without_the_new_keys() -> void:
	var saved: Dictionary = _loaded(EffectKit.fight([EffectKit.enemy(ConditionKit.MONSTER_B, 40, 2000)], 1500, 100060)).combat.to_save()
	assert_false((saved["enemies"][0] as Dictionary).has("cond"))
	assert_false(saved.has("ward"))
	assert_false(saved.has("cond_clock_ms"))
	assert_eq(_loaded(saved).combat.to_save(), saved)


func test_an_idle_engine_writes_none_of_them() -> void:
	var s: GameSession = autofree(TestFactory.session(1))
	var saved: Dictionary = s.combat.to_save()
	assert_false(saved.has("ward") or saved.has("cond_clock_ms"))


func test_the_ward_is_saved_between_encounters() -> void:
	var s: GameSession = autofree(ConditionKit.session([EffectKit.enemy(ConditionKit.MONSTER_A, 1, 2800)], 100))
	s.combat._ward.grant(40, 6000)
	s.combat.advance(100)
	assert_eq(s.combat.state(), CombatEngine.STATE_TRAVEL)
	var saved: Dictionary = s.combat.to_save()
	assert_eq(saved["ward"], {"amount": 40, "ms": 5900})
	assert_false(saved.has("cond_clock_ms"))
	assert_eq(_loaded(saved).combat.to_save()["ward"], saved["ward"])


func test_the_timer_of_a_staggered_enemy_may_pass_its_interval_but_only_by_the_window() -> void:
	var staggered: Dictionary = EffectKit.fight([{"monster": ConditionKit.MONSTER_B, "hp": 40, "timer_ms": 3000,
			"cond": {"stagger_ms": 800, "immune_ms": 3000}}])
	assert_eq(_loaded(staggered).combat.to_save()["enemies"][0]["timer_ms"], 3000, "2400 + 800 allows it")
	var plain: Dictionary = EffectKit.fight([{"monster": ConditionKit.MONSTER_B, "hp": 40, "timer_ms": 3000}])
	assert_eq(_loaded(plain).combat.to_save()["enemies"][0]["timer_ms"], 2400, "without the Stagger it is the old limit")


func test_malformed_values_are_cleaned() -> void:
	var saved: Dictionary = EffectKit.fight([{"monster": ConditionKit.MONSTER_B, "hp": 40, "timer_ms": 2000,
			"cond": {"bleed": "much", "weaken": {"pct": 500, "ms": -4}, "expose": {"pct": 15, "ms": 99999999}, "surprise": true}}])
	saved["ward"] = {"amount": 12, "ms": 0}
	saved["cond_clock_ms"] = "soon"
	var s: GameSession = _loaded(saved)
	var enemy: Dictionary = s.combat.to_save()["enemies"][0]
	assert_eq(enemy["cond"], {"expose": {"pct": 15.0, "ms": EnemyConditions.MS_MAX}}, "only the usable one stays, limited")
	assert_false(s.combat.to_save().has("ward"), "a Ward with no time is none")
	assert_false(s.combat.to_save().has("cond_clock_ms"))


func test_the_clock_follows_the_enemies_that_bleed() -> void:
	var with_bleed: Dictionary = EffectKit.fight([{"monster": ConditionKit.MONSTER_B, "hp": 40, "timer_ms": 2000,
			"cond": {"bleed": {"left": 9, "ticks": 3}}}])
	assert_eq(_loaded(with_bleed).combat._clock.ms, 1000, "a Bleed without a saved clock starts it full")
	with_bleed["cond_clock_ms"] = 99999
	assert_eq(_loaded(with_bleed).combat._clock.ms, 1000, "a clock longer than a tick is limited")
	with_bleed["cond_clock_ms"] = 250
	assert_eq(_loaded(with_bleed).combat._clock.ms, 250)
	var no_bleed: Dictionary = EffectKit.fight([EffectKit.enemy(ConditionKit.MONSTER_B, 40, 2000)])
	no_bleed["cond_clock_ms"] = 250
	assert_eq(_loaded(no_bleed).combat._clock.ms, -1, "nobody bleeds: the clock is off")
