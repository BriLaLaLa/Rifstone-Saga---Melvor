extends GutTest
## M15-08: 12 hours offline with a Monolith in every encounter (chance 100%) and the full 28 summoned monsters (4 waves of
## wave_size, F-126). Measures the time; the bound is the 10 s target of the GDD (§12) with the same slack as the other offline tests.

const SEED: int = 15081
const AREA: StringName = &"redrock_plains"
const SWORD: StringName = &"emberbronze_sword"
const HERO: StringName = &"test:hero"
const CAP_MS: int = 43200000


func test_twelve_hours_with_monoliths_of_28_summons() -> void:
	var data: GameData = GameData.load_from_dirs(TestFactory.REAL_CONTENT_ROOT, TestFactory.CONFIG_ROOT)
	data.area(AREA).rift_stone_chance_pct = 100.0
	(data._balance["metin"] as Dictionary)["hp_base"] = 3000  # tough stone: it lives long enough for the four waves
	var s: GameSession = autofree(TestFactory.session(SEED, data))
	assert_true(s.equipment.equip(TestFactory.give_piece(s, SWORD)).ok)
	# Strong enough to survive for a long time, weak enough that every wave is summoned.
	s.modifiers.set_source(HERO, [Modifier.make(&"power_bonus", 5000.0), Modifier.make(&"max_hp_flat", 100000.0), Modifier.make(&"evasion_bonus", 100000.0)])
	TestFactory.make_roomy(s)
	var stones: Array[int] = [0, 0]
	s.events.rift_stone_appeared.connect(func(_id: StringName) -> void: stones[0] += 1)
	s.events.monster_killed.connect(func(_i: int, id: StringName) -> void:
		if not data.has_rift_stone(id):
			stones[1] += 1)
	assert_true(s.combat.start(AREA).ok)
	var started_us: int = Time.get_ticks_usec()
	var summary: OfflineSummary = await OfflineSimulator.new().run(s, CAP_MS, true, false)
	var took_ms: int = (Time.get_ticks_usec() - started_us) / 1000
	gut.p("12 h offline with Monoliths: %d ms, %d Monoliths, %d other kills, stops %s" % [took_ms, stones[0], stones[1], summary.stop_reasons])
	assert_gt(stones[0], 0, "Monoliths appeared")
	assert_gte(stones[1], 25 * stones[0], "about 28 summoned monsters per Monolith (4 waves of wave_size)")
	assert_lt(took_ms, 120000, "sanity bound only, like test_twelve_hours_of_combat_is_simulated_and_timed")
