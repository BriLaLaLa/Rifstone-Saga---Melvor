extends GutTest
## F-193 (the damage the player takes) of docs/02_FORMULAS_M28.md: d0 -> Weaken and `damage_trade` -> `hit_cap_pct` -> Ward -> hp.
## The attack is given as its damage `d0` (after F-25) to the engine; the effects are fake ones (the real types come with M28-05).

var _s: GameSession


# A fight with one enemy (index 0) and a player with `max_hp` hp, full.
func _fight(max_hp: int = 400) -> void:
	_s = autofree(ConditionKit.session([EffectKit.enemy(ConditionKit.MONSTER_A, 20, 2800)], 100000, max_hp - 60))


func _weaken(pct: float) -> void:
	ConditionKit.cond(_s, 0).apply(ConditionKit.apply(ConditionApply.WEAKEN, pct, 6000), 0, 0, true, _s.data.conditions())


func _hp() -> int:
	return _s.combat.get_state()["player_hp"]


func test_the_weaken_of_the_source_lowers_the_damage() -> void:
	_fight()
	_weaken(25.0)
	assert_eq(_s.combat._incoming_damage(0, 25), 18, "floor(25 x 0.75) = floor(18.75)")


func test_weaken_and_damage_trade_make_one_product() -> void:
	_fight()
	_weaken(25.0)
	var fake: ConditionKit.Fake = ConditionKit.install(_s, ConditionKit.Fake.new())
	fake.incoming = 1.2
	assert_eq(_s.combat._incoming_damage(0, 25), 22, "floor(25 x 0.75 x 1.2) = floor(22.5)")


func test_damage_trade_alone_raises_the_damage() -> void:
	_fight()
	ConditionKit.install(_s, ConditionKit.Fake.new()).incoming = 1.2
	assert_eq(_s.combat._incoming_damage(0, 25), 30)


func test_a_weakened_hit_still_does_at_least_one() -> void:
	_fight()
	_weaken(25.0)
	assert_eq(_s.combat._incoming_damage(0, 1), 1)
	_weaken(90.0)
	assert_eq(_s.combat._incoming_damage(0, 1), 1, "floor(0.1) = 0, but at least 1")


func test_without_weaken_or_trade_the_damage_is_untouched() -> void:
	_fight()
	assert_eq(_s.combat._incoming_damage(0, 37), 37)
	assert_eq(_s.combat._incoming_damage(-2, 37), 37, "the pulse of a Fracture has no source")


func test_a_weaken_that_has_ended_does_not_count() -> void:
	_fight()
	_weaken(25.0)
	ConditionKit.cond(_s, 0).elapse(6000)
	assert_eq(_s.combat._incoming_damage(0, 25), 25)


func test_the_hp_lose_the_weakened_damage() -> void:
	_fight()
	_weaken(25.0)
	_s.combat._hurt_player(0, 25)
	assert_eq(_hp(), 400 - 18)


# Ward 60, d1 25 -> Ward 35, nothing else happens; then d1 50 -> Ward 0, hp -15, on_damaged(15).
func test_the_ward_takes_the_hit_and_then_what_is_left_goes_to_the_hp() -> void:
	_fight()
	var fake: ConditionKit.Fake = ConditionKit.install(_s, ConditionKit.Fake.new())
	_s.combat._ward.grant(60, 6000)
	_s.combat._hurt_player(0, 25)
	assert_eq(_s.combat._ward.amount, 35)
	assert_eq(_hp(), 400)
	assert_true(fake.hooks("on_damaged").is_empty(), "no hp lost: no on_damaged")
	_s.combat._hurt_player(0, 50)
	assert_false(_s.combat._ward.active())
	assert_eq(_hp(), 400 - 15)
	assert_eq(fake.hooks("on_damaged").size(), 1)
	assert_eq(fake.hooks("on_damaged")[0]["damage"], 15, "the reflect and the stacks see the hp lost")


# PV max 400, hit_cap_pct 25, Ward 60, d1 180 -> the cap makes it 100 -> the Ward takes 60 -> hp -40.
func test_the_cap_comes_before_the_ward() -> void:
	_fight()
	_s.combat._fx.effects().append(HitCapPct.new(&"cap", {"pct": 25}))
	_s.combat._ward.grant(60, 6000)
	_s.combat._hurt_player(0, 180)
	assert_eq(_hp(), 400 - 40)


func test_a_ward_that_takes_it_all_keeps_the_food_and_the_reflect() -> void:
	_fight()
	_s.combat._fx.effects().append(ReflectPct.new(&"reflect", {"pct": 100}))
	var enemy: Encounter.Enemy = _s.combat._encounter.enemies[0]
	var hp_before: int = enemy.hp
	_s.combat._ward.grant(100, 6000)
	_s.combat._hurt_player(0, 40)
	assert_eq(enemy.hp, hp_before, "no reflect")
	assert_eq(_s.combat.food_eaten(), 0)


func test_the_ward_does_not_stop_a_death() -> void:
	_fight(60)
	_s.combat._ward.grant(10, 6000)
	_s.combat._hurt_player(0, 100)
	assert_eq(_s.combat.deaths(), 1)
	assert_eq(_s.combat._ward.to_save(), {})


func test_without_a_ward_or_a_weaken_the_path_is_the_old_one() -> void:
	_fight()
	_s.combat._hurt_player(0, 31)
	assert_eq(_hp(), 400 - 31)
	assert_true(_s.combat._ward.to_save().is_empty())
