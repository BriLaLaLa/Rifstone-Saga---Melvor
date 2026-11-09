extends GutTest
## The three abilities of a Fracture boss (F-112, docs/01_GDD.md §17.3) on the fixture bosses: grade 1 `heavy_strike`
## (every 8000 ms, x2.0), grade 2 `shield` (every 10000 ms, 4000 ms, 20%), grade 3 `summon` (every 12000 ms, 1, max 2).
## Unit tests on `BossAbility` / `FractureCombat`, then the engine: timing, F-76 order, save and resume, advance in steps.

const SOURCE: StringName = &"test:hero"

var _s: GameSession = null
var _clock: int = 0  # ms advanced by `_adv`
var _t0: int = 0  # the clock at the instant the boss appeared
var _boss_seen: bool = false
var _hits: Array = []  # [t, hit, damage, blocked] of the boss hitting the player, t = ms since the boss appeared


func _tank(s: GameSession) -> void:
	s.modifiers.set_source(SOURCE, [Modifier.make(&"power_bonus", -1000.0), Modifier.make(&"max_hp_flat", 100000.0)])


func _adv(ms: int) -> void:
	_s.advance(ms)
	_clock += ms


func _on_boss(_id: StringName) -> void:
	_boss_seen = true
	_t0 = _clock + _s.combat.advance_offset_ms
	_tank(_s)


func _on_hit(attacker: int, defender: int, hit: bool, damage: int, blocked: bool) -> void:
	if _boss_seen and attacker == 0 and defender == CombatFight.PLAYER:
		_hits.append([_clock + _s.combat.advance_offset_ms - _t0, hit, damage, blocked])


## A session on the fixtures with `_s` at the very start of the boss of `grade`, the player turned into a tank that barely hurts.
func _to_boss(grade: int, seed_value: int = 55) -> GameSession:
	_s = autofree(FractureUtil.session(seed_value))
	_clock = 0
	_boss_seen = false
	_hits = []
	FractureUtil.hero(_s)
	_s.events.fracture_boss_started.connect(_on_boss)
	_s.events.combat_hit.connect(_on_hit)
	assert_true(_s.fractures.open(FractureUtil.card(_s, grade)).ok)
	while not _boss_seen and _clock < 3_600_000:
		_adv(100)
	assert_true(_boss_seen)
	return _s


func _at(t: int) -> void:
	_adv(t - (_clock - _t0))


func _expected_heavy(mult: float) -> int:
	var raw: int = floori(float(_s.combat.enemy_stats(0).max_hit) * mult + 1e-9)
	return maxi(1, floori(float(raw) * (1.0 - _s.combat.player_stats().damage_reduction / 100.0) + 1e-9))


# F-112 example: max_hit 40, mult 2.0, reduction 10% -> 80 -> 72.
func test_heavy_strike_example() -> void:
	var data: GameData = FractureUtil.data()
	var boss := CombatantStats.new()
	boss.max_hit = 40
	boss.style = &"blade"
	var me := CombatantStats.new()
	me.style = &"blade"
	me.damage_reduction = 10.0
	var ability: BossAbilityDef = data.boss_for_grade(1).ability
	var result: Dictionary = BossAbility.heavy_strike(boss, me, ability, RngService.new(1), data)
	assert_eq(result, {"hit": true, "blocked": false, "damage": 72})


func test_heavy_strike_can_be_blocked_and_the_block_is_the_only_roll() -> void:
	var data: GameData = FractureUtil.data()
	var boss := CombatantStats.new()
	boss.max_hit = 40
	boss.style = &"blade"
	var me := CombatantStats.new()
	me.style = &"blade"
	me.block_chance = 100.0
	var rng := RngService.new(5)
	var shadow := RngService.new(5)
	var result: Dictionary = BossAbility.heavy_strike(boss, me, data.boss_for_grade(1).ability, rng, data)
	assert_true(result["blocked"])
	assert_eq(result["damage"], 0)
	shadow.roll_pct(100.0)
	assert_eq(rng.to_save(), shadow.to_save(), "one roll only")
	me.block_chance = 0.0
	var before: Dictionary = rng.to_save()
	BossAbility.heavy_strike(boss, me, data.boss_for_grade(1).ability, rng, data)
	assert_eq(rng.to_save(), before, "no roll without a block chance")


# F-112 example: 20% of 1000 hp -> 200.
func test_shield_example() -> void:
	assert_eq(BossAbility.shield_amount(1000, FractureUtil.data().boss_for_grade(2).ability), 200)
	assert_eq(BossAbility.shield_amount(3500, FractureUtil.data().boss_for_grade(2).ability), 700)


func test_summon_respects_max_alive_and_the_pack_size() -> void:
	var data: GameData = FractureUtil.data()
	var ability: BossAbilityDef = data.boss_for_grade(3).ability
	var none: Array[Dictionary] = []
	assert_eq(BossAbility.summon_defs(ability, 0, 1, 6, 3, none, data).size(), 1, "count 1")
	assert_eq(BossAbility.summon_defs(ability, 2, 3, 6, 3, none, data).size(), 0, "max_alive 2 reached")
	var wide: BossAbilityDef = BossAbilityDef.new()
	wide.type = BossAbilityDef.SUMMON
	wide.count = 3
	wide.max_alive = 9
	wide.monsters = [&"test_monster_a", &"test_loot_monster"]
	var defs: Array[MonsterDef] = BossAbility.summon_defs(wide, 0, 1, 6, 3, none, data)
	assert_eq(defs.size(), 3)
	assert_eq([defs[0].id, defs[1].id, defs[2].id], [&"test_monster_a", &"test_loot_monster", &"test_monster_a"], "repeated in order")
	assert_eq(BossAbility.summon_defs(wide, 0, 5, 6, 3, none, data).size(), 1, "boss + summoned <= max_pack_size")
	assert_eq(BossAbility.summon_defs(wide, 4, 6, 6, 3, none, data).size(), 0)


# The first use is `every_ms` after the boss appears, at the instant of the base attack of the boss and after it (F-76).
func test_heavy_strike_timing_and_order() -> void:
	_to_boss(1)
	_at(25000)
	var heavy: int = _expected_heavy(2.0)
	var at_8000: Array = _hits.filter(func(h: Array) -> bool: return h[0] == 8000)
	assert_eq(at_8000.size(), 1)
	assert_eq(at_8000[0].slice(1), [true, heavy, false])
	assert_eq(_hits.filter(func(h: Array) -> bool: return h[0] == 16000).size(), 1)
	var at_24000: Array = _hits.filter(func(h: Array) -> bool: return h[0] == 24000)
	assert_eq(at_24000.size(), 2, "the base attack and the ability at the same instant")
	assert_eq(at_24000[1].slice(1), [true, heavy, false], "the ability after the base attack")
	assert_true(_hits.all(func(h: Array) -> bool: return h[0] % 3000 == 0 or h[0] % 8000 == 0))


func test_shield_appears_absorbs_and_fades() -> void:
	_to_boss(2)
	_at(9900)
	assert_eq(_s.combat.get_state()["fracture"]["shield"], 0)
	_at(10000)
	var view: Dictionary = _s.combat.get_state()["fracture"]
	assert_eq(view["shield"], 700, "20% of 3500")
	assert_eq(view["shield_ms"], 4000)
	var boss_hp: int = _s.combat.get_state()["enemies"][0]["hp"]
	_at(13900)
	view = _s.combat.get_state()["fracture"]
	assert_lt(view["shield"], 700, "the player hit the shield")
	assert_eq(_s.combat.get_state()["enemies"][0]["hp"], boss_hp, "the hp is untouched while the shield holds")
	_at(14000)
	view = _s.combat.get_state()["fracture"]
	assert_eq([view["shield"], view["shield_ms"]], [0, 0], "gone after duration_ms, with what was left")


func test_shield_takes_the_damage_first_and_is_not_renewed() -> void:
	var s: GameSession = autofree(FractureUtil.session(3))
	assert_true(s.fractures.open(FractureUtil.card(s, 2)).ok)
	var fc := FractureCombat.new(s)
	fc.begin(s.fractures.run())
	fc.run.groups_cleared = fc.run.groups_total
	var encounter: Encounter = fc.next_encounter()
	var boss: Encounter.Enemy = encounter.enemies[0]
	assert_true(fc.is_boss(boss))
	assert_eq(fc.boss_ability_ms, 10000)
	assert_eq(fc.absorb(boss, 50), 50, "no shield yet")
	var summoned: Array[int] = []
	fc.use_ability(boss, encounter, s.combat.player_stats(), summoned)
	assert_eq(fc.boss_shield, boss.stats.max_hp * 20 / 100)
	var shield: int = fc.boss_shield
	assert_eq(fc.absorb(boss, 50), 0)
	assert_eq(fc.boss_shield, shield - 50)
	fc.use_ability(boss, encounter, s.combat.player_stats(), summoned)
	assert_eq(fc.boss_shield, shield - 50, "an active shield is not renewed")
	assert_eq(fc.boss_ability_ms, 10000, "but the timer restarts")
	assert_eq(fc.absorb(boss, shield), 50, "the shield breaks and the rest goes through")
	assert_eq(fc.boss_shield, 0)
	assert_eq(fc.boss_shield_ms, 0)
	fc.tick(1)
	assert_eq(fc.boss_ability_ms, 9999)


func test_summon_positions_and_no_rewards() -> void:
	var s: GameSession = autofree(FractureUtil.session(4))
	assert_true(s.fractures.open(FractureUtil.card(s, 3)).ok)
	var fc := FractureCombat.new(s)
	fc.begin(s.fractures.run())
	fc.run.groups_cleared = fc.run.groups_total
	var encounter: Encounter = fc.next_encounter()
	var boss: Encounter.Enemy = encounter.enemies[0]
	var me: CombatantStats = s.combat.player_stats()
	var added: Array[int] = []
	fc.use_ability(boss, encounter, me, added)
	fc.use_ability(boss, encounter, me, added)
	fc.use_ability(boss, encounter, me, added)
	assert_eq(added, [1, 2], "max_alive 2: the third use summons nothing")
	assert_eq(encounter.enemies.size(), 3)
	assert_true(encounter.enemies[1].summoned and encounter.enemies[2].summoned and not boss.summoned)
	encounter.enemies[1].hp = 0
	added = []
	fc.use_ability(boss, encounter, me, added)
	assert_eq(added, [1], "the free position is used again")
	assert_eq(encounter.enemies.size(), 3)
	assert_lte(encounter.alive_count(), int(s.data.balance_value("combat.max_pack_size")))
	var xp: int = s.character.get_xp()
	var gold: int = s.wallet.get_gold()
	assert_false(fc.reward(encounter.enemies[1]), "a summoned enemy is not a kill of the data")
	assert_eq(s.character.get_xp(), xp)
	assert_eq(s.wallet.get_gold(), gold)
	assert_true(s.fractures.run().bag.is_empty())


func test_the_summoned_enemies_appear_in_the_fight_and_die_with_the_fracture() -> void:
	_to_boss(3)
	_at(11900)
	assert_eq(_s.combat.get_state()["enemies"].size(), 1)
	_at(12000)
	var enemies: Array = _s.combat.get_state()["enemies"]
	assert_eq(enemies.size(), 2)
	assert_true(_s.combat.to_save()["enemies"][1]["summoned"])
	assert_false((_s.combat.to_save()["enemies"][0] as Dictionary).has("summoned"))
	_at(24000)
	assert_eq(_s.combat.get_state()["enemies"].size(), 3, "boss and two summoned (max_alive 2)")
	_s.fractures.abandon()
	assert_false(_s.combat.in_fracture())


func test_no_phases_the_boss_has_one_ability() -> void:
	for grade: int in range(1, 4):
		assert_true(FractureUtil.data().boss_for_grade(grade).ability != null)


func test_advance_in_different_steps_gives_the_same_fight() -> void:
	for grade: int in range(1, 4):
		var a: GameSession = _to_boss(grade, 70 + grade)
		var clock_a: int = _clock
		for _i: int in 30:
			a.advance(1000)
		var state_a: Array = [a.combat.to_save(), a.combat.get_state(), a.rng.to_save()]
		var b: GameSession = _to_boss(grade, 70 + grade)
		assert_eq(_clock, clock_a)
		for _i: int in 300:
			b.advance(100)
		assert_eq([b.combat.to_save(), b.combat.get_state(), b.rng.to_save()], state_a, "grade %d" % grade)
		assert_true(b.combat.in_fracture())


func test_save_and_resume_with_each_ability() -> void:
	for grade: int in range(1, 4):
		var a: GameSession = _to_boss(grade, 80 + grade)
		_at(11000)
		var saved: Dictionary = (a.combat.to_save()["fracture"] as Dictionary)["boss"]
		assert_eq(saved["ability_ms"], [5000, 9000, 1000][grade - 1])
		if grade == 2:
			assert_eq([saved["shield"] > 0, saved["shield_ms"]], [true, 3000])
		var parsed: Variant = JSON.parse_string(JSON.stringify(a.to_save(1)))
		var b: GameSession = autofree(FractureUtil.session(999))
		assert_true(b.from_save(parsed as Dictionary).ok)
		_tank(b)  # a test modifier is not saved: restore the fight again with it in place (no clamp of the hp)
		b.combat.from_save(((parsed as Dictionary)["modules"] as Dictionary)["combat"])
		assert_eq(b.combat.to_save(), a.combat.to_save(), "grade %d" % grade)
		assert_eq(b.combat.get_state(), a.combat.get_state())
		for _i: int in 60:
			a.advance(250)
			b.advance(250)
		assert_eq(b.combat.to_save(), a.combat.to_save(), "grade %d after 15 s" % grade)
		assert_eq(b.rng.to_save(), a.rng.to_save())
