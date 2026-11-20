extends GutTest
## F-189 (the Ward of the player) of docs/02_FORMULAS_M28.md: the amount, the grant (the bigger amount and the longer time), the time
## in every state, and the end (stop, death, a new combat).


func test_the_amount_is_a_percentage_of_the_maximum_hp() -> void:
	var s: GameSession = autofree(ConditionKit.session([EffectKit.enemy(ConditionKit.MONSTER_A, 20, 2800)], 100000, 340))  # 400 hp
	var ctx: EffectContext = s.combat._ctx()
	assert_eq(ctx.player_max_hp, 400)
	ctx.ward_pct = 15.0
	ctx.ward_ms = 6000
	s.combat._grant_ward(ctx)
	assert_eq(s.combat._ward.to_save(), {"amount": 60, "ms": 6000}, "400 x 15% = 60")


func test_a_new_ward_keeps_the_bigger_amount_and_the_longer_time() -> void:
	var ward := PlayerWard.new()
	ward.grant(20, 2000)
	ward.grant(60, 6000)
	assert_eq(ward.to_save(), {"amount": 60, "ms": 6000}, "20 for 2 s then 60 for 6 s")
	ward = PlayerWard.new()
	ward.grant(60, 1000)
	ward.grant(32, 5000)
	assert_eq(ward.to_save(), {"amount": 60, "ms": 5000}, "60 for 1 s then 32 for 5 s")


func test_nothing_is_granted_without_an_amount_or_a_time() -> void:
	var ward := PlayerWard.new()
	ward.grant(0, 5000)
	ward.grant(50, 0)
	assert_false(ward.active())
	assert_eq(ward.to_save(), {})


func test_absorb_takes_what_it_can_and_ends_at_zero() -> void:
	var ward := PlayerWard.new()
	ward.grant(60, 6000)
	assert_eq(ward.absorb(25), 0)
	assert_eq(ward.amount, 35)
	assert_eq(ward.absorb(50), 15, "the Ward is gone and 15 is left for the hp")
	assert_false(ward.active())
	assert_eq(ward.absorb(10), 10, "no Ward: all of it")


func test_the_ward_runs_down_and_ends() -> void:
	var ward := PlayerWard.new()
	ward.grant(60, 1500)
	ward.elapse(1000)
	assert_eq(ward.ms, 500)
	ward.elapse(500)
	assert_false(ward.active(), "at 0 ms it is over")
	assert_eq(ward.amount, 0)


# F-192 ward_on at a kill: max hp 500, 8% -> 40 for 6 s; it runs down after the encounter, in the journey to the next one.
func test_a_ward_from_a_kill_goes_on_between_encounters() -> void:
	var s: GameSession = autofree(ConditionKit.session([EffectKit.enemy(ConditionKit.MONSTER_A, 1, 2800)], 500, 440))  # 500 hp
	var fake: ConditionKit.Fake = ConditionKit.install(s, ConditionKit.Fake.new())
	fake.ward_pct = 8.0
	fake.ward_ms = 6000
	s.combat.advance(500)
	assert_eq(s.combat.state(), CombatEngine.STATE_TRAVEL)
	assert_eq(s.combat.get_state()["ward"], {"amount": 40, "ms": 6000})
	s.combat.advance(1000)
	assert_eq(s.combat.get_state()["ward"], {"amount": 40, "ms": 5000}, "time passes in the journey too")


func test_the_ward_ends_with_stop_and_with_a_new_combat() -> void:
	var s: GameSession = autofree(ConditionKit.session([EffectKit.enemy(ConditionKit.MONSTER_A, 20, 2800)]))
	s.combat._ward.grant(60, 6000)
	s.combat.stop()
	assert_eq(s.combat.get_state()["ward"], {})
	s.combat._ward.grant(60, 6000)
	s.combat.start(&"test_area")
	assert_eq(s.combat.get_state()["ward"], {}, "a new combat starts without it")


func test_the_ward_ends_with_the_death_of_the_player() -> void:
	var s: GameSession = autofree(ConditionKit.session([EffectKit.enemy(ConditionKit.MONSTER_A, 20, 2800)], 100000, 0, 5))
	s.combat._ward.grant(2, 6000)
	s.combat._hurt_player(0, 50)
	assert_eq(s.combat.deaths(), 1)
	assert_eq(s.combat._ward.to_save(), {})


func test_a_saved_ward_is_read_with_care() -> void:
	assert_eq(PlayerWard.from_save({"amount": 35, "ms": 4200}).to_save(), {"amount": 35, "ms": 4200})
	assert_false(PlayerWard.from_save({"amount": 35, "ms": 0}).active(), "no time: no Ward")
	assert_false(PlayerWard.from_save({"amount": "x", "ms": 100}).active())
	assert_false(PlayerWard.from_save("ward").active())
	assert_false(PlayerWard.from_save(null).active())
	assert_false(PlayerWard.from_save({"amount": -5, "ms": 100}).active(), "a negative amount is 0")
