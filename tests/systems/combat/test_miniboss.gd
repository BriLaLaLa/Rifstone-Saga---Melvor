extends GutTest
## F-139 (docs/02_FORMULAS.md §5j) the miniboss of an area on the real data: the multipliers of `balance.miniboss` applied once, the
## roll after a normal encounter (`chance_pct` 100 and 0), the escorts, the precedence of a Rift Stone, the save in the middle.
## `MinibossData` loads the real content with another `chance_pct`. Fixed seeds.

const AREA: StringName = &"redrock_plains"
const MINIBOSS: StringName = &"miniboss_redrock_plains"
const HERO: StringName = &"test:hero"

var _started: Array = []  # the monster ids of every encounter started


func _session(chance_pct: int, seed_value: int = 5) -> GameSession:
	var s: GameSession = autofree(TestFactory.session(seed_value, MinibossData.data(chance_pct)))
	s.modifiers.set_source(HERO, [Modifier.make(&"power_bonus", 5000.0), Modifier.make(&"max_hp_flat", 100000.0)])
	_started = []
	s.events.encounter_started.connect(func(ids: Array[StringName]) -> void: _started.append(ids.duplicate()))
	return s


func _run_encounters(s: GameSession, count: int) -> void:
	var guard: int = 0
	while _started.size() < count and guard < 4000:
		s.advance(250)
		guard += 1


func _has_miniboss(ids: Array) -> bool:
	return ids.has(MINIBOSS)


# --- the numbers ------------------------------------------------------------------------------------------------------

func test_scale_applies_the_multipliers_of_the_balance_once() -> void:
	var data: GameData = TestFactory.real_data()
	var base: MonsterDef = data.monster(MINIBOSS)
	assert_true(base.is_miniboss, "the monster of the data has the plain stats of its area")
	var scaled: MonsterDef = Miniboss.scale(base, data)
	assert_eq(scaled.hp, int(round(float(base.hp) * float(data.balance_value("miniboss.hp_mult")))))
	assert_eq(scaled.hp, base.hp * 4, "hp_mult 4.0")
	assert_eq(scaled.xp, base.xp * 4, "xp_mult 4.0")
	assert_eq(scaled.gold_min, base.gold_min * 4, "gold_mult 4.0")
	assert_eq(scaled.gold_max, base.gold_max * 4)
	assert_true(scaled is ScaledMonsterDef and (scaled as ScaledMonsterDef).damage_mult == 1.5, "power_mult 1.5")
	assert_true(scaled.is_miniboss)
	assert_same(Miniboss.scale(scaled, data), scaled, "a scaled miniboss is never scaled again")
	assert_eq(base.hp, data.monster(MINIBOSS).hp, "the data is not touched")


func test_the_hits_of_the_miniboss_are_the_plain_ones_times_power_mult() -> void:
	var data: GameData = TestFactory.real_data()
	var base: MonsterDef = data.monster(MINIBOSS)
	var plain: CombatantStats = CombatantStats.for_monster(base, data)
	var scaled: CombatantStats = CombatantStats.for_monster(Miniboss.scale(base, data), data)
	assert_eq(scaled.max_hit, maxi(1, floori(float(plain.max_hit) * 1.5 + 1e-9)))
	assert_eq(scaled.max_hp, base.hp * 4)
	assert_eq(scaled.attack_interval_ms, plain.attack_interval_ms, "the speed is not changed")


func test_pack_is_the_miniboss_and_its_escorts() -> void:
	var data: GameData = MinibossData.data(100)
	var area: AreaDef = data.area(AREA)
	var pack: Array[MonsterDef] = Miniboss.pack(area, RngService.new(9), data)
	assert_eq(pack.size(), 1 + area.miniboss_escorts)
	assert_eq(pack[0].id, MINIBOSS)
	assert_eq(pack[0].hp, data.monster(MINIBOSS).hp * 4)
	for i: int in range(1, pack.size()):
		assert_true(area.monster_ids.has(pack[i].id), "an escort is a monster of the area")
		assert_false(pack[i].is_miniboss)
	assert_eq(Miniboss.pack(AreaDef.new(), RngService.new(9), data), [] as Array[MonsterDef], "an area without a miniboss")


func test_roll_follows_chance_pct() -> void:
	var always: GameData = MinibossData.data(100)
	var never: GameData = MinibossData.data(0)
	var rng := RngService.new(3)
	for _i: int in 30:
		assert_true(Miniboss.roll(always.area(AREA), rng, always))
		assert_false(Miniboss.roll(never.area(AREA), rng, never))
	var plain := RngService.new(3)
	var untouched := RngService.new(3)
	assert_false(Miniboss.roll(AreaDef.new(), plain, always), "no miniboss in the area: false")
	assert_eq(plain.randf(), untouched.randf(), "and no random number consumed")


# --- in the engine -----------------------------------------------------------------------------------------------------

func test_with_chance_100_every_normal_encounter_is_followed_by_the_miniboss() -> void:
	var s: GameSession = _session(100)
	s.combat.start(AREA)
	_run_encounters(s, 14)
	assert_gte(_started.size(), 14)
	var kinds: Array[String] = []  # n = normal, m = miniboss, s = Rift Stone (a stone may appear by chance, F-87)
	for ids: Array in _started:
		kinds.append("m" if _has_miniboss(ids) else ("s" if s.data.has_rift_stone(ids[0]) else "n"))
	for i: int in 13:
		if kinds[i] == "n":
			assert_ne(kinds[i + 1], "n", "a normal encounter is followed by the miniboss (or by a stone that was pending): %s" % [kinds])
		else:
			assert_ne(kinds[i + 1], "m", "no miniboss after a miniboss or a stone: %s" % [kinds])
	assert_eq(kinds[1], "m")
	assert_eq((_started[1] as Array).size(), 1 + 2, "the miniboss and two escorts of the area")
	assert_eq((_started[1] as Array)[0], MINIBOSS)


func test_with_chance_0_there_is_never_a_miniboss() -> void:
	var s: GameSession = _session(0)
	s.combat.start(AREA)
	_run_encounters(s, 10)
	assert_gte(_started.size(), 10)
	for ids: Array in _started:
		assert_false(_has_miniboss(ids))
	assert_false(s.combat.to_save()["miniboss_pending"] if s.combat.to_save().has("miniboss_pending") else false)


func test_the_miniboss_is_in_the_row_with_its_scaled_hp() -> void:
	var s: GameSession = _session(100)
	s.combat.start(AREA)
	var guard: int = 0
	while _started.size() < 2 and guard < 4000:
		s.advance(250)
		guard += 1
	var enemies: Array = s.combat.get_state()["enemies"]
	assert_eq(enemies[0]["monster"], MINIBOSS)
	assert_eq(enemies[0]["max_hp"], s.data.monster(MINIBOSS).hp * 4)


func test_a_pending_rift_stone_goes_first_and_no_roll_follows_a_stone() -> void:
	var s: GameSession = _session(100)
	var d: Dictionary = s.combat.to_save()
	d["stone"] = {"since": int(s.data.balance_value("rift_stone.pity_kills")) - 1, "pending": false, "stone_id": ""}
	s.combat.from_save(d)
	s.combat.start(AREA)
	_run_encounters(s, 5)
	# the first kill makes the stone appear (pity), so the first encounter ends with a stone pending: no miniboss roll
	assert_false(_has_miniboss(_started[0]))
	assert_false(_has_miniboss(_started[1]), "the stone, not the miniboss, is the second encounter")
	assert_true(s.data.has_rift_stone((_started[1] as Array)[0]), "the Rift Stone")
	assert_false(_has_miniboss(_started[2]), "a stone is not a normal encounter: no roll after it")
	assert_true(_has_miniboss(_started[3]), "after a normal encounter the miniboss comes (chance 100)")


func test_a_miniboss_does_not_roll_another_and_counts_as_kills() -> void:
	var s: GameSession = _session(100)
	s.combat.start(AREA)
	_run_encounters(s, 4)
	assert_gte(s.combat.kills(MINIBOSS), 1, "the miniboss counts as a kill (F-87)")
	assert_false(_has_miniboss(_started[2]), "no miniboss right after a miniboss")


func test_the_pending_miniboss_is_saved_and_the_fight_resumes_with_the_scaled_hp() -> void:
	var s: GameSession = _session(100)
	s.combat.start(AREA)
	var guard: int = 0
	while s.combat.state() != CombatEngine.STATE_BETWEEN and guard < 4000:
		s.advance(100)
		guard += 1
	assert_true(s.combat.to_save()["miniboss_pending"], "a miniboss waits after the first encounter")
	var twin: GameSession = autofree(TestFactory.session(5, MinibossData.data(100)))
	twin.modifiers.set_source(HERO, [Modifier.make(&"power_bonus", 5000.0), Modifier.make(&"max_hp_flat", 100000.0)])
	twin.combat.from_save(JSON.parse_string(JSON.stringify(s.combat.to_save())) as Dictionary)
	assert_true(twin.combat.to_save()["miniboss_pending"])
	_started = []
	twin.events.encounter_started.connect(func(ids: Array[StringName]) -> void: _started.append(ids.duplicate()))
	guard = 0
	while _started.is_empty() and guard < 100:
		twin.advance(250)
		guard += 1
	assert_true(_has_miniboss(_started[0]), "the next encounter after the load is the miniboss")
	var hp_before: int = (twin.combat.get_state()["enemies"] as Array)[0]["hp"]
	assert_eq(hp_before, s.data.monster(MINIBOSS).hp * 4)
	var again: GameSession = autofree(TestFactory.session(5, MinibossData.data(100)))
	again.combat.from_save(JSON.parse_string(JSON.stringify(twin.combat.to_save())) as Dictionary)
	assert_eq((again.combat.get_state()["enemies"] as Array)[0]["max_hp"], s.data.monster(MINIBOSS).hp * 4, "scaled once")
