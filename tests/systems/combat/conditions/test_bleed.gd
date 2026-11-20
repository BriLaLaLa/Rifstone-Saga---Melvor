extends GutTest
## F-186 (Bleed) of docs/02_FORMULAS_M28.md: the total, the ticks, the accumulation, the one clock, the kill and the boss shield.
## The Bleed is applied by hand (the engine call the effects use) in a fight on the fixture data; `tick_ms` is 1000.

var _params: ConditionParams
var _sessions: Array[GameSession] = []


func before_all() -> void:
	_params = TestFactory.fixture_data().conditions()


# A fight with `enemies` (monster B has 60 hp, A 20), the player far away from his next attack.
func _fight(enemies: Array) -> GameSession:
	var s: GameSession = autofree(ConditionKit.session(enemies))
	return s


func _bleed(s: GameSession, index: int, damage: int, pct: float, ms: int) -> void:
	s.combat._apply_condition(index, ConditionKit.apply(ConditionApply.BLEED, pct, ms), damage)


# The damages of the ticks of one enemy over `ms` of time, in one `advance`.
func _ticks(s: GameSession, ms: int) -> Array[int]:
	var out: Array[int] = []
	var listener: Callable = func(_t: int, d: int, _c: StringName) -> void: out.append(d)
	s.events.combat_condition_damage.connect(listener)
	s.combat.advance(ms)
	s.events.combat_condition_damage.disconnect(listener)
	return out


func test_total_and_ticks_5_5_4_4() -> void:
	var s: GameSession = _fight([EffectKit.enemy(ConditionKit.MONSTER_B, 60, 2400)])
	_bleed(s, 0, 37, 50.0, 4000)
	assert_eq([ConditionKit.cond(s, 0).bleed_left, ConditionKit.cond(s, 0).bleed_ticks], [18, 4], "floor(37 x 50%) = 18, 4 ticks")
	assert_eq(_ticks(s, 2300), [5, 5] as Array[int], "the first two ticks of a 2.3 s span")
	assert_eq(_ticks(s, 2000), [4, 4] as Array[int])
	assert_false(ConditionKit.cond(s, 0).bleeds())


func test_a_new_bleed_adds_the_damage_and_keeps_the_longer_ticks() -> void:
	var s: GameSession = _fight([EffectKit.enemy(ConditionKit.MONSTER_B, 60, 2400)])
	_bleed(s, 0, 37, 50.0, 4000)
	var first: Array[int] = _ticks(s, 2000)
	assert_eq(first, [5, 5] as Array[int])
	assert_eq([ConditionKit.cond(s, 0).bleed_left, ConditionKit.cond(s, 0).bleed_ticks], [8, 2], "8 left in 2 ticks")
	_bleed(s, 0, 20, 50.0, 4000)
	assert_eq([ConditionKit.cond(s, 0).bleed_left, ConditionKit.cond(s, 0).bleed_ticks], [18, 4])
	assert_eq(_ticks(s, 4000), [5, 5, 4, 4] as Array[int])


func test_a_hit_of_one_damage_leaves_no_bleed() -> void:
	var s: GameSession = _fight([EffectKit.enemy(ConditionKit.MONSTER_B, 60, 2400)])
	_bleed(s, 0, 1, 50.0, 4000)
	assert_false(ConditionKit.cond(s, 0).bleeds())
	assert_eq(s.combat._clock.ms, -1, "and no clock")


func test_ticks_are_the_duration_over_the_tick_time_rounded_up() -> void:
	var c := EnemyConditions.new()
	c.apply(ConditionKit.apply(ConditionApply.BLEED, 100.0, 2500), 30, 0, true, _params)
	assert_eq(c.bleed_ticks, 3)
	assert_eq([c.take_tick(), c.take_tick(), c.take_tick(), c.take_tick()], [10, 10, 10, 0], "ceil(30 / 3), no tick after the last")


func test_the_enemy_that_dies_of_a_tick_counts_as_a_kill() -> void:
	var s: GameSession = _fight([EffectKit.enemy(ConditionKit.MONSTER_A, 7, 2800)])
	_bleed(s, 0, 20, 50.0, 2000)  # 10 in 2 ticks: 5, 5
	var killed: Array[int] = []
	s.events.monster_killed.connect(func(i: int, _id: StringName) -> void: killed.append(i))
	var ticks: Array[int] = _ticks(s, 2000)
	assert_eq(ticks, [5, 5] as Array[int])
	assert_eq(killed, [0] as Array[int], "7 hp: dead at the second tick")
	assert_eq(s.combat.kills(&"test_monster_a"), 1)


# The first enemy starts to bleed at t = 2.3 s: ticks at 3.3, 4.3, 5.3, 6.3 s. The second starts at 3.8 s: its first tick is at 4.3 s,
# with the second tick of the first (the clock is one), and the first enemy is served first.
func test_the_clock_is_one_for_all_the_enemies() -> void:
	var s: GameSession = _fight([EffectKit.enemy(ConditionKit.MONSTER_B, 60, 2400), EffectKit.enemy(ConditionKit.MONSTER_B, 60, 2400)])
	var time: Dictionary = {"t": 0}
	var ticks: Array = []
	s.events.combat_condition_damage.connect(func(i: int, d: int, _c: StringName) -> void:
		ticks.append([time["t"] + s.combat.advance_offset_ms, i, d]))
	s.combat.advance(2300)
	_bleed(s, 0, 40, 100.0, 4000)
	assert_eq(s.combat._clock.ms, 1000, "the clock starts full")
	time["t"] = 2300
	s.combat.advance(1500)
	_bleed(s, 1, 40, 100.0, 4000)
	assert_eq(s.combat._clock.ms, 500, "the second enemy joins the running clock: 4.3 s - 3.8 s")
	time["t"] = 3800
	s.combat.advance(3000)
	assert_eq(ticks, [[3300, 0, 10], [4300, 0, 10], [4300, 1, 10], [5300, 0, 10], [5300, 1, 10], [6300, 0, 10], [6300, 1, 10]])


# F-186: a boss with a shield of 3 and a tick of 5: shield 0, hp -2 (the shield of a dungeon boss, F-112).
func test_a_boss_shield_takes_the_tick() -> void:
	var s: GameSession = _fight([EffectKit.enemy(ConditionKit.MONSTER_B, 60, 2400)])
	var stage := DungeonStageDef.new()
	stage.monster = s.data.monster(&"test_monster_b")
	s.combat._dg.stage = stage
	s.combat._dg.fighting = true
	s.combat._dg.shield = 3
	s.combat._dg.shield_ms = 100000
	_bleed(s, 0, 10, 50.0, 1000)  # 5 damage in one tick
	s.combat._bleed_tick()
	assert_eq(s.combat._dg.shield, 0)
	assert_eq(s.combat._encounter.enemies[0].hp, 58)


func test_the_clock_stops_when_the_encounter_is_over() -> void:
	var s: GameSession = _fight([EffectKit.enemy(ConditionKit.MONSTER_A, 7, 2800)])
	_bleed(s, 0, 20, 50.0, 2000)
	s.combat.advance(2000)
	assert_eq(s.combat._clock.ms, -1, "the only enemy is dead")
	assert_eq(s.combat.state(), CombatEngine.STATE_TRAVEL)


func test_the_same_events_in_one_step_and_in_ten() -> void:
	var rows: Array = [[], []]
	for variant: int in 2:
		var s: GameSession = autofree(ConditionKit.session([EffectKit.enemy(ConditionKit.MONSTER_B, 60, 2400),
				EffectKit.enemy(ConditionKit.MONSTER_B, 60, 1700)], 3000))
		s.rng = RngService.new(77)
		_bleed(s, 0, 60, 100.0, 5000)
		var clock: Dictionary = {"t": 0}
		ConditionKit.record(s, rows[variant], clock)
		if variant == 0:
			s.combat.advance(10000)
		else:
			for i: int in 100:
				clock["t"] = i * 100
				s.combat.advance(100)
	assert_eq(rows[0], rows[1])
	assert_true(rows[0].any(func(r: Array) -> bool: return r[1] == "tick"), "the Bleed did tick")
