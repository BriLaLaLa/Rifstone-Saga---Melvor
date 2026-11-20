extends GutTest
## F-188 (Stagger) of docs/02_FORMULAS_M28.md: the timer is lengthened, the enemy is staggered for that time and then immune
## (`combat.conditions.stagger_immunity_ms` = 4000 in the tests), a boss and a Monolith never stagger.

var _params: ConditionParams


func before_all() -> void:
	_params = TestFactory.fixture_data().conditions()


func _stagger(ms: int) -> ConditionApply:
	return ConditionKit.apply(ConditionApply.STAGGER, 0.0, ms)


func test_the_timer_is_lengthened_and_the_window_and_the_immunity_start() -> void:
	var c := EnemyConditions.new()
	assert_eq(c.apply(_stagger(1500), 0, 1200, true, _params), 2700, "1.2 s + 1.5 s")
	assert_eq([c.stagger_ms, c.immune_ms, c.has(ConditionApply.STAGGER)], [1500, 4000, true])


func test_a_second_stagger_during_the_immunity_is_ignored_and_one_after_it_is_not() -> void:
	var c := EnemyConditions.new()
	c.apply(_stagger(1500), 0, 1200, true, _params)
	c.elapse(1000)
	assert_eq(c.immune_ms, 3000)
	assert_eq(c.apply(_stagger(1000), 0, 1700, true, _params), 1700, "ignored: the timer does not change")
	assert_eq(c.stagger_ms, 500, "not even the window of the second one")
	c.elapse(3000)
	assert_eq(c.immune_ms, 0)
	assert_eq(c.apply(_stagger(1000), 0, 1700, true, _params), 2700, "4 s after the first it works again")


func test_a_boss_or_a_monolith_is_not_staggered() -> void:
	var c := EnemyConditions.new()
	assert_eq(c.apply(_stagger(1500), 0, 1200, false, _params), 1200)
	assert_true(c.is_empty())


func test_the_enemy_types_that_are_immune() -> void:
	var s: GameSession = autofree(ConditionKit.session([EffectKit.enemy(ConditionKit.MONSTER_A, 20, 2800)]))
	var plain: Encounter.Enemy = s.combat._encounter.enemies[0]
	assert_false(plain.stagger_immune())
	var boss: ScaledMonsterDef = ScaledMonsterDef.copy_of(s.data.monster(&"test_monster_b"))
	assert_false(Encounter.Enemy.new(boss, s.data).stagger_immune(), "a scaled monster that is not a boss")
	boss.is_boss = true
	assert_true(Encounter.Enemy.new(boss, s.data).stagger_immune(), "the boss of a Fracture")
	var stone: Encounter.Enemy = Encounter.Enemy.new(s.data.monster(&"test_monster_a"), s.data, 5)
	assert_true(stone.stagger_immune(), "a Monolith (it has a pulse)")
	assert_true(stone.immune_to(ConditionApply.WEAKEN) and stone.immune_to(ConditionApply.STAGGER))
	assert_false(stone.immune_to(ConditionApply.BLEED) or stone.immune_to(ConditionApply.EXPOSE))
	assert_false(plain.immune_to(ConditionApply.WEAKEN))


func test_engine_lengthens_the_timer_of_the_enemy() -> void:
	var s: GameSession = autofree(ConditionKit.session([EffectKit.enemy(ConditionKit.MONSTER_B, 60, 1200)]))
	s.combat._apply_condition(0, _stagger(1500), 0)
	assert_eq(s.combat._encounter.enemies[0].timer_ms, 2700)
	s.combat._apply_condition(0, _stagger(1000), 0)
	assert_eq(s.combat._encounter.enemies[0].timer_ms, 2700, "immune")


func test_a_monolith_is_not_staggered_by_the_engine() -> void:
	var s: GameSession = autofree(ConditionKit.session([EffectKit.enemy(ConditionKit.MONSTER_B, 60, 1200)]))
	s.combat._encounter.enemies[0].pulse_damage = 10  # a Rift Stone
	s.combat._apply_condition(0, _stagger(1500), 0)
	s.combat._apply_condition(0, ConditionKit.apply(ConditionApply.WEAKEN, 25.0, 5000), 0)
	assert_eq(s.combat._encounter.enemies[0].timer_ms, 1200)
	assert_true(ConditionKit.cond(s, 0).is_empty())


func test_the_chief_of_a_dungeon_stage_is_not_staggered() -> void:
	var s: GameSession = autofree(ConditionKit.session([EffectKit.enemy(ConditionKit.MONSTER_B, 60, 1200)]))
	var stage := DungeonStageDef.new()
	stage.monster = s.data.monster(&"test_monster_b")
	s.combat._dg.stage = stage
	s.combat._dg.fighting = true
	s.combat._apply_condition(0, _stagger(1500), 0)
	assert_eq(s.combat._encounter.enemies[0].timer_ms, 1200)


# F-188: the enemy with the timer at 0 in the instant the player staggers it for 1 s does not attack in that instant.
func test_a_stagger_of_the_player_comes_before_the_attack_of_the_enemy() -> void:
	var s: GameSession = autofree(ConditionKit.session([EffectKit.enemy(ConditionKit.MONSTER_A, 20, 800)], 800))
	(s.rng as ConditionKit.ScriptRng).ints = [1]
	var fake: ConditionKit.Fake = ConditionKit.install(s, ConditionKit.Fake.new())
	fake.applies = [_stagger(1000)]
	var attackers: Array[int] = []
	s.events.combat_hit.connect(func(a: int, _t: int, _h: bool, _d: int, _b: bool) -> void: attackers.append(a))
	s.combat.advance(800)
	assert_eq(attackers, [CombatEngine.PLAYER], "the player hit; the enemy did not attack")
	assert_eq(s.combat._encounter.enemies[0].timer_ms, 1000)
	s.combat.advance(1000)
	assert_eq(attackers, [CombatEngine.PLAYER, 0], "1 s later the enemy attacks")
