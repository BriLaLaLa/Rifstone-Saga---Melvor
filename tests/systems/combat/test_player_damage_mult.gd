extends GutTest
## F-190 (the damage of the player: the one multiplier `M`) of docs/02_FORMULAS_M28.md, with fake effects that give the factors
## (the real types come with M28-05). The roll is scripted: `ints` are the raw damage rolls, every attack hits.

var _s: GameSession


# A fight with one enemy of `hp` (A: blade like the player, no reduction) and the reduction of the enemy set to `dr`.
func _fight(hp: int, dr: float = 0.0, max_hp_extra: int = 100000) -> Encounter.Enemy:
	_s = autofree(ConditionKit.session([EffectKit.enemy(ConditionKit.MONSTER_A, hp, 2800)], 100000, max_hp_extra))
	var enemy: Encounter.Enemy = _s.combat._encounter.enemies[0]
	enemy.stats.damage_reduction = dr
	enemy.stats.max_hp = maxi(enemy.stats.max_hp, hp)
	return enemy


func _roll(raw: int) -> void:
	(_s.rng as ConditionKit.ScriptRng).ints = [raw]


# The base attack against the enemy at 0 as the engine rolls it.
func _base() -> int:
	var ctx: EffectContext = _s.combat._ctx()
	ctx.base_attack = true
	ctx.primary_index = 0
	return _s.combat._base_roll(0, ctx)["damage"]


func test_all_the_factors_at_one_give_the_plain_damage() -> void:
	_fight(100)
	_roll(40)
	assert_eq(_base(), 40, "tiro 40, neutro, DR 0")


# M = 1.15 (Momentum x3) x 1.25 (damage_trade) x 1.15 (Expose) = 1.653125 -> floor(40 x 1.653125) = floor(66.125) = 66
func test_the_factors_make_one_product_and_one_floor() -> void:
	_fight(100)
	var a: ConditionKit.Fake = ConditionKit.install(_s, ConditionKit.Fake.new(&"stacks"))
	a.hit = 1.15
	var b: ConditionKit.Fake = ConditionKit.install(_s, ConditionKit.Fake.new(&"trade"))
	b.hit = 1.25
	ConditionKit.cond(_s, 0).apply(ConditionKit.apply(ConditionApply.EXPOSE, 15.0, 6000), 0, 0, true, _s.data.conditions())
	_roll(40)
	assert_eq(_base(), 66)


func test_base_attack_of_the_effects_of_m27_stays_in_the_product() -> void:
	_fight(100)
	_roll(40)
	var ctx: EffectContext = _s.combat._ctx()
	ctx.damage_mult = 1.5  # F-81 low_hp_damage_mult
	ctx.primary_index = 0
	var fake: ConditionKit.Fake = ConditionKit.install(_s, ConditionKit.Fake.new())
	fake.hit = 1.15
	assert_eq(_s.combat._base_roll(0, ctx)["damage"], floori(40 * 1.5 * 1.15), "60 x 1.15 = 69")


# An ability x1.3 on a target with 25/100 hp and an `execute` of 30% x2.5: tiro 40, DR 10 -> 52 -> 130 -> floor(130 x 0.9) = 117;
# with 31/100 hp the factor is 1: 52 -> floor(46.8) = 46.
func test_an_ability_with_an_execute_factor() -> void:
	var enemy: Encounter.Enemy = _fight(100, 10.0)
	enemy.hp = 25
	_roll(40)
	var m: float = 2.5 if enemy.hp * 100 <= enemy.stats.max_hp * 30 else 1.0
	assert_eq(Encounter.roll_power_attack(_s.combat.player_stats(), enemy.stats, 1.3, m, _s.rng, _s.data)["damage"], 117)
	enemy.hp = 31
	_roll(40)
	m = 2.5 if enemy.hp * 100 <= enemy.stats.max_hp * 30 else 1.0
	assert_eq(Encounter.roll_power_attack(_s.combat.player_stats(), enemy.stats, 1.3, m, _s.rng, _s.data)["damage"], 46)


func test_the_pierce_applies_after_m() -> void:
	_fight(100, 10.0)
	_roll(20)
	var ctx: EffectContext = _s.combat._ctx()
	ctx.dr_mult = 0.5  # armor_pierce_pct: half of the reduction
	ctx.primary_index = 0
	assert_eq(_s.combat._base_roll(0, ctx)["damage"], 19, "floor(20 x (1 - 0.05))")


# F-192 riposte: parry, tiro 30, x0.8, neutral, DR 10 -> floor(24) = 24 -> floor(21.6) = 21.
func test_a_counter_attack_example() -> void:
	var enemy: Encounter.Enemy = _fight(100, 10.0)
	_roll(30)
	assert_eq(Encounter.roll_power_attack(_s.combat.player_stats(), enemy.stats, 0.8, 1.0, _s.rng, _s.data)["damage"], 21)


func test_the_hit_context_describes_the_target_and_the_kind() -> void:
	_fight(100)
	var fake: ConditionKit.Fake = ConditionKit.install(_s, ConditionKit.Fake.new())
	_roll(10)
	var ctx: EffectContext = _s.combat._ctx()
	ctx.primary_index = 0
	_s.combat._base_roll(0, ctx)
	_s.combat._hit_mult(0, EffectContext.HIT_ABILITY, -1, AbilityDef.KIND_STRIKE)
	var seen: Array[Dictionary] = fake.hooks("hit_mult")
	assert_eq(seen[0]["kind"], EffectContext.HIT_BASE)
	assert_eq([seen[0]["target"], seen[0]["primary"], seen[0]["alive"]], [0, 0, 1])
	assert_eq([seen[1]["kind"], seen[1]["ability_kind"]], [EffectContext.HIT_ABILITY, AbilityDef.KIND_STRIKE])


func test_roll_power_attack_draws_like_the_ability_roll_of_m27() -> void:
	var enemy: Encounter.Enemy = _fight(100)
	var a := RngService.new(5)
	var b := RngService.new(5)
	var plain: Dictionary = Encounter.roll_power_attack(_s.combat.player_stats(), enemy.stats, 1.7, 1.0, a, _s.data)
	var again: Dictionary = Encounter.roll_power_attack(_s.combat.player_stats(), enemy.stats, 1.7, 1.0, b, _s.data)
	assert_eq(plain, again)
	assert_eq(a.to_save(), b.to_save())
	assert_eq(a.to_save()["state"] != RngService.new(5).to_save()["state"], true, "two draws were taken")
