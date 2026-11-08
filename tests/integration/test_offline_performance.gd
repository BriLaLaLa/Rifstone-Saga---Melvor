extends GutTest
## M9-07 performance: 12 h of offline combat against packs of 6 monsters with the real OfflineSimulator takes < 10 s
## (docs/06_ROADMAP.md M9 criteria). Real data; the area's packs are replaced by the 6-monster pack of
## `rift_threshold` only, so every fight is a full group. Two scenarios: an overpowered hero (never dies: the most
## events possible) and a hero who dies early (the rest of the time passes empty). The times go in the GUT output.

const SEED: int = 99
const AREA: StringName = &"rift_threshold"
const SWORD: StringName = &"emberbronze_sword"
const CAP_MS: int = 43200000
const LIMIT_MS: int = 10000
const HERO: StringName = &"test:hero"
const GROUP_SIZE: int = 6


func _six_pack_data() -> GameData:
	var data: GameData = GameData.load_from_dirs(TestFactory.REAL_CONTENT_ROOT, TestFactory.CONFIG_ROOT)
	var area: AreaDef = data.area(AREA)
	var found: bool = false
	# Weights of the other packs go to 0, the list keeps its indexes (Rift Stones summon packs by index).
	for pack: PackDef in area.packs:
		pack.weight = 1 if pack.monster_ids.size() == GROUP_SIZE else 0
		found = found or pack.weight == 1
	assert(found, "rift_threshold has a 6-monster pack")
	return data


func _session(power: float, hp: float, dr: float) -> GameSession:
	var s: GameSession = autofree(TestFactory.session(SEED, _six_pack_data()))
	TestFactory.set_character_level(s, 65)
	assert_true(s.equipment.equip(TestFactory.give_piece(s, SWORD)).ok)
	s.modifiers.set_source(HERO, [Modifier.make(&"power_bonus", power), Modifier.make(&"max_hp_flat", hp),
			Modifier.make(&"damage_reduction", dr), Modifier.make(&"evasion_bonus", dr * 1000.0)])
	TestFactory.make_roomy(s)
	return s


func _measure(s: GameSession, label: String) -> Dictionary:
	assert_true(s.combat.start(AREA).ok, "combat starts in %s" % AREA)
	var started_us: int = Time.get_ticks_usec()
	var summary: OfflineSummary = await OfflineSimulator.new().run(s, CAP_MS, true, false)
	var took_ms: int = (Time.get_ticks_usec() - started_us) / 1000
	var kills: int = 0
	for n: int in summary.kills.values():
		kills += n
	gut.p("PERF %s: 12 h in %d ms, kills %d, deaths %d, pieces stored %d, dismantled %d" % [
		label, took_ms, kills, summary.deaths, summary.pieces_stored, summary.pieces_dismantled])
	return {"ms": took_ms, "kills": kills, "summary": summary}


func test_twelve_hours_with_groups_of_six_never_dying_under_ten_seconds() -> void:
	var r: Dictionary = await _measure(_session(100000.0, 100000.0, 80.0), "overpowered")
	assert_gt(r["kills"], 1000, "a real workload: thousands of monsters")
	assert_eq(r["summary"].deaths, 0)
	assert_eq(r["summary"].elapsed_ms, CAP_MS)
	assert_lt(r["ms"], LIMIT_MS, "12 h of groups of 6 in < 10 s")


func test_twelve_hours_with_groups_of_six_dying_early_under_ten_seconds() -> void:
	var r: Dictionary = await _measure(_session(300.0, 3000.0, 30.0), "moderate hero")
	assert_lt(r["ms"], LIMIT_MS, "12 h of groups of 6 in < 10 s")
