extends GutTest
## F-185 (the common rules) and F-187 (Weaken and Expose) of docs/02_FORMULAS_M28.md: renewal, time, the save, and the Expose
## inside the damage of the player.

var _params: ConditionParams


func before_all() -> void:
	_params = TestFactory.fixture_data().conditions()


func test_params_come_from_the_balance() -> void:
	assert_eq(_params.tick_ms, 1000)
	assert_eq(_params.stagger_immunity_ms, 4000)


func test_a_weaker_weaken_keeps_the_stronger_percentage_and_the_longer_time() -> void:
	var c := EnemyConditions.new()
	c.apply(ConditionKit.apply(ConditionApply.WEAKEN, 25.0, 3000), 0, 0, true, _params)
	c.apply(ConditionKit.apply(ConditionApply.WEAKEN, 15.0, 6000), 0, 0, true, _params)
	assert_eq(c.weaken_pct, 25.0)
	assert_eq(c.weaken_ms, 6000)


func test_expose_renews_like_weaken() -> void:
	var c := EnemyConditions.new()
	c.apply(ConditionKit.apply(ConditionApply.EXPOSE, 10.0, 5000), 0, 0, true, _params)
	c.apply(ConditionKit.apply(ConditionApply.EXPOSE, 20.0, 2000), 0, 0, true, _params)
	assert_eq([c.expose_pct, c.expose_ms], [20.0, 5000])


func test_time_runs_down_and_an_expired_condition_is_off() -> void:
	var c := EnemyConditions.new()
	c.apply(ConditionKit.apply(ConditionApply.WEAKEN, 25.0, 1500), 0, 0, true, _params)
	c.elapse(1000)
	assert_true(c.has(ConditionApply.WEAKEN))
	c.elapse(500)
	assert_false(c.has(ConditionApply.WEAKEN), "at exactly 0 ms it is gone")
	assert_eq(c.weaken_pct, 0.0)
	assert_true(c.is_empty())


func test_a_condition_with_no_time_is_not_in_the_save_or_the_view() -> void:
	var c := EnemyConditions.new()
	c.apply(ConditionKit.apply(ConditionApply.EXPOSE, 15.0, 400), 0, 0, true, _params)
	assert_eq(c.to_save(), {"expose": {"pct": 15.0, "ms": 400}})
	c.elapse(400)
	assert_eq(c.to_save(), {})
	assert_eq(c.view(), {})


func test_the_view_names_the_conditions_that_are_on() -> void:
	var c := EnemyConditions.new()
	c.apply(ConditionKit.apply(ConditionApply.BLEED, 50.0, 4000), 37, 0, true, _params)
	c.apply(ConditionKit.apply(ConditionApply.WEAKEN, 25.0, 3000), 0, 0, true, _params)
	c.apply(ConditionKit.apply(ConditionApply.STAGGER, 0.0, 900), 0, 1200, true, _params)
	assert_eq(c.view(), {"bleed": {"left": 18, "ticks": 4}, "weaken": {"pct": 25.0, "ms": 3000},
			"stagger": {"ms": 900}, "immune_ms": 4000})


func test_save_round_trip() -> void:
	var c := EnemyConditions.new()
	c.apply(ConditionKit.apply(ConditionApply.BLEED, 50.0, 4000), 37, 0, true, _params)
	c.apply(ConditionKit.apply(ConditionApply.WEAKEN, 12.5, 3000), 0, 0, true, _params)
	c.apply(ConditionKit.apply(ConditionApply.EXPOSE, 15.0, 1200), 0, 0, true, _params)
	c.apply(ConditionKit.apply(ConditionApply.STAGGER, 0.0, 900), 0, 0, true, _params)
	var saved: Dictionary = c.to_save()
	assert_eq(EnemyConditions.from_save(saved).to_save(), saved)
	assert_eq(saved["stagger_ms"], 900)
	assert_eq(saved["immune_ms"], 4000)


func test_a_save_with_malformed_or_out_of_range_values_is_cleaned() -> void:
	var c: EnemyConditions = EnemyConditions.from_save({"bleed": {"left": 8, "ticks": 500}, "weaken": {"pct": 400, "ms": 999999},
			"expose": {"pct": "x", "ms": 100}, "stagger_ms": -5, "immune_ms": 3400, "mystery": 1})
	assert_eq(c.bleed_ticks, EnemyConditions.TICKS_MAX, "ticks are limited")
	assert_eq([c.weaken_pct, c.weaken_ms], [EnemyConditions.WEAKEN_PCT_MAX, EnemyConditions.MS_MAX], "pct and ms are limited")
	assert_eq(c.expose_ms, 0, "a malformed Expose is dropped")
	assert_eq(c.stagger_ms, 0, "a negative time is no time")
	assert_eq(c.immune_ms, 3400)


func test_a_save_that_is_not_an_object_gives_no_conditions() -> void:
	assert_true(EnemyConditions.from_save(null).is_empty())
	assert_true(EnemyConditions.from_save([1, 2]).is_empty())
	assert_true(EnemyConditions.from_save({"bleed": {"left": 0, "ticks": 3}}).is_empty(), "no damage left = no Bleed")


func test_condition_apply_from_dict() -> void:
	var app: ConditionApply = ConditionApply.from_dict({"condition": "bleed", "pct": 30, "ms": 4000})
	assert_eq([app.condition, app.pct, app.ms], [ConditionApply.BLEED, 30.0, 4000])
	var stagger: ConditionApply = ConditionApply.from_dict({"condition": "stagger", "ms": 1500})
	assert_eq([stagger.condition, stagger.pct, stagger.ms], [ConditionApply.STAGGER, 0.0, 1500])


# F-187: Expose at 400 ms with the attack 400 ms later: it no longer applies. At 399 ms of time it still does.
func test_expose_that_ends_at_the_instant_of_the_attack_does_not_apply() -> void:
	var damages: Array[int] = []
	for expose_ms: int in [400, 401]:
		var s: GameSession = autofree(ConditionKit.session([EffectKit.enemy(ConditionKit.MONSTER_A, 20, 2800)], 400))
		(s.rng as ConditionKit.ScriptRng).ints = [20]
		ConditionKit.cond(s, 0).apply(ConditionKit.apply(ConditionApply.EXPOSE, 15.0, expose_ms), 0, 0, true, _params)
		s.events.combat_hit.connect(func(a: int, _t: int, _h: bool, d: int, _b: bool) -> void:
			if a == CombatEngine.PLAYER:
				damages.append(d))
		s.combat.advance(400)
	assert_eq(damages, [20, 23], "no Expose at 0 ms left: floor(20) = 20; with 1 ms left: floor(20 x 1.15) = 23")


# F-187 (Expose 15, neutral, DR 10): tiro 20 -> floor(20 x 1.15) = 23 -> floor(23 x 0.9) = 20.
func test_expose_example_through_the_base_roll() -> void:
	var s: GameSession = autofree(ConditionKit.session([EffectKit.enemy(ConditionKit.MONSTER_A, 20, 2800)]))
	s.combat._encounter.enemies[0].stats.damage_reduction = 10.0
	(s.rng as ConditionKit.ScriptRng).ints = [20]
	ConditionKit.cond(s, 0).apply(ConditionKit.apply(ConditionApply.EXPOSE, 15.0, 6000), 0, 0, true, _params)
	var ctx: EffectContext = s.combat._ctx()
	ctx.primary_index = 0
	assert_eq(s.combat._base_roll(0, ctx)["damage"], 20)


# F-187: ability x1.2, tiro 30, Expose 15, DR 10 -> floor(36) = 36 -> floor(41.4) = 41 -> floor(41 x 0.9) = 36.
func test_expose_example_through_an_ability_hit() -> void:
	var s: GameSession = autofree(ConditionKit.session([EffectKit.enemy(ConditionKit.MONSTER_A, 20, 2800)]))
	var enemy: Encounter.Enemy = s.combat._encounter.enemies[0]
	enemy.stats.damage_reduction = 10.0
	(s.rng as ConditionKit.ScriptRng).ints = [30]
	ConditionKit.cond(s, 0).apply(ConditionKit.apply(ConditionApply.EXPOSE, 15.0, 6000), 0, 0, true, _params)
	var m: float = s.combat._hit_mult(0, EffectContext.HIT_ABILITY)
	assert_eq(m, 1.15)
	var hit: Dictionary = Encounter.roll_power_attack(s.combat.player_stats(), enemy.stats, 1.2, m, s.rng, s.data)
	assert_eq(hit["damage"], 36)
