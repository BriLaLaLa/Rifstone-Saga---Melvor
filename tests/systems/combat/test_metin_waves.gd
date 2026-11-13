extends GutTest
## F-126 (docs/02_FORMULAS.md §5f): the waves of a Rift Stone: thresholds (the first hit, 75, 50, 25), the monsters of a wave,
## the summoned give nothing, and the save in the middle of a wave. Fixture data (`test_stone_area`: monster A only; the stone
## `test_stone` is level 5, 450 hp) with the real balance; fixed seeds.

const AREA: StringName = &"test_stone_area"
const STONE: StringName = &"test_stone"
const MONSTER_A: StringName = &"test_monster_a"
const SOURCE: StringName = &"test:boost"
const THRESHOLDS: Array[int] = [100, 75, 50, 25]


func _session(seed_value: int = 5) -> GameSession:
	return autofree(TestFactory.session(seed_value, TestFactory.fixture_data()))


func _no_fired() -> Array[int]:
	return []


# A save in the stone state: the stone with `stone_hp` and the thresholds already `fired`, then the `extra` enemies.
func _save(stone_hp: int, fired: Array, extra: Array = []) -> Dictionary:
	var enemies: Array = [{"monster": String(STONE), "hp": stone_hp, "timer_ms": 3000}]
	enemies.append_array(extra)
	return {"state": "riftstone", "area": String(AREA), "player_hp": 100000, "player_timer_ms": 0, "hand": 0, "between_ms": 0,
		"loot": {}, "kills": {}, "deaths": 0, "food_eaten": 0, "enemies": enemies,
		"stone": {"since": 0, "pending": false, "stone_id": ""}, "wave": {"fired": fired}}


# --- the pure threshold function (the examples of F-126) ---

func test_waves_crossed_examples() -> void:
	assert_eq(StoneFight.waves_crossed(960, 1000, _no_fired(), THRESHOLDS), [100] as Array[int], "the first hit")
	assert_eq(StoneFight.waves_crossed(749, 1000, [100] as Array[int], THRESHOLDS), [75] as Array[int], "749 is under 75%")
	assert_eq(StoneFight.waves_crossed(750, 1000, [100] as Array[int], THRESHOLDS), [] as Array[int], "750 is not (strict)")
	assert_eq(StoneFight.waves_crossed(240, 1000, [100, 75] as Array[int], THRESHOLDS), [50, 25] as Array[int],
			"one hit across two thresholds fires both, in descending order")
	assert_eq(StoneFight.waves_crossed(200, 1000, _no_fired(), THRESHOLDS), [100, 75, 50, 25] as Array[int],
			"a single hit 1000 -> 200 fires the four")
	assert_eq(StoneFight.waves_crossed(10, 1000, [100, 75, 50, 25] as Array[int], THRESHOLDS), [] as Array[int],
			"a threshold fires once")


func test_thresholds_come_from_the_balance() -> void:
	assert_eq(StoneFight.thresholds(TestFactory.real_data()), THRESHOLDS)


# --- the monsters of a wave ---

func test_a_wave_has_wave_size_monsters_at_the_level_of_the_stone() -> void:
	var data: GameData = TestFactory.real_data()
	var def: RiftStoneDef = data.rift_stone(&"whisper_wood_stone_15")
	var rng := RngService.new(77)
	for _i: int in 20:
		var defs: Array[MonsterDef] = StoneFight.wave_defs(def, data, rng)
		assert_eq(defs.size(), int(data.balance_value("metin.wave_size")), "the last pack is truncated")
		for monster: MonsterDef in defs:
			assert_eq([monster.attack_level, monster.power_level, monster.defence_level], [15, 15, 15])
			assert_eq(monster.hp, data.monster(monster.id).hp, "hp unchanged")
			assert_eq(monster.xp, data.monster(monster.id).xp, "rewards unchanged")


func test_the_level_is_capped_at_99() -> void:
	var monster: MonsterDef = TestFactory.real_data().monster(&"plains_boar")
	assert_eq(StoneFight.scaled(monster, 120).attack_level, 99)
	assert_eq(StoneFight.scaled(monster, 95).power_level, 95)
	assert_ne(monster.attack_level, 99, "the data monster is not changed")


func test_wave_packs_limit_the_draw() -> void:
	var data: GameData = GameData.load_from_dirs(TestFactory.REAL_CONTENT_ROOT, TestFactory.CONFIG_ROOT)
	var def: RiftStoneDef = data.rift_stone(&"redrock_plains_stone_5")
	def.wave_packs = [0] as Array[int]  # pack 0 of the Plains: one plains_boar
	var rng := RngService.new(5)
	for monster: MonsterDef in StoneFight.wave_defs(def, data, rng):
		assert_eq(monster.id, &"plains_boar")


# --- in the fight ---

func test_first_hit_then_the_thresholds_summon_in_order() -> void:
	var s: GameSession = _session()
	s.combat.from_save(_save(450, []))
	var waves: Array = []
	s.events.rift_stone_wave.connect(func(id: StringName, threshold: int, count: int) -> void: waves.append([id, threshold, count]))
	var guard: int = 0
	while waves.is_empty() and guard < 200:
		s.combat.advance(500)
		guard += 1
	assert_eq(waves, [[STONE, 100, 7]], "the first hit calls 7 monsters")
	var state: Dictionary = s.combat.get_state()
	assert_eq((state["enemies"] as Array).size(), 8)
	assert_eq(state["stone"]["fired"], [100])
	assert_eq(state["stone"]["id"], STONE)
	assert_eq(state["stone"]["level"], 5)
	assert_eq(state["stone"]["max_hp"], 450)
	for i: int in range(1, 8):
		assert_true(state["enemies"][i]["summoned"], "the new monsters are summoned")
	# one hit across two thresholds (the stone at 44% with the first hit and 75% fired): 75 was crossed too.
	var other: GameSession = _session(9)
	other.combat.from_save(_save(200, [100]))
	var crossed: Array = []
	other.events.rift_stone_wave.connect(func(_id: StringName, threshold: int, _count: int) -> void: crossed.append(threshold))
	guard = 0
	while crossed.is_empty() and guard < 200:
		other.combat.advance(500)
		guard += 1
	assert_eq(crossed, [75, 50], "both at once, descending")
	assert_eq((other.combat.get_state()["enemies"] as Array).size(), 1 + 14)


func test_a_stone_killed_by_one_hit_calls_nobody() -> void:
	var s: GameSession = _session()
	s.modifiers.set_source(SOURCE, [Modifier.make(&"power_bonus", 5000.0)])
	s.combat.from_save(_save(450, []))
	var count: Array[int] = [0]
	s.events.rift_stone_wave.connect(func(_id: StringName, _t: int, _c: int) -> void: count[0] += 1)
	var guard: int = 0
	while s.combat.state() == CombatEngine.STATE_RIFTSTONE and guard < 200:
		s.combat.advance(500)
		guard += 1
	assert_eq(s.combat.state(), CombatEngine.STATE_BETWEEN)
	assert_eq(count[0], 0, "a dead stone summons nothing")


func test_summoned_monsters_give_no_xp_gold_drops_or_kills() -> void:
	var s: GameSession = _session()
	s.modifiers.set_source(SOURCE, [Modifier.make(&"power_bonus", 5000.0)])
	var summoned: Dictionary = {"monster": String(MONSTER_A), "hp": 20, "timer_ms": 2800, "summoned": true}
	s.combat.from_save(_save(0, [100], [summoned, summoned]))  # the stone is already dead
	var xp: int = s.character.get_xp()
	var gold: int = s.wallet.get_gold()
	var guard: int = 0
	while s.combat.state() == CombatEngine.STATE_RIFTSTONE and guard < 200:
		s.combat.advance(500)
		guard += 1
	assert_eq(s.combat.state(), CombatEngine.STATE_BETWEEN, "the encounter ends when everything is dead")
	assert_eq(s.character.get_xp(), xp)
	assert_eq(s.wallet.get_gold(), gold)
	assert_true(s.combat.total_kills().is_empty(), "no kills")
	assert_eq(s.combat.loot.used(), 0, "no drops")


func test_save_in_the_middle_of_a_wave_and_the_fired_thresholds_survive() -> void:
	var s: GameSession = _session(21)
	s.combat.from_save(_save(450, []))
	var guard: int = 0
	while (s.combat.get_state()["stone"]["fired"] as Array).is_empty() and guard < 200:
		s.combat.advance(500)
		guard += 1
	var saved: Dictionary = s.combat.to_save()
	assert_eq(saved["wave"], {"fired": [100]})
	var other: GameSession = _session(21)
	other.combat.from_save(saved)
	assert_eq(other.combat.to_save(), saved, "save -> load -> save")
	assert_eq(other.combat.get_state()["stone"]["fired"], [100], "the first hit is not called again")
	assert_eq((other.combat.get_state()["enemies"] as Array).size(), 8)
	# the summoned of the saved fight come back at the level of the stone and still summoned
	assert_true(other.combat.get_state()["enemies"][3]["summoned"])
	# both sessions go on identically
	s.combat.advance(1000)
	other.combat.advance(1000)
	assert_eq(other.combat.to_save(), s.combat.to_save())


func test_steps_do_not_change_a_fight_with_waves() -> void:
	var results: Array[Dictionary] = []
	for step_ms: int in [9000, 1000, 100]:
		var s: GameSession = _session(17)
		s.combat.from_save(_save(450, []))
		for i: int in 9000 / step_ms:
			s.combat.advance(step_ms)
		results.append(s.combat.to_save())
	assert_eq(results[1], results[0], "1x9000 = 9x1000")
	assert_eq(results[2], results[0], "1x9000 = 90x100")


func test_a_malformed_wave_is_empty_and_unknown_thresholds_are_dropped() -> void:
	var s: GameSession = _session()
	var save: Dictionary = _save(300, [100, 33, "x", 100])
	s.combat.from_save(save)
	assert_eq(s.combat.get_state()["stone"]["fired"], [100])
	save["wave"] = "bad"
	s.combat.from_save(save)
	assert_eq(s.combat.get_state()["stone"]["fired"], [])
