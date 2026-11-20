extends GutTest
## F-193 (the order of the instant) and the hooks of M28 of docs/02_FORMULAS_M28.md and docs/05_INTERFACES_M28.md §5.10b-c, with
## fake effects: who is asked what, and in which order, when the player and the enemies act at the same instant.

var _s: GameSession


func _fight(enemies: Array, player_timer_ms: int = 100000, max_hp_extra: int = 100000) -> ConditionKit.Fake:
	_s = autofree(ConditionKit.session(enemies, player_timer_ms, max_hp_extra))
	return ConditionKit.install(_s, ConditionKit.Fake.new())


# --- the order of one instant ----------------------------------------------------------------------------------------

func test_player_then_enemies_by_position_then_the_bleed() -> void:
	_fight([EffectKit.enemy(ConditionKit.MONSTER_B, 60, 0), EffectKit.enemy(ConditionKit.MONSTER_B, 60, 0)], 0)
	var rows: Array = []
	ConditionKit.record(_s, rows)
	_s.combat._apply_condition(1, ConditionKit.apply(ConditionApply.BLEED, 100.0, 1000), 10)  # one tick of 10
	_s.combat._clock.ms = 0
	_s.combat.advance(0)
	var order: Array = rows.map(func(r: Array) -> String: return "%s:%s" % [r[1], str(r[2])])
	assert_eq(order, ["hit:-1", "hit:0", "hit:1", "tick:1"], "player, enemy 0, enemy 1, then the Bleed")


# --- the hooks of the player's hits ---------------------------------------------------------------------------------

func test_on_hit_sees_the_kind_the_target_and_the_damage() -> void:
	var fake: ConditionKit.Fake = _fight([EffectKit.enemy(ConditionKit.MONSTER_B, 60, 2400)], 0)
	(_s.rng as ConditionKit.ScriptRng).ints = [7]
	_s.combat.advance(0)
	var hit: Dictionary = fake.hooks("on_hit")[0]
	assert_eq([hit["kind"], hit["target"], hit["base"]], [EffectContext.HIT_BASE, 0, true])
	assert_eq(hit["damage"], hit["ctx_damage"])
	assert_eq(fake.hooks("hit_mult")[0]["primary"], 0)


func test_the_conditions_of_the_effects_are_applied_after_the_hit() -> void:
	var fake: ConditionKit.Fake = _fight([EffectKit.enemy(ConditionKit.MONSTER_B, 60, 2400)], 0)
	fake.applies = [ConditionKit.apply(ConditionApply.WEAKEN, 25.0, 6000)]
	(_s.rng as ConditionKit.ScriptRng).ints = [7]
	_s.combat.advance(0)
	assert_eq(ConditionKit.cond(_s, 0).weaken_pct, 25.0)


func test_a_target_that_dies_of_the_hit_gets_no_condition() -> void:
	var fake: ConditionKit.Fake = _fight([EffectKit.enemy(ConditionKit.MONSTER_A, 3, 2800), EffectKit.enemy(ConditionKit.MONSTER_B, 60, 2400)], 0)
	fake.applies = [ConditionKit.apply(ConditionApply.BLEED, 100.0, 4000)]
	(_s.rng as ConditionKit.ScriptRng).ints = [9]
	_s.combat.advance(0)
	assert_eq(_s.combat.kills(&"test_monster_a"), 1)
	assert_eq(_s.combat._clock.ms, -1, "the dead enemy does not bleed")


func test_the_hits_left_on_a_dead_target_are_lost_without_an_event() -> void:
	_fight([EffectKit.enemy(ConditionKit.MONSTER_A, 3, 2800), EffectKit.enemy(ConditionKit.MONSTER_B, 60, 2400)])
	var hits: Array = []
	_s.events.combat_hit.connect(func(a: int, t: int, h: bool, d: int, b: bool) -> void: hits.append([a, t, h, d, b]))
	var attacks: Array[Dictionary] = [{"hit": true, "blocked": false, "damage": 5}, {"hit": true, "blocked": false, "damage": 5},
			{"hit": true, "blocked": false, "damage": 5}]
	_s.combat._apply_hits([0, 0, 1], attacks)
	assert_eq(hits, [[-1, 0, true, 5, false], [-1, 1, true, 5, false]], "the second hit on the dead enemy is not an event")


func test_the_ability_conditions_and_drain_of_an_attack_are_applied() -> void:
	_fight([EffectKit.enemy(ConditionKit.MONSTER_B, 60, 2400)], 100000, 0)
	_s.combat._set_hp(10)
	var attack: Dictionary = {"hit": true, "blocked": false, "damage": 10, "drain": 4,
			"applies": [ConditionKit.apply(ConditionApply.BLEED, 30.0, 4000), ConditionKit.apply(ConditionApply.EXPOSE, 15.0, 6000)]}
	_s.combat._apply_hits([0], [attack] as Array[Dictionary])
	assert_eq([ConditionKit.cond(_s, 0).bleed_left, ConditionKit.cond(_s, 0).bleed_ticks], [3, 4], "floor(10 x 30%)")
	assert_eq(ConditionKit.cond(_s, 0).expose_ms, 6000)
	assert_eq(_s.combat.get_state()["player_hp"], 14, "drain 4")


func test_the_drain_does_not_go_over_the_maximum() -> void:
	_fight([EffectKit.enemy(ConditionKit.MONSTER_B, 60, 2400)], 100000, 0)
	_s.combat._set_hp(58)
	_s.combat._apply_hits([0], [{"hit": true, "blocked": false, "damage": 10, "drain": 9}] as Array[Dictionary])
	assert_eq(_s.combat.get_state()["player_hp"], 60)


func test_ability_used_has_no_repeated_targets() -> void:
	assert_eq(CombatState._distinct([2, 0, 2, 1, 0] as Array[int]), [2, 0, 1] as Array[int])


# --- the hooks of an attack of the enemy ----------------------------------------------------------------------------

func test_a_miss_calls_on_evade_and_a_hit_does_not() -> void:
	var fake: ConditionKit.Fake = _fight([EffectKit.enemy(ConditionKit.MONSTER_B, 60, 2400)])
	_s.combat._incoming(0, {"hit": false, "blocked": false, "damage": 0})
	assert_eq(fake.hooks("on_evade").size(), 1)
	assert_eq(fake.hooks("on_evade")[0]["source"], 0)
	_s.combat._incoming(0, {"hit": true, "blocked": false, "damage": 9})
	assert_eq(fake.hooks("on_evade").size(), 1)
	assert_true(fake.hooks("on_block").is_empty())
	assert_eq(fake.hooks("on_damaged")[0]["source"], 0)


func test_the_pulse_has_no_source_and_no_counter() -> void:
	var fake: ConditionKit.Fake = _fight([EffectKit.enemy(ConditionKit.MONSTER_B, 60, 2400)])
	fake.counter = 0.8
	_s.combat._incoming(FractureCombat.PULSE_SOURCE, {"hit": true, "blocked": true, "damage": 0})
	assert_eq(fake.hooks("on_block")[0]["source"], -1)
	assert_eq(_s.combat._encounter.enemies[0].hp, 60, "no counter-attack on a pulse")


func test_a_block_gives_the_counter_attack_of_the_strongest_riposte() -> void:
	var fake: ConditionKit.Fake = _fight([EffectKit.enemy(ConditionKit.MONSTER_B, 60, 2400)])
	fake.counter = 0.8
	var other: ConditionKit.Fake = ConditionKit.install(_s, ConditionKit.Fake.new(&"other"))
	other.counter = 1.5
	(_s.rng as ConditionKit.ScriptRng).ints = [10]
	var hits: Array = []
	_s.events.combat_hit.connect(func(a: int, t: int, h: bool, d: int, b: bool) -> void: hits.append([a, t, h, d, b]))
	_s.combat._incoming(0, {"hit": true, "blocked": true, "damage": 0})
	assert_eq(hits.size(), 2, "the blocked attack and ONE counter-attack")
	assert_eq(hits[1][0], CombatEngine.PLAYER)
	assert_eq(hits[1][1], 0)
	var counter_hit: Dictionary = fake.hooks("on_hit")[0]
	assert_eq(counter_hit["kind"], EffectContext.HIT_COUNTER)
	assert_false(counter_hit["base"])
	assert_eq(fake.hooks("hit_mult")[0]["kind"], EffectContext.HIT_COUNTER)


func test_a_block_gives_a_ward_the_largest_one() -> void:
	var fake: ConditionKit.Fake = _fight([EffectKit.enemy(ConditionKit.MONSTER_B, 60, 2400)], 100000, 340)
	fake.ward_pct = 5.0
	fake.ward_ms = 3000
	_s.combat._incoming(0, {"hit": true, "blocked": true, "damage": 0})
	assert_eq(_s.combat._ward.to_save(), {"amount": 20, "ms": 3000}, "5% of 400")


func test_a_kill_cuts_the_cooldowns_and_a_kill_with_no_cut_changes_nothing() -> void:
	var fake: ConditionKit.Fake = _fight([EffectKit.enemy(ConditionKit.MONSTER_A, 3, 2800), EffectKit.enemy(ConditionKit.MONSTER_B, 60, 2400)], 0)
	var loadout_timers_before: Dictionary = _s.combat._abilities.timers_save()
	(_s.rng as ConditionKit.ScriptRng).ints = [9]
	_s.combat.advance(0)
	assert_eq(_s.combat._abilities.timers_save(), loadout_timers_before, "a cut of 0 does not even write the timers")
	assert_eq(fake.hooks("on_kill")[0]["target"], 0)


func test_the_base_timer_after_an_attack_follows_the_factor_but_not_under_the_minimum() -> void:
	var fake: ConditionKit.Fake = _fight([EffectKit.enemy(ConditionKit.MONSTER_B, 60, 2400)], 0)
	var interval: int = _s.combat.player_stats().attack_interval_ms
	fake.timer = 0.5
	_s.combat.advance(0)
	assert_eq(_s.combat._player_timer_ms, maxi(int(_s.data.balance_value("combat.min_attack_interval_ms")), floori(interval * 0.5)))
	fake.timer = 1.0
	_s.combat._player_timer_ms = 0
	_s.combat.advance(0)
	assert_eq(_s.combat._player_timer_ms, interval)
